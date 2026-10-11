require_relative 'boot'
require 'rails/all'
Bundler.require(*Rails.groups)
module QueueLess
  class Application < Rails::Application
    config.load_defaults 8.1
    config.api_only = true
    config.eager_load = false
    config.autoload_paths << Rails.root.join('app/services')
    configured_frontend_origin = ENV['FRONTEND_ORIGIN'].to_s.strip
    if Rails.env.production? && configured_frontend_origin.blank?
      raise 'Set FRONTEND_ORIGIN to the deployed frontend origin in production.'
    end
    cors_origins = [configured_frontend_origin].reject(&:blank?)
    cors_origins.concat(['http://localhost:5173', 'http://127.0.0.1:5173', 'http://localhost:5174', 'http://127.0.0.1:5174']) unless Rails.env.production?
    config.middleware.insert_before 0, Rack::Cors do
      allow do
        origins(*cors_origins)
        resource '/api/*', headers: :any, methods: %i[get post patch delete options], expose: ['Content-Type']
      end
    end
  end
end
