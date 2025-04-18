# frozen_string_literal: true

require_relative 'lib/flow_state/version'

Gem::Specification.new do |spec|
  spec.name = 'flow_state'
  spec.version = FlowState::VERSION
  spec.authors = ['Chris Garrett']
  spec.email = ['chris@c8va.com']

  spec.summary = 'Active Record backed State Machine for Rails.'
  spec.description = 'FlowState is a minimal, database-backed state machine for Rails. It tracks transitions across multi-step workflows. Built for real-world workflows where state spans multiple jobs.' # rubocop:disable Layout/LineLength
  spec.homepage = 'https://www.chrsgrrtt.com/flow-state-gem'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.0.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/hyperlaunch/flow-state'
  spec.metadata['changelog_uri'] = 'https://github.com/hyperlaunch/flow-state/changelog.md'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end

  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'rails', '~> 8.0'

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
  spec.metadata['rubygems_mfa_required'] = 'true'
end
