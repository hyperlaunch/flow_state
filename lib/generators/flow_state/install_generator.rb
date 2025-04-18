# frozen_string_literal: true

require 'rails/generators'
require 'rails/generators/migration'

module FlowState
  module Generators
    # Generates migrations etc for FlowState
    class InstallGenerator < Rails::Generators::Base
      include Rails::Generators::Migration

      source_root File.expand_path('templates', __dir__)

      def create_migrations
        migration_template 'create_flow_state_flows.rb', 'db/migrate/create_flow_state_flows.rb'
        migration_template 'create_flow_state_flow_transitions.rb', 'db/migrate/create_flow_state_flow_transitions.rb'
      end

      # Ensures migration filenames are unique
      def self.next_migration_number(dirname)
        if ActiveRecord::Base.timestamped_migrations
          Time.now.utc.strftime('%Y%m%d%H%M%S')
        else
          format('%.3d', (current_migration_number(dirname) + 1))
        end
      end
    end
  end
end
