RSpec.describe FlowState::Base do
  before do
    stub_const('Flow', Class.new(FlowState::Base) do
      self.table_name = 'flow_state_flows'

      state :draft
      state :review
      state :failed, error: true
      initial_state :draft
      completed_state :draft

      prop :name, String
      persists :third_party_api_response, Hash
    end)
  end

  let!(:flow) { Flow.create!(props: { name: 'Example' }) }

  describe 'artefact persistence' do
    it 'raises if you pass an unknown persists name' do
      expect { flow.transition!(from: :draft, to: :review, persist: :nope) { {} } }
        .to raise_error(FlowState::Base::UnknownArtefactError)
    end

    it 'raises if the block returns wrong type' do
      expect do
        flow.transition!(from: :draft, to: :review, persist: :third_party_api_response) { 'not a hash' }
      end.to raise_error(FlowState::Base::PayloadValidationError, /must be Hash/)
    end

    it 'saves an artefact record before after_transition' do
      flag = false
      flow.transition!(
        from: :draft,
        to: :review,
        persist: :third_party_api_response,
        after_transition: -> { flag = true }
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
        flow.transition!(from: :draft, to: :review, guard: -> { false })
      end.to raise_error(FlowState::Base::GuardFailedError)
    end

    it 'allows transition when guard is true' do
      flow.transition!(from: :draft, to: :review, guard: -> { true })
      expect(flow.current_state).to eq('review')
    end
  end

  describe 'destroy_on_complete' do # rubocop:disable Metrics/BlockLength
    context 'when destroy_on_complete is set' do
      before do
        stub_const('AutoPurgeFlow', Class.new(FlowState::Base) do
          self.table_name = 'flow_state_flows'

          state :draft
          state :complete
          initial_state :draft
          completed_state :complete
          destroy_on_complete
        end)
      end

      it 'destroys the record after reaching the completed state' do
        f = AutoPurgeFlow.create!
        expect { f.transition!(from: :draft, to: :complete) }
          .to change { AutoPurgeFlow.count }.by(-1)
        expect { f.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'when destroy_on_complete is not set' do
      before do
        stub_const('KeepFlow', Class.new(FlowState::Base) do
          self.table_name = 'flow_state_flows'

          state :draft
          state :complete
          initial_state :draft
          completed_state :complete
        end)
      end

      it 'retains the record after reaching the completed state' do
        f = KeepFlow.create!
        expect { f.transition!(from: :draft, to: :complete) }
          .not_to(change { KeepFlow.count })
        f.reload
        expect(f.current_state).to eq('complete')
        expect(f.completed?).to be true
        expect(f.completed_at).to be_a_kind_of(Time)
      end
    end
  end
end
