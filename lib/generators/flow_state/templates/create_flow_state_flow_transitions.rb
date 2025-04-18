# frozen_string_literal: true

# Tbale for flow transition changes
class CreateFlowStateFlowTransitions < ActiveRecord::Migration[8.0]
  def change
    create_table :flow_state_flow_transitions do |t|
      t.references :flow, null: false, foreign_key: { to_table: :flow_state_flows }
      t.string :transitioned_from, null: false
      t.string :transitioned_to,   null: false
      t.timestamps
    end
  end
end
