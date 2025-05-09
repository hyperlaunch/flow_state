# FlowState

> **Model workflows cleanly, explicitly, and with durable persistence between steps.**

---

**FlowState** is a small gem for Rails, for building *state-machine–style* workflows that persist every step, artefact and decision to your database.
Everything is explicit – no metaprogramming, no hidden callbacks, no magic helpers.

Use it when you need to:

* orchestrate multi-step jobs that call external services
* restart safely after crashes or retries
* inspect an audit trail of *what happened, when and why*
* attach typed artefacts (payloads) to a given transition

---

## What’s new in 0.2

| Change                                                | Why it matters                                                                            |
| ----------------------------------------------------- | ----------------------------------------------------------------------------------------- |
| **`initial_state` & `completed_state` are mandatory** | Keeps definitions explicit and prevents silent mis-configuration.                         |
| **`destroy_on_complete` macro**                       | One-liner to delete finished flows – replaces manual `after_transition { destroy! }`.     |
| **`payload` → `props` column**                        | Aligns storage with the `prop` DSL (`flow.props["key"]`). No more auto-generated getters. |
| **`persist` macro → `persists`**                      | Reads better, matches the transition keyword (`persist:`).                                |
| **`completed_at` & `last_errored_at` timestamps**     | Easier querying: `where(completed_at: ..)` or `where.not(last_errored_at: nil)`.          |

See the [migration guide](./MIGRATION_0_1_to_0_2.md) for a drop-in migration.

---

## Quick example – syncing an API and saving the result

### 1  Define the flow

```ruby
class SyncApiFlow < FlowState::Base
  # typed metadata saved in the JSON `props` column
  prop :record_id,      String
  prop :remote_api_id,  String

  # states
  state :pending
  state :fetching
  state :fetched
  state :saving
  state :saved
  state :failed_fetch, error: true
  state :failed_save,  error: true
  state :done

  # mandatory
  initial_state   :pending
  completed_state :done
  destroy_on_complete          # <— remove if you prefer to keep rows

  # artefacts persisted at runtime
  persists :api_response, Hash

  # public API ---------------------------------------------------------

  def start_fetch!
    transition!(from: :pending, to: :fetching)
  end

  def finish_fetch!(response)
    transition!(
      from:   :fetching,
      to:     :fetched,
      persist: :api_response,
      after_transition: -> { SaveJob.perform_later(id) }
    ) { response }
  end

  def fail_fetch!
    transition!(from: :fetching, to: :failed_fetch)
  end

  def start_save!
    transition!(from: :fetched, to: :saving)
  end

  def finish_save!
    transition!(from: :saving, to: :saved, after_transition: -> { complete! })
  end

  def fail_save!
    transition!(from: :saving, to: :failed_save)
  end

  def complete!
    transition!(from: :saved, to: :done)
  end
end
```

### 2  Kick it off

```ruby
flow = SyncApiFlow.create!(props: {
  "record_id"     => record.id,
  "remote_api_id" => remote_id
})

flow.start_fetch!
FetchJob.perform_later(flow.id)
```

### 3  Jobs move the flow

```ruby
class FetchJob < ApplicationJob
  def perform(flow_id)
    flow = SyncApiFlow.find(flow_id)

    response = ThirdParty::Client.new(flow.props["remote_api_id"]).get
    flow.finish_fetch!(response)
  rescue StandardError => e
    begin
      flow.fail_fetch!
    rescue StandardError
      nil
    end
    raise e
  end
end

class SaveJob < ApplicationJob
  def perform(flow_id)
    flow = SyncApiFlow.find(flow_id)

    flow.start_save!

    MyRecord.find(flow.props["record_id"]).update!(payload: artefact(flow, :api_response))

    flow.finish_save!
  rescue StandardError => e
    begin
      flow.fail_save!
    rescue StandardError
      nil
    end
    raise e
  end
  end

  private

  def artefact(flow, name)
    flow.flow_artefacts.find_by!(name: name.to_s).payload
  end
end
```

That’s it – every step, timestamp, artefact and error is stored automatically.

---

## API reference

### DSL macros

| Macro                             | Description                                                           |
| --------------------------------- | --------------------------------------------------------------------- |
| `state :name, error: false`       | Declare a state. `error: true` marks it as a failure state.           |
| `initial_state :name`             | **Required.** First state assigned to new flows.                      |
| `completed_state :name`           | **Required.** Terminal state that marks the flow as finished.         |
| `destroy_on_complete(flag: true)` | Delete the row automatically once the flow reaches `completed_state`. |
| `prop :key, Type`                 | Typed key stored in JSONB `props`. Access via `flow.props["key"]`.    |
| `persists :name, Type`            | Declare an artefact that can be saved during a transition.            |

### Instance helpers

| Method                                                                             | Use                                                                            |
| ---------------------------------------------------------------------------------- | ------------------------------------------------------------------------------ |
| `transition!(from:, to:, guard: nil, persist: nil, after_transition: nil) { ... }` | Perform a state change with optional guard, artefact persistence and callback. |
| `completed?`                                                                       | `true` if `current_state == completed_state`.                                  |
| `errored?`                                                                         | `true` if the current state is marked `error: true`.                           |

---

## Installation

```bash
bundle add flow_state
bin/rails generate flow_state:install
bin/rails db:migrate
```

Follow the [migration guide](./MIGRATION_0_1_to_0_2.md) if you’re upgrading from 0.1.

---

## License

MIT
