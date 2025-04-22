# FlowState

> **Model workflows cleanly, explicitly, and with durable persistence between steps.**

---

**FlowState** provides a clean, Rails-native way to model **stepped workflows** as explicit, durable workflows, with support for persisting arbitrary artefacts between transitions. It lets you define each step, move between states safely, track execution history, and persist payloads ("artefacts") in a type-safe way — without using metaprogramming, `method_missing`, or other hidden magic.

Perfect for workflows that rely on third party resources and integrations.
Every workflow instance, transition and artefact is persisted to the database.
Every change happens through clear, intention-revealing methods that you define yourself.

Built for real-world systems where you need to:
- Track complex, multi-step processes
- Handle failures gracefully with error states and retries
- Persist state and interim data across asynchronous jobs
- Store and type-check arbitrary payloads (artefacts) between steps
- Avoid race conditions via database locks and explicit guards

---

## Key Features

- **Explicit transitions** — Every state change is triggered manually via a method you define.  
- **Full execution history** — Every transition is recorded with timestamps and a history table.  
- **Error recovery** — Model and track failures directly with error states.  
- **Typed payloads** — Strongly-typed metadata attached to every workflow. 
- **Artefact persistence** — Declare named and typed artefacts to persist between specific transitions.  
- **Guard clauses** — Protect transitions with guards that raise if conditions aren’t met.  
- **Persistence-first** — Workflow state and payloads are stored in your database, not memory.  
- **No Magic** — No metaprogramming, no dynamic method generation, no `method_missing` tricks.  

---

## Installation

Add to your bundle:

```bash
bundle add flow_state
```

Generate the tables:

```bash
bin/rails generate flow_state:install
bin/rails db:migrate
```

---

## Example: Saving a third party API response to local database

Suppose you want to build a workflow that:
- Fetches a response from a third party API
- Allows for retrying the fetch on failure
- And persists the response to the workflow
- Then saves the persisted response to the database
- As two separate, encapsulated jobs
- Tracking each step, while protecting against race conditions

---

### Define your Flow

```ruby
class SyncThirdPartyApiFlow < FlowState::Base
  prop :my_record_id, String
  prop :third_party_id, String

  state :pending
  state :picked
  state :fetching_third_party_api
  state :fetched_third_party_api
  state :failed_to_fetch_third_party_api, error: true
  state :saving_my_record
  state :saved_my_record
  state :failed_to_save_my_record, error: true
  state :completed

  persist :third_party_api_response

  initial_state :pending

  def pick!
    transition!(
      from: %i[pending],
      to: :picked,
      after_transition: -> { enqueue_fetch }
    )
  end

  def start_third_party_api_request!
    transition!(
      from: %i[picked failed_to_fetch_third_party_api], 
      to: :fetching_third_party_api
    )
  end

  def finish_third_party_api_request!(result)
    transition!(
      from: :fetching_third_party_api,
      to:   :fetched_third_party_api,
      persists: :third_party_api_response,
      after_transition: -> { enqueue_save }
    ) { result }
  end

  def fail_third_party_api_request!
    transition!(
      from: :fetching_third_party_api, 
      to: :failed_to_fetch_third_party_api
    )
  end
  
  def start_record_save!
    transition!(
      from: %i[fetched_third_party_api failed_to_save_my_record],
      to:   :saving_my_record,
      guard: -> { flow_artefacts.where(name: 'third_party_api_response').exists? }
    )
  end

  def finish_record_save!
    transition!(
      from: :saving_my_record, 
      to: :saved_my_record,
      after_transition: -> { complete! }
    )
  end

  def fail_record_save!
    transition!(
      from: :saving_my_record, 
      to: :failed_to_save_my_record
    )
  end

  def complete!
    transition!(from: :saved_my_record, to: :completed, after_transition: -> { destroy })
  end

  private

  def enqueue_fetch
    FetchThirdPartyJob.perform_later(flow_id: id)
  end

  def enqueue_save
    SaveLocalRecordJob.perform_later(flow_id: id)
  end
end
```

---

### Background Jobs

Each job moves the flow through the correct states, step-by-step.

---

**Create and start the flow**

```ruby
flow = SyncThirdPartyApiFlow.create(
  my_record_id: "my_local_record_id", 
  third_party_id: "some_service_id"
)

flow.pick!
```

---

**Fetch Third Party API Response**

```ruby
class FetchThirdPartyJob < ApplicationJob
  retry_on StandardError,
           wait: ->(executions) { 10.seconds * (2**executions) },
           attempts: 3

  def perform(flow_id:)
    @flow_id = flow_id

    flow.start_third_party_api_request!

    response = ThirdPartyApiRequest.new(id: flow.third_party_id).to_h

    flow.finish_third_party_api_request!(response)
  rescue
    flow.fail_third_party_api_request!
    raise
  end

  private

  def flow
    @flow ||= SyncThirdPartyApiFlow.find(@flow_id)
  end
end
```

---

**Save Result to Local Database**

```ruby
class SaveLocalRecordJob < ApplicationJob
  def perform(flow_id:)
    @flow_id = flow_id

    flow.start_record_save!

    record.update!(payload: third_party_payload)

    flow.finish_record_save!
  rescue
    flow.fail_record_save!
    raise
  end

  private

  def flow
    @flow ||= SyncThirdPartyApiFlow.find(@flow_id)
  end

  def third_party_payload
    flow.flow_artefacts
        .find_by!(name: 'third_party_api_response')
        .payload
  end

  def record
    @record ||= MyRecord.find(flow.my_record_id)
  end
end
```

---

## Why use FlowState?

Because it enables you to model workflows explicitly,
and track real-world execution reliably —  
**without any magic**.

---

## License

MIT.
