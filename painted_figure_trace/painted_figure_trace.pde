/**
 * OVERGROWN — the figure, traced by what grows
 * ------------------------------------------------------------------
 * Processing 4 (Java mode).
 *
 * Two things only: the painting, and what grows on it. Fine vines find
 * the black lines of the figure, lift off them, follow them part of
 * the way round, then peel away into the open and curl. Along the
 * vines come leaves, compound leaves, tendrils, buds, fern tips and
 * wild flowers: daisies, bells, flower spikes, poppies, seed-heads.
 * The calligraphy around the figure and the lettering at the top are
 * not traced.
 *
 * The painting is coloured all over the figure and nowhere else, so
 * the figure is found by its colour: the painted area is taken as the
 * body, and the black lines that belong to it are the ones that touch
 * it. Nothing has to be marked by hand.
 *
 * Format: 1080 x 1920 (9:16), 30 fps — Instagram Reel.
 *
 * Outputs (written next to this sketch):
 *   output/painted_figure_trace_3240x5760.png   high-res still
 *   frames/reel-####.png                        one PNG per frame
 *   output/painted_figure_trace_reel.mp4        via ffmpeg if on PATH
 *
 * No ffmpeg? Use Tools > Movie Maker on the frames folder (30 fps).
 */

// ---------- output settings ----------
final int     OUT_W = 1080, OUT_H = 1920;
final int     HIRES_SCALE  = 3;
final int     FPS          = 30;
final int     INTRO_FRAMES = 45;    // the painting alone
final int     GROW_FRAMES  = 900;   // 30 s of growth
final int     HOLD_FRAMES  = 90;
final boolean RECORD       = true;
final int     SEED         = 2026;

// ---------- FINDING THE FIGURE (pixels of the 1080 x 1920 painting) ----------
final float COLOUR_MIN = 55;     // how far apart a pixel's channels must be to count as painted
final float DARK_MAX   = 105;    // brightest a pixel may be and still count as black line
final float CLOSE_R    = 26;     // black lines up to twice this wide inside the painted area are bridged
final float LINE_REACH = 60;     // how far beyond the painted area a figure line may run

// ---------- CONTOURS ----------
final float CONTOUR_MIN_LENGTH = 90;   // px; shorter outlines (flecks) are ignored
final float CONTOUR_SPACING = 3;       // px between points along an outline

// ---------- VINES ----------
// Each vine starts on an outline of the figure, lifts off it to a small
// distance, follows it part of the way round, then peels away into a
// noise current and ends in a curl.
final int   STRAND_COUNT = 420;
final float OFFSET_MIN = 4, OFFSET_MAX = 20;   // distance kept from the outline (px)
final float WOBBLE = 5;                        // how much that distance breathes
final float LIFT = 24;                         // points over which a vine rises off the outline
final float WRAP_MIN = 0.10, WRAP_MAX = 0.50;  // share of the outline it travels round
final int   MAX_WRAP = 700;
final int   PEEL_MIN = 30, PEEL_MAX = 150;     // steps after leaving the outline
final float STEP_LEN = 2.2, FLOW_SCALE = 0.006, FLOW_TURN = 0.16, CURL = 0.22;
final int   SMOOTH = 3;
final float STRAND_W_MIN = 0.9, STRAND_W_MAX = 3.0;
final float STRAND_A_MIN = 235, STRAND_A_MAX = 255;
final float STAGGER = 0.65;                    // vines start somewhere in the first 65% of the growth

// ---------- COLOUR: gold vines, violet and white flowers ----------
final String[] STRAND_COLORS = { "#f2b600", "#e08a00", "#c96a00", "#ffd84a", "#b8860b", "#f6c244", "#8a5a00" };
final String[] LEAF_COLORS   = { "#d4a017", "#e9c46a", "#b5890f", "#f4d35e", "#9c6f0a", "#c9b037" };
final String[] FLOWER_COLORS = { "#5b2be0", "#7b4dff", "#2b1e9e", "#ffffff", "#b9a6ff", "#3a1c8f", "#e8e0ff", "#1f3fd6" };
final String[] CENTRE_COLORS = { "#ffd84a", "#ffffff", "#f2b600", "#1a103f" };

// ---------- FLORA ----------
final float LEAF_CHANCE = 0.011, LEAF_MIN = 5, LEAF_MAX = 15;
final float TENDRIL_CHANCE = 0.004;
final float BUD_CHANCE = 0.002;
final float FLOWER_CHANCE = 0.0055, FLOWER_MIN = 6, FLOWER_MAX = 15;
final float FERN_TIP_CHANCE = 0.3;
final int   BLOOM_FRAMES = 24;                 // frames a leaf or flower takes to open

PImage bg;
boolean[] dark;                                   // the painting's black line
boolean[] figInk;                                 // the black line that belongs to the figure
PGraphics strandLayer;
ArrayList<Ring> figureRings = new ArrayList<Ring>();
ArrayList<Strand> strands = new ArrayList<Strand>();

public void settings() {
  size(OUT_W, OUT_H);
  pixelDensity(1);
}

public void setup() {
  frameRate(FPS);
  bg = loadImage("background.jpg");
  if (bg.width != OUT_W || bg.height != OUT_H) bg.resize(OUT_W, OUT_H);
  studyBackground();
  traceFigure();
  buildStrands();

  strandLayer = createGraphics(width, height);
  strandLayer.beginDraw();
  strandLayer.clear();
  strandLayer.endDraw();
}

public void draw() {
  int f = frameCount - 1;
  float tt = f - INTRO_FRAMES;
  image(bg, 0, 0);
  strandLayer.beginDraw();
  growStep(strandLayer, tt);
  strandLayer.endDraw();
  image(strandLayer, 0, 0);
  drawLiveFlora(g, tt);

  if (RECORD) saveFrame("frames/reel-####.png");
  if (f >= INTRO_FRAMES + GROW_FRAMES + HOLD_FRAMES) {
    if (RECORD) {
      saveHiRes();
      makeMovie();
    }
    exit();
  }
}

// =====================================================================
//  THE PAINTING, STUDIED
// =====================================================================

// Finds the figure: its painted body, and the black lines that belong to it.
void studyBackground() {
  bg.loadPixels();
  int w = bg.width, h = bg.height, n = w * h;
  dark = new boolean[n];
  float[] d = new float[n];                    // distance to the nearest painted pixel
  for (int i = 0; i < n; i++) {
    int c = bg.pixels[i];
    float r = (c >> 16) & 255, g = (c >> 8) & 255, b = c & 255;
    float hi = max(r, g, b), lo = min(r, g, b);
    dark[i] = hi < DARK_MAX;
    boolean lettering = b - g > 18 && b - r > 45;        // the blue word behind the head
    d[i] = (hi - lo > COLOUR_MIN && !dark[i] && !lettering) ? 0 : 99999;
  }
  chamfer(d, w, h);

  // everything within CLOSE_R of paint, with the holes filled: flood the
  // rest from the frame edge; what the flood cannot reach is the blob
  boolean[] reached = new boolean[n];
  int[] stack = new int[n];
  int top = 0;
  for (int x = 0; x < w; x++) { stack[top++] = x; stack[top++] = (h - 1) * w + x; }
  for (int y = 0; y < h; y++) { stack[top++] = y * w; stack[top++] = y * w + w - 1; }
  while (top > 0) {
    int i = stack[--top];
    if (reached[i] || d[i] < CLOSE_R) continue;
    reached[i] = true;
    int x = i % w;
    if (x > 0) stack[top++] = i - 1;
    if (x < w - 1) stack[top++] = i + 1;
    if (i >= w) stack[top++] = i - w;
    if (i < n - w) stack[top++] = i + w;
    if (top > n - 8) top = n - 8;
  }

  // keep only the largest piece: stray flecks of colour are not the figure
  int[] label = new int[n];
  int best = 0, bestSize = 0, labels = 0;
  for (int start = 0; start < n; start++) {
    if (reached[start] || label[start] != 0) continue;
    labels++;
    int size = 0;
    top = 0;
    stack[top++] = start;
    label[start] = labels;
    while (top > 0) {
      int i = stack[--top];
      size++;
      int x = i % w;
      int[] nb = { x > 0 ? i - 1 : -1, x < w - 1 ? i + 1 : -1, i >= w ? i - w : -1, i < n - w ? i + w : -1 };
      for (int j : nb) {
        if (j < 0 || reached[j] || label[j] != 0) continue;
        label[j] = labels;
        stack[top++] = j;
      }
    }
    if (size > bestSize) { bestSize = size; best = labels; }
  }

  // shrink the blob back to the painted area: that is the body
  float[] e = new float[n];
  for (int i = 0; i < n; i++) e[i] = (label[i] == best) ? 99999 : 0;
  chamfer(e, w, h);
  float[] db = new float[n];                   // distance from the body
  for (int i = 0; i < n; i++) db[i] = (e[i] > CLOSE_R - 2) ? 0 : 99999;
  chamfer(db, w, h);

  // the figure's line: black that touches the body, followed outward
  // through connected black no further than LINE_REACH
  figInk = new boolean[n];
  top = 0;
  for (int i = 0; i < n; i++) if (dark[i] && db[i] < 3) { figInk[i] = true; stack[top++] = i; }
  while (top > 0) {
    int i = stack[--top];
    int x = i % w;
    int[] nb = { x > 0 ? i - 1 : -1, x < w - 1 ? i + 1 : -1, i >= w ? i - w : -1, i < n - w ? i + w : -1 };
    for (int j : nb) {
      if (j < 0 || figInk[j] || !dark[j] || db[j] >= LINE_REACH) continue;
      figInk[j] = true;
      stack[top++] = j;
    }
  }

}

// two-pass chamfer distance transform, in place
void chamfer(float[] d, int w, int h) {
  float d1 = 1, d2 = 1.4142;
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      int i = y * w + x;
      float v = d[i];
      if (x > 0) v = min(v, d[i - 1] + d1);
      if (y > 0) {
        v = min(v, d[i - w] + d1);
        if (x > 0) v = min(v, d[i - w - 1] + d2);
        if (x < w - 1) v = min(v, d[i - w + 1] + d2);
      }
      d[i] = v;
    }
  }
  for (int y = h - 1; y >= 0; y--) {
    for (int x = w - 1; x >= 0; x--) {
      int i = y * w + x;
      float v = d[i];
      if (x < w - 1) v = min(v, d[i + 1] + d1);
      if (y < h - 1) {
        v = min(v, d[i + w] + d1);
        if (x < w - 1) v = min(v, d[i + w + 1] + d2);
        if (x > 0) v = min(v, d[i + w - 1] + d2);
      }
      d[i] = v;
    }
  }
}

// =====================================================================
//  THE FIGURE'S CONTOURS — found in the drawing
// =====================================================================

class Ring {
  float[][] pts, nrm;      // even points round an outline; normal pointing away from the line
  boolean[] ok;            // false where the line runs on into the calligraphy around the figure
  float weight;
}

// Follows the edge of the figure's black line into rings.
void traceFigure() {
  int w = bg.width, h = bg.height;
  boolean[] ink = dark, m = figInk;

  // every pixel edge between marked and unmarked, directed so that the
  // marked side is on the right; two edges can leave one corner
  int vw = w + 1;
  int[] nextA = new int[vw * (h + 1)], nextB = new int[vw * (h + 1)];
  java.util.Arrays.fill(nextA, -1);
  java.util.Arrays.fill(nextB, -1);
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      if (!m[y * w + x]) continue;
      int tl = y * vw + x, tr = tl + 1, bl = tl + vw, br = bl + 1;
      if (y == 0 || !m[(y - 1) * w + x]) addEdge(nextA, nextB, tl, tr);
      if (x == w - 1 || !m[y * w + x + 1]) addEdge(nextA, nextB, tr, br);
      if (y == h - 1 || !m[(y + 1) * w + x]) addEdge(nextA, nextB, br, bl);
      if (x == 0 || !m[y * w + x - 1]) addEdge(nextA, nextB, bl, tl);
    }
  }
  for (int v = 0; v < nextA.length; v++) {
    while (nextA[v] != -1) {
      ArrayList<float[]> loop = new ArrayList<float[]>();
      int cur = v;
      boolean closed = false;
      for (int guard = 0; guard < 400000; guard++) {
        int nx = nextA[cur];
        if (nx == -1) break;
        nextA[cur] = nextB[cur];
        nextB[cur] = -1;
        loop.add(new float[] { cur % vw, cur / vw });
        cur = nx;
        if (cur == v) { closed = true; break; }
      }
      if (closed && loop.size() >= 30) {
        Ring r = resample(smoothRing(loop), ink, w, h);
        if (r != null) figureRings.add(r);
      }
    }
  }
  println("figure outlines found: " + figureRings.size());
}

void addEdge(int[] nextA, int[] nextB, int from, int to) {
  if (nextA[from] == -1) nextA[from] = to; else nextB[from] = to;
}

// takes the pixel staircase out of a traced edge
ArrayList<float[]> smoothRing(ArrayList<float[]> in) {
  int n = in.size();
  ArrayList<float[]> out = in;
  for (int pass = 0; pass < 2; pass++) {
    ArrayList<float[]> nx = new ArrayList<float[]>();
    for (int i = 0; i < n; i++) {
      float sx = 0, sy = 0;
      for (int d = -2; d <= 2; d++) { float[] p = out.get(((i + d) % n + n) % n); sx += p[0]; sy += p[1]; }
      nx.add(new float[] { sx / 5, sy / 5 });
    }
    out = nx;
  }
  return out;
}

// even points round a closed ring, each with the normal that points away
// from the line (the edges were followed with the line on the right)
Ring resample(ArrayList<float[]> ring, boolean[] ink, int w, int h) {
  ArrayList<float[]> out = new ArrayList<float[]>();
  float carry = 0;
  for (int i = 0; i < ring.size(); i++) {
    float[] a = ring.get(i), b = ring.get((i + 1) % ring.size());
    float len = dist(a[0], a[1], b[0], b[1]);
    float d = carry;
    while (d < len) {
      float u = d / len;
      out.add(new float[] { a[0] + (b[0] - a[0]) * u, a[1] + (b[1] - a[1]) * u });
      d += CONTOUR_SPACING;
    }
    carry = d - len;
  }
  int n = out.size();
  if (n * CONTOUR_SPACING < CONTOUR_MIN_LENGTH) return null;
  Ring r = new Ring();
  r.pts = out.toArray(new float[n][]);
  r.nrm = new float[n][2];
  r.ok = new boolean[n];
  int good = 0;
  for (int k = 0; k < n; k++) {
    float[] p = r.pts[(k - 2 + n) % n], q = r.pts[(k + 2) % n];
    float dx = q[0] - p[0], dy = q[1] - p[1];
    float l = sqrt(dx * dx + dy * dy);
    if (l == 0) l = 1;
    r.nrm[k][0] = dy / l;
    r.nrm[k][1] = -dx / l;
    // if there is still black just outside, this stretch is where the
    // figure's line was cut off from a line running on: not a real outline
    int sx = (int) constrain(round(r.pts[k][0] + r.nrm[k][0] * 2.5 - 0.5), 0, w - 1);
    int sy = (int) constrain(round(r.pts[k][1] + r.nrm[k][1] * 2.5 - 0.5), 0, h - 1);
    r.ok[k] = !ink[sy * w + sx];
    if (r.ok[k]) good++;
  }
  if (good < n * 0.3) return null;
  r.weight = pow(good, 0.8);
  return r;
}

// =====================================================================
//  VINES AND WHAT GROWS ON THEM
// =====================================================================

class Flora {
  int k, kind, petals;         // kind: see drawFlora()
  float a, size;
  float[] col, col2;
  boolean baked;
}

class Strand {
  float[][] pts;
  float[] ang, col;
  float w0, start, dur;
  int drawn;
  ArrayList<Flora> flora = new ArrayList<Flora>();
}

float[] rgba(String hx, float a) { return new float[] { unhex(hx.substring(1, 3)), unhex(hx.substring(3, 5)), unhex(hx.substring(5, 7)), a }; }
String pick(String[] arr) { return arr[floor(random(arr.length))]; }

void buildStrands() {
  randomSeed(SEED + 6);
  noiseSeed(SEED + 6);
  if (figureRings.size() == 0) return;
  float total = 0;
  for (Ring r : figureRings) total += r.weight;
  for (int i = 0; i < STRAND_COUNT; i++) {
    float pk = random(total);
    Ring ring = figureRings.get(0);
    for (Ring r : figureRings) { pk -= r.weight; if (pk < 0) { ring = r; break; } }
    strands.add(makeStrand(ring));
  }
}

Strand makeStrand(Ring ring) {
  int n = ring.pts.length;
  int start = floor(random(n));
  for (int t = 0; t < 40 && !ring.ok[start]; t++) start = floor(random(n));
  int dir = random(1) < 0.5 ? 1 : -1;
  int steps = min(MAX_WRAP, floor(n * random(WRAP_MIN, WRAP_MAX)));
  float off = random(OFFSET_MIN, OFFSET_MAX);
  float nz = random(1000);
  ArrayList<float[]> pts = new ArrayList<float[]>();

  // follow the outline at a breathing distance, rising off it at the start
  for (int k = 0; k < steps; k++) {
    int idx = ((start + dir * k) % n + n) % n;
    if (!ring.ok[idx] && k > 3) break;           // the outline ends where the figure's line ends
    float lift = min(1, k / LIFT);
    float o = max(1, (off + (noise(k * 0.02, nz) - 0.5) * 2 * WOBBLE) * lift);
    pts.add(new float[] { ring.pts[idx][0] + ring.nrm[idx][0] * o, ring.pts[idx][1] + ring.nrm[idx][1] * o });
  }
  if (pts.size() < 2) { pts.clear(); pts.add(ring.pts[start].clone()); pts.add(ring.pts[(start + 1) % n].clone()); }

  // peel away into the current and end in a tightening curl
  float[] last = pts.get(pts.size() - 1), prev = pts.get(pts.size() - 2);
  float x = last[0], y = last[1], a = atan2(last[1] - prev[1], last[0] - prev[0]);
  int peel = floor(random(PEEL_MIN, PEEL_MAX));
  float curlDir = random(1) < 0.5 ? -1 : 1;
  int curlFrom = floor(peel * random(0.55, 0.8));
  for (int j = 0; j < peel; j++) {
    a += (noise(x * FLOW_SCALE, y * FLOW_SCALE, nz) - 0.5) * 2 * FLOW_TURN;
    if (j > curlFrom) { float u = (j - curlFrom) / (float) (peel - curlFrom); a += curlDir * u * u * CURL; }
    x += cos(a) * STEP_LEN;
    y += sin(a) * STEP_LEN;
    pts.add(new float[] { x, y });
  }

  // soften corners from the outline
  Strand th = new Strand();
  int m = pts.size();
  th.pts = new float[m][2];
  for (int k = 0; k < m; k++) {
    float sx = 0, sy = 0;
    int c = 0;
    for (int q = max(0, k - SMOOTH); q <= min(m - 1, k + SMOOTH); q++) { sx += pts.get(q)[0]; sy += pts.get(q)[1]; c++; }
    th.pts[k][0] = sx / c;
    th.pts[k][1] = sy / c;
  }
  th.ang = new float[m];
  for (int k = 0; k < m; k++) {
    float[] q = th.pts[min(m - 1, k + 1)], r = th.pts[max(0, k - 1)];
    th.ang[k] = atan2(q[1] - r[1], q[0] - r[0]);
  }

  th.col = rgba(pick(STRAND_COLORS), random(STRAND_A_MIN, STRAND_A_MAX));
  th.w0 = random(STRAND_W_MIN, STRAND_W_MAX);
  th.start = random(GROW_FRAMES * STAGGER);
  th.dur = max(30, GROW_FRAMES - th.start);

  // what grows along the way
  for (int k = 6; k < m - 2; k++) {
    float side = random(1) < 0.5 ? -1 : 1;
    float roll = random(1);
    Flora f = null;
    if (roll < LEAF_CHANCE) {
      f = new Flora(); f.kind = random(1) < 0.25 ? 9 : 0; f.a = th.ang[k] + side * random(0.5, 1.1);
      f.size = random(LEAF_MIN, LEAF_MAX); f.col = rgba(pick(LEAF_COLORS), 230);
    } else if (roll < LEAF_CHANCE + TENDRIL_CHANCE) {
      f = new Flora(); f.kind = 8; f.a = th.ang[k] + side * random(0.7, 1.3);
      f.size = random(7, 16); f.col = th.col.clone();
    } else if (roll < LEAF_CHANCE + TENDRIL_CHANCE + BUD_CHANCE) {
      f = new Flora(); f.kind = 1; f.a = th.ang[k] + side * random(0.6, 1.2);
      f.size = random(4, 8); f.col = rgba(pick(FLOWER_COLORS), 240); f.col2 = rgba(pick(LEAF_COLORS), 240);
    } else if (roll < LEAF_CHANCE + TENDRIL_CHANCE + BUD_CHANCE + FLOWER_CHANCE) {
      // a wild flower: daisy, bell, spike, poppy or seed-head
      int[] kinds = { 2, 2, 4, 5, 6, 7 };
      f = new Flora(); f.kind = kinds[floor(random(kinds.length))];
      f.a = (f.kind == 2 || f.kind == 6 || f.kind == 7) ? random(TWO_PI) : th.ang[k] + side * random(0.7, 1.3);
      f.size = random(FLOWER_MIN, FLOWER_MAX);
      f.col = rgba(pick(FLOWER_COLORS), 245); f.col2 = rgba(pick(CENTRE_COLORS), 255); f.petals = floor(random(6, 13));
    }
    if (f != null) { f.k = k; th.flora.add(f); }
  }
  if (random(1) < FERN_TIP_CHANCE) {
    Flora f = new Flora(); f.k = m - 1; f.kind = 3; f.a = th.ang[m - 1]; f.size = random(5, 12); f.col = th.col.clone(); th.flora.add(f);
  }
  return th;
}

float widthAt(Strand th, int k) {
  float u = k / (float) (th.pts.length - 1);
  return th.w0 * (0.2 + 0.8 * pow(max(0, sin(PI * min(1, u * 1.08))), 0.6));
}

int revealAt(Strand th, float frame) {
  float u = constrain((frame - th.start) / th.dur, 0, 1);
  return floor(u * (th.pts.length - 1));
}

// frame on which point k of a strand is reached
float reachedAt(Strand th, int k) { return th.start + (k / (float) (th.pts.length - 1)) * th.dur; }

// draw newly reached segments, and bake plant forms that have finished opening
void growStep(PGraphics g, float frame) {
  g.strokeCap(ROUND);
  for (Strand th : strands) {
    int target = revealAt(th, frame);
    g.stroke(th.col[0], th.col[1], th.col[2], th.col[3]);
    for (int k = max(1, th.drawn + 1); k <= target; k++) {
      g.strokeWeight(widthAt(th, k));
      g.line(th.pts[k - 1][0], th.pts[k - 1][1], th.pts[k][0], th.pts[k][1]);
    }
    if (target > th.drawn) th.drawn = target;
    for (Flora f : th.flora) {
      if (f.baked || f.k > th.drawn) continue;
      if (frame - reachedAt(th, f.k) >= BLOOM_FRAMES) { drawFlora(g, th, f, 1); f.baked = true; }
    }
  }
}

void drawLiveFlora(PGraphics g, float frame) {
  for (Strand th : strands)
    for (Flora f : th.flora)
      if (!f.baked && f.k <= th.drawn) drawFlora(g, th, f, constrain((frame - reachedAt(th, f.k)) / BLOOM_FRAMES, 0.05, 1));
}

// everything at a given growth frame, for the still
void drawStrandsAt(PGraphics g, float frame) {
  g.strokeCap(ROUND);
  for (Strand th : strands) {
    int target = revealAt(th, frame);
    g.stroke(th.col[0], th.col[1], th.col[2], th.col[3]);
    for (int k = 1; k <= target; k++) {
      g.strokeWeight(widthAt(th, k));
      g.line(th.pts[k - 1][0], th.pts[k - 1][1], th.pts[k][0], th.pts[k][1]);
    }
  }
  for (Strand th : strands) {
    int target = revealAt(th, frame);
    for (Flora f : th.flora)
      if (f.k <= target) drawFlora(g, th, f, constrain((frame - reachedAt(th, f.k)) / BLOOM_FRAMES, 0.05, 1));
  }
}

