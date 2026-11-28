/**
 * OVERGROWN ALPHABET — cotton threads and a grid of letters
 * ------------------------------------------------------------------
 * Processing 4 (Java mode).
 *
 * Layers, bottom to top:
 *  1. data/background.jpg — the drawing.
 *  2. A grid of letters that fills the whole canvas, 9 x 16 cells.
 *     Each cell holds a letter from a modern typeface (Inter Black,
 *     Inter Thin, JetBrains Mono ExtraBold), in one of several colours
 *     and transparencies. In the spirit of early computer art, the grid
 *     moves from order to disorder. No letter is shown whole: each is
 *     enlarged and cropped by its cell, so what is left is the anatomy
 *     of type (a bowl, a stem, an apex, a counter). At the top left the
 *     fragments are mostly upright and still close to their letters;
 *     towards the bottom right they are larger, turned, overprinted,
 *     and now and then missing.
 *  3. Organic cotton threads in many colours that find the black lines
 *     of the figure, lift off them, follow them part of the way round,
 *     then peel away into the open and curl.
 *
 * Format: 1080 x 1920 (9:16), 30 fps — Instagram Reel.
 *
 * Outputs (written next to this sketch):
 *   output/alphabet_grid_thread_1080x1920.png   still of the finished state
 *   frames/reel-####.png                        one PNG per frame
 *   output/alphabet_grid_thread_reel.mp4        via ffmpeg if on PATH
 *
 * Set STILL_SCALE to 2 or 3 for a larger still: the letters and the
 * threads are redrawn sharp, only the drawing itself is enlarged.
 * No ffmpeg? Use Tools > Movie Maker on the frames folder (30 fps).
 *
 * Fonts in data/: Inter (SIL Open Font License) and JetBrains Mono
 * (Apache License 2.0); the licence texts are alongside.
 */

// ---------- output settings ----------
final int     OUT_W = 1080, OUT_H = 1920;
final int     STILL_SCALE  = 1;     // 1 = 1080 x 1920
final int     FPS          = 30;
final int     INTRO_FRAMES = 45;    // the drawing and the grid alone
final int     GROW_FRAMES  = 900;   // 30 s of growth
final int     HOLD_FRAMES  = 90;
final boolean RECORD       = true;
final int     SEED         = 2026;

// ---------- FINDING THE FIGURE (pixels of the 1080 x 1920 drawing) ----------
final float   DARK_MAX  = 110;                         // brightest a pixel may be and still count as black line
final float[] SIGNATURE = { 680, 1815, 780, 1870 };    // a black mark lying wholly inside this box is not traced

// ---------- CONTOURS ----------
final float CONTOUR_MIN_LENGTH = 160;  // px; shorter outlines (flecks) are ignored
final float CONTOUR_SPACING = 3;       // px between points along an outline

// ---------- THREADS ----------
// Each thread starts on an outline of the figure, lifts off it to a
// small distance, follows it part of the way round, then peels away
// into a noise current and ends in a curl.
final int   THREAD_COUNT = 130;
final float OFFSET_MIN = 3, OFFSET_MAX = 18;   // distance kept from the outline (px)
final float WOBBLE = 6;                        // how much that distance breathes
final float LIFT = 24;                         // points over which a thread rises off the outline
final float WRAP_MIN = 0.15, WRAP_MAX = 0.6;   // share of the outline it travels round
final int   MAX_WRAP = 700;
final int   PEEL_MIN = 25, PEEL_MAX = 130;     // steps after leaving the outline
final float STEP_LEN = 2.2, FLOW_SCALE = 0.006, FLOW_TURN = 0.2, CURL = 0.24;
final int   SMOOTH = 3;
final float TW_MIN = 2.0, TW_MAX = 3.8;        // thread thickness (px)
final float STAGGER = 0.65;                    // threads start somewhere in the first 65% of the growth
final int   CHUNK = 12, OVERLAP = 10;          // laid down in short stitches
final String[] THREAD_COLORS = { "#ff1f8f", "#ff5a1f", "#ffc21a", "#22c55e", "#00b3d6", "#2f5bff",
                                 "#8b3dff", "#e6007e", "#00d18f", "#ff3b3b", "#14b8a6", "#f97316" };

