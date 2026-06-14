# frozen_string_literal: true

# Deferred poll embeds. Entity-backed — `poll_id` carries the source `original_id`
# of a poll converted by its own step (the `polls` table), which the importer
# renders into the post body once that entity is available. The `placeholder`
# column holds the token spliced into `post.raw`; see `Migrations::Placeholder`.
Migrations::Tooling::Schema.table :post_polls do
  synthetic!

  add_column :post_id, :numeric, required: true
  add_column :placeholder, :text, required: true
  add_column :poll_id, :numeric

  index :post_id
end