// kinds: 0 leaf · 1 bud · 2 daisy · 3 fern tip · 4 bell · 5 flower spike
//        6 poppy · 7 seed-head · 8 tendril · 9 compound leaf
void drawFlora(PGraphics g, Strand th, Flora f, float grow) {
  float x = th.pts[f.k][0], y = th.pts[f.k][1], s = f.size * grow;
  g.pushMatrix();
  g.translate(x, y);
  g.rotate(f.a);
  if (f.kind == 0) {
    leaf(g, s, f.col);
  } else if (f.kind == 1) {
    g.stroke(f.col2[0], f.col2[1], f.col2[2], f.col2[3]);
    g.strokeWeight(1);
    g.line(0, 0, s * 1.2, 0);
    g.noStroke();
    g.fill(f.col[0], f.col[1], f.col[2], f.col[3]);
    g.ellipse(s * 1.4, 0, s * 0.9, s * 0.65);
    g.fill(f.col2[0], f.col2[1], f.col2[2], f.col2[3]);
    g.ellipse(s * 1.1, 0, s * 0.45, s * 0.6);
  } else if (f.kind == 2) {
    // daisy: narrow petals round a centre
    g.noStroke();
    g.fill(f.col[0], f.col[1], f.col[2], f.col[3]);
    for (int i = 0; i < f.petals; i++) {
      g.pushMatrix();
      g.rotate(i * TWO_PI / f.petals);
      g.ellipse(s * 0.36, 0, s * 0.52, s * 0.2);
      g.popMatrix();
    }
    g.fill(f.col2[0], f.col2[1], f.col2[2], f.col2[3]);
    g.ellipse(0, 0, s * 0.3, s * 0.3);
  } else if (f.kind == 3 || f.kind == 8) {
    // fern tip, or a longer and finer tendril: a spiral
    boolean tendril = f.kind == 8;
    g.noFill();
    g.stroke(f.col[0], f.col[1], f.col[2], f.col[3]);
    g.strokeWeight(tendril ? 0.7 : max(0.5, widthAt(th, f.k) * 0.8 + 0.4));
    g.beginShape();
    float turns = (tendril ? 2.4 : 1.6) * grow;
    for (float u = 0; u <= turns * TWO_PI; u += 0.2) {
      float r = s * (1 - u / (TWO_PI * (tendril ? 2.9 : 2.2)));
      g.vertex(sin(u) * r + (tendril ? u * s * 0.05 : 0), -(1 - cos(u)) * r);
    }
    g.endShape();
  } else if (f.kind == 4) {
    // bell on a short stalk
    g.stroke(f.col2[0] * 0.6, f.col2[1] * 0.6, f.col2[2] * 0.6, 220);
    g.strokeWeight(0.8);
    g.line(0, 0, s * 0.7, 0);
    g.noStroke();
    g.fill(f.col[0], f.col[1], f.col[2], f.col[3]);
    g.translate(s * 0.7, 0);
    g.beginShape();
    g.vertex(0, -s * 0.2);
    g.bezierVertex(s * 0.35, -s * 0.36, s * 0.6, -s * 0.26, s * 0.78, -s * 0.44);
    g.vertex(s * 0.66, -s * 0.15);
    g.vertex(s * 0.8, 0);
    g.vertex(s * 0.66, s * 0.15);
    g.vertex(s * 0.78, s * 0.44);
    g.bezierVertex(s * 0.6, s * 0.26, s * 0.35, s * 0.36, 0, s * 0.2);
    g.endShape(CLOSE);
  } else if (f.kind == 5) {
    // spike of small florets
    g.stroke(f.col2[0] * 0.6, f.col2[1] * 0.6, f.col2[2] * 0.6, 220);
    g.strokeWeight(0.8);
    g.line(0, 0, s * 1.9, 0);
    g.noStroke();
    g.fill(f.col[0], f.col[1], f.col[2], f.col[3]);
    for (int i = 0; i < 9; i++) {
      float u = i / 8.0;
      float d = s * 0.26 * (1 - u * 0.6);
      g.ellipse(s * (0.55 + u * 1.35), (i % 2 == 0 ? -1 : 1) * s * 0.13 * (1 - u * 0.7), d, d);
    }
  } else if (f.kind == 6) {
    // poppy: four broad petals, dark heart
    g.noStroke();
    for (int i = 0; i < 4; i++) {
      g.pushMatrix();
      g.rotate(i * HALF_PI + 0.3);
      g.fill(f.col[0] * (i % 2 == 0 ? 1 : 0.86), f.col[1] * (i % 2 == 0 ? 1 : 0.86), f.col[2] * (i % 2 == 0 ? 1 : 0.86), f.col[3]);
      g.ellipse(s * 0.3, 0, s * 0.66, s * 0.6);
      g.popMatrix();
    }
    g.fill(30, 20, 40, 255);
    g.ellipse(0, 0, s * 0.28, s * 0.28);
    g.fill(f.col2[0], f.col2[1], f.col2[2], f.col2[3]);
    for (int i = 0; i < 7; i++) g.ellipse(cos(i * 0.9) * s * 0.2, sin(i * 0.9) * s * 0.2, s * 0.07, s * 0.07);
  } else if (f.kind == 7) {
    // seed-head: fine spokes with a dot on each
    g.stroke(f.col[0], f.col[1], f.col[2], 200);
    g.strokeWeight(0.5);
    int spokes = f.petals + 6;
    for (int i = 0; i < spokes; i++) {
      float a = i * TWO_PI / spokes;
      g.line(0, 0, cos(a) * s * 0.6, sin(a) * s * 0.6);
    }
    g.noStroke();
    g.fill(f.col[0], f.col[1], f.col[2], f.col[3]);
    for (int i = 0; i < spokes; i++) {
      float a = i * TWO_PI / spokes;
      g.ellipse(cos(a) * s * 0.6, sin(a) * s * 0.6, s * 0.11, s * 0.11);
    }
    g.fill(f.col2[0], f.col2[1], f.col2[2], f.col2[3]);
    g.ellipse(0, 0, s * 0.16, s * 0.16);
  } else {
    // compound leaf: paired leaflets on a stalk
    g.stroke(f.col[0] * 0.6, f.col[1] * 0.6, f.col[2] * 0.6, 220);
    g.strokeWeight(0.7);
    g.line(0, 0, s * 1.5, 0);
    for (int i = 0; i < 3; i++) {
      for (int side = -1; side <= 1; side += 2) {
        g.pushMatrix();
        g.translate(s * (0.35 + i * 0.4), 0);
        g.rotate(side * 0.9);
        leaf(g, s * 0.5, f.col);
        g.popMatrix();
      }
    }
    g.translate(s * 1.5, 0);
    leaf(g, s * 0.5, f.col);
  }
  g.popMatrix();
}

