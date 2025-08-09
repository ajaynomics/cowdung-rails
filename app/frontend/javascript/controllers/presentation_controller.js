import { Controller } from "@hotwired/stimulus"
import Reveal from 'reveal.js'
import Markdown from 'reveal.js/plugin/markdown/markdown.esm.js'
import Notes from 'reveal.js/plugin/notes/notes.esm.js'
import Highlight from 'reveal.js/plugin/highlight/highlight.esm.js'

export default class extends Controller {
  connect() {
    this.deck = new Reveal(this.element, {
      hash: true,
      controls: true,
      progress: true,
      center: true,
      transition: 'slide',
      
      plugins: [Markdown, Notes, Highlight]
    })
    
    this.deck.initialize()
  }

  disconnect() {
    if (this.deck) {
      this.deck.destroy()
    }
  }
}