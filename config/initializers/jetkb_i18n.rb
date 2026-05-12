# jetKB i18n configuration.
#
# Locales:
#   :en    — upstream baseline + jetKB brand overrides
#   :"zh-CN" — jetKB primary locale (Simplified Chinese)
#
# Falls back to :en when a key is missing in :"zh-CN", so partial
# translations never render as blank.
#
# Override default at deploy time with JETKB_DEFAULT_LOCALE=en if needed.

Rails.application.configure do
  config.i18n.available_locales = [ :en, :"zh-CN" ]
  config.i18n.default_locale    = ENV.fetch("JETKB_DEFAULT_LOCALE", "zh-CN").to_sym
  config.i18n.fallbacks         = [ :en ]
end
