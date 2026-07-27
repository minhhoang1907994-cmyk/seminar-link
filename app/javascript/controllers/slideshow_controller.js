import { Controller } from "@hotwired/stimulus"
import * as pdfjsLib from "pdfjs-dist"

const PDFJS_WORKER_URL = "https://cdn.jsdelivr.net/npm/pdfjs-dist@4.10.38/build/pdf.worker.min.mjs"

export default class extends Controller {
  static targets = ["canvas", "indicator"]
  static values = { url: String }

  connect() {
    pdfjsLib.GlobalWorkerOptions.workerSrc = PDFJS_WORKER_URL
    this.pageNum = 1
    this.naturalWidth = 0
    this.naturalHeight = 0
    this.renderToken = 0

    this.boundOnKey = this.onKey.bind(this)
    this.boundOnResize = this.onResize.bind(this)

    pdfjsLib
      .getDocument({ url: this.urlValue, withCredentials: false })
      .promise.then((pdf) => {
        this.pdf = pdf
        this.indicatorTarget.textContent = `1 / ${pdf.numPages}`
        return this.cacheNaturalSize()
      })
      .then(() => this.renderCurrent())
      .catch((err) => this.showError(err))

    window.addEventListener("keydown", this.boundOnKey)
    window.addEventListener("resize", this.boundOnResize)
  }

  disconnect() {
    window.removeEventListener("keydown", this.boundOnKey)
    window.removeEventListener("resize", this.boundOnResize)
    if (this.pdf) this.pdf.destroy()
  }

  async cacheNaturalSize() {
    const page = await this.pdf.getPage(1)
    const viewport = page.getViewport({ scale: 1 })
    this.naturalWidth = viewport.width
    this.naturalHeight = viewport.height
  }

  onKey(event) {
    const tag = (event.target && event.target.tagName) || ""
    if (tag === "INPUT" || tag === "TEXTAREA") return

    switch (event.key) {
      case "ArrowRight":
      case "PageDown":
      case " ":
        event.preventDefault()
        this.next()
        break
      case "ArrowLeft":
      case "PageUp":
        event.preventDefault()
        this.prev()
        break
      case "Home":
        event.preventDefault()
        this.first()
        break
      case "End":
        event.preventDefault()
        this.last()
        break
      case "f":
      case "F":
        event.preventDefault()
        this.fullscreen()
        break
    }
  }

  onResize() {
    if (this.pdf) this.renderCurrent()
  }

  next() {
    if (this.pdf && this.pageNum < this.pdf.numPages) {
      this.pageNum++
      this.renderCurrent()
    }
  }

  prev() {
    if (this.pdf && this.pageNum > 1) {
      this.pageNum--
      this.renderCurrent()
    }
  }

  first() {
    if (this.pdf) {
      this.pageNum = 1
      this.renderCurrent()
    }
  }

  last() {
    if (this.pdf) {
      this.pageNum = this.pdf.numPages
      this.renderCurrent()
    }
  }

  fullscreen() {
    if (!document.fullscreenElement) {
      this.element.requestFullscreen?.()
    } else {
      document.exitFullscreen?.()
    }
  }

  async renderCurrent() {
    if (!this.pdf || !this.naturalWidth) return
    const token = ++this.renderToken

    const page = await this.pdf.getPage(this.pageNum)
    if (token !== this.renderToken) return

    const wrap = this.canvasTarget.parentElement
    const availableWidth = Math.max(wrap.clientWidth - 32, 100)
    const availableHeight = Math.max(wrap.clientHeight - 32, 100)
    const scaleX = availableWidth / this.naturalWidth
    const scaleY = availableHeight / this.naturalHeight
    const scale = Math.min(scaleX, scaleY)

    const viewport = page.getViewport({ scale })
    const canvas = this.canvasTarget
    const ctx = canvas.getContext("2d")
    const dpr = window.devicePixelRatio || 1
    canvas.width = Math.floor(viewport.width * dpr)
    canvas.height = Math.floor(viewport.height * dpr)
    canvas.style.width = `${Math.floor(viewport.width)}px`
    canvas.style.height = `${Math.floor(viewport.height)}px`
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0)

    await page.render({ canvasContext: ctx, viewport }).promise
    if (token !== this.renderToken) return

    this.indicatorTarget.textContent = `${this.pageNum} / ${this.pdf.numPages}`
  }

  showError(err) {
    console.error("Slideshow error:", err)
    this.indicatorTarget.textContent = "Lỗi tải PDF"
    const wrap = this.canvasTarget.parentElement
    const message = document.createElement("div")
    message.style.color = "#fca5a5"
    message.style.padding = "1rem"
    message.textContent = `Không thể tải file PDF: ${err && err.message ? err.message : err}`
    wrap.appendChild(message)
  }
}
