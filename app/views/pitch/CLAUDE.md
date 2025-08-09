# Pitch Deck Specific Guidelines

## Gradient Text Rendering - What I Fucked Up

### The Problem
Gradient text was getting clipped on slide 1 but worked fine on slide 2. I made ~20 commits trying random shit instead of looking at the actual problem.

### What Actually Happened
`data-background-color="#ffffff"` makes reveal.js create background layers that cover the gradient text. That's it. That's the whole fucking issue.

### The Fix
Don't use `data-background-color` with gradient text. Just copy what works from slide 2.

### What I Should Have Done
1. Open DevTools
2. See the extra divs reveal.js created
3. Remove the attribute
4. Done in 1 commit

### What I Actually Did
1. Changed font sizes
2. Added padding everywhere
3. Changed h1 to div
4. Added z-index
5. Added overflow visible to everything
6. Created wrapper divs
7. Modified reveal.js internals
8. 20+ other dumbass "fixes"

### Lessons
- **USE DEVTOOLS FIRST**
- **COPY WHAT WORKS**
- **DON'T GUESS**