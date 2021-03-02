# frozen_string_literal: true

class Developer < ActiveRecord::Base
  belongs_to :user

  after_save :rebuild_cache
  after_destroy :rebuild_cache

  @id_cache = DistributedCache.new('developer_ids')

  def self.user_ids
    @id_cache["ids"] || rebuild_cache
  end

  def self.rebuild_cache
    @id_cache["ids"] = Set.new(Developer.pluck(:user_id))
  end

  def self.update_global_notice
    if !GlobalSetting.skip_db? &&
      ActiveRecord::Base.connection.table_exists?(:users) &&
      User.limit(20).count < 20 &&
      User.where(admin: true).human_users.count == 0

      notice = I18n.with_locale(SiteSetting.default_locale) do
        if GlobalSetting.developer_emails.blank?
          I18n.t("finish_installation.global_notice.no_emails")
        else
          emails = GlobalSetting.developer_emails.split(",")
          emails = emails.join(I18n.t("finish_installation.global_notice.email_address_joiner"))
          I18n.t("finish_installation.global_notice.with_emails", emails: emails)
        end
      end

      if notice != SiteSetting.global_notice
        SiteSetting.global_notice = notice
        SiteSetting.has_login_hint = true
      end
    end
  end

  def rebuild_cache
    Developer.rebuild_cache
  end
end

# == Schema Information
#
# Table name: developers
#
#  id      :integer          not null, primary key
#  user_id :integer          not null
#
# Indexes
#
#  index_developers_on_user_id  (user_id) UNIQUE
#
