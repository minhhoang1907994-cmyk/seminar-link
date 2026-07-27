class DocumentsController < ApplicationController
  before_action :set_document, only: %i[show update present retry_convert verify_password destroy]

  def index
    @documents = Document.recent.limit(100)
  end

  def new
    @document = Document.new
  end

  def create
    @document = Document.new(document_params)
    if @document.file.attached?
      @document.original_filename = @document.file.filename.to_s
    end

    if @document.save
      DocumentConvertJob.perform_later(@document.id)
      redirect_to documents_path, notice: "Đã upload. Đang convert trong background..."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
  end

  def update
    unless @document.file_password_matches?(params[:file_password])
      redirect_to document_path(@document), alert: "Sai mật khẩu file."
      return
    end

    if @document.update(update_params)
      redirect_to document_path(@document), notice: "Đã cập nhật thông tin file."
    else
      redirect_to document_path(@document), alert: @document.errors.full_messages.to_sentence
    end
  end

  def present
    unless @document.presentable?
      redirect_to document_path(@document), alert: "Chưa sẵn sàng (status: #{@document.status})."
    end
  end

  def retry_convert
    unless @document.convertible?
      redirect_to document_path(@document), alert: "Chỉ hỗ trợ convert file PDF hoặc PowerPoint (.pptx)."
      return
    end

    if @document.failed? || @document.pending?
      @document.update!(status: "pending", error_message: nil)
      DocumentConvertJob.perform_later(@document.id)
      redirect_to documents_path, notice: "Đã đưa vào hàng đợi convert lại."
    else
      redirect_to document_path(@document), alert: "Không thể retry từ status #{@document.status}."
    end
  end

  def verify_password
    render json: { ok: @document.file_password_matches?(params[:file_password]) }
  end

  def destroy
    unless @document.file_password_matches?(params[:file_password])
      redirect_to documents_path, alert: "Sai mật khẩu file."
      return
    end

    @document.file.purge if @document.file.attached?
    @document.slides_pdf.purge if @document.slides_pdf.attached?
    @document.destroy!

    redirect_to documents_path, notice: "Đã xóa file và dữ liệu liên quan."
  end

  private

  def set_document
    @document = Document.find(params[:id])
  end

  def document_params
    params.require(:document).permit(:uploader_name, :description, :file_password, :file)
  end

  def update_params
    params.require(:document).permit(:uploader_name, :description)
  end
end
