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
      
      // Auto-animate configuration
      autoAnimate: true,
      autoAnimateEasing: 'cubic-bezier(0.770, 0.000, 0.175, 1.000)',
      autoAnimateDuration: 0.8,
      autoAnimateUnmatched: true,
      autoAnimateStyles: [
        'opacity',
        'color',
        'background-color',
        'padding',
        'font-size',
        'line-height',
        'letter-spacing',
        'border-width',
        'border-color',
        'border-radius',
        'background',
        'transform'
      ],
      
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