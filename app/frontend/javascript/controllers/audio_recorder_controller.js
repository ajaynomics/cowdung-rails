import { Controller } from "@hotwired/stimulus"
import consumer from "../channels/consumer"

export default class extends Controller {
  static targets = [
    "startBtn", "stopBtn", "indicator", "status", 
    "visualizer", "connectionIndicator", "connectionStatus",
    "muteBtn", "permissionError", "permissionInstructions",
    "results", "resultsList"
  ]
  
  connect() {
    this.stream = null
    this.mediaRecorder = null
    this.audioContext = null
    this.analyser = null
    this.subscription = null
    this.isMuted = false
    this.isRecording = false
    
    // Set up canvas for visualization
    this.setupCanvas()
  }
  
  setupCanvas() {
    const canvas = this.visualizerTarget
    canvas.width = canvas.offsetWidth
    canvas.height = canvas.offsetHeight
    this.canvasContext = canvas.getContext('2d')
  }
  
  async start() {
    try {
      // Request microphone permission
      this.stream = await navigator.mediaDevices.getUserMedia({ audio: true })
      
      // Set up audio context and analyser for visualization
      this.audioContext = new (window.AudioContext || window.webkitAudioContext)()
      this.analyser = this.audioContext.createAnalyser()
      this.analyser.fftSize = 256
      
      const source = this.audioContext.createMediaStreamSource(this.stream)
      source.connect(this.analyser)
      
      // Set up MediaRecorder for streaming
      const options = {
        mimeType: 'audio/webm;codecs=opus',
        audioBitsPerSecond: 16000 // Low bitrate for streaming
      }
      
      this.mediaRecorder = new MediaRecorder(this.stream, options)
      
      // Stream audio chunks every second
      this.mediaRecorder.ondataavailable = (event) => {
        if (event.data.size > 0 && this.subscription && !this.isMuted) {
          // Convert blob to base64 for transmission
          const reader = new FileReader()
          reader.onloadend = () => {
            const base64data = reader.result.split(',')[1]
            this.subscription.send({ audio_chunk: base64data })
          }
          reader.readAsDataURL(event.data)
        }
      }
      
      // Set up ActionCable subscription
      this.setupSubscription()
      
      // Start recording with 1-second chunks
      this.mediaRecorder.start(1000)
      this.isRecording = true
      
      // Update UI
      this.updateUI(true)
      this.statusTarget.textContent = "Listening for BS..."
      
      // Start visualization
      this.visualize()
      
    } catch (error) {
      this.handlePermissionError(error)
    }
  }
  
  setupSubscription() {
    this.subscription = consumer.subscriptions.create("DetectorChannel", {
      connected: () => {
        this.updateConnectionStatus(true)
      },
      
      disconnected: () => {
        this.updateConnectionStatus(false)
      },
      
      received: (data) => {
        // Handle BS detection results
        if (data.bs_detected) {
          this.displayResult(data)
        }
      }
    })
  }
  
  updateConnectionStatus(connected) {
    if (connected) {
      this.connectionIndicatorTarget.classList.remove('bg-gray-400')
      this.connectionIndicatorTarget.classList.add('bg-green-500')
      this.connectionStatusTarget.textContent = 'Connected'
    } else {
      this.connectionIndicatorTarget.classList.remove('bg-green-500')
      this.connectionIndicatorTarget.classList.add('bg-gray-400')
      this.connectionStatusTarget.textContent = 'Disconnected'
    }
  }
  
  stop() {
    if (this.mediaRecorder && this.mediaRecorder.state !== 'inactive') {
      this.mediaRecorder.stop()
    }
    
    if (this.stream) {
      this.stream.getTracks().forEach(track => track.stop())
      this.stream = null
    }
    
    if (this.audioContext) {
      this.audioContext.close()
      this.audioContext = null
    }
    
    if (this.subscription) {
      this.subscription.unsubscribe()
      this.subscription = null
    }
    
    this.isRecording = false
    this.updateUI(false)
    this.statusTarget.textContent = "Stopped detecting"
    this.updateConnectionStatus(false)
    
    // Clear visualization
    this.clearVisualization()
  }
  
  toggleMute() {
    this.isMuted = !this.isMuted
    
    if (this.isMuted) {
      this.muteBtnTarget.classList.add('text-red-500')
      this.muteBtnTarget.classList.remove('text-gray-500')
      this.statusTarget.textContent = "Muted - not sending audio"
    } else {
      this.muteBtnTarget.classList.remove('text-red-500')
      this.muteBtnTarget.classList.add('text-gray-500')
      if (this.isRecording) {
        this.statusTarget.textContent = "Listening for BS..."
      }
    }
  }
  
  visualize() {
    if (!this.isRecording || !this.analyser) return
    
    const bufferLength = this.analyser.frequencyBinCount
    const dataArray = new Uint8Array(bufferLength)
    
    const draw = () => {
      if (!this.isRecording) return
      
      requestAnimationFrame(draw)
      
      this.analyser.getByteFrequencyData(dataArray)
      
      const canvas = this.visualizerTarget
      const ctx = this.canvasContext
      const width = canvas.width
      const height = canvas.height
      
      ctx.fillStyle = 'rgb(243, 244, 246)' // bg-gray-100
      ctx.fillRect(0, 0, width, height)
      
      const barWidth = (width / bufferLength) * 2.5
      let barHeight
      let x = 0
      
      for (let i = 0; i < bufferLength; i++) {
        barHeight = (dataArray[i] / 255) * height * 0.8
        
        // Color based on volume
        const intensity = dataArray[i] / 255
        if (this.isMuted) {
          ctx.fillStyle = `rgb(156, 163, 175)` // gray-400
        } else if (intensity > 0.7) {
          ctx.fillStyle = `rgb(239, 68, 68)` // red-500
        } else if (intensity > 0.4) {
          ctx.fillStyle = `rgb(251, 191, 36)` // amber-400
        } else {
          ctx.fillStyle = `rgb(34, 197, 94)` // green-500
        }
        
        ctx.fillRect(x, height - barHeight, barWidth, barHeight)
        
        x += barWidth + 1
      }
    }
    
    draw()
  }
  
  clearVisualization() {
    const canvas = this.visualizerTarget
    const ctx = this.canvasContext
    ctx.fillStyle = 'rgb(243, 244, 246)'
    ctx.fillRect(0, 0, canvas.width, canvas.height)
  }
  
  updateUI(isRecording) {
    this.startBtnTarget.classList.toggle("hidden", isRecording)
    this.stopBtnTarget.classList.toggle("hidden", !isRecording)
    this.indicatorTarget.classList.toggle("hidden", !isRecording)
  }
  
  handlePermissionError(error) {
    console.error("Microphone access error:", error)
    
    this.permissionErrorTarget.classList.remove("hidden")
    this.statusTarget.textContent = "Microphone access denied"
    
    // Detect browser and provide specific instructions
    const instructions = this.getBrowserInstructions()
    this.permissionInstructionsTarget.innerHTML = instructions
  }
  
  getBrowserInstructions() {
    const userAgent = navigator.userAgent.toLowerCase()
    
    if (userAgent.includes('chrome') && !userAgent.includes('edg')) {
      return `
        <p class="mb-2">To enable microphone access in Chrome:</p>
        <ol class="list-decimal list-inside space-y-1">
          <li>Click the camera/lock icon in the address bar</li>
          <li>Find "Microphone" and change to "Allow"</li>
          <li>Refresh the page and try again</li>
        </ol>
      `
    } else if (userAgent.includes('firefox')) {
      return `
        <p class="mb-2">To enable microphone access in Firefox:</p>
        <ol class="list-decimal list-inside space-y-1">
          <li>Click the lock icon in the address bar</li>
          <li>Click "Connection secure" → "More information"</li>
          <li>Go to "Permissions" tab and find "Use the Microphone"</li>
          <li>Uncheck "Use Default" and select "Allow"</li>
          <li>Refresh the page and try again</li>
        </ol>
      `
    } else if (userAgent.includes('safari')) {
      return `
        <p class="mb-2">To enable microphone access in Safari:</p>
        <ol class="list-decimal list-inside space-y-1">
          <li>Go to Safari → Preferences → Websites</li>
          <li>Click on "Microphone" in the left sidebar</li>
          <li>Find this website and change to "Allow"</li>
          <li>Refresh the page and try again</li>
        </ol>
      `
    } else {
      return `
        <p>Please check your browser settings and allow microphone access for this website, then refresh the page.</p>
      `
    }
  }
  
  async requestPermission() {
    this.permissionErrorTarget.classList.add("hidden")
    await this.start()
  }
  
  displayResult(data) {
    // This will be implemented in a future phase
    console.log("BS detected:", data)
  }
  
  disconnect() {
    this.stop()
  }
}