# occupy_garden — OCCUPY · Exhibition 2, NODE (Palo Alto)

The plant-growth sketch adapted for NODE's Exhibition 2 File Upload: one file per surface, at the
exact pixel size.

| Surface | File | Plays | Length |
|---|---|---|---|
| `wall` — projector wall | 8640 × 2160 MP4 | pieces I–VI | 6 × (18 s grow + 6 s hold) = 2:24 loop |
| `pool1` — LED pool 1 | 1600 × 1600 MP4 | pieces I, III, V | 3 × (30 s + 10 s) = 2:00 loop |
| `pool2` — LED pool 2 | 1600 × 1600 MP4 | pieces II, IV, VI | 3 × (30 s + 10 s) = 2:00 loop |

Each piece is one edition of the same system: the figure starts bare, the meadow grows in patch by
patch (outline vines first, then vines on the letters, contours, main grid, meadow) and sprawls out
in swathes along a flow field, rising from the bottom of the canvas and around the figure, while a field of letters filling the whole canvas behind it - one
continuous stream of the sketch's own advertising calls to action, spaces removed, one letter per cell
- erodes into abstract letter fragments. Billboards and
drifting coins arrive late in the growth. Each piece crossfades into the next, and the last crossfades
back into the first, so every file loops without a jump. The three files don't need to start together.

## Setup

1. Processing 4. The sketch uses only the core library — **Video Export is no longer needed**.
2. ffmpeg (macOS: `brew install ffmpeg`). If the sketch can't find it, set `ffmpegPath` in `Compositor.pde`.
3. Put the drawings in `data/` (see `data/README.md`). They are not in the repository.

## Making the files

1. Open `occupy_garden.pde`, set `surfaceName` to `"wall"`, `"pool1"` or `"pool2"`, and Run. The
   window is a scaled-down preview of exactly what gets rendered.
2. Press **V** to render. The sketch draws every frame at full size and pipes it straight into ffmpeg,
   writing `output/occupy_<surface>_master.mp4` (near-lossless, larger than 500 MB for the wall).
3. Fit it under NODE's 500 MB limit:
   ```bash
   ./encode_for_node.sh output/occupy_wall_master.mp4
   ```
   This writes `output/occupy_wall_node.mp4`, a two-pass encode sized to ~480 MB.
4. Repeat for `pool1` and `pool2`.

From the command line (e.g. overnight), using Processing's `processing-java`:
```bash
processing-java --sketch="$PWD" --run surface=wall render exit
```
Arguments: `surface=wall|pool1|pool2`, `render`, `stills`, `exit`, `seed=N`, and `grow=` / `hold=`
(seconds) to try a different pacing without editing the code. `grow=3 hold=1` makes a quick draft.

## Keys

| Key | |
|---|---|
| Space | pause / play |
| N / B | next / previous piece |
| R | rebuild this piece from its seed (also applies placement changes) |
| S | save this frame as a full-size PNG (NODE also accepts PNG) |
| F | save every piece's final frame as full-size PNGs |
| V | render this surface's looping MP4 |
| M | show what the sketch thinks is the figure (translucent red) |
| C, X, Q/E, A/D, [ / ] , click | colour tools from the original sketch |
| 1 / 2, arrows, - / = | move/scale the drawing; prints the values to paste into `SURFACES` |

## What to set

All in `occupy_garden.pde`:

- **`PIECES`**: each piece's edition, drawing, optional mask, seed and face zone.
- **`SURFACES`**: figure placement, safe margin, rows of the letter field (8 on each surface; columns
  follow so cells are square — 38 × 8 letters on the wall, 11 × 11 on a pool), timing.
  NODE's pixel map gives no safe area, so the 240 px (wall) / 80 px (pool) margin is our own choice.

In `Compositor.pde`: `typeFontNames` (system sans-serifs tried in order — Helvetica Neue first), `typeCellFill`
(1 = every cell has a letter), `typeLetterScale` (letter size within its cell), `typeAlphaMin` /
`typeAlphaMax` (the range of per-letter opacity), `erosionEnd`, `growthSpread`, and the ink colour per edition in `typeInkFor()`. The CTA vocabulary itself is the
`cta*` lists in `Garden.pde`.

## Render time and memory

Measured on a 4-core Linux machine with Processing core 4.3.1 (a recent Mac will likely be faster):

- wall (8640 × 2160): ~1.2 s per frame on average — a 720-frame test loop took 14 minutes, so the
  full 2:24 loop (4,320 frames) is roughly 1½ hours. Its master was 667 MB; `encode_for_node.sh`
  brought it to 471 MB.
- pool (1600 × 1600): ~0.9 s per frame — the full 2:00 loop (3,600 frames) is under an hour.

The wall needs several GB of memory (each full-size layer is ~75 MB). If you see `OutOfMemoryError`,
raise Processing's maximum memory (Preferences, or `run.options.memory.maximum` in `preferences.txt`).
