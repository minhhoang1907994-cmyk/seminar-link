require "test_helper"

class ActiveStorageServiceConfigTest < ActiveSupport::TestCase
  test "uses configured storage service when provided" do
    with_env("ACTIVE_STORAGE_SERVICE" => "production") do
      assert_equal :production, ActiveStorageServiceConfig.service_name
    end
  end

  test "defaults to local storage in development" do
    with_env("RAILS_ENV" => "development", "ACTIVE_STORAGE_SERVICE" => nil) do
      assert_equal :local, ActiveStorageServiceConfig.service_name
    end
  end

  private

  def with_env(env)
    original = ENV.to_h
    env.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
    yield
  ensure
    ENV.replace(original)
  end
end
