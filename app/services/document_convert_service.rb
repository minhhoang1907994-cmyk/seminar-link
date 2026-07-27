require "open3"
require "tmpdir"
require "securerandom"
require "timeout"
require "fileutils"

# Converts an uploaded Document to PDF using LibreOffice headless.
# For PDFs, copies the original blob to slides_pdf (no conversion needed).
#
# Each invocation uses a unique LibreOffice user profile directory
# (`tmp/lo_profiles/<doc-id>-<rand>`) to avoid profile lock contention when
# jobs run in parallel. See: https://www.thomastsoi.com/blog/a-real-world-concurrency-bug-caused-by-libreoffice-profile-locking
class DocumentConvertService
  Result = Struct.new(:success?, :error_message, :pdf_path, keyword_init: true)

  SOFFICE_PATHS = [
    "C:/Program Files/LibreOffice/program/soffice.com",
    "C:/Program Files/LibreOffice/program/soffice.exe",
    "C:/Program Files (x86)/LibreOffice/program/soffice.com",
    "C:/Program Files (x86)/LibreOffice/program/soffice.exe",
    "/usr/bin/soffice",
    "/Applications/LibreOffice.app/Contents/MacOS/soffice"
  ].freeze

  TIMEOUT_SECONDS = 180

  def self.call(document)
    new(document).call
  end

  def initialize(document)
    @document = document
  end

  def call
    if @document.pdf?
      attach_pdf_passthrough
      return Result.new(success?: true)
    end

    unless @document.powerpoint?
      return Result.new(success?: false, error_message: "Unsupported file type. Only PDF and PowerPoint (.pptx) files are supported.")
    end

    if @document.file.byte_size > Document::MAX_PPTX_BYTES
      return Result.new(
        success?: false,
        error_message: "PowerPoint file is too large for safe conversion on this server (limit: #{Document::MAX_PPTX_BYTES / 1.megabyte}MB)."
      )
    end

    Dir.mktmpdir("doc_convert_#{@document.id}_") do |dir|
      input_path  = stage_input(dir)
      profile_dir = build_profile_dir
      FileUtils.mkdir_p(profile_dir)

      begin
        cmd = [
          soffice_binary,
          "--headless",
          "--norestore", "--nolockcheck", "--nodefault", "--nofirststartwizard",
          "-env:UserInstallation=file:///#{to_url_path(profile_dir)}",
          "--convert-to", "pdf",
          "--outdir", dir,
          input_path
        ]

        stdout, stderr, status = run_with_timeout(cmd)
        unless status.success?
          return Result.new(
            success?: false,
            error_message: conversion_error("LibreOffice exited #{status.exitstatus}", stdout, stderr)
          )
        end

        produced = produced_pdf_path(dir, input_path)
        unless produced
          return Result.new(success?: false, error_message: conversion_error("LibreOffice did not produce a PDF", stdout, stderr))
        end

        attach_produced_pdf(produced)
        Result.new(success?: true, pdf_path: produced)
      ensure
        FileUtils.rm_rf(profile_dir)
      end
    end
  rescue Timeout::Error
    Result.new(success?: false, error_message: "convert timed out after #{TIMEOUT_SECONDS}s")
  rescue => e
    Result.new(success?: false, error_message: "#{e.class}: #{e.message}")
  end

  private

  def attach_pdf_passthrough
    @document.slides_pdf.attach(@document.file.blob)
  end

  def attach_produced_pdf(path)
    pdf_filename = "#{@document.original_filename.sub(/\.[^.]+\z/, '')}.pdf"
    File.open(path, "rb") do |file|
      @document.slides_pdf.attach(
        io:           file,
        filename:     pdf_filename,
        content_type: "application/pdf"
      )
    end
  end

  def stage_input(dir)
    ext = File.extname(@document.original_filename).to_s.downcase
    ext = ".bin" if ext.empty?
    path = File.join(dir, "input#{ext}")

    File.open(path, "wb") do |file|
      @document.file.open do |io|
        IO.copy_stream(io, file)
      end
    end

    path
  end

  def produced_pdf_path(dir, input_path)
    expected = File.join(dir, "#{File.basename(input_path, ".*")}.pdf")
    return expected if File.file?(expected)

    entry = Dir.children(dir).find do |name|
      path = File.join(dir, name)
      File.file?(path) && File.extname(name).casecmp(".pdf").zero?
    end
    File.join(dir, entry) if entry
  end

  def build_profile_dir
    Rails.root.join("tmp", "lo_profiles", "doc-#{@document.id || 'new'}-#{SecureRandom.hex(4)}").to_s
  end

  def to_url_path(path)
    path.tr("\\", "/").gsub(" ", "%20")
  end

  def soffice_binary
    @soffice_binary ||= SOFFICE_PATHS.find { |p| File.exist?(p) } ||
      raise("soffice binary not found in any known location: #{SOFFICE_PATHS.inspect}")
  end

  def run_with_timeout(cmd)
    Timeout.timeout(TIMEOUT_SECONDS) do
      Open3.capture3(*cmd)
    end
  end

  def conversion_error(summary, stdout, stderr)
    parts = [summary]
    parts << "stdout: #{stdout.to_s.strip}" if stdout.to_s.strip.present?
    parts << "stderr: #{stderr.to_s.strip}" if stderr.to_s.strip.present?
    parts.join("\n")
  end
end
