# frozen_string_literal: true

# Deferred `@mention` embeds. Pure artifacts — they reference no Discourse entity
# and exist only as raw substitutions that the importer finalizes once the
# `original_id -> discourse_id` maps are available. `mention_type` is one of
# `user` / `group` / `here` / `all`; `target_id` carries the source `original_id`
# of the mentioned user or group (nil for `here` / `all`). The `placeholder`
# column holds the token spliced into `post.raw`; see `Migrations::Placeholder`.
Migrations::Tooling::Schema.table :post_mentions do
  synthetic!

  add_column :post_id, :numeric, required: true
  add_column :placeholder, :text, required: true
  add_column :mention_type, :text
  add_column :target_id, :numeric
  add_column :name, :text

  index :post_id
end
