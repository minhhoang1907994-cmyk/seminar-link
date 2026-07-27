#!/usr/bin/env ruby
require './config/environment'

doc = Document.order(id: :desc).first
if doc
  puts "ID: #{doc.id}"
  puts "Filename: #{doc.original_filename}"
  puts "Status: #{doc.status}"
  puts "Error: #{doc.error_message}"
  puts "Attempts: #{doc.conversion_attempts}"
  puts "Created: #{doc.created_at}"
  puts "File attached: #{doc.file.attached?}"
  puts "PDF attached: #{doc.slides_pdf.attached?}"
else
  puts "No documents found"
end
