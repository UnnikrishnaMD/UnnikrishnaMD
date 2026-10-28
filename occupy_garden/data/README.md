# data/

Drawings go here. They are kept out of the repository (see `.gitignore`).

- `recliningman.jpg` — the drawing every piece uses by default (set per piece in `PIECES`).
- Any size works. The sketch analyses a 1920 px-wide copy (so plant density stays as tuned) and draws
  the full-resolution file, so a large source stays sharp on the 8640 px wall. With the default wall
  placement a 16:9 drawing is shown at about 3,530 × 1,990 px, so anything 3,600 px wide or more is
  drawn at 1:1 or better; the 1920 × 1080 test file is upscaled about 1.8x there and looks soft.
- A plain white background is keyed out to show the sky/earth gradient behind the figure.

## Masks

If a drawing's figure is not one flat fill colour, the automatic figure detection can't find it (it
looks for the single most common saturated hue). Give that piece a mask: a PNG the same size as the
drawing, **white where the figure is, black everywhere else**, and set it as the piece's `mask`.
Press M in the running sketch to check what is being treated as the figure.
