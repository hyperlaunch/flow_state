# frozen_string_literal: true

RSpec.describe FlowState::Base do # rubocop:disable Metrics/BlockLength
  before do
    stub_const('Flow', Class.new(FlowState::Base) do
      self.table_name = 'flow_state_flows'

      state :draft
      state :review
      state :failed, error: true
      initial_state :draft

      prop :name, String
    end)
  end

  let!(:flow) { Flow.create!(payload: { name: 'Example' }) }

  describe 'initialisation' do
    it 'sets the configured initial state' do
      expect(flow.current_state).to eq('draft')
    end
  end

  describe 'attribute getter' do
    it 'reads from payload' do
      expect(flow.name).to eq('Example')
    end
  end

  describe '#transition!' do
    it 'updates the state and records a FlowTransition row' do
      expect do
        flow.transition!(from: :draft, to: :review)
      end.to change { flow.flow_transitions.count }.by(1)

      expect(flow.reload.current_state).to eq('review')
    end

    it 'runs the after_transition callback' do
      flag = false
      flow.transition!(
        from: :draft,
        to: :review,
        after_transition: -> { flag = true }
      )

      expect(flag).to eq(true)
    end

    it 'raises InvalidTransitionError when current state not in :from list' do
      expect do
        flow.transition!(from: :review, to: :draft)
      end.to raise_error(FlowState::Base::InvalidTransitionError)
    end

    it 'raises UnknownStateError when :to is unknown' do
      expect do
        flow.transition!(from: :draft, to: :bogus)
      end.to raise_error(FlowState::Base::UnknownStateError)
    end
  end

  describe '#errored?' do
    it 'is true when current_state is an error state' do
      flow.update!(current_state: :failed)
      expect(flow).to be_errored
    end
  end

  describe 'payload validation' do
    it 'is invalid when a key is missing' do
      flow = Flow.new
      expect(flow).to be_invalid
      expect(flow.errors[:payload]).to include('name missing')
    end

    it 'is invalid when key type is wrong' do
      flow = Flow.new(payload: { name: 1 })
      expect(flow).to be_invalid
      expect(flow.errors[:payload]).to include('name must be String')
    end
  end

  describe 'initial state validation' do
    it 'raises UnknownStateError if initial_state is not declared' do
      stub_const('BadFlow', Class.new(FlowState::Base) do
        self.table_name = 'flow_state_flows'

        state :only_state
        initial_state :ghost
      end)

      expect do
        BadFlow.create!
      end.to raise_error(FlowState::Base::UnknownStateError)
    end
  end
end
