import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button"]

  connect() {
    this.isRecording = false
    this.isPlaying = false
    this.mediaRecorder = null
    this.audioChunks = []
    this.audio = null
    this.recordingTimer = null
  }

  async toggle() {
    if (this.isRecording || this.isPlaying) {
      this.stop()
    } else {
      await this.startRecording()
    }
  }

  async startRecording() {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true })
      
      this.mediaRecorder = new MediaRecorder(stream)
      this.audioChunks = []
      
      this.mediaRecorder.ondataavailable = (event) => {
        this.audioChunks.push(event.data)
      }
      
      this.mediaRecorder.onstop = () => {
        stream.getTracks().forEach(track => track.stop())
        this.playRecording()
      }
      
      this.mediaRecorder.start()
      this.isRecording = true
      this.updateButton("Stop")
      
      // Stop recording after 10 seconds
      this.recordingTimer = setTimeout(() => {
        if (this.isRecording) {
          this.mediaRecorder.stop()
          this.isRecording = false
        }
      }, 10000)
      
    } catch (error) {
      this.handleError(error)
    }
  }

  playRecording() {
    const audioBlob = new Blob(this.audioChunks, { type: 'audio/webm' })
    const audioUrl = URL.createObjectURL(audioBlob)
    
    this.audio = new Audio(audioUrl)
    this.audio.onended = () => {
      this.isPlaying = false
      this.updateButton("Start Recording")
      URL.revokeObjectURL(audioUrl)
    }
    
    this.isPlaying = true
    this.updateButton("Stop")
    this.audio.play()
  }

  stop() {
    if (this.recordingTimer) {
      clearTimeout(this.recordingTimer)
      this.recordingTimer = null
    }
    
    if (this.isRecording && this.mediaRecorder) {
      this.mediaRecorder.stop()
      this.isRecording = false
    }
    
    if (this.isPlaying && this.audio) {
      this.audio.pause()
      this.audio = null
      this.isPlaying = false
    }
    
    this.updateButton("Start Recording")
  }

  updateButton(text) {
    if (this.hasButtonTarget) {
      this.buttonTarget.textContent = text
    }
  }

  handleError(error) {
    let message = "Audio recording error: "
    
    if (error.name === 'NotAllowedError' || error.name === 'PermissionDeniedError') {
      message += "Microphone access denied. Please allow microphone access in your browser settings and reload the page."
    } else if (error.name === 'NotFoundError') {
      message += "No microphone found. Please connect a microphone and reload the page."
    } else {
      message += error.message
    }
    
    alert(message)
    console.error('Audio recording error:', error)
  }

  disconnect() {
    this.stop()
  }
}