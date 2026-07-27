class DocumentConvertJob < ApplicationJob
  queue_as :default

  retry_on ActiveRecord::Deadlocked, wait: 5.seconds, attempts: 3

  def perform(document_id)
    document = Document.find(document_id)
    return if document.ready?

    document.update!(status: "processing")
    result = DocumentConvertService.call(document)

    if result.success?
      document.update!(status: "ready", error_message: nil)
    else
      Rails.logger.error("[DocumentConvertJob] doc=#{document_id} #{result.error_message}")
      document.update!(status: "failed", error_message: result.error_message.to_s.first(2000))
    end
  end
end