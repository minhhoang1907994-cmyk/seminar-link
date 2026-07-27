import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "passwordDialog",
    "passwordTitle",
    "passwordInput",
    "passwordError",
    "editDialog",
    "editForm",
    "editUploader",
    "editDescription",
    "editPassword",
    "errorDialog",
    "errorText",
    "copyStatus"
  ]

  openDelete(event) {
    this.current = this.readActionData(event.currentTarget, "delete")
    this.passwordTitleTarget.textContent = `Xóa ${this.current.name}`
    this.openPasswordDialog()
  }

  openEdit(event) {
    this.current = this.readActionData(event.currentTarget, "edit")
    this.passwordTitleTarget.textContent = `Sửa ${this.current.name}`
    this.openPasswordDialog()
  }

  closePassword() {
    this.passwordDialogTarget.close()
  }

  closeEdit() {
    this.editDialogTarget.close()
  }

  openError(event) {
    this.errorTextTarget.textContent = event.currentTarget.dataset.errorMessage || "Không có chi tiết lỗi."
    this.errorDialogTarget.showModal()
  }

  closeError() {
    this.errorDialogTarget.close()
  }

  copyShare(event) {
    const url = event.currentTarget.dataset.shareUrl
    if (!url) return

    navigator.clipboard.writeText(url).then(() => {
      if (this.hasCopyStatusTarget) {
        this.copyStatusTarget.textContent = "Đã copy link chia sẻ."
      }
    })
  }

  verifyPassword(event) {
    event.preventDefault()
    const password = this.passwordInputTarget.value
    this.passwordErrorTarget.textContent = ""

    fetch(this.current.verifyUrl, {
      method: "POST",
      headers: {
        "Accept": "application/json",
        "Content-Type": "application/x-www-form-urlencoded",
        "X-CSRF-Token": this.csrfToken()
      },
      body: new URLSearchParams({ file_password: password })
    })
      .then((response) => response.json())
      .then((data) => {
        if (!data.ok) {
          this.passwordErrorTarget.textContent = "Sai mật khẩu file."
          return
        }

        if (this.current.mode === "delete") {
          this.submitDelete(password)
        } else {
          this.openEditDialog(password)
        }
      })
      .catch(() => {
        this.passwordErrorTarget.textContent = "Không thể xác thực mật khẩu."
      })
  }

  readActionData(button, mode) {
    return {
      mode,
      id: button.dataset.documentId,
      name: button.dataset.documentName,
      verifyUrl: button.dataset.verifyUrl,
      deleteUrl: button.dataset.deleteUrl,
      updateUrl: button.dataset.updateUrl,
      uploader: button.dataset.uploader || "",
      description: button.dataset.description || ""
    }
  }

  openPasswordDialog() {
    this.passwordInputTarget.value = ""
    this.passwordErrorTarget.textContent = ""
    this.passwordDialogTarget.showModal()
    this.passwordInputTarget.focus()
  }

  submitDelete(password) {
    const form = document.createElement("form")
    form.method = "post"
    form.action = this.current.deleteUrl
    form.append(this.hidden("authenticity_token", this.csrfToken()))
    form.append(this.hidden("_method", "delete"))
    form.append(this.hidden("file_password", password))
    document.body.append(form)
    form.submit()
  }

  openEditDialog(password) {
    this.passwordDialogTarget.close()
    this.editFormTarget.action = this.current.updateUrl
    this.editUploaderTarget.value = this.current.uploader
    this.editDescriptionTarget.value = this.current.description
    this.editPasswordTarget.value = password
    this.editDialogTarget.showModal()
    this.editUploaderTarget.focus()
  }

  hidden(name, value) {
    const input = document.createElement("input")
    input.type = "hidden"
    input.name = name
    input.value = value
    return input
  }

  csrfToken() {
    return document.querySelector("meta[name='csrf-token']").content
  }
}
