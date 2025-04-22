# FlowState

> **Model workflows without magic.**

---

**FlowState** provides a clean, Rails-native way to model **stepped workflows** as explicit, durable state machines.  
It lets you define each step, move between states deliberately, and track execution — without relying on metaprogramming, `method_missing`, or hidden magic.

Every workflow instance is persisted to the database.  
Every transition is logged.  
Every change happens through clear, intention-revealing methods you define yourself.

Built for real-world systems where you need to:
- Track complex, multi-step processes
- Handle failures gracefully
- Persist state safely across asynchronous jobs

---

## Key Features

- **Explicit transitions** — Every state change is triggered manually via a method you define.
- **Full execution history** — Every transition is recorded with timestamps and a history table.
- **Error recovery** — Model and track failures directly with error states.
- **Typed payloads** — Strongly-typed metadata attached to every workflow.
- **Persistence-first** — Workflow state is stored in your database, not memory.
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

## Example: Syncing song data with Soundcharts

Suppose you want to build a workflow that:
- Gets song metadata from Soundcharts
- Then fetches audience data
- Tracks each step and handles retries on failure

---

### Define your Flow

```ruby
class SyncSoundchartsFlow < FlowState::Base
  prop :song_id, String

  state :pending
  state :picked
  state :syncing_song_metadata
  state :synced_song_metadata
  state :syncing_audience_data
  state :synced_audience_data
  state :completed

  state :failed_to_sync_song_metadata, error: true
  state :failed_to_sync_audience_data, error: true

  initial_state :pending

  def pick!
    transition!(
      from: %i[pending completed failed_to_sync_song_metadata failed_to_sync_audience_data],
      to: :picked,
      after_transition: -> { sync_song_metadata }
    )
  end

  def start_song_metadata_sync!
    transition!(from: %i[picked failed_to_sync_song_metadata], to: :syncing_song_metadata)
  end

  def finish_song_metadata_sync!
    transition!(
      from: :syncing_song_metadata, to: :synced_song_metadata,
      after_transition: -> { sync_audience_data }
    )
  end

  def fail_song_metadata_sync!
    transition!(from: :syncing_song_metadata, to: :failed_to_sync_song_metadata)
  end

  def start_audience_data_sync!
    transition!(
      from: %i[synced_song_metadata failed_to_sync_audience_data], 
      to: :syncing_audience_data
    )
  end

  def finish_audience_data_sync!
    transition!(
      from: :syncing_audience_data, to: :synced_audience_data,
      after_transition: -> { complete! }
    )
  end

  def fail_audience_data_sync!
    transition!(from: :syncing_audience_data, to: :failed_to_sync_audience_data)
  end

  def complete!
    transition!(from: :synced_audience_data, to: :completed, after_transition: -> { destroy })
  end

  private

  def song
    @song ||= Song.find(song_id)
  end

  def sync_song_metadata
    SyncSoundchartsSongJob.perform_later(flow_id: id)
  end

  def sync_audience_data
    SyncSoundchartsAudienceJob.perform_later(flow_id: id)
  end
end
```

---

### Background Jobs

Each job moves the flow through the correct states, step-by-step.

---

**Sync song metadata**

```ruby
class SyncSoundchartsSongJob < ApplicationJob
  def perform(flow_id:)
    @flow_id = flow_id

    flow.start_song_metadata_sync!

    # Fetch song metadata from Soundcharts etc

    flow.finish_song_metadata_sync!
  rescue
    flow.fail_song_metadata_sync!
    raise
  end

  private

  def flow
    @flow ||= SyncSoundchartsFlow.find(@flow_id)
  end
end
```

---

**Sync audience data**

```ruby
class SyncSoundchartsAudienceJob < ApplicationJob
  def perform(flow_id:)
    @flow_id = flow_id

    flow.start_audience_data_sync!

    # Fetch audience data from Soundcharts etc

    flow.finish_audience_data_sync!
  rescue
    flow.fail_audience_data_sync!
    raise
  end

  private

  def flow
    @flow ||= SyncSoundchartsFlow.find(@flow_id)
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
