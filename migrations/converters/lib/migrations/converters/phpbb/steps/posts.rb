# frozen_string_literal: true

module Migrations
  module Converters
    module Phpbb
      # The centrepiece: convert each phpBB post to Markdown, defer its embeds, and
      # write the post + a permalink. Runs in parallel because `process` is
      # CPU-bound (content conversion).
      #
      # TODO (fill-in), per migrations/docs/converter-architecture.md:
      #   * setup: build `Phpbb::Content` (smilies + attachment resolver from
      #     `phpbb_config`) once per worker.
      #   * process:
      #       embeds = EmbedBuffer.new
      #       raw = @content.to_markdown(item[:post_text], bbcode_uid: item[:bbcode_uid], on_embed: embeds)
      #       embeds.poll(poll_id: item[:topic_id]) if item[:has_poll]   # token spliced into raw
      #       IntermediateDB::Post.create(original_id: item[:post_id], topic_id:, created_at:,
      #                                   raw:, original_raw: item[:post_text], user_id: author_id(item), ...)
      #       PostEmbedWriter.write(item[:post_id], embeds)
      #       IntermediateDB::Permalink.create(url: "#{settings[:url_prefix]}viewtopic.php?p=#{item[:post_id]}",
      #                                        post_id: item[:post_id])
      #   * helpers: `author_id` maps an anonymous `post_username` to a stable id.
      class Posts < Conversion::ProgressStep
        run_in_parallel true

        source do
          attr_accessor :source_db

          def max_progress
            source_db.count_posts
          end

          def items
            source_db.fetch_posts
          end
        end

        processor do
          attr_accessor :phpbb_config

          def setup
            # @content = Phpbb::Content.new(...)
          end

          def process(item)
            raise NotImplementedError
          end
        end

        helpers do
          # def author_id(item)
          #   item[:post_username].present? ? IdGenerator.short_id(item[:post_username]) : item[:poster_id]
          # end
        end
      end
    end
  end
end
