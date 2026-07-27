require "fileutils"

class ActiveStorageServiceConfig
  class << self
    def service_name(environment = Rails.env, configured_service = ENV["ACTIVE_STORAGE_SERVICE"])
      configured_service = configured_service.presence
      return configured_service.to_sym if configured_service.present?

      environment.to_s == "production" ? :production : :local
    end

    def storage_root(environment = Rails.env, configured_root = ENV["ACTIVE_STORAGE_ROOT"])
      configured_root.presence || (environment.to_s == "production" ? "/var/lib/rails/storage" : Rails.root.join("storage").to_s)
    end

    def ensure_storage_directory(environment = Rails.env)
      root = storage_root(environment)
      FileUtils.mkdir_p(root)
      root
    end
  end
end
