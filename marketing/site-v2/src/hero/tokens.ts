/**
 * Palette, shared by the DOM and the canvas so both halves of the page read as
 * one object. Mirrors the CSS custom properties in styles.css — if you change a
 * value, change it in both places.
 */
export const T = {
  subgrade: '#07070F',
  substrate: '#12122A',
  strata: '#1C1E3D',
  ink: '#14163A',
  indigo: '#6366F1',
  violet: '#8B5CF6',
  warm: '#FF8A5B',
  green: '#34D399',
  ground: '#F6F5FC',
} as const
