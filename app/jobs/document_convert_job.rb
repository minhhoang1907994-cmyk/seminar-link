class DocumentConvertJob < ApplicationJob
  queue_as :default

  MAX_ATTEMPTS = 3

  retry_on ActiveRecord::Deadlocked, wait: 5.seconds, attempts: 3

  def perform(document_id)
    document = Document.find(document_id)
    return if document.ready?

    document.increment!(:conversion_attempts)
    document.update!(status: "processing")
    result = DocumentConvertService.call(document)

    if result.success?
      document.update!(status: "ready", error_message: nil)
    elsif document.conversion_attempts < MAX_ATTEMPTS
      Rails.logger.warn("[DocumentConvertJob] doc=#{document_id} retry=#{document.conversion_attempts} #{result.error_message}")
      document.update!(status: "pending", error_message: result.error_message.to_s.first(2000))
      self.class.set(wait: 5.seconds).perform_later(document.id)
    else
      Rails.logger.error("[DocumentConvertJob] doc=#{document_id} #{result.error_message}")
      document.update!(status: "failed", error_message: result.error_message.to_s.first(2000))
    end
  end
end
