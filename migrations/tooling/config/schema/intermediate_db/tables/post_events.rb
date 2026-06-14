# frozen_string_literal: true

# Deferred event embeds. Entity-backed — `event_id` carries the source
# `original_id` of an event converted by its own step (the `events` table), which
# the importer renders into the post body once that entity is available. The
# `placeholder` column holds the token spliced into `post.raw`; see
# `Migrations::Placeholder`.
Migrations::Tooling::Schema.table :post_events do
  synthetic!

  add_column :post_id, :numeric, required: true
  add_column :placeholder, :text, required: true
  add_column :event_id, :numeric

  index :post_id
end
