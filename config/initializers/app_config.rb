Rails.application.configure do
  config.x.app.name = ENV.fetch("APP_NAME", "Campfire")
end
