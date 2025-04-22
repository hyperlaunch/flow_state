# frozen_string_literal: true

# Tbale for flow transition changes
class CreateFlowStateTransitionArtefacts < ActiveRecord::Migration[8.0]
  def change
    create_table :flow_state_transition_artefacts do |t|
      t.references :transition, null: false, foreign_key: { to_table: :flow_state_flow_transitions }
      t.string :name, null: false
      t.json :payload
      t.timestamps
    end
  end
end
