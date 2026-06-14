# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      class Posts < Conversion::ProgressStep
        source do
          attr_accessor :source_db

          def max_progress
            @source_db.count <<~SQL
              SELECT COUNT(*) FROM posts
            SQL
          end

          def items
            # `reply_to_post_id` resolves the source `reply_to_post_number` to the
            # parent post's id (same topic) so the reference survives renumbering.
            @source_db.query <<~SQL
              SELECT posts.*,
                     reply_to.id AS reply_to_post_id
                FROM posts
                     LEFT JOIN posts reply_to
                       ON reply_to.topic_id = posts.topic_id
                      AND reply_to.post_number = posts.reply_to_post_number
              ORDER BY posts.topic_id, posts.post_number
            SQL
          end
        end

        processor do
          attr_accessor :group_names, :here_mention

          def setup
            @extractor =
              RawExtractor.new(
                mention_resolver:
                  MentionResolver.new(here_mention:, group_names: group_names || []),
              )
          end

          def process(item)
            embeds = EmbedBuffer.new
            raw = @extractor.extract(item[:raw], on_embed: embeds)

            IntermediateDB::Post.create(
              original_id: item[:id],
              action_code: item[:action_code],
              created_at: item[:created_at],
              deleted_at: item[:deleted_at],
              deleted_by_id: item[:deleted_by_id],
              hidden: item[:hidden],
              hidden_at: item[:hidden_at],
              hidden_reason_id: valid_enum(Enums::PostHiddenReason, item[:hidden_reason_id]),
              last_editor_id: item[:last_editor_id],
              like_count: item[:like_count],
              locked_by_id: item[:locked_by_id],
              original_raw: item[:raw],
              post_number: item[:post_number],
              post_type:
                valid_enum(Enums::PostType, item[:post_type], fallback: Enums::PostType::REGULAR),
              raw:,
              reply_to_post_id: item[:reply_to_post_id],
              reply_to_user_id: item[:reply_to_user_id],
              sort_order: item[:sort_order],
              topic_id: item[:topic_id],
              user_deleted: item[:user_deleted],
              user_id: item[:user_id],
              wiki: item[:wiki],
            )

            PostEmbedWriter.write(item[:id], embeds)
          end

          private

          # Keeps only values the enum recognizes, otherwise the fallback (the
          # source may carry values from plugins or versions we don't model).
          def valid_enum(enum_module, value, fallback: nil)
            return fallback if value.nil?
            enum_module.valid?(value) ? value : fallback
          end
        end
      end
    end
  end
end
