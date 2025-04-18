# frozen_string_literal: true

require 'rails/generators'
require 'rails/generators/migration'

module FlowState
  module Generators
    # Generates migrations for FlowState
    class InstallGenerator < Rails::Generators::Base
      include Rails::Generators::Migration

      source_root File.expand_path('templates', __dir__)

      @call_count = 0

      def create_migrations
        migration_template 'create_flow_state_flows.rb', 'db/migrate/create_flow_state_flows.rb'
        migration_template 'create_flow_state_flow_transitions.rb', 'db/migrate/create_flow_state_flow_transitions.rb'
      end

      def self.next_migration_number(_dirname)
        @call_count ||= 0
        timestamp = Time.now.utc.strftime('%Y%m%d%H%M%S').to_i
        migration_number = timestamp + @call_count
        @call_count += 1
        migration_number.to_s
      end
    end
  end
end
