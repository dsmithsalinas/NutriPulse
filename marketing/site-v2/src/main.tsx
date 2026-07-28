import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
// The opsz axis is what gives us Inter Display at headline sizes without a
// second font file — set `font-variation-settings: 'opsz' 32` on the H1.
import '@fontsource-variable/inter/opsz.css'
import '@fontsource-variable/inter/opsz-italic.css'
// One serif italic against the grotesk, reserved for the emotional pull-quotes.
// Latin subset only — the full family ships eight files we'd never render.
import '@fontsource/instrument-serif/latin-400-italic.css'
import './styles.css'
import './sections.css'
import App from './App'

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <App />
  </StrictMode>,
)
