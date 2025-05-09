# Flow State 0.1 → 0.2 Migration Guide

---

## 1. Database migration

```ruby
# db/migrate/xxxxxxxxxxxxxx_flow_state_02_upgrade.rb
class FlowState02Upgrade < ActiveRecord::Migration[6.1]
  def change
    rename_column :flow_state_flows, :payload, :props
    add_column    :flow_state_flows, :type,    :string
    add_column    :flow_state_flows, :completed_at,    :datetime
    add_column    :flow_state_flows, :last_errored_at, :datetime
  end
end

```

Run the migration and bump your gem version to `0.2.0`.

---

## 2. Required changes

| Area               | Old (≤ 0.1)                            | New (0.2)                                                  |
| ------------------ | -------------------------------------- | ---------------------------------------------------------- |
| Flow setup         | `initial_state` optional               | `initial_state` and `completed_state` **required**         |
| Completed handling | manual `after_transition { destroy! }` | `destroy_on_complete` handles cleanup automatically        |
| Column rename      | `payload`                              | `props`, used via `flow.props["key"]` only                 |
| Prop accessors     | auto-generated methods                 | removed – use `props["key"]`                               |
| Macro rename       | `persist :foo, Hash`                   | `persists :foo, Hash`                                      |
| Transition keyword | `persists:`                            | `persist:`                                                 |
| Timestamps         | —                                      | `completed_at` and `last_errored_at` tracked automatically |

---

## 3. Example refactor

### Flow definition

```ruby
class SignupFlow < FlowState::Base
  state :draft
  state :processing
  state :failed,    error: true
  state :completed

  initial_state   :draft
  completed_state :completed
  destroy_on_complete

  prop     :user_id, Integer
  persists :external_response, Hash
end
```

### Usage

```ruby
flow = SignupFlow.create!(props: { "user_id" => 42 })

flow.transition!(from: :draft, to: :processing)

flow.transition!(
  from:   :processing,
  to:     :completed,
  persist: :external_response
) { { status: 200 } }

# If destroy_on_complete was set:
#   flow.destroyed?      # => true
# Otherwise:
#   flow.completed_at    # => Time
#   flow.last_errored_at # => nil (unless failed state was hit)
```

---

## 4. Cleanup tips

- Remove any `after_transition { destroy! }` logic and replace with `destroy_on_complete`.
- Stop calling dynamic prop getters like `flow.name`; use `flow.props["name"]` instead.
- Rename all usages of `persist` (macro) to `persists`.
- Update any `persists:` keyword args to `persist:` in your `transition!` calls.

You're now on **Flow State 0.2.0**.
