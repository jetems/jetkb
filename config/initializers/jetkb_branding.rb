# jetKB branding constants — single source of truth for user-visible brand
# strings. Views, mailers, and configs should reference these instead of
# hardcoding "Fizzy" or "jetKB" so the rebrand surface stays in this one file.
#
# Production: set JETKB_* and MAILER_FROM_ADDRESS env vars via Kamal config.
# Development: defaults below apply unless overridden in the shell.

module JetKB
  module Brand
    APP_NAME      = ENV.fetch("JETKB_APP_NAME",      "jetKB")
    SUPPORT_EMAIL = ENV.fetch("JETKB_SUPPORT_EMAIL", "support@jetkb.com")
    MARKETING_URL = ENV.fetch("JETKB_MARKETING_URL", "https://jetkb.com")
    DOMAIN        = ENV.fetch("JETKB_DOMAIN",        "jetkb.com")
    COMPANY       = ENV.fetch("JETKB_COMPANY",       "jetKB")
  end
end

# Default the mailer "From" if MAILER_FROM_ADDRESS isn't set externally.
# app/mailers/application_mailer.rb reads ENV.fetch("MAILER_FROM_ADDRESS", ...),
# so this keeps that file upstream-clean while still defaulting to the jetKB brand.
ENV["MAILER_FROM_ADDRESS"] ||= "#{JetKB::Brand::APP_NAME} <#{JetKB::Brand::SUPPORT_EMAIL}>"
