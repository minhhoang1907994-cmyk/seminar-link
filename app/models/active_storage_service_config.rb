require "fileutils"

class ActiveStorageServiceConfig
  class << self
    def service_name(environment = Rails.env, configured_service = ENV["ACTIVE_STORAGE_SERVICE"])
      configured_service = configured_service.presence
      return configured_service.to_sym if configured_service.present?

      return :backblaze if backblaze_configured?(environment)

      environment.to_s == "production" ? :production : :local
    end

    def storage_root(environment = Rails.env, configured_root = ENV["ACTIVE_STORAGE_ROOT"])
      configured_root.presence || default_storage_root(environment)
    end

    def ensure_storage_directory(environment = Rails.env)
      root = storage_root(environment)
      FileUtils.mkdir_p(root)
      migrate_legacy_storage(root)
      root
    rescue SystemCallError
      fallback_root = Rails.root.join("storage").to_s
      FileUtils.mkdir_p(fallback_root)
      fallback_root
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
    rescue SystemCallError
      nil
    end

    def default_storage_root(environment)
      return Rails.root.join("storage").to_s unless environment.to_s == "production"

      "/data/storage"
    end

    def backblaze_configured?(environment)
      return false unless environment.to_s == "production"

      ENV["B2_ACCESS_KEY_ID"].present? &&
        ENV["B2_SECRET_ACCESS_KEY"].present? &&
        ENV["B2_BUCKET"].present?
    end
  end
end
