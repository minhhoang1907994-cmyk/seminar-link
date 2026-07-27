import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "dropzone", "name", "meta"]

  connect() {
    this.update()
  }

  browse() {
    this.inputTarget.click()
  }

  dragover(event) {
    event.preventDefault()
    this.dropzoneTarget.classList.add("is-dragover")
  }

  dragleave() {
    this.dropzoneTarget.classList.remove("is-dragover")
  }

  drop(event) {
    event.preventDefault()
    this.dropzoneTarget.classList.remove("is-dragover")

    if (!event.dataTransfer.files.length) return
    this.inputTarget.files = event.dataTransfer.files
    this.update()
  }

  update() {
    const file = this.inputTarget.files[0]
    if (!file) {
      this.nameTarget.textContent = "Chọn hoặc kéo file vào đây"
      this.metaTarget.textContent = "PDF hoặc PPTX, tối đa 50MB"
      return
    }

    this.nameTarget.textContent = file.name
    this.metaTarget.textContent = `${this.humanSize(file.size)} · ${file.type || "Không rõ loại file"}`
  }

  humanSize(bytes) {
    if (bytes < 1024) return `${bytes} B`
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`
    return `${(bytes / 1024 / 1024).toFixed(1)} MB`
  }
}
