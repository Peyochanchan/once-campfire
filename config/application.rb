require_relative "boot"

require "rails/all"

Bundler.require(*Rails.groups)

module Campfire
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.2

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks rails_ext])

    # i18n configuration
    config.i18n.available_locales = %i[en fr]
    config.i18n.default_locale = ENV.fetch("DEFAULT_LOCALE", "en").to_sym
    config.i18n.fallbacks = true
  end
end
