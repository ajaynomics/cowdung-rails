import { Controller } from "@hotwired/stimulus"
import consumer from "../channels/consumer"

export default class extends Controller {
  static targets = [
    "startBtn", "stopBtn", "indicator", "status", 
    "visualizer", "connectionIndicator", "connectionStatus",
    "muteBtn", "permissionError", "permissionInstructions",
    "results", "resultsList", "bsIndicator", "recordingTime",
    "bsHistory", "bsHistoryList"
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
    this.startTime = null
    this.timerInterval = null
    
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
      // Clear previous transcriptions
      this.resultsTarget.classList.add("hidden")
      this.resultsListTarget.innerHTML = ""
      
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
          pcm16[i] = Math.max(-32768, Math.min(32767, inputData[i] * 32768))
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
      
      // Start recording timer
      this.startTime = Date.now()
      this.startTimer()
      
      // Update UI
      this.updateUI(true)
      this.statusTarget.textContent = "Recording audio..."
      
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
        } else if (data.type === 'bullshit_detected') {
          this.displayBullshitAlert(data)
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
    
    // Stop timer
    if (this.timerInterval) {
      clearInterval(this.timerInterval)
      this.timerInterval = null
    }
    
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
    this.statusTarget.textContent = "Stopped recording"
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
        this.statusTarget.textContent = "Recording audio..."
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
    
    // Show/hide BS detection indicator
    if (this.hasBsIndicatorTarget) {
      this.bsIndicatorTarget.classList.toggle("hidden", !isRecording)
    }
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
  
  startTimer() {
    this.timerInterval = setInterval(() => {
      const elapsed = Math.floor((Date.now() - this.startTime) / 1000)
      const minutes = Math.floor(elapsed / 60).toString().padStart(2, '0')
      const seconds = (elapsed % 60).toString().padStart(2, '0')
      if (this.hasRecordingTimeTarget) {
        this.recordingTimeTarget.textContent = `${minutes}:${seconds}`
      }
    }, 1000)
  }
  
  
  displayTranscription(data) {
    // Show the results section with animation
    this.resultsTarget.classList.remove("hidden")
    
    if (data.narrative_text) {
      // Display as flowing narrative with improved styling
      this.resultsListTarget.innerHTML = `
        <div class="prose prose-gray max-w-none transcript-fade-in">
          <p class="text-gray-800 leading-relaxed text-lg">${data.narrative_text}</p>
        </div>
        <div class="flex items-center justify-between mt-3 pt-3 border-t border-gray-100">
          <div class="text-xs text-gray-400">
            Last updated: ${new Date(data.timestamp).toLocaleTimeString()}
          </div>
          <div class="text-xs text-gray-500">
            Session: ${data.session_id || this.sessionId}
          </div>
        </div>
      `
      
      // Auto-scroll to bottom
      this.resultsListTarget.scrollTop = this.resultsListTarget.scrollHeight
    }
  }
  
  displayBullshitAlert(data) {
    if (!data.detected) return
    
    // Show BS history section
    if (this.hasBsHistoryTarget) {
      this.bsHistoryTarget.classList.remove("hidden")
    }
    
    // Add to BS history list
    if (this.hasBsHistoryListTarget) {
      const bsItem = document.createElement('div')
      bsItem.className = 'bg-red-50 border border-red-200 rounded-lg p-4 bs-alert-shake'
      
      const categoryEmoji = {
        'misinformation': '📰',
        'exaggeration': '📈',
        'misleading': '🎭',
        'false_claim': '❌',
        'manipulation': '🎯'
      }[data.category] || '🚨'
      
      bsItem.innerHTML = `
        <div class="flex items-start space-x-3">
          <span class="text-2xl">${categoryEmoji}</span>
          <div class="flex-1">
            <div class="flex items-center justify-between mb-1">
              <span class="text-sm font-semibold text-red-800 capitalize">${data.category || 'Detected'}</span>
              <span class="text-xs text-red-500">${new Date(data.timestamp).toLocaleTimeString()}</span>
            </div>
            <p class="text-sm text-red-700 mb-2">${data.explanation}</p>
            ${data.quote ? `<p class="text-xs text-red-600 italic bg-red-100 p-2 rounded">"${data.quote}"</p>` : ''}
            <div class="flex items-center justify-between mt-2">
              <span class="text-xs text-red-500">Confidence: ${Math.round(data.confidence * 100)}%</span>
              ${data.severity ? `<span class="text-xs font-medium text-red-600">Severity: ${data.severity}/5</span>` : ''}
            </div>
          </div>
        </div>
      `
      
      // Add to top of list
      this.bsHistoryListTarget.insertBefore(bsItem, this.bsHistoryListTarget.firstChild)
      
      // Limit to 10 items
      while (this.bsHistoryListTarget.children.length > 10) {
        this.bsHistoryListTarget.removeChild(this.bsHistoryListTarget.lastChild)
      }
    }
    
    // Create floating alert
    let alertContainer = document.getElementById('bullshit-alert')
    if (!alertContainer) {
      alertContainer = document.createElement('div')
      alertContainer.id = 'bullshit-alert'
      alertContainer.className = 'fixed top-4 right-4 max-w-md z-50'
      document.body.appendChild(alertContainer)
    }
    
    // Create alert element
    const alert = document.createElement('div')
    alert.className = 'bg-red-100 border-2 border-red-300 p-4 rounded-xl shadow-2xl mb-2 transform transition-all duration-500 scale-0'
    alert.innerHTML = `
      <div class="flex items-start">
        <div class="flex-shrink-0">
          <span class="text-3xl animate-bounce">🚨</span>
        </div>
        <div class="ml-3 flex-1">
          <p class="text-lg font-bold text-red-800">Bullshit Detected!</p>
          <p class="text-sm text-red-700 mt-1">${data.explanation}</p>
          ${data.quote ? `<p class="text-xs text-red-600 mt-2 italic bg-red-200 p-1 rounded">"${data.quote}"</p>` : ''}
          <p class="text-xs text-red-500 mt-1">Confidence: ${Math.round(data.confidence * 100)}%</p>
        </div>
        <button onclick="this.parentElement.parentElement.remove()" class="ml-3 text-red-400 hover:text-red-600 transition-colors">
          <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
            <path d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z"/>
          </svg>
        </button>
      </div>
    `
    
    alertContainer.appendChild(alert)
    
    // Animate in with sound effect (optional)
    setTimeout(() => {
      alert.classList.remove('scale-0')
      alert.classList.add('scale-100')
    }, 100)
    
    // Auto-remove after 10 seconds
    setTimeout(() => {
      alert.classList.add('scale-0')
      setTimeout(() => alert.remove(), 500)
    }, 10000)
  }
  
  disconnect() {
    this.stop()
  }
}