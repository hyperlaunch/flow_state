# frozen_string_literal: true

require 'bundler/setup'
require 'active_record'
require 'flow_state'
require 'rails/generators'
require 'active_support'
require 'active_support/core_ext'
require 'fileutils'

ActiveRecord::Base.establish_connection(
  adapter: 'sqlite3',
  database: ':memory:'
)

ActiveRecord::Schema.define do
  create_table :flow_state_flows, force: true do |t|
    t.string :current_state, null: false
    t.json   :payload
    t.timestamps
  end

  create_table :flow_state_flow_transitions, force: true do |t|
    t.references :flow, null: false
    t.string :transitioned_from, null: false
    t.string :transitioned_to,   null: false
    t.timestamps
  end
end

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
