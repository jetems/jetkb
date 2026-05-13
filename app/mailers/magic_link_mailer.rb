class MagicLinkMailer < ApplicationMailer
  def sign_in_instructions(magic_link)
    @magic_link = magic_link
    @identity = @magic_link.identity

    mail to: @identity.email_address, subject: t("magic_link_mailer.sign_in_instructions.subject", code: @magic_link.code)
  end
end
