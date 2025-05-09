# frozen_string_literal: true

# Table for flow runs
class CreateFlowStateFlows < ActiveRecord::Migration[8.0]
  def change
    create_table :flow_state_flows do |t|
      t.string :type, null: false
      t.string :current_state, null: false
      t.json :props
      t.timestamps
    end
  end
end
