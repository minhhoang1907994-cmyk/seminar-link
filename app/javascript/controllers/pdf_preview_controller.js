import { Controller } from "@hotwired/stimulus"
import * as pdfjsLib from "pdfjs-dist"

const PDFJS_WORKER_URL = "https://cdn.jsdelivr.net/npm/pdfjs-dist@4.10.38/build/pdf.worker.min.mjs"

export default class extends Controller {
  static targets = ["canvas", "meta"]
  static values = { url: String }

  connect() {
    if (!this.hasUrlValue) return
    pdfjsLib.GlobalWorkerOptions.workerSrc = PDFJS_WORKER_URL

    pdfjsLib
      .getDocument({ url: this.urlValue, withCredentials: false })
      .promise.then((pdf) => {
        this.pdf = pdf
        if (this.hasMetaTarget) this.metaTarget.textContent = `${pdf.numPages} trang`
        return pdf.getPage(1)
      })
      .then((page) => this.renderPage(page))
      .catch(() => {
        if (this.hasMetaTarget) this.metaTarget.textContent = "Không thể tải preview"
      })
  }

  disconnect() {
    if (this.pdf) this.pdf.destroy()
  }

  renderPage(page) {
    const wrap = this.canvasTarget.parentElement
    const base = page.getViewport({ scale: 1 })
    const scale = Math.min(wrap.clientWidth / base.width, 240 / base.height)
    const viewport = page.getViewport({ scale })
    const dpr = window.devicePixelRatio || 1
    const canvas = this.canvasTarget
    const context = canvas.getContext("2d")

    canvas.width = Math.floor(viewport.width * dpr)
    canvas.height = Math.floor(viewport.height * dpr)
    canvas.style.width = `${Math.floor(viewport.width)}px`
    canvas.style.height = `${Math.floor(viewport.height)}px`
    context.setTransform(dpr, 0, 0, dpr, 0, 0)

    page.render({ canvasContext: context, viewport })
  }
}
