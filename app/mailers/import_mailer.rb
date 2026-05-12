class ImportMailer < ApplicationMailer
  def completed(identity, account)
    @account = account
    mail to: identity.email_address, subject: I18n.t("import_mailer.subject_completed")
  end

  def failed(import)
    @import = import
    mail to: import.identity.email_address, subject: I18n.t("import_mailer.subject_failed")
  end
end
