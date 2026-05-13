class Notification::BundleMailer < ApplicationMailer
  include Mailers::Unsubscribable

  helper NotificationsHelper

  def notification(bundle)
    @user = bundle.user
    @bundle = bundle
    @notifications = bundle.notifications
      .preload(:card, :creator, source: [ :board, :creator ])
      .reject { |n| n.source.nil? || n.card.nil? }
    @unsubscribe_token = @user.generate_token_for(:unsubscribe)

    if @notifications.any?
      subject = if @user.identity.accounts.many?
        I18n.t("notification.bundle_mailer.subject_multi", account: Current.account.name)
      else
        I18n.t("notification.bundle_mailer.subject_single")
      end

      mail \
        to: bundle.user.identity.email_address,
        subject: subject
    end
  end
end
