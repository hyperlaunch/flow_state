# frozen_string_literal: true

require 'zeitwerk'

loader = Zeitwerk::Loader.for_gem
loader.ignore("#{__dir__}/generators")
loader.setup

require 'flow_state/railtie' if defined?(Rails::Railtie)

# FlowState library
module FlowState
end
