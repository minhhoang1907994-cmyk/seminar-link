# Load Solid Queue schema for development environment (Rails 8 only loads
# queue/cache schemas for multi-DB production by default; for single-DB dev
# we run the schema on demand).
namespace :db do
  desc "Load Solid Queue schema into the current database"
  task queue_schema: :environment do
    schema_path = Rails.root.join("db/queue_schema.rb")
    if File.exist?(schema_path)
      load schema_path.to_s
      Rails.logger.info "Solid Queue schema loaded"
      puts "Solid Queue schema loaded"
    end
  end
end

# Auto-load queue schema after `db:migrate` so `bin/rails db:migrate` is enough
Rake::Task["db:migrate"].enhance(["db:queue_schema"])