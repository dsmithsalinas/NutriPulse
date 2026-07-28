import { useEffect, useRef } from 'react'

/**
 * Marks a container revealed the first time it enters view, and never again.
 * Re-triggering entrance animations on scroll-back is the fastest way to make
 * an expensive-looking page feel cheap.
 *
 * The stagger lives in CSS (nth-child delays) rather than inline styles, so the
 * reduced-motion media query can flatten the whole thing in one place.
 */
export function useReveal<T extends HTMLElement>(threshold = 0.2) {
  const ref = useRef<T>(null)

  useEffect(() => {
    const el = ref.current
    if (!el) return

    const io = new IntersectionObserver(
      ([entry]) => {
        if (!entry.isIntersecting) return
        el.dataset.revealed = 'true'
        io.disconnect()
      },
      { threshold, rootMargin: '0px 0px -8% 0px' },
    )

    io.observe(el)
    return () => io.disconnect()
  }, [threshold])

  return ref
}
