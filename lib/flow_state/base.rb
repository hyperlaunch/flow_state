# frozen_string_literal: true

module FlowState
  # Base Model to be extended by app models
  class Base < ActiveRecord::Base
    class UnknownStateError < StandardError; end
    class InvalidTransitionError < StandardError; end
    class PayloadValidationError < StandardError; end

    DEPRECATOR = ActiveSupport::Deprecation.new(FlowState::VERSION, 'FlowState')

    self.table_name = 'flow_state_flows'

    has_many :flow_transitions,
             class_name: 'FlowState::FlowTransition',
             foreign_key: :flow_id,
             inverse_of: :flow,
             dependent: :destroy

    class << self
      def state(name, error: false)
        name = name.to_sym
        all_states << name
        error_states << name if error
      end

      def error_state(name)
        DEPRECATOR.warn(
          'FlowState::Base.error_state is deprecated. ' \
          'Use state(name, error: true) instead.'
        )

        state(name, error: true)
      end

      def initial_state(name = nil)
        name ? @initial_state = name.to_sym : @initial_state
      end

      def prop(name, type)
        payload_schema[name.to_sym] = type
        define_method(name) { payload&.dig(name.to_s) }
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
    end

    validates :current_state, presence: true
    validate :validate_payload

    after_initialize { self.current_state ||= resolve_initial_state }

    def transition!(from:, to:, after_transition: nil) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
      from = Array(from).map(&:to_sym)
      to   = to.to_sym

      ensure_known_states!(from + [to])

      with_lock do
        unless from.include?(current_state&.to_sym)
          raise InvalidTransitionError,
                "state #{current_state} not in #{from} (#{from.inspect}->#{to.inspect}"
        end

        transaction do
          flow_transitions.create!(
            transitioned_from: current_state,
            transitioned_to: to
          )
          update!(current_state: to)
        end
      end

      after_transition&.call
    end

    def errored?
      self.class.error_states.include?(current_state&.to_sym)
    end

    private

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
        raise PayloadValidationError, "#{key} missing" if v.nil?
        raise PayloadValidationError, "#{key} must be #{klass}" unless v.is_a?(klass)
      end
    rescue PayloadValidationError => e
      errors.add(:payload, e.message)
    end
  end
end
