# frozen_string_literal: true

module FlowState
  # Model for logging transition changes to
  class TransitionArtefact < ActiveRecord::Base
    self.table_name = 'flow_state_transition_artefacts'

    belongs_to :transition,
               class_name: 'FlowState::FlowTransition',
               foreign_key: :transition_id,
               inverse_of: :flow_artefacts
  end
end
