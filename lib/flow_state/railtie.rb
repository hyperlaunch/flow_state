# frozen_string_literal: true

require 'rails/railtie'

module FlowState
  # Auto-load our generators etc
  class Railtie < Rails::Railtie
    generators do
      require_relative '../generators/flow_state/install_generator'
    end

    initializer 'flow_state.configure' do
      Rails.logger&.info '[FlowState] Loaded'
    end
  end
end
