# frozen_string_literal: true

module FlowState
  # Model for logging transition changes to
  class FlowTransition < ActiveRecord::Base
    self.table_name = 'flow_state_flow_transitions'

    belongs_to :flow,
               class_name: 'FlowState::Base',
               foreign_key: :flow_id,
               inverse_of: :flow_transitions
  end
end
