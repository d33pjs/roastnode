import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "stage", "image", "box", "preview", "fileInput", "form" ]
  static values = { filename: String }

  connect() {
    this.dragging = false
    this.submitting = false
    this.selection = null

    if (this.imageTarget.complete) {
      this.initializeSelection()
    } else {
      this.imageTarget.addEventListener("load", () => this.initializeSelection(), { once: true })
    }
  }

  start(event) {
    event.preventDefault()
    this.dragging = true
    this.startPoint = this.pointFromEvent(event)
    this.selection = { x: this.startPoint.x, y: this.startPoint.y, width: 1, height: 1 }
    this.stageTarget.setPointerCapture(event.pointerId)
    this.renderSelection()
  }

  move(event) {
    if (!this.dragging) return

    event.preventDefault()
    const point = this.pointFromEvent(event)
    this.selection = this.selectionFromPoints(this.startPoint, point)
    this.renderSelection()
  }

  finish(event) {
    if (!this.dragging) return

    event.preventDefault()
    this.dragging = false
    this.renderSelection()
    this.renderPreview()
  }

  submit(event) {
    if (this.submitting) return

    event.preventDefault()
    const crop = this.cropInNaturalPixels()
    if (!crop) return

    const canvas = document.createElement("canvas")
    canvas.width = crop.width
    canvas.height = crop.height

    const context = canvas.getContext("2d")
    context.drawImage(this.imageTarget, crop.x, crop.y, crop.width, crop.height, 0, 0, crop.width, crop.height)

    canvas.toBlob((blob) => {
      if (!blob) return

      const dataTransfer = new DataTransfer()
      dataTransfer.items.add(new File([ blob ], this.filenameValue, { type: "image/jpeg" }))
      this.fileInputTarget.files = dataTransfer.files
      this.submitting = true
      this.formTarget.requestSubmit()
    }, "image/jpeg", 0.92)
  }

  initializeSelection() {
    const imageRect = this.displayedImageRect
    if (!imageRect.width || !imageRect.height) return

    const size = Math.min(imageRect.width, imageRect.height) * 0.72
    this.selection = {
      x: imageRect.left + (imageRect.width - size) / 2,
      y: imageRect.top + (imageRect.height - size) / 2,
      width: size,
      height: size
    }
    this.renderSelection()
    this.renderPreview()
  }

  renderSelection() {
    if (!this.selection) return

    this.boxTarget.classList.remove("hidden")
    this.boxTarget.style.left = `${this.selection.x}px`
    this.boxTarget.style.top = `${this.selection.y}px`
    this.boxTarget.style.width = `${this.selection.width}px`
    this.boxTarget.style.height = `${this.selection.height}px`
  }

  renderPreview() {
    const crop = this.cropInNaturalPixels()
    if (!crop) return

    const preview = this.previewTarget
    const previewSize = 420
    const ratio = crop.width / crop.height
    preview.width = ratio >= 1 ? previewSize : Math.round(previewSize * ratio)
    preview.height = ratio >= 1 ? Math.round(previewSize / ratio) : previewSize

    const context = preview.getContext("2d")
    context.clearRect(0, 0, preview.width, preview.height)
    context.drawImage(this.imageTarget, crop.x, crop.y, crop.width, crop.height, 0, 0, preview.width, preview.height)
  }

  cropInNaturalPixels() {
    if (!this.selection || !this.imageTarget.naturalWidth || !this.imageTarget.naturalHeight) return null

    const imageRect = this.displayedImageRect
    if (!imageRect.width || !imageRect.height) return null

    const selection = this.selectionInsideImage(imageRect)
    if (!selection) return null

    const scaleX = this.imageTarget.naturalWidth / imageRect.width
    const scaleY = this.imageTarget.naturalHeight / imageRect.height

    return {
      x: Math.round((selection.x - imageRect.left) * scaleX),
      y: Math.round((selection.y - imageRect.top) * scaleY),
      width: Math.max(1, Math.round(selection.width * scaleX)),
      height: Math.max(1, Math.round(selection.height * scaleY))
    }
  }

  selectionFromPoints(start, end) {
    const x = Math.min(start.x, end.x)
    const y = Math.min(start.y, end.y)

    return {
      x,
      y,
      width: Math.max(1, Math.abs(end.x - start.x)),
      height: Math.max(1, Math.abs(end.y - start.y))
    }
  }

  pointFromEvent(event) {
    const bounds = this.stageTarget.getBoundingClientRect()
    const imageRect = this.displayedImageRect

    return {
      x: this.clamp(event.clientX - bounds.left, imageRect.left, imageRect.left + imageRect.width),
      y: this.clamp(event.clientY - bounds.top, imageRect.top, imageRect.top + imageRect.height)
    }
  }

  selectionInsideImage(imageRect) {
    const left = this.clamp(this.selection.x, imageRect.left, imageRect.left + imageRect.width)
    const top = this.clamp(this.selection.y, imageRect.top, imageRect.top + imageRect.height)
    const right = this.clamp(this.selection.x + this.selection.width, imageRect.left, imageRect.left + imageRect.width)
    const bottom = this.clamp(this.selection.y + this.selection.height, imageRect.top, imageRect.top + imageRect.height)
    const width = right - left
    const height = bottom - top

    if (width <= 0 || height <= 0) return null

    return { x: left, y: top, width, height }
  }

  get displayedImageRect() {
    const stageRect = this.stageTarget.getBoundingClientRect()
    const imageRect = this.imageTarget.getBoundingClientRect()
    if (!imageRect.width || !imageRect.height || !this.imageTarget.naturalWidth || !this.imageTarget.naturalHeight) {
      return { left: 0, top: 0, width: 0, height: 0 }
    }

    const naturalRatio = this.imageTarget.naturalWidth / this.imageTarget.naturalHeight
    const boxRatio = imageRect.width / imageRect.height
    let width = imageRect.width
    let height = imageRect.height
    let left = imageRect.left - stageRect.left
    let top = imageRect.top - stageRect.top

    if (boxRatio > naturalRatio) {
      width = imageRect.height * naturalRatio
      left += (imageRect.width - width) / 2
    } else {
      height = imageRect.width / naturalRatio
      top += (imageRect.height - height) / 2
    }

    return { left, top, width, height }
  }

  clamp(value, minimum, maximum) {
    return Math.min(maximum, Math.max(minimum, value))
  }
}
