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
    this.sessionId = null
    this.audioChunks = []
    this.chunkStartTime = null
    
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
      // Generate session ID for this recording session
      this.sessionId = `session-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`
      
      // Request microphone permission
      this.stream = await navigator.mediaDevices.getUserMedia({ audio: true })
      
      // Set up audio context and analyser for visualization
      this.audioContext = new (window.AudioContext || window.webkitAudioContext)()
      this.analyser = this.audioContext.createAnalyser()
      this.analyser.fftSize = 256
      
      const source = this.audioContext.createMediaStreamSource(this.stream)
      source.connect(this.analyser)
      
      // Set up audio capture using ScriptProcessorNode for PCM data
      // This gives us raw audio we can easily process
      const bufferSize = 16384 // ~370ms at 44.1kHz
      this.sampleRate = this.audioContext.sampleRate
      this.scriptProcessor = this.audioContext.createScriptProcessor(bufferSize, 1, 1)
      this.pcmChunks = []
      this.chunkDuration = 1000 // 1 second chunks
      
      // Connect audio pipeline
      source.connect(this.scriptProcessor)
      this.scriptProcessor.connect(this.audioContext.destination)
      
      // Capture PCM data
      this.scriptProcessor.onaudioprocess = (event) => {
        if (!this.isRecording || this.isMuted) return
        
        const inputData = event.inputBuffer.getChannelData(0)
        // Convert Float32Array to Int16Array for smaller size
        const pcm16 = new Int16Array(inputData.length)
        for (let i = 0; i < inputData.length; i++) {
          const s = Math.max(-1, Math.min(1, inputData[i]))
          pcm16[i] = s < 0 ? s * 0x8000 : s * 0x7FFF
        }
        
        this.pcmChunks.push(pcm16)
      }
      
      // Set up ActionCable subscription
      this.setupSubscription()
      
      // Send PCM data every second
      this.sendInterval = setInterval(() => {
        if (this.pcmChunks.length > 0 && this.subscription && !this.isMuted) {
          // Combine PCM chunks
          const totalLength = this.pcmChunks.reduce((acc, chunk) => acc + chunk.length, 0)
          const combined = new Int16Array(totalLength)
          let offset = 0
          this.pcmChunks.forEach(chunk => {
            combined.set(chunk, offset)
            offset += chunk.length
          })
          
          // Convert to base64
          const buffer = combined.buffer
          const base64 = btoa(String.fromCharCode(...new Uint8Array(buffer)))
          
          console.log(`Sending PCM audio: ${totalLength} samples (${(totalLength/this.sampleRate).toFixed(2)}s)`)
          this.subscription.perform('receive_audio', { 
            audio_chunk: base64,
            format: 'pcm16',
            sample_rate: this.sampleRate
          })
          
          // Clear chunks
          this.pcmChunks = []
        }
      }, this.chunkDuration)
      
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
    this.subscription = consumer.subscriptions.create({
      channel: "DetectorChannel",
      session_id: this.sessionId
    }, {
      connected: () => {
        this.updateConnectionStatus(true)
      },
      
      disconnected: () => {
        this.updateConnectionStatus(false)
      },
      
      received: (data) => {
        // Handle different types of messages
        if (data.type === 'transcription') {
          this.displayTranscription(data)
        } else if (data.bs_detected) {
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
    // Stop recording
    this.isRecording = false
    
    // Clear send interval
    if (this.sendInterval) {
      clearInterval(this.sendInterval)
      this.sendInterval = null
    }
    
    // Disconnect audio nodes
    if (this.scriptProcessor) {
      this.scriptProcessor.disconnect()
      this.scriptProcessor = null
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
    
    // Clear any remaining PCM data
    this.pcmChunks = []
    
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
  
  displayTranscription(data) {
    // Show the results section
    this.resultsTarget.classList.remove("hidden")
    
    // Create a new transcription entry
    const entry = document.createElement("div")
    entry.className = "mb-4 p-4 bg-gray-50 rounded-lg"
    entry.innerHTML = `
      <div class="text-sm text-gray-500 mb-1">
        ${new Date(data.timestamp).toLocaleTimeString()}
      </div>
      <div class="text-gray-800">
        ${data.text}
      </div>
    `
    
    // Append to results list
    this.resultsListTarget.appendChild(entry)
    
    // Scroll to bottom to show latest
    this.resultsListTarget.scrollTop = this.resultsListTarget.scrollHeight
  }
  
  
  disconnect() {
    this.stop()
  }
}