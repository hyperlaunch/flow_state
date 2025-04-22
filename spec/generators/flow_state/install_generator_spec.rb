# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('../../../lib/generators', __dir__)

require 'spec_helper'
require 'fileutils'
require 'rails/generators'
require 'flow_state/install_generator'

RSpec.describe FlowState::Generators::InstallGenerator, type: :generator do # rubocop:disable Metrics/BlockLength
  destination_root = File.expand_path('tmp/generator_test', __dir__)
  migration_dir = File.join(destination_root, 'db/migrate')

  before do
    FileUtils.rm_rf(destination_root)
    FileUtils.mkdir_p(destination_root)

    Dir.chdir(destination_root) do
      described_class.start
    end
  end

  after do
    FileUtils.rm_rf(File.expand_path('tmp', __dir__))
  end

  let(:migration_files) { Dir.glob(File.join(migration_dir, '*.rb')) }
  let(:filenames)       { migration_files.map { |f| File.basename(f) } }
  let(:timestamps)      { filenames.map { |filename| filename[/^\d{14}/] } }

  it 'creates three migration files' do
    expect(migration_files.size).to eq(3)
  end

  it 'names the migrations correctly' do
    expect(filenames.any? { |name| name.match(/^\d{14}_create_flow_state_flows\.rb$/) }).to be true
    expect(filenames.any? { |name| name.match(/^\d{14}_create_flow_state_flow_transitions\.rb$/) }).to be true
    expect(filenames.any? { |name| name.match(/^\d{14}_create_flow_state_transition_artefacts\.rb$/) }).to be true
  end

  it 'assigns unique timestamps to each migration' do
    expect(timestamps.size).to eq(3)
    expect(timestamps.uniq.size).to eq(3)
  end

  it 'generates correct class definitions inside the migrations' do
    flows_migration        = migration_files.find { |f| f.include?('create_flow_state_flows') }
    transitions_migration  = migration_files.find { |f| f.include?('create_flow_state_flow_transitions') }
    artefacts_migration    = migration_files.find { |f| f.include?('create_flow_state_transition_artefacts') }

    expect(File.read(flows_migration)).to       include('class CreateFlowStateFlows')
    expect(File.read(transitions_migration)).to include('class CreateFlowStateFlowTransitions')
    expect(File.read(artefacts_migration)).to   include('class CreateFlowStateTransitionArtefacts')
  end
end
