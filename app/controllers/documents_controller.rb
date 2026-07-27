class DocumentsController < ApplicationController
  before_action :set_document, only: %i[show update present status download_pdf retry_convert verify_password destroy]

  def index
    @query = params[:q].to_s.strip
    @status_filter = params[:status].to_s
    @sort = params[:sort].presence || "newest"

    @documents = Document.with_attached_file.with_attached_slides_pdf
    @documents = @documents.where(status: @status_filter) if Document::STATUSES.include?(@status_filter)

    if @query.present?
      like = "%#{ActiveRecord::Base.sanitize_sql_like(@query)}%"
      @documents = @documents.where(
        "original_filename LIKE :q OR uploader_name LIKE :q OR description LIKE :q",
        q: like
      )
    end

    @documents = case @sort
                 when "oldest" then @documents.order(created_at: :asc)
                 when "name" then @documents.order(:original_filename)
                 when "status" then @documents.order(:status, created_at: :desc)
                 else @documents.recent
                 end.limit(100)
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
      return
    end
  end

  def shared_present
    @document = Document.find_by!(share_token: params[:share_token])
    unless @document.presentable?
      redirect_to documents_path, alert: "File chưa sẵn sàng để trình chiếu."
      return
    end

    render :present
  end

  def status
    render json: document_status(@document)
  end

  def download_pdf
    unless @document.slides_pdf.attached?
      redirect_to document_path(@document), alert: "File PDF chưa sẵn sàng."
      return
    end

    redirect_to rails_blob_path(@document.slides_pdf, disposition: "attachment")
  end

  def retry_convert
    unless @document.convertible?
      redirect_to document_path(@document), alert: "Chỉ hỗ trợ convert file PDF hoặc PowerPoint (.pptx)."
      return
    end

    if @document.failed? || @document.pending?
      @document.update!(status: "pending", error_message: nil, conversion_attempts: 0)
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

  def document_status(document)
    {
      id: document.id,
      status: document.status,
      human_status: document.human_status,
      badge_class: document.status_badge_class,
      error_summary: document.error_summary,
      error_message: document.error_message,
      presentable: document.presentable?,
      processing: document.processing? || document.pending?,
      present_url: (present_document_path(document) if document.presentable?),
      download_url: (download_pdf_document_path(document) if document.slides_pdf.attached?),
      share_url: (shared_present_url(document.share_token) if document.share_token.present? && document.presentable?),
      retry_url: (retry_convert_document_path(document) if document.convertible? && (document.failed? || document.pending?))
    }
  end

  def document_params
    params.require(:document).permit(:uploader_name, :description, :file_password, :file)
  end

  def update_params
    params.require(:document).permit(:uploader_name, :description)
  end
end
