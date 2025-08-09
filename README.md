<img width="1910" height="794" alt="image" src="https://github.com/user-attachments/assets/6a89f65e-a946-4d45-864d-b3f1eb6fae92" />

# 🐄 Cowdung: The BS Detector

**Real-time bullshit detection for the modern world**

Ever been in a meeting where someone's spouting obvious nonsense? Listening to a podcast full of conspiracy theories? Getting pitched a "guaranteed" get-rich-quick scheme? This app's got your back.

## What It Does

CowdungRails listens to conversations in real-time and calls out serious bullshit when it hears it. Not the harmless "best pizza ever" kind - we're talking about the dangerous stuff:

- **Blatant lies**: "The earth is flat" 🌍
- **Dangerous misinformation**: False medical claims, conspiracy theories
- **Impossible claims**: "I invented the internet" 
- **Scams**: Get-rich-quick schemes, fake credentials
- **Extreme exaggerations**: "100% guaranteed returns!"

## What It Ignores (Because We're Not Pedantic)

- Normal exaggeration ("This is amazing!")
- Corporate buzzword bingo (annoying but harmless)
- Personal opinions ("I think this policy is wrong")
- Speculation ("Maybe aliens exist?")
- Metaphors and figures of speech

## How to Use It

1. **Visit the site** - Just go to the homepage
2. **Click the red button** - Start recording (you'll see a timer)
3. **Talk or play audio** - The app transcribes in real-time
4. **Watch for BS alerts** - They pop up when detected
5. **Stop when done** - Click the button again

That's it. No signup, no downloads, no nonsense.

## Privacy First

- **Nothing is stored permanently** - Audio is processed and discarded
- **No user accounts** - We don't track who you are
- **Local processing where possible** - Minimal server interaction
- **Open source** - See exactly what we're doing

## Technical Limits (The Fine Print)

- **2-3 second delay** - It's not instant, but it's pretty quick
- **English only** - For now
- **Needs decent audio** - Works best with clear speech
- **Not legal advice** - This is for entertainment/education, not court

## The Tech Behind It (For the Curious)

We use AI to transcribe speech and detect BS, but we've tuned it to be chill about normal conversation. It only flags the serious stuff that actually matters.

- Real-time audio streaming via WebSockets
- OpenAI's Whisper for transcription
- GPT-4 for BS detection (but tuned to not be annoying)
- Ruby on Rails because we like nice things

## Why "CowdungRails"?

Because we're detecting BS (cow dung) and we built it with Ruby on Rails. Sometimes the obvious name is the best name. 🐮

## Found Some BS in Our BS Detector?

The irony isn't lost on us. If you find issues:
- [Report bugs here](https://github.com/anthropics/claude-code/issues)
- Pull requests welcome (but keep it simple)

## Credits

Built with Ruby on Rails, Whisper, and a healthy skepticism of everything.

---

*Remember: A little skepticism is healthy, but don't let this app turn you into that person who fact-checks casual conversation. Use responsibly.*
