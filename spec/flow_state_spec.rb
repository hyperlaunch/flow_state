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

      persist :third_party_api_response, Hash
    end)
  end

  let!(:flow) { Flow.create!(props: { name: 'Example' }) }

  describe 'artefact persistence' do # rubocop:disable Metrics/BlockLength
    it 'raises if you pass an unknown persists name' do
      expect do
        flow.transition!(from: :draft, to: :review, persists: :nope) { {} }
      end.to raise_error(FlowState::Base::UnknownArtefactError)
    end

    it 'raises if the block returns wrong type' do
      expect do
        flow.transition!(from: :draft, to: :review, persists: :third_party_api_response) { 'not a hash' }
      end.to raise_error(FlowState::Base::PayloadValidationError, /must be Hash/)
    end

    it 'saves an artefact record before after_transition' do
      flag = false
      flow.transition!(
        from: :draft,
        to: :review,
        persists: :third_party_api_response,
        after_transition: lambda {
          expect(flow.flow_transitions.last
            .flow_artefacts
            .find_by(name: 'third_party_api_response')).to be_present
          flag = true
        }
      ) { { foo: 'bar' } }

      expect(flag).to be true
      artefact = flow.flow_transitions.last.flow_artefacts.last
      expect(artefact.name).to eq('third_party_api_response')
      expect(artefact.payload).to eq('foo' => 'bar')
    end
  end

  describe 'guards' do
    it 'raises if guard block returns false' do
      expect do
        flow.transition!(
          from: :draft,
          to: :review,
          guard: -> { false }
        )
      end.to raise_error(FlowState::Base::GuardFailedError)
    end

    it 'allows transition when guard is true' do
      flow.transition!(
        from: :draft,
        to: :review,
        guard: -> { true }
      )
      expect(flow.current_state).to eq('review')
    end
  end
end
