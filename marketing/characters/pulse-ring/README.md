# Pulse ring — canonical assets

The authoritative design/behavior specification is [docs/pulse-ring-system.md](../../../docs/pulse-ring-system.md). Footing is the product; Pulse is the intelligence/coach represented by this faceless ring; Cove is the emotional companion. They never merge.

- [Icon sheet](preview.html) / [PNG](icon-sheet.png): 32 / 48 / 80 px, Daylight and dark.
- [Pulse in context](context.html) / [PNG](context.png): eight product/marketing compositions.
- `svg/`: 16 scalable masters (eight states × two surfaces), default 80 px.
- `svg/32/`, `svg/48/`, `svg/80/`: 48 explicit-size exports.
- `manifest.json`: canonical export inventory and fixed-node geometry.
- `generate.py`: dependency-free deterministic SVG generator; run `python3 generate.py` from this directory or pass `--output-dir`.
- [Validation](validation.md): contrast, geometry, dimensions and render checks.
- `archive/v1/`: historical foundation, never a source for new designs.

Final names: Ready, Listening, Thinking, Progress, Floor Cleared, Check-in, Rest, Pulse Coaching. Filename mappings are `ready`, `listening`, `thinking`, `progress`, `floor-cleared`, `check-in`, `rest`, `coaching`; `-dark` means use on a dark surface. SVGs are static, with reduced-motion fallbacks and optional motion documented in the spec. Progress is a 60% sample: bind actual values in product. Floor Cleared is categorical success, not all-goals completion.
