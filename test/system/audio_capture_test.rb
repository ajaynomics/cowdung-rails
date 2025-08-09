require "application_system_test_case"

class AudioCaptureTest < ApplicationSystemTestCase
  test "displays recording interface" do
    visit root_path

    assert_selector "h1", text: "Audio Transcription"
    assert_button "Start Recording"
  end

  test "toggles recording state when buttons clicked" do
    visit root_path

    # Mock getUserMedia to avoid permission issues in test
    page.execute_script <<~JS
      navigator.mediaDevices.getUserMedia = function(constraints) {
        return Promise.resolve({
          getTracks: function() {
            return [{
              stop: function() {}
            }];
          }
        });
      };

      // Mock MediaRecorder
      window.MediaRecorder = class {
        constructor(stream, options) {
          this.state = 'inactive';
          this.ondataavailable = null;
        }
        start(timeslice) {
          this.state = 'recording';
          // Simulate data events
          if (this.ondataavailable) {
            setTimeout(() => {
              this.ondataavailable({ data: new Blob(['test'], { type: 'audio/webm' }) });
            }, 100);
          }
        }
        stop() {
          this.state = 'inactive';
        }
      };

      // Mock AudioContext
      window.AudioContext = class {
        constructor() {
          this.sampleRate = 44100;
        }
        createAnalyser() {
          return {
            fftSize: 256,
            frequencyBinCount: 128,
            getByteFrequencyData: function(array) {
              for(let i = 0; i < array.length; i++) {
                array[i] = Math.random() * 255;
              }
            }
          };
        }
        createMediaStreamSource() {
          return { connect: function() {} };
        }
        createScriptProcessor(bufferSize, inputChannels, outputChannels) {
          return {
            connect: function() {},
            disconnect: function() {},
            onaudioprocess: null
          };
        }
        close() {
          return Promise.resolve();
        }
      };
    JS

    # Initial state - start button visible, stop button hidden
    assert_selector "button", text: "Start Recording", visible: true
    assert_selector "button", text: "Stop Recording", visible: false
    assert_selector "[data-audio-recorder-target='indicator']", visible: false

    # Click start button
    click_button "Start Recording"

    # Verify UI changed to recording state
    assert_selector "button", text: "Start Recording", visible: false
    assert_selector "button", text: "Stop Recording", visible: true
    assert_selector "[data-audio-recorder-target='indicator']", visible: true
    assert_text "Recording audio..."

    # Click stop button
    click_button "Stop Recording"

    # Verify UI changed back to initial state
    assert_selector "button", text: "Start Recording", visible: true
    assert_selector "button", text: "Stop Recording", visible: false
    assert_selector "[data-audio-recorder-target='indicator']", visible: false
    assert_text "Stopped recording"
  end

  test "mute button toggles audio state" do
    visit root_path

    # Set up mocks (same as above)
    page.execute_script <<~JS
      navigator.mediaDevices.getUserMedia = function(constraints) {
        return Promise.resolve({
          getTracks: function() {
            return [{
              stop: function() {}
            }];
          }
        });
      };
      window.MediaRecorder = class {
        constructor(stream, options) {
          this.state = 'inactive';
          this.ondataavailable = null;
        }
        start(timeslice) {
          this.state = 'recording';
        }
        stop() {
          this.state = 'inactive';
        }
      };
      window.AudioContext = class {
        constructor() {
          this.sampleRate = 44100;
        }
        createAnalyser() {
          return {
            fftSize: 256,
            frequencyBinCount: 128,
            getByteFrequencyData: function(array) {}
          };
        }
        createMediaStreamSource() {
          return { connect: function() {} };
        }
        createScriptProcessor() {
          return {
            connect: function() {},
            disconnect: function() {},
            onaudioprocess: null
          };
        }
        close() {
          return Promise.resolve();
        }
      };
    JS

    # Start recording
    click_button "Start Recording"
    assert_text "Recording audio..."

    # Find and click mute button
    mute_button = find("[data-audio-recorder-target='muteBtn']")

    # Mute the audio
    mute_button.click
    assert_text "Muted - not sending audio"
    assert_selector "[data-audio-recorder-target='muteBtn'].text-red-500"

    # Unmute the audio
    mute_button.click
    assert_text "Recording audio..."
    assert_no_selector "[data-audio-recorder-target='muteBtn'].text-red-500"
  end

  test "shows permission error when microphone access denied" do
    visit root_path

    # Mock getUserMedia to reject with permission error
    page.execute_script <<~JS
      navigator.mediaDevices.getUserMedia = function(constraints) {
        return Promise.reject(new DOMException('Permission denied', 'NotAllowedError'));
      };
    JS

    # Try to start recording
    click_button "Start Recording"

    # Verify permission error is shown
    assert_selector "[data-audio-recorder-target='permissionError']", visible: true
    assert_text "Microphone Access Required"
    assert_text "Microphone access denied"
    assert_button "Try Again"

    # Verify recording did not start
    assert_selector "button", text: "Start Recording", visible: true
    assert_selector "button", text: "Stop Recording", visible: false
  end
end
