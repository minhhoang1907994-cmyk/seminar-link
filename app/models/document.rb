require "openssl"
require "securerandom"

class Document < ApplicationRecord
  ALLOWED_CONTENT_TYPES = %w[
    application/pdf
    application/vnd.openxmlformats-officedocument.presentationml.presentation
  ].freeze

  MAX_PDF_BYTES = 50.megabytes
  MAX_PPTX_BYTES = 15.megabytes
  STATUSES = %w[pending processing ready failed].freeze

  attr_reader :file_password

  STATUSES.each do |s|
    define_method("#{s}?") { status == s }
  end

  has_one_attached :file
  has_one_attached :slides_pdf

  validates :uploader_name, presence: true, length: { maximum: 100 }
  validates :original_filename, presence: true
  validates :share_token, presence: true, uniqueness: true
  validates :description, length: { maximum: 1000 }
  validates :file_password, presence: true, length: { minimum: 4, maximum: 100 }, on: :create
  validate  :file_attached_with_valid_type_and_size

  before_validation :ensure_share_token
  before_validation :assign_file_password_digest, if: -> { file_password.present? }

  scope :recent, -> { order(created_at: :desc) }

  def file_password=(password)
    @file_password = password.to_s
  end

  def file_password_matches?(password)
    return false if file_password_digest.blank? || file_password_salt.blank?

    candidate = self.class.password_digest(password.to_s, file_password_salt)
    ActiveSupport::SecurityUtils.secure_compare(candidate, file_password_digest)
  end

  def pdf?
    file.attached? && file.content_type == "application/pdf"
  end

  def powerpoint?
    file.attached? && file.content_type == "application/vnd.openxmlformats-officedocument.presentationml.presentation"
  end

  def presentable?
    ready? && slides_pdf.attached?
  end

  def convertible?
    pdf? || powerpoint?
  end

  def status_badge_class
    {
      "pending"    => "gray",
      "processing" => "blue",
      "ready"      => "green",
      "failed"     => "red"
    }[status]
  end

  def human_status
    {
      "pending"    => "Đang chờ",
      "processing" => "Đang convert",
      "ready"      => "Sẵn sàng",
      "failed"     => "Lỗi"
    }[status] || status
  end

  def file_extension
    File.extname(original_filename).delete_prefix(".").upcase.presence || "FILE"
  end

  def error_summary
    return nil if error_message.blank?

    case error_message
    when /soffice binary not found/i
      "Không tìm thấy LibreOffice trên máy chủ."
    when /timed out/i
      "Convert mất quá nhiều thời gian."
    when /did not produce a PDF/i
      "LibreOffice không xuất được PDF từ file này."
    when /Unsupported file type/i
      "Định dạng file chưa được hỗ trợ."
    when /Permission denied/i
      "Máy chủ không thể ghi hoặc xoá file tạm."
    else
      error_message.lines.first.to_s.strip.presence || "Không thể convert file."
    end
  end

  def self.password_digest(password, salt)
    OpenSSL::HMAC.hexdigest("SHA256", Rails.application.secret_key_base, "#{salt}:#{password}")
  end

  private

  def ensure_share_token
    self.share_token ||= SecureRandom.urlsafe_base64(18)
  end

  def assign_file_password_digest
    self.file_password_salt = SecureRandom.hex(16)
    self.file_password_digest = self.class.password_digest(file_password, file_password_salt)
  end

  def file_attached_with_valid_type_and_size
    unless file.attached?
      errors.add(:file, "must be attached")
      return
    end

    unless ALLOWED_CONTENT_TYPES.include?(file.content_type)
      errors.add(:file, "must be .pptx or .pdf")
      return
    end

    if powerpoint? && file.byte_size > MAX_PPTX_BYTES
      errors.add(:file, "must be less than #{MAX_PPTX_BYTES / 1.megabyte}MB for PowerPoint conversion")
    elsif pdf? && file.byte_size > MAX_PDF_BYTES
      errors.add(:file, "must be less than #{MAX_PDF_BYTES / 1.megabyte}MB")
    end
  end
end
