namespace :debug do
  desc "Check latest document status"
  task check_doc: :environment do
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
  end

  desc "List last 5 documents"
  task list_docs: :environment do
    puts "ID | Filename | Status | Attempts"
    puts "---+----------+--------+---------"
    Document.order(id: :desc).limit(5).each do |doc|
      puts "#{doc.id} | #{doc.original_filename} | #{doc.status} | #{doc.conversion_attempts}"
    end
  end

  desc "Check if LibreOffice is installed and accessible"
  task check_libreoffice: :environment do
    service = DocumentConvertService.new(nil)
    
    puts "Checking LibreOffice availability..."
    puts "Rails env: #{Rails.env}"
    
    # Test LibreOffice binary discovery
    require "open3"
    
    soffice_paths = [
      "C:/Program Files/LibreOffice/program/soffice.com",
      "C:/Program Files/LibreOffice/program/soffice.exe",
      "C:/Program Files (x86)/LibreOffice/program/soffice.com",
      "C:/Program Files (x86)/LibreOffice/program/soffice.exe",
      "/usr/bin/soffice",
      "/Applications/LibreOffice.app/Contents/MacOS/soffice"
    ]
    
    found = false
    soffice_paths.each do |path|
      if File.exist?(path)
        puts "✓ Found LibreOffice: #{path}"
        found = true
        
        # Try to run version check
        stdout, stderr, status = Open3.capture3("\"#{path}\" --version")
        if status.success?
          puts "  Version: #{stdout.strip}"
        else
          puts "  Version check failed: #{stderr}"
        end
      end
    end
    
    puts "✗ LibreOffice not found" unless found
  end
end
