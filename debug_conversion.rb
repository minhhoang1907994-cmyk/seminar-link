#!/usr/bin/env ruby
require './config/environment'

puts "=== DocumentConvertService Debug ==="

# Test 1: Check if soffice is available
soffice_paths = [
  "C:/Program Files/LibreOffice/program/soffice.com",
  "C:/Program Files/LibreOffice/program/soffice.exe",
  "C:/Program Files (x86)/LibreOffice/program/soffice.com",
  "C:/Program Files (x86)/LibreOffice/program/soffice.exe",
  "/usr/bin/soffice",
  "/Applications/LibreOffice.app/Contents/MacOS/soffice"
]

puts "\nChecking LibreOffice installation..."
found_soffice = false
soffice_paths.each do |path|
  if File.exist?(path)
    puts "✓ Found: #{path}"
    found_soffice = true
  end
end
puts "✗ LibreOffice not found" unless found_soffice

# Test 2: Try to get environment info
puts "\nEnvironment:"
puts "RAILS_ENV: #{Rails.env}"
puts "SOLID_QUEUE_IN_PUMA: #{ENV['SOLID_QUEUE_IN_PUMA']}"
puts "Active Job Adapter: #{ActiveJob::Base.queue_adapter.class.name}"

# Test 3: List recent documents
puts "\nRecent documents:"
Document.order(id: :desc).limit(3).each do |doc|
  puts "  [#{doc.id}] #{doc.original_filename} (#{doc.status}) - #{doc.conversion_attempts} attempts"
  puts "      Error: #{doc.error_message.lines.first}" if doc.error_message.present?
end

# Test 4: Check file attachment attachment
puts "\nFile attachment info:"
doc = Document.order(id: :desc).first
if doc
  puts "  Document: #{doc.original_filename}"
  puts "  File attached: #{doc.file.attached?}"
  if doc.file.attached?
    puts "    Content-type: #{doc.file.content_type}"
    puts "    Blob exists: #{doc.file.blob.persisted?}"
  end
  puts "  Slides PDF attached: #{doc.slides_pdf.attached?}"
  if doc.slides_pdf.attached?
    puts "    Content-type: #{doc.slides_pdf.content_type}"
    puts "    Blob exists: #{doc.slides_pdf.blob.persisted?}"
  end
end
