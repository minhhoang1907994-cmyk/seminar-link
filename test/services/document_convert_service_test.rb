require "test_helper"

class DocumentConvertServiceTest < ActiveSupport::TestCase
  test "rejects oversized powerpoint files before launching LibreOffice" do
    document = Document.new(
      uploader_name: "tester",
      original_filename: "large.pptx",
      description: "large deck",
      file_password: "secret123"
    )

    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("x" * (Document::MAX_PPTX_BYTES + 1)),
      filename: "large.pptx",
      content_type: "application/vnd.openxmlformats-officedocument.presentationml.presentation"
    )
    document.file.attach(blob)

    service = DocumentConvertService.new(document)
    service.define_singleton_method(:soffice_binary) { raise "should not run soffice" }

    result = service.call

    assert_not result.success?
    assert_match(/too large/i, result.error_message)
  end
end
