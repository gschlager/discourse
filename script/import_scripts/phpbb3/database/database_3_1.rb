require_relative 'database_3_0'
require_relative '../support/constants/constants'

module ImportScripts::PhpBB3
  # noinspection RubyResolve
  class Database_3_1 < Database_3_0
    def fetch_users(offset)
      unix_timestamp = Time.now.to_i
      banlist_join_condition = Sequel.virtual_row { (u__user_id =~ b__ban_userid) & (b__ban_exclude =~ 0) &
        ((b__ban_end =~ 0) | (b__ban_end >= unix_timestamp)) }

      @database
        .select(:u__user_id, :u__user_email, :u__username, :u__user_password, :u__user_regdate, :u__user_lastvisit,
                :u__user_ip, :u__user_type, :u__user_inactive_reason, :g__group_name, :b__ban_start, :b__ban_end,
                :b__ban_reason, :u__user_posts, :f__pf_phpbb_website___user_website, :f__pf_phpbb_location___user_from,
                :u__user_birthday, :u__user_avatar_type, :u__user_avatar)
        .from(table(:users, :u))
        .join(table(:profile_fields_data, :f), [:user_id])
        .join(table(:groups, :g), [:group_id])
        .left_join(table(:banlist, :b), banlist_join_condition)
        .where { (u__user_type !~ Constants::USER_TYPE_IGNORE) }
        .order(:u__user_id)
        .limit(@batch_size)
        .offset(offset)
        .all
    end
  end
end