void leaf(PGraphics g, float s, float[] c) {
  g.noStroke();
  g.fill(c[0], c[1], c[2], c[3]);
  g.beginShape();
  g.vertex(0, 0);
  g.bezierVertex(s * 0.3, -s * 0.42, s * 0.8, -s * 0.34, s, 0);
  g.bezierVertex(s * 0.8, s * 0.34, s * 0.3, s * 0.42, 0, 0);
  g.endShape(CLOSE);
  g.stroke(c[0] * 0.6, c[1] * 0.6, c[2] * 0.6, 150);
  g.strokeWeight(0.6);
  g.line(0, 0, s * 0.85, 0);
}

// =====================================================================
//  EXPORT
// =====================================================================

void saveHiRes() {
  PGraphics big = createGraphics(OUT_W * HIRES_SCALE, OUT_H * HIRES_SCALE);
  big.beginDraw();
  big.image(bg, 0, 0, big.width, big.height);
  big.scale(HIRES_SCALE);
  drawStrandsAt(big, GROW_FRAMES + HOLD_FRAMES);
  big.endDraw();
  big.save(sketchPath("output/painted_figure_trace_" + big.width + "x" + big.height + ".png"));
}

void makeMovie() {
  try {
    ProcessBuilder pb = new ProcessBuilder(
      "ffmpeg", "-y", "-framerate", str(FPS),
      "-i", sketchPath("frames/reel-%04d.png"),
      "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "16",
      "-movflags", "+faststart",
      sketchPath("output/painted_figure_trace_reel.mp4"));
    pb.inheritIO();
    pb.start().waitFor();
  }
  catch (Exception e) {
    println("ffmpeg not found - use Tools > Movie Maker on the frames folder (" + FPS + " fps)");
  }
}
