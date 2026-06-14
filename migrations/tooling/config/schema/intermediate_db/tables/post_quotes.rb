# frozen_string_literal: true

# Deferred `[quote]` embeds. Pure artifacts — they reference no Discourse entity
# and exist only as raw substitutions that the importer finalizes once the
# `original_id -> discourse_id` maps are available. The `placeholder` column holds
# the token spliced into `post.raw`; see `Migrations::Placeholder`.
Migrations::Tooling::Schema.table :post_quotes do
  synthetic!

  add_column :post_id, :numeric, required: true
  add_column :placeholder, :text, required: true
  add_column :quoted_post_id, :numeric
  add_column :quoted_user_id, :numeric
  add_column :quoted_username, :text

  index :post_id
end
