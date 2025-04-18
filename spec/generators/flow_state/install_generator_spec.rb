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
  let(:filenames) { migration_files.map { |f| File.basename(f) } }
  let(:timestamps) { filenames.map { |filename| filename[/^\d{14}/] } }

  it 'creates two migration files' do
    expect(migration_files.size).to eq(2)
  end

  it 'names the migrations correctly' do
    expect(filenames.any? { |name| name.match(/^\d{14}_create_flow_state_flows\.rb$/) }).to be true
    expect(filenames.any? { |name| name.match(/^\d{14}_create_flow_state_flow_transitions\.rb$/) }).to be true
  end

  it 'assigns unique timestamps to each migration' do
    expect(timestamps.size).to eq(2)
    expect(timestamps.uniq.size).to eq(2)
  end

  it 'generates correct class definitions inside the migrations' do
    flow_state_flows = migration_files.find { |f| f.include?('create_flow_state_flows') }
    flow_state_flow_transitions = migration_files.find { |f| f.include?('create_flow_state_flow_transitions') }

    expect(File.read(flow_state_flows)).to include('class CreateFlowStateFlows')
    expect(File.read(flow_state_flow_transitions)).to include('class CreateFlowStateFlowTransitions')
  end
end
