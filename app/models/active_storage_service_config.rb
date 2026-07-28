require "fileutils"

class ActiveStorageServiceConfig
  class << self
    def service_name(environment = Rails.env, configured_service = ENV["ACTIVE_STORAGE_SERVICE"])
      configured_service = configured_service.presence
      return configured_service.to_sym if configured_service.present?

      environment.to_s == "production" ? :production : :local
    end

    def storage_root(environment = Rails.env, configured_root = ENV["ACTIVE_STORAGE_ROOT"])
      configured_root.presence || "/data/storage"
    end

    def ensure_storage_directory(environment = Rails.env)
      root = storage_root(environment)
      FileUtils.mkdir_p(root)
      migrate_legacy_storage(root)
      root
    rescue SystemCallError => e
      Rails.logger.warn("Unable to create Active Storage directory #{root}: #{e.message}")
      Rails.root.join("storage").to_s
    end

    private

    def migrate_legacy_storage(root)
      legacy_root = Rails.root.join("storage").to_s
      return if root == legacy_root || !File.directory?(legacy_root)
      return if Dir.children(legacy_root).empty?

      FileUtils.mkdir_p(root)
      Dir.glob(File.join(legacy_root, "*")) do |entry|
        FileUtils.cp_r(entry, root)
      end
    rescue SystemCallError => e
      Rails.logger.warn("Unable to migrate Active Storage files from #{legacy_root} to #{root}: #{e.message}")
    end
  end
end
