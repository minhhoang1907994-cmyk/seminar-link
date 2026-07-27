import { Controller } from "@hotwired/stimulus"
import * as pdfjsLib from "pdfjs-dist"

const PDFJS_WORKER_URL = "https://cdn.jsdelivr.net/npm/pdfjs-dist@4.10.38/build/pdf.worker.min.mjs"

export default class extends Controller {
  static targets = ["canvas", "indicator", "progress", "toolbar", "stage", "pointer", "blackout", "thumbs"]
  static values = { url: String }

  connect() {
    pdfjsLib.GlobalWorkerOptions.workerSrc = PDFJS_WORKER_URL
    this.pageNum = 1
    this.naturalWidth = 0
    this.naturalHeight = 0
    this.zoom = 1
    this.renderToken = 0
    this.pointerEnabled = false
    this.hideToolbarTimer = null

    this.boundOnKey = this.onKey.bind(this)
    this.boundOnResize = this.onResize.bind(this)
    this.boundOnPointerMove = this.onPointerMove.bind(this)
    this.boundWakeToolbar = this.wakeToolbar.bind(this)

    pdfjsLib
      .getDocument({ url: this.urlValue, withCredentials: false })
      .promise.then((pdf) => {
        this.pdf = pdf
        this.indicatorTarget.textContent = `1 / ${pdf.numPages}`
        this.updateProgress()
        this.buildThumbnails()
        return this.cacheNaturalSize()
      })
      .then(() => this.renderCurrent())
      .catch((err) => this.showError(err))

    window.addEventListener("keydown", this.boundOnKey)
    window.addEventListener("resize", this.boundOnResize)
    this.element.addEventListener("mousemove", this.boundWakeToolbar)
    this.stageTarget.addEventListener("pointermove", this.boundOnPointerMove)
    this.wakeToolbar()
  }

  disconnect() {
    window.removeEventListener("keydown", this.boundOnKey)
    window.removeEventListener("resize", this.boundOnResize)
    this.element.removeEventListener("mousemove", this.boundWakeToolbar)
    this.stageTarget.removeEventListener("pointermove", this.boundOnPointerMove)
    window.clearTimeout(this.hideToolbarTimer)
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
      case "p":
      case "P":
        event.preventDefault()
        this.togglePointer()
        break
      case "b":
      case "B":
        event.preventDefault()
        this.toggleBlackout()
        break
      case "+":
      case "=":
        event.preventDefault()
        this.zoomIn()
        break
      case "-":
      case "_":
        event.preventDefault()
        this.zoomOut()
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

  zoomIn() {
    this.zoom = Math.min(this.zoom + 0.15, 2.5)
    this.renderCurrent()
  }

  zoomOut() {
    this.zoom = Math.max(this.zoom - 0.15, 0.5)
    this.renderCurrent()
  }

  togglePointer() {
    this.pointerEnabled = !this.pointerEnabled
    this.pointerTarget.classList.toggle("is-visible", this.pointerEnabled)
    this.stageTarget.classList.toggle("has-pointer", this.pointerEnabled)
  }

  toggleBlackout() {
    this.blackoutTarget.classList.toggle("is-visible")
  }

  fullscreen() {
    if (!document.fullscreenElement) {
      this.element.requestFullscreen?.()
    } else {
      document.exitFullscreen?.()
    }
  }

  wakeToolbar() {
    this.toolbarTarget.classList.remove("is-hidden")
    window.clearTimeout(this.hideToolbarTimer)
    this.hideToolbarTimer = window.setTimeout(() => {
      this.toolbarTarget.classList.add("is-hidden")
    }, 2600)
  }

  onPointerMove(event) {
    if (!this.pointerEnabled) return

    const rect = this.stageTarget.getBoundingClientRect()
    this.pointerTarget.style.left = `${event.clientX - rect.left}px`
    this.pointerTarget.style.top = `${event.clientY - rect.top}px`
  }

  async renderCurrent() {
    if (!this.pdf || !this.naturalWidth) return
    const token = ++this.renderToken

    const page = await this.pdf.getPage(this.pageNum)
    if (token !== this.renderToken) return

    const wrap = this.stageTarget
    const availableWidth = Math.max(wrap.clientWidth - 32, 100)
    const availableHeight = Math.max(wrap.clientHeight - 32, 100)
    const scaleX = availableWidth / this.naturalWidth
    const scaleY = availableHeight / this.naturalHeight
    const scale = Math.min(scaleX, scaleY) * this.zoom

    const viewport = page.getViewport({ scale })
    const canvas = this.canvasTarget
    const ctx = canvas.getContext("2d")
    const dpr = window.devicePixelRatio || 1
    canvas.width = Math.floor(viewport.width * dpr)
    canvas.height = Math.floor(viewport.height * dpr)
    canvas.style.width = `${Math.floor(viewport.width)}px`
    canvas.style.height = `${Math.floor(viewport.height)}px`
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0)
    ctx.clearRect(0, 0, viewport.width, viewport.height)

    await page.render({ canvasContext: ctx, viewport }).promise
    if (token !== this.renderToken) return

    this.indicatorTarget.textContent = `${this.pageNum} / ${this.pdf.numPages}`
    this.updateProgress()
    this.updateActiveThumbnail()
  }

  updateProgress() {
    if (!this.pdf) return
    const percent = (this.pageNum / this.pdf.numPages) * 100
    this.progressTarget.style.width = `${percent}%`
  }

  buildThumbnails() {
    this.thumbsTarget.replaceChildren()
    for (let page = 1; page <= this.pdf.numPages; page++) {
      const button = document.createElement("button")
      button.type = "button"
      button.className = "thumb-btn"
      button.dataset.page = page
      button.title = `Trang ${page}`
      button.setAttribute("aria-label", `Trang ${page}`)
      button.addEventListener("click", () => {
        this.pageNum = page
        this.renderCurrent()
      })

      const canvas = document.createElement("canvas")
      const label = document.createElement("span")
      label.textContent = page
      button.append(canvas, label)
      this.thumbsTarget.append(button)
      this.renderThumbnail(page, canvas)
    }
  }

  async renderThumbnail(pageNum, canvas) {
    const page = await this.pdf.getPage(pageNum)
    const base = page.getViewport({ scale: 1 })
    const viewport = page.getViewport({ scale: 92 / base.width })
    const context = canvas.getContext("2d")
    const dpr = window.devicePixelRatio || 1

    canvas.width = Math.floor(viewport.width * dpr)
    canvas.height = Math.floor(viewport.height * dpr)
    canvas.style.width = `${Math.floor(viewport.width)}px`
    canvas.style.height = `${Math.floor(viewport.height)}px`
    context.setTransform(dpr, 0, 0, dpr, 0, 0)

    await page.render({ canvasContext: context, viewport }).promise
    this.updateActiveThumbnail()
  }

  updateActiveThumbnail() {
    this.thumbsTarget.querySelectorAll(".thumb-btn").forEach((button) => {
      button.classList.toggle("is-active", Number(button.dataset.page) === this.pageNum)
    })

    const active = this.thumbsTarget.querySelector(".thumb-btn.is-active")
    active?.scrollIntoView({ block: "nearest", inline: "nearest" })
  }

  showError(err) {
    console.error("Slideshow error:", err)
    this.indicatorTarget.textContent = "Lỗi tải PDF"
    const message = document.createElement("div")
    message.className = "presenter-error"
    message.textContent = `Không thể tải file PDF: ${err && err.message ? err.message : err}`
    this.stageTarget.appendChild(message)
  }
}
