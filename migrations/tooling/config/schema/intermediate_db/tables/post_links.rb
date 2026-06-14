# frozen_string_literal: true

# Deferred internal/external links. Pure artifacts — they reference no Discourse
# entity and exist only as raw substitutions that the importer finalizes once the
# `original_id -> discourse_id` maps are available. `target_topic_id` /
# `target_post_id` carry the source `original_id` of the linked entity, if any.
# The `placeholder` column holds the token spliced into `post.raw`; see
# `Migrations::Placeholder`.
Migrations::Tooling::Schema.table :post_links do
  synthetic!

  add_column :post_id, :numeric, required: true
  add_column :placeholder, :text, required: true
  add_column :url, :text
  add_column :text, :text
  add_column :target_topic_id, :numeric
  add_column :target_post_id, :numeric

  index :post_id
end
