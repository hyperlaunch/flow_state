# frozen_string_literal: true

module FlowState
  # Base Model to be extended by app flows
  class Base < ActiveRecord::Base # rubocop:disable Metrics/ClassLength
    class UnknownStateError < StandardError; end
    class InvalidTransitionError < StandardError; end
    class PayloadValidationError < StandardError; end
    class PropsValidationError < StandardError; end
    class GuardFailedError < StandardError; end
    class UnknownArtefactError < StandardError; end
    class MissingInitialStateError   < StandardError; end
    class MissingCompletedStateError < StandardError; end

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

      def completed_state(name = nil)
        name ? @completed_state = name.to_sym : @completed_state
      end

      def destroy_on_complete(flag)
        @destroy_on_complete = flag || false
      end

      def destroy_on_complete?
        !!@destroy_on_complete
      end

      def prop(name, type)
        props_schema[name.to_sym] = type
        define_method(name) { props&.dig(name.to_s) }
      end

      def persists(name, type)
        artefact_schema[name.to_sym] = type
      end

      def all_states
        @all_states ||= []
      end

      def error_states
        @error_states ||= []
      end

      def props_schema
        @props_schema ||= {}
      end

      def artefact_schema
        @artefact_schema ||= {}
      end
    end

    validates :current_state, presence: true
    validate :validate_props
    after_commit :destroy_if_complete, on: :update

    after_initialize :validate_initial_states!, if: :new_record?
    after_initialize :assign_initial_state, if: :new_record?

    def transition!(from:, to:, guard: nil, persist: nil, after_transition: nil, &block)
      setup_transition!(from, to, guard, persist, &block)
      perform_transition!(to, persist)
      after_transition&.call
    end

    def errored?
      self.class.error_states.include?(current_state&.to_sym)
    end

    def completed?
      self.class.completed_state && current_state&.to_sym == self.class.completed_state
    end

    def destroy_if_complete
      return unless self.class.destroy_on_complete?

      destroy! if completed?
    end

    private

    def validate_initial_states!
      init_state = self.class.initial_state
      comp_state = self.class.completed_state

      raise MissingInitialStateError,   "#{self.class} must declare initial_state"   unless init_state
      raise MissingCompletedStateError, "#{self.class} must declare completed_state" unless comp_state

      unknown = [init_state, comp_state] - self.class.all_states
      raise UnknownStateError, "unknown #{unknown.join(', ')}" if unknown.any?
    end

    def assign_initial_state
      self.current_state ||= self.class.initial_state
    end

    def setup_transition!(from, to, guard, persists, &block)
      @from_states = Array(from).map(&:to_sym)
      @to_state    = to.to_sym

      ensure_known_states!(@from_states + [@to_state])
      run_guard!(guard) if guard
      @artefact_name, @artefact_data = load_artefact(persists, &block) if persists
    end

    def perform_transition!(to, persists) # rubocop:disable Metrics/MethodLength
      transaction do
        save! if changed?
        with_lock do
          ensure_valid_from_state!(@from_states, to)
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
        raise PayloadValidationError,
              "artefact #{@artefact_name} must be #{expected}"
      end

      @tr.flow_artefacts.create!(
        name: @artefact_name.to_s,
        payload: @artefact_data
      )
    end

    def ensure_known_states!(states)
      unknown = states - self.class.all_states
      raise UnknownStateError, "unknown #{unknown.join(', ')}" if unknown.any?
    end

    def validate_props
      schema = self.class.props_schema
      return if schema.empty?

      schema.each do |key, klass|
        v = props&.dig(key.to_s)
        raise PropsValidationError, "#{key} missing" unless v
        raise PropsValidationError, "#{key} must be #{klass}" unless v.is_a?(klass)
      end
    rescue PropsValidationError => e
      errors.add(:props, e.message)
    end
  end
end
