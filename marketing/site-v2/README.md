# tryfooting.app

The Footing marketing site, in the same Daylight design as the app (tokens, fonts and tiles
from `NutriPulse/DesignSystem/Theme.swift`).

- `src/` — the home page (React + Vite). `sections/Home.tsx` holds every section;
  `ProteinTile.tsx` is the animated hero, a port of the app's floor-cleared moment.
- `public/` — static pages served as-is: `privacy.html`, `terms.html`, `contact.html`,
  `404.html`, styled by `legal.css`. The fonts in `public/fonts/` are the app's own files, converted to woff2
  (SIL Open Font License, included).
- Every product claim must be one the app actually makes. The FAQ's privacy answer and
  `public/privacy.html` must agree: change both in the same commit.

```bash
npm run dev          # local dev server
npm run build        # type-check and build to dist/
npx wrangler dev     # serve dist/ the way Cloudflare does (/privacy, 404s)
```

Deploying: see [DEPLOY.md](./DEPLOY.md). Commit and push before any deploy.
