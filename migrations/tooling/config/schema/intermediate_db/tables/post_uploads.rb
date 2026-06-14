# frozen_string_literal: true

# Deferred upload embeds. Entity-backed — `upload_id` references a row in the
# `uploads` table; the importer reads that upload's resolved `upload://…` markdown
# from the uploads store and substitutes it into the post body. The `placeholder`
# column holds the token spliced into `post.raw`; see `Migrations::Placeholder`.
#
# NOTE: `upload_id` is `:text`, not `:numeric`. Upload `original_id`s in the
# IntermediateDB are content hashes (see `uploads.id`, also `:text`), matching the
# global `.*upload.*_id$ => :text` convention, so the reference must be text too.
Migrations::Tooling::Schema.table :post_uploads do
  synthetic!

  add_column :post_id, :numeric, required: true
  add_column :placeholder, :text, required: true
  add_column :upload_id, :text

  index :post_id
end