// ---------- THE GRID ----------
final int   COLS = 9, ROWS = 16;               // 120 px cells: the grid fills the canvas exactly
final String LETTERS = "ABCDEFGHIJKLMNOPQRSTUVWXYZaegkmnrsy";
final String[] FONT_FILES = { "Inter-Black.otf", "Inter-Thin.otf", "JetBrainsMono-ExtraBold.ttf" };
final float[] FONT_WEIGHTS = { 0.55, 0.2, 0.25 };       // how often each typeface is used
final String[] GRID_COLORS = { "#1d3bff", "#ff3b1d", "#ffc400", "#00a36c", "#ff4fb8", "#141414", "#7a3cff", "#00b5d8" };
final float[] GRID_ALPHAS = { 0.12, 0.25, 0.4, 0.55, 0.7 };
final float FIT = 0.78;                        // a letter at zoom 1 would just fit its cell
final float ZOOM_MIN = 1.45, ZOOM_MAX = 3.4;   // enlargement at the most ordered and the most disordered cell
final float ORDER_FLOOR = 0.3;                 // even the most ordered cell has this much disorder
final float INTERRUPT = 0.2;                   // chance a cell is left empty, at full disorder
final float OUTLINE_SHARE = 0.3;               // share of letters drawn as outline
final float OUTLINE_W = 2.2;                   // their line weight (px)
final float OVERPRINT = 0.4;                   // chance of a second letter on top, at full disorder

PImage bg;
boolean[] dark;                                   // the drawing's black line
boolean[] figInk;                                 // the black line that belongs to the figure
java.awt.Font[] fonts;
ArrayList<Mark> marks = new ArrayList<Mark>();
ArrayList<Ring> figureRings = new ArrayList<Ring>();
ArrayList<Strand> strands = new ArrayList<Strand>();
PGraphics base, threadLayer;

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
  loadFonts();
  buildGrid();

  base = createGraphics(OUT_W, OUT_H);
  base.beginDraw();
  drawBase(base);
  base.endDraw();

  threadLayer = createGraphics(OUT_W, OUT_H);
  threadLayer.beginDraw();
  threadLayer.clear();
  threadLayer.endDraw();
}

public void draw() {
  int f = frameCount - 1;
  float tt = f - INTRO_FRAMES;
  threadLayer.beginDraw();
  for (Strand st : strands) {
    int target = revealAt(st, tt);
    if (target > st.drawn) {
      drawThread(threadLayer, st, st.drawn, target);
      st.drawn = target;
    }
  }
  threadLayer.endDraw();
  image(base, 0, 0);
  image(threadLayer, 0, 0);

  if (RECORD) saveFrame("frames/reel-####.png");
  if (f >= INTRO_FRAMES + GROW_FRAMES + HOLD_FRAMES) {
    if (RECORD) {
      saveStill();
      makeMovie();
    }
    exit();
  }
}

// =====================================================================
//  THE FIGURE — found in the drawing
// =====================================================================

