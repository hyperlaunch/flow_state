# frozen_string_literal: true

module FlowState
  # Base Model to be extended by app flows
  class Base < ActiveRecord::Base # rubocop:disable Metrics/ClassLength
    class UnknownStateError      < StandardError; end
    class InvalidTransitionError < StandardError; end
    class PayloadValidationError < StandardError; end
    class GuardFailedError       < StandardError; end
    class UnknownArtefactError   < StandardError; end

    DEPRECATOR = ActiveSupport::Deprecation.new(FlowState::VERSION, 'FlowState')

    self.table_name = 'flow_state_flows'

    has_many :flow_transitions,
             class_name: 'FlowState::FlowTransition',
             foreign_key: :flow_id,
             inverse_of: :flow,
             dependent: :destroy

    has_many :flow_artefacts, through: :flow_transitions

    class << self
      def state(name, error: false)
        name = name.to_sym
        all_states << name
        error_states << name if error
      end

      def initial_state(name = nil)
        name ? @initial_state = name.to_sym : @initial_state
      end

      def prop(name, type)
        payload_schema[name.to_sym] = type
        define_method(name) { payload&.dig(name.to_s) }
      end

      def persist(name, type)
        artefact_schema[name.to_sym] = type
      end

      def all_states
        @all_states ||= []
      end

      def error_states
        @error_states ||= []
      end

      def payload_schema
        @payload_schema ||= {}
      end

      def artefact_schema
        @artefact_schema ||= {}
      end
    end

    validates :current_state, presence: true
    validate :validate_payload

    after_initialize { self.current_state ||= resolve_initial_state }

    # Public API: handles state change, guards, artefacts and callback
    def transition!(from:, to:, guard: nil, persists: nil, after_transition: nil, &block)
      setup_transition!(from, to, guard, persists, &block)
      perform_transition!(to, persists)
      after_transition&.call
    end

    def errored?
      self.class.error_states.include?(current_state&.to_sym)
    end

    private

    # 1) validate inputs, run guard, capture artefact info
    def setup_transition!(from, to, guard, persists, &block)
      @from_states = Array(from).map(&:to_sym)
      @to_state    = to.to_sym

      ensure_known_states!(@from_states + [@to_state])
      run_guard!(guard) if guard
      @artefact_name, @artefact_data = load_artefact(persists, &block) if persists
    end

    # 2) inside DB lock + tx create transition, update state, persist artefact
    def perform_transition!(to, persists)
      with_lock do
        ensure_valid_from_state!(@from_states, to)
        transaction do
          @tr = flow_transitions.create!(
            transitioned_from: current_state,
            transitioned_to: to
          )
          update!(current_state: to)
          persist_artefact! if persists
        end
      end
    end

    def run_guard!(guard)
      raise GuardFailedError, "guard failed for #{@to_state}" unless instance_exec(&guard)
    end

    def load_artefact(persists)
      name = persists.to_sym
      schema = self.class.artefact_schema
      raise UnknownArtefactError, "#{name} not declared" unless schema.key?(name)

      data = yield
      [name, data]
    end

    def ensure_valid_from_state!(from_states, to)
      return if from_states.include?(current_state&.to_sym)

      raise InvalidTransitionError,
            "state #{current_state} not in #{from_states.inspect} -> #{to.inspect}"
    end

    def persist_artefact!
      expected = self.class.artefact_schema[@artefact_name]
      unless @artefact_data.is_a?(expected)
        raise PayloadValidationError, "artefact #{@artefact_name} must be #{expected}"
      end

      @tr.flow_artefacts.create!(
        name: @artefact_name.to_s,
        payload: @artefact_data
      )
    end

    def resolve_initial_state
      init = self.class.initial_state || self.class.all_states.first
      ensure_known_states!([init]) if init
      init
    end

    def ensure_known_states!(states)
      unknown = states - self.class.all_states
      raise UnknownStateError, "unknown #{unknown.join(', ')}" if unknown.any?
    end

    def validate_payload
      schema = self.class.payload_schema
      return if schema.empty?

      schema.each do |key, klass|
        v = payload&.dig(key.to_s)
        raise PayloadValidationError, "#{key} missing" unless v
        raise PayloadValidationError, "#{key} must be #{klass}" unless v.is_a?(klass)
      end
    rescue PayloadValidationError => e
      errors.add(:payload, e.message)
    end
  end
end
