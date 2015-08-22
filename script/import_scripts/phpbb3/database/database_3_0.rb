require_relative 'database_base'
require_relative '../support/constants'

module ImportScripts::PhpBB3
  # noinspection RubyResolve
  class Database_3_0 < DatabaseBase
    def count_users
      @database
        .from(table(:users, :u))
        .join(table(:groups, :g), [:group_id])
        .where { (u__user_type !~ Constants::USER_TYPE_IGNORE) }
        .count
    end

    def fetch_users(offset)
      unix_timestamp = Time.now.to_i
      banlist_join_condition = Sequel.virtual_row { (u__user_id =~ b__ban_userid) & (b__ban_exclude =~ 0) &
        ((b__ban_end =~ 0) | (b__ban_end >= unix_timestamp)) }

      @database
        .select(:u__user_id, :u__user_email, :u__username, :u__user_password, :u__user_regdate, :u__user_lastvisit,
                :u__user_ip, :u__user_type, :u__user_inactive_reason, :g__group_name, :b__ban_start, :b__ban_end,
                :b__ban_reason, :u__user_posts, :u__user_website, :u__user_from, :u__user_birthday,
                :u__user_avatar_type, :u__user_avatar)
        .from(table(:users, :u))
        .join(table(:groups, :g), [:group_id])
        .left_join(table(:banlist, :b), banlist_join_condition)
        .where { (u__user_type !~ Constants::USER_TYPE_IGNORE) }
        .order(:u__user_id)
        .limit(@batch_size)
        .offset(offset)
        .all
    end

    def count_anonymous_users
      @database
        .from(table(:posts))
        .where { (post_username !~ '') }
        .count { distinct(post_username) }
    end

    def fetch_anonymous_users(offset)
      @database
        .from(table(:posts))
        .select_group(:post_username)
        .select_append { min(post_time).as(first_post_time) }
        .where { (post_username !~ '') }
        .order(:post_username)
        .limit(@batch_size)
        .offset(offset)
        .all
    end

    def fetch_categories
      first_post_times = @database
                           .from(table(:topics))
                           .select_group(:forum_id)
                           .select_append { min(topic_time).as(first_post_time) }
                           .as(:x)

      @database
        .select(:f__forum_id, :f__parent_id, :f__forum_name, :f__forum_desc, :x__first_post_time)
        .from(table(:forums, :f))
        .left_join(first_post_times, [:forum_id])
        .where { (f__forum_type !~ Constants::FORUM_TYPE_LINK) }
        .order(:f__parent_id, :f__left_id)
        .all
    end

    def count_posts
      @database
        .from(table(:posts))
        .count
    end

    def fetch_posts(offset)
      # CASE t.poll_length WHEN 0 THEN NULL ELSE t.poll_start + t.poll_length END AS poll_end
      poll_end = Sequel.case({0 => nil}, Sequel.+(:t__poll_start, :t__poll_length), :t__poll_length).as(:poll_end)

      @database
        .select(:p__post_id, :p__topic_id, :t__forum_id, :t__topic_title, :t__topic_first_post_id, :p__poster_id,
                :p__post_text, :p__post_time, :p__post_username, :t__topic_status, :t__topic_type, :t__poll_title,
                poll_end, :t__poll_max_options, :p__post_attachment)
        .from(table(:posts, :p))
        .join(table(:topics, :t), [:topic_id])
        .order(:p__post_id)
        .limit(@batch_size)
        .offset(offset)
        .all
    end

    def get_first_post_id(topic_id)
      @database
        .from(table(:topics))
        .where(:topic_id => topic_id)
        .get(:topic_first_post_id)
    end

    def fetch_poll_options(topic_id)
      @database
        .select(:poll_option_id, :poll_option_text, :poll_option_total)
        .from(table(:poll_options))
        .where(:topic_id => topic_id)
        .order(:poll_option_id)
        .all
    end

    def fetch_poll_votes(topic_id)
      # this query ignores votes from users that do not exist anymore
      @database
        .select(:u__user_id, :v__poll_option_id)
        .from(table(:poll_votes, :v))
        .join(table(:users, :u), :v__vote_user_id => :u__user_id)
        .where(:v__topic_id => topic_id)
        .all
    end

    def count_voters(topic_id)
      # anonymous voters can't be counted, but lets try to make the count look "correct" anyway
      voters = @database
                 .from(table(:poll_votes))
                 .where(:topic_id => topic_id)
                 .select { count(:vote_user_id).distinct.as(:count) }

      max_votes = @database
                    .from(table(:poll_options))
                    .where(:topic_id => topic_id)
                    .select { max(:poll_option_total).as(:count) }

      @database
        .from(voters.union(max_votes, :from_self => false).as(:x))
        .max(:count)
    end

    def get_max_attachment_size
      @database
        .from(table(:attachments))
        .get(Sequel.function(:coalesce, :filesize, 0).as(:filesize))
    end

    def fetch_attachments(topic_id, post_id)
      @database
        .select(:physical_filename, :real_filename)
        .from(table(:attachments, :a))
        .where { (a__topic_id =~ topic_id) & (a__post_msg_id =~ post_id) }
        .order(Sequel.desc(:filetime), :post_msg_id)
        .all
    end

    def count_messages(use_fixed_messages)
      if use_fixed_messages
        @database
          .from(table(:import_privmsgs))
          .count
      else
        @database
          .from(table(:privmsgs))
          .count
      end
    end

    def fetch_messages(use_fixed_messages, offset)
      attachment_counts = @database
                            .from(table(:attachments))
                            .group_and_count(:post_msg_id)
                            .where(:topic_id => 0)
                            .as(:a)

      attachment_count = Sequel.function(:coalesce, :a__count, 0).as(:attachment_count)

      if use_fixed_messages
        @database
          .select(:m__msg_id, :i__root_msg_id, :m__author_id, :m__message_time, :m__message_subject,
                  :m__message_text, attachment_count)
          .from(table(:privmsgs, :m))
          .join(table(:import_privmsgs, :i), :m__msg_id => :i__msg_id)
          .left_join(attachment_counts, {:m__msg_id => :a__post_msg_id})
          .order(:i__root_msg_id, :m__msg_id)
          .limit(@batch_size)
          .offset(offset)
          .all
      else
        @database
          .select(:m__msg_id, :m__root_level___root_msg_id, :m__author_id, :m__message_time, :m__message_subject,
                  :m__message_text, attachment_count)
          .from(table(:privmsgs, :m))
          .left_join(attachment_counts, {:m__msg_id => :a__post_msg_id})
          .order(:m__root_level, :m__msg_id)
          .limit(@batch_size)
          .offset(offset)
          .all
      end
    end

    def fetch_message_participants(msg_id, use_fixed_messages)
      if use_fixed_messages
        @database
          .select(:m__to_address)
          .from(table(:privmsgs, :m))
          .join(table(:import_privmsgs, :i), [:msg_id])
          .where { (i__msg_id =~ msg_id) | (i__root_msg_id =~ msg_id) }
          .all
      else
        @database
          .select(:m__to_address)
          .from(table(:privmsgs, :m))
          .where { (m__msg_id =~ msg_id) | (m__root_level =~ msg_id) }
          .all
      end
    end

    def calculate_fixed_messages
      drop_temp_import_message_table
      create_temp_import_message_table
      fill_temp_import_message_table

      drop_import_message_table
      create_import_message_table
      fill_import_message_table

      drop_temp_import_message_table
    end

    def count_bookmarks
      @database
        .from(table(:bookmarks))
        .count
    end

    def fetch_bookmarks(offset)
      @database
        .select(:b__user_id, :t__topic_first_post_id)
        .from(table(:bookmarks, :b))
        .join(table(:topics, :t), [:topic_id])
        .order(:b__user_id, :b__topic_id)
        .limit(@batch_size)
        .offset(offset)
        .all
    end

    def get_config_values
      @database.select(
        select_config_value('version').as(:phpbb_version),
        select_config_value('avatar_gallery_path').as(:avatar_gallery_path),
        select_config_value('avatar_path').as(:avatar_path),
        select_config_value('avatar_salt').as(:avatar_salt),
        select_config_value('smilies_path').as(:smilies_path),
        select_config_value('upload_path').as(:attachment_path)
      ).first
    end

    protected

    def drop_temp_import_message_table
      @database.drop_table?(table(:import_privmsgs_temp))
    end

    def create_temp_import_message_table
      @database.create_table(table(:import_privmsgs_temp)) do
        column :msg_id, Integer, :primary_key => true, :null => false
        column :root_msg_id, Integer, :null => false
        column :recipient_id, Integer, :null => true
        column :normalized_subject, String, :size => 255, :null => false
      end
    end

    # this removes duplicate messages, converts the to_address to a number
    # and stores the message_subject in lowercase and without the prefix "Re: "
    def fill_temp_import_message_table
      # CASE WHEN m.root_level = 0 AND INSTR(m.to_address, ':') = 0 THEN
      # CAST(SUBSTRING(m.to_address, 3) AS SIGNED INTEGER)
      # ELSE NULL END AS recipient_id
      is_root_message_with_one_recipient = {m__root_level: 0, position(:m__to_address, ':') => 0}
      extract_user_id = Sequel.cast(substring(:m__to_address, 3), Integer)
      recipient_id = Sequel.case([[is_root_message_with_one_recipient, extract_user_id]], nil).as(:recipient_id)

      # LOWER(CASE WHEN m.message_subject LIKE 'Re: %' THEN
      # SUBSTRING(m.message_subject, 5)
      # ELSE m.message_subject END) AS normalized_subject
      subject_starts_with_re = Sequel.like(:m__message_subject, 'Re: %')
      subject = Sequel.case([[subject_starts_with_re, substring(:m__message_subject, 5)]], :m__message_subject)
      normalized_subject = Sequel.function(:lower, subject).as(:normalized_subject)

      is_duplicate_message = Sequel.virtual_row { (x__msg_id < m__msg_id) & (x__root_level =~ m__root_level) &
        (x__author_id =~ m__author_id) & (x__to_address =~ m__to_address) & (x__message_time =~ m__message_time) }

      subquery = @database
                   .select(:m__msg_id, :m__root_level, recipient_id, normalized_subject)
                   .from(table(:privmsgs, :m))
                   .where(@database
                            .select(1)
                            .from(table(:privmsgs, :x))
                            .where(is_duplicate_message)
                            .exists).invert

      @database[table(:import_privmsgs_temp)]
        .insert([:msg_id, :root_msg_id, :recipient_id, :normalized_subject], subquery)
    end

    def drop_import_message_table
      @database.drop_table?(table(:import_privmsgs))
    end

    def create_import_message_table
      @database.create_table(table(:import_privmsgs)) do
        column :msg_id, Integer, :primary_key => true, :null => false
        column :root_msg_id, Integer, :null => false, :index => true
      end
    end

    # this tries to calculate the actual root_level (= msg_id of the first message in a
    # private conversation) based on subject, time, author and recipient
    def fill_import_message_table
      is_same_conversation = Sequel.virtual_row {
        (((a__author_id =~ m__author_id) & (b__recipient_id =~ i__recipient_id)) |
          ((a__author_id =~ i__recipient_id) & (b__recipient_id =~ m__author_id))) &
          (b__normalized_subject =~ i__normalized_subject) &
          (a__msg_id !~ m__msg_id) &
          (a__message_time < m__message_time)
      }
      msg_id_subquery = @database
                          .select(:a__msg_id)
                          .from(table(:privmsgs, :a))
                          .join(table(:import_privmsgs_temp, :b), [:msg_id])
                          .where(is_same_conversation)
                          .order(:a__message_time)
                          .limit(1)

      root_msg_id = Sequel.case({0 => Sequel.function(:coalesce, msg_id_subquery, 0)}, 0, :i__root_msg_id).as(:root_msg_id)

      subquery = @database
                   .select(:m__msg_id, root_msg_id)
                   .from(table(:privmsgs, :m))
                   .join(table(:import_privmsgs_temp, :i), [:msg_id])

      @database[table(:import_privmsgs)]
        .insert([:msg_id, :root_msg_id], subquery)
    end

    def select_config_value(config_name)
      @database
        .select(:config_value)
        .from(table(:config))
        .where(:config_name => config_name)
    end
  end
end