// Marks the black line, and leaves out any mark that lies wholly
// inside the SIGNATURE box.
void studyBackground() {
  bg.loadPixels();
  int w = bg.width, h = bg.height, n = w * h;
  dark = new boolean[n];
  for (int i = 0; i < n; i++) {
    int c = bg.pixels[i];
    dark[i] = max((c >> 16) & 255, (c >> 8) & 255, c & 255) < DARK_MAX;
  }
  figInk = new boolean[n];
  boolean[] seen = new boolean[n];
  int[] stack = new int[n], members = new int[n];
  for (int start = 0; start < n; start++) {
    if (!dark[start] || seen[start]) continue;
    int count = 0, top = 0;
    float x0 = 99999, y0 = 99999, x1 = -1, y1 = -1;
    stack[top++] = start;
    seen[start] = true;
    while (top > 0) {
      int i = stack[--top];
      members[count++] = i;
      int x = i % w, y = i / w;
      x0 = min(x0, x); x1 = max(x1, x); y0 = min(y0, y); y1 = max(y1, y);
      int[] nb = { x > 0 ? i - 1 : -1, x < w - 1 ? i + 1 : -1, i >= w ? i - w : -1, i < n - w ? i + w : -1 };
      for (int j : nb) {
        if (j < 0 || seen[j] || !dark[j]) continue;
        seen[j] = true;
        stack[top++] = j;
      }
    }
    boolean signature = x0 >= SIGNATURE[0] && y0 >= SIGNATURE[1] && x1 <= SIGNATURE[2] && y1 <= SIGNATURE[3];
    if (!signature) for (int k = 0; k < count; k++) figInk[members[k]] = true;
  }
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


class Ring {
  float[][] pts, nrm;      // even points round an outline; normal pointing away from the line
  boolean[] ok;            // false where the line was cut off from a line that runs on
  float weight;
}

// =====================================================================
//  THREADS — where they go
// =====================================================================

class Strand {
  float[] x, y, fuzzLen, fuzzAng;
  int edge, body, light, twist, fuzz;
  float tw, start, dur;    // thickness; frame it starts on, frames it takes
  int drawn;
}

int shade(float[] c, float k) { return color(c[0] * k, c[1] * k, c[2] * k); }
int tint(float[] c, float k) { return color(lerp(c[0], 255, k), lerp(c[1], 255, k), lerp(c[2], 255, k)); }
float[] rgb(String hx) { return new float[] { unhex(hx.substring(1, 3)), unhex(hx.substring(3, 5)), unhex(hx.substring(5, 7)) }; }

void buildStrands() {
  randomSeed(SEED + 6);
  noiseSeed(SEED + 6);
  if (figureRings.size() == 0) return;
  float total = 0;
  for (Ring r : figureRings) total += r.weight;
  for (int i = 0; i < THREAD_COUNT; i++) {
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

  // soften the corners inherited from the outline
  Strand st = new Strand();
  int m = pts.size();
  st.x = new float[m];
  st.y = new float[m];
  st.fuzzLen = new float[m];
  st.fuzzAng = new float[m];
  st.tw = random(TW_MIN, TW_MAX);
  for (int k = 0; k < m; k++) {
    float sx = 0, sy = 0;
    int c = 0;
    for (int q = max(0, k - SMOOTH); q <= min(m - 1, k + SMOOTH); q++) { sx += pts.get(q)[0]; sy += pts.get(q)[1]; c++; }
    st.x[k] = sx / c;
    st.y[k] = sy / c;
    st.fuzzLen[k] = random(1) < 0.3 ? random(st.tw * 0.8, st.tw * 2.6) * (random(1) < 0.5 ? 1 : -1) : 0;
    st.fuzzAng[k] = random(-0.9, 0.9);
  }

  float[] c = rgb(THREAD_COLORS[floor(random(THREAD_COLORS.length))]);
  st.edge = shade(c, 0.62);
  st.body = color(c[0], c[1], c[2]);
  st.light = tint(c, 0.55);
  st.twist = shade(c, 0.42);
  st.fuzz = tint(c, 0.25);
  st.start = random(GROW_FRAMES * STAGGER);
  st.dur = max(30, GROW_FRAMES - st.start);
  return st;
}

// index of the last point a thread has reached on a given growth frame
int revealAt(Strand st, float frame) {
  float u = constrain((frame - st.start) / st.dur, 0, 1);
  return floor(u * (st.x.length - 1));
}

// =====================================================================
//  THREADS — what they look like
// =====================================================================

void poly(PGraphics g, Strand st, int a, int b, float ox, float oy) {
  g.beginShape();
  for (int i = a; i <= b; i++) g.vertex(st.x[i] + ox, st.y[i] + oy);
  g.endShape();
}

// Lays down points a..b of one thread in short stitches, so that where
// threads cross, the later one sits on top and drops its shadow.
void drawThread(PGraphics g, Strand st, int a, int b) {
  int n = st.x.length;
  float tw = st.tw;
  g.pushMatrix();
  g.scale(g.width / (float) OUT_W);
  g.noFill();
  g.strokeJoin(ROUND);
  for (int s = a; s < b; s += CHUNK) {
    int e = min(b, s + CHUNK);
    int s0 = max(0, s - OVERLAP);

    // shadow
    g.strokeCap(SQUARE);
    g.stroke(0, 22);
    g.strokeWeight(tw * 1.8);
    poly(g, st, s, e, tw * 0.30, tw * 0.44);
    g.stroke(0, 34);
    g.strokeWeight(tw * 1.2);
    poly(g, st, s, e, tw * 0.22, tw * 0.32);

    // fibres that escape the twist
    g.strokeCap(ROUND);
    g.stroke(st.fuzz, 200);
    g.strokeWeight(0.6);
    for (int i = max(1, s0); i < e && i < n - 1; i++) {
      if (st.fuzzLen[i] == 0) continue;
      float ta = atan2(st.y[i + 1] - st.y[i - 1], st.x[i + 1] - st.x[i - 1]);
      float side = st.fuzzLen[i] > 0 ? 1 : -1;
      float na = ta + side * (HALF_PI + st.fuzzAng[i]);
      float bx = st.x[i] + cos(ta + side * HALF_PI) * tw * 0.35;
      float by = st.y[i] + sin(ta + side * HALF_PI) * tw * 0.35;
      float len = abs(st.fuzzLen[i]);
      g.bezier(bx, by,
               bx + cos(na) * len * 0.5, by + sin(na) * len * 0.5,
               bx + cos(na + 0.6) * len * 0.8, by + sin(na + 0.6) * len * 0.8,
               bx + cos(na + 0.9) * len, by + sin(na + 0.9) * len);
    }

    // body
    g.stroke(st.edge);
    g.strokeWeight(tw);
    poly(g, st, s0, e, 0, 0);
    g.stroke(st.body);
    g.strokeWeight(tw * 0.76);
    poly(g, st, s0, e, 0, 0);
    g.stroke(st.light, 190);
    g.strokeWeight(tw * 0.26);
    poly(g, st, s0, e, -tw * 0.15, -tw * 0.17);

    // the twist of the ply
    g.stroke(st.twist, 130);
    g.strokeWeight(0.7);
    g.strokeCap(SQUARE);
    for (int i = max(1, s0); i < e && i < n - 1; i++) {
      if (i % 2 != 0) continue;
      float ta = atan2(st.y[i + 1] - st.y[i - 1], st.x[i + 1] - st.x[i - 1]) + 0.95;
      float hl = tw * 0.36;
      g.line(st.x[i] - cos(ta) * hl, st.y[i] - sin(ta) * hl, st.x[i] + cos(ta) * hl, st.y[i] + sin(ta) * hl);
    }
  }
  g.popMatrix();
}

// =====================================================================
//  THE GRID OF LETTERS
// =====================================================================

class Mark {
  java.awt.Shape shape;    // the letter, already placed (canvas pixels)
  java.awt.geom.Rectangle2D cell;
  java.awt.Color col;
  boolean outline;
}

void loadFonts() {
  fonts = new java.awt.Font[FONT_FILES.length];
  for (int i = 0; i < FONT_FILES.length; i++) {
    try {
      fonts[i] = java.awt.Font.createFont(java.awt.Font.TRUETYPE_FONT, new java.io.File(dataPath(FONT_FILES[i])));
    }
    catch (Exception e) {
      println("could not load " + FONT_FILES[i] + ", using SansSerif bold");
      fonts[i] = new java.awt.Font("SansSerif", java.awt.Font.BOLD, 1);
    }
  }
}

int pickFont() {
  float r = random(1), acc = 0;
  for (int i = 0; i < FONT_WEIGHTS.length; i++) { acc += FONT_WEIGHTS[i]; if (r < acc) return i; }
  return 0;
}

// One letter as an outline, scaled, turned and moved into a cell.
java.awt.Shape letterShape(int font, char ch, float cx, float cy, float zoom, float rot, float ox, float oy) {
  java.awt.Font f = fonts[font].deriveFont(1000f);
  java.awt.font.FontRenderContext frc = new java.awt.font.FontRenderContext(null, true, true);
  java.awt.Shape s = f.createGlyphVector(frc, String.valueOf(ch)).getOutline();
  java.awt.geom.Rectangle2D b = s.getBounds2D();
  float cell = OUT_W / (float) COLS;
  float fit = FIT * cell / (float) Math.max(b.getWidth(), b.getHeight());
  java.awt.geom.AffineTransform at = new java.awt.geom.AffineTransform();
  at.translate(cx + ox, cy + oy);
  at.rotate(rot);
  at.scale(fit * zoom, fit * zoom);
  at.translate(-b.getCenterX(), -b.getCenterY());
  return at.createTransformedShape(s);
}

java.awt.Color gridColour() {
  float[] c = rgb(GRID_COLORS[floor(random(GRID_COLORS.length))]);
  float a = GRID_ALPHAS[floor(random(GRID_ALPHAS.length))];
  return new java.awt.Color((int) c[0], (int) c[1], (int) c[2], round(a * 255));
}

// From order (top left) to disorder (bottom right).
void buildGrid() {
  randomSeed(SEED + 9);
  float cell = OUT_W / (float) COLS;
  for (int r = 0; r < ROWS; r++) {
    for (int c = 0; c < COLS; c++) {
      float d = (r / (float) (ROWS - 1)) * 0.7 + (c / (float) (COLS - 1)) * 0.3;
      d = constrain(lerp(ORDER_FLOOR, 1, d) + random(-0.08, 0.08), 0, 1);
      if (random(1) < INTERRUPT * d) continue;                       // an interruption
      int layers = random(1) < OVERPRINT * d ? 2 : 1;
      for (int l = 0; l < layers; l++) {
        float zoom = lerp(ZOOM_MIN, random(ZOOM_MIN + 0.4, ZOOM_MAX), d);
        float rot = 0;
        if (random(1) < d) rot = floor(random(1, 4)) * HALF_PI;
        if (random(1) < d * 0.4) rot += random(-0.35, 0.35);
        float slack = (zoom - 1) * 0.5 * cell * max(d, 0.5);
        Mark mk = new Mark();
        mk.cell = new java.awt.geom.Rectangle2D.Float(c * cell, r * cell, cell, cell);
        mk.shape = letterShape(pickFont(), LETTERS.charAt(floor(random(LETTERS.length()))),
                               (c + 0.5) * cell, (r + 0.5) * cell, zoom, rot, random(-slack, slack), random(-slack, slack));
        mk.col = gridColour();
        mk.outline = random(1) < OUTLINE_SHARE;
        marks.add(mk);
      }
    }
  }
}

// The drawing, then every letter clipped to its own cell.
void drawBase(PGraphics pg) {
  pg.image(bg, 0, 0, pg.width, pg.height);
  pg.pushMatrix();
  pg.scale(pg.width / (float) OUT_W);
  java.awt.Graphics2D g2 = ((processing.awt.PGraphicsJava2D) pg).g2;
  g2.setRenderingHint(java.awt.RenderingHints.KEY_ANTIALIASING, java.awt.RenderingHints.VALUE_ANTIALIAS_ON);
  java.awt.Shape oldClip = g2.getClip();
  for (Mark mk : marks) {
    g2.setClip(mk.cell);
    g2.setColor(mk.col);
    if (mk.outline) {
      g2.setStroke(new java.awt.BasicStroke(OUTLINE_W, java.awt.BasicStroke.CAP_BUTT, java.awt.BasicStroke.JOIN_MITER));
      g2.draw(mk.shape);
    } else g2.fill(mk.shape);
  }
  g2.setClip(oldClip);
  pg.popMatrix();
}

// =====================================================================
//  EXPORT
// =====================================================================

void saveStill() {
  PGraphics big = createGraphics(OUT_W * STILL_SCALE, OUT_H * STILL_SCALE);
  big.beginDraw();
  drawBase(big);
  for (Strand st : strands) drawThread(big, st, 0, st.x.length - 1);
  big.endDraw();
  big.save(sketchPath("output/alphabet_grid_thread_" + big.width + "x" + big.height + ".png"));
}

void makeMovie() {
  try {
    ProcessBuilder pb = new ProcessBuilder(
      "ffmpeg", "-y", "-framerate", str(FPS),
      "-i", sketchPath("frames/reel-%04d.png"),
      "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "16",
      "-movflags", "+faststart",
      sketchPath("output/alphabet_grid_thread_reel.mp4"));
    pb.inheritIO();
    pb.start().waitFor();
  }
  catch (Exception e) {
    println("ffmpeg not found - use Tools > Movie Maker on the frames folder (" + FPS + " fps)");
  }
}
