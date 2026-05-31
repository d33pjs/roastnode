import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "error", "currentPassword", "nickname" ]
  static values = {
    optionsUrl: String,
    submitUrl: String
  }

  async register(event) {
    event.preventDefault()
    this.clearError()

    try {
      const options = await this.postJson(this.optionsUrlValue, {
        current_password: this.currentPasswordTarget.value
      })
      const credential = await navigator.credentials.create({
        publicKey: this.decodeCreationOptions(options)
      })
      const response = await this.postJson(this.submitUrlValue, {
        nickname: this.hasNicknameTarget ? this.nicknameTarget.value : "",
        credential: this.encodeRegistrationCredential(credential)
      })

      window.location.href = response.redirect_url
    } catch (error) {
      this.showError(error)
    }
  }

  async authenticate(event) {
    event.preventDefault()
    this.clearError()

    try {
      const options = await this.postJson(this.optionsUrlValue, {})
      const credential = await navigator.credentials.get({
        publicKey: this.decodeRequestOptions(options)
      })
      const response = await this.postJson(this.submitUrlValue, {
        credential: this.encodeAssertionCredential(credential)
      })

      window.location.href = response.redirect_url
    } catch (error) {
      this.showError(error)
    }
  }

  async postJson(url, body) {
    const response = await fetch(url, {
      method: "POST",
      credentials: "same-origin",
      headers: this.jsonHeaders(),
      body: JSON.stringify(body)
    })
    const payload = await response.json()

    if (!response.ok) {
      throw new Error(payload.error || response.statusText)
    }

    return payload
  }

  jsonHeaders() {
    return {
      "Accept": "application/json",
      "Content-Type": "application/json",
      "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content || ""
    }
  }

  decodeCreationOptions(options) {
    const decoded = { ...options }
    decoded.challenge = this.base64urlToBuffer(decoded.challenge)

    if (decoded.user?.id) {
      decoded.user = {
        ...decoded.user,
        id: this.base64urlToBuffer(decoded.user.id)
      }
    }

    if (decoded.excludeCredentials) {
      decoded.excludeCredentials = decoded.excludeCredentials.map((credential) => ({
        ...credential,
        id: this.base64urlToBuffer(credential.id)
      }))
    }

    return decoded
  }

  decodeRequestOptions(options) {
    const decoded = { ...options }
    decoded.challenge = this.base64urlToBuffer(decoded.challenge)

    if (decoded.allowCredentials) {
      decoded.allowCredentials = decoded.allowCredentials.map((credential) => ({
        ...credential,
        id: this.base64urlToBuffer(credential.id)
      }))
    }

    return decoded
  }

  encodeRegistrationCredential(credential) {
    return {
      id: credential.id,
      rawId: this.bufferToBase64url(credential.rawId),
      type: credential.type,
      response: {
        clientDataJSON: this.bufferToBase64url(credential.response.clientDataJSON),
        attestationObject: this.bufferToBase64url(credential.response.attestationObject)
      },
      clientExtensionResults: credential.getClientExtensionResults()
    }
  }

  encodeAssertionCredential(credential) {
    return {
      id: credential.id,
      rawId: this.bufferToBase64url(credential.rawId),
      type: credential.type,
      response: {
        clientDataJSON: this.bufferToBase64url(credential.response.clientDataJSON),
        authenticatorData: this.bufferToBase64url(credential.response.authenticatorData),
        signature: this.bufferToBase64url(credential.response.signature),
        userHandle: credential.response.userHandle ? this.bufferToBase64url(credential.response.userHandle) : null
      },
      clientExtensionResults: credential.getClientExtensionResults()
    }
  }

  base64urlToBuffer(value) {
    const base64 = value.replace(/-/g, "+").replace(/_/g, "/")
    const padded = base64.padEnd(base64.length + ((4 - base64.length % 4) % 4), "=")
    const binary = atob(padded)
    const bytes = new Uint8Array(binary.length)

    for (let index = 0; index < binary.length; index++) {
      bytes[index] = binary.charCodeAt(index)
    }

    return bytes.buffer
  }

  bufferToBase64url(buffer) {
    const bytes = new Uint8Array(buffer)
    const chunks = []

    for (let index = 0; index < bytes.length; index += 0x8000) {
      chunks.push(String.fromCharCode(...bytes.subarray(index, index + 0x8000)))
    }

    return btoa(chunks.join(""))
      .replace(/\+/g, "-")
      .replace(/\//g, "_")
      .replace(/=+$/g, "")
  }

  clearError() {
    if (!this.hasErrorTarget) return

    this.errorTarget.textContent = ""
    this.errorTarget.classList.add("hidden")
  }

  showError(error) {
    if (!this.hasErrorTarget) return

    this.errorTarget.textContent = error.message
    this.errorTarget.classList.remove("hidden")
  }
}
