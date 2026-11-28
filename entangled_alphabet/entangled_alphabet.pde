/**
 * ENTANGLED ALPHABET — cotton threads through a grid of letters
 * ------------------------------------------------------------------
 * Processing 4 (Java mode). No image is used: the paper, the letters
 * and the threads are all drawn here.
 *
 * Layers, bottom to top:
 *  1. Paper.
 *  2. A grid of letters that fills the whole canvas, 9 x 16 cells.
 *     Each cell holds a heavy letter (Inter Black, JetBrains Mono
 *     ExtraBold), enlarged far beyond its cell, turned and cropped,
 *     in one of several colours and transparencies, so that only bold
 *     pieces of type are left: a bowl, a stem, an apex, a counter.
 *     None can be read. In the spirit of early computer art the grid
 *     still moves from order to disorder: towards the bottom right the
 *     pieces tilt further, are overprinted more often, and now and
 *     then a cell is left empty.
 *  3. Organic cotton threads in many colours. Every piece of every
 *     letter is traced by at least one thread: it follows the letter's
 *     own edge (never the cell's crop) part of the way round, then travels to a neighbouring
 *     piece and wraps that too, two or three times over, before it
 *     peels away into the open and curls. Crossing paths entangle the
 *     whole grid.
 *
 * Format: 1080 x 1920 (9:16), 30 fps — Instagram Reel.
 *
 * Outputs (written next to this sketch):
 *   output/entangled_alphabet_1080x1920.png    still of the finished state
 *   frames/reel-####.png                       one PNG per frame
 *   output/entangled_alphabet_reel.mp4         via ffmpeg if on PATH
 *
 * No ffmpeg? Use Tools > Movie Maker on the frames folder (30 fps).
 *
 * Fonts in data/: Inter (SIL Open Font License) and JetBrains Mono
 * (Apache License 2.0); the licence texts are alongside.
 */

// ---------- output settings ----------
final int     OUT_W = 1080, OUT_H = 1920;
final int     STILL_SCALE  = 1;     // 1 = 1080 x 1920
final int     FPS          = 30;
final int     INTRO_FRAMES = 45;    // the letters alone
final int     GROW_FRAMES  = 900;   // 30 s of growth
final int     HOLD_FRAMES  = 90;
final boolean RECORD       = true;
final int     SEED         = 2026;

final int PAPER = 0xFFF3EFE6;

// ---------- THE GRID ----------
final int   COLS = 9, ROWS = 16;               // 120 px cells: the grid fills the canvas exactly
final String LETTERS = "ABCDEFGHJKMNPQRSUVWXYZabdegkmnpqrsy";
final String[] FONT_FILES = { "Inter-Black.otf", "JetBrainsMono-ExtraBold.ttf" };
final float[] FONT_WEIGHTS = { 0.72, 0.28 };    // how often each typeface is used
final String[] GRID_COLORS = { "#1d3bff", "#ff3b1d", "#ffc400", "#00a36c", "#ff4fb8", "#141414", "#7a3cff", "#00b5d8" };
final float[] GRID_ALPHAS = { 0.35, 0.5, 0.65, 0.8, 0.92 };
final float FIT = 0.78;                        // a letter at zoom 1 would just fit its cell
final float ZOOM_MIN = 2.6, ZOOM_MAX = 4.6;    // every letter is enlarged this much: only pieces remain
final float TILT_MIN = 0.12, TILT_MAX = 0.6;   // free turn (radians) at the most ordered / disordered cell
final float INTERRUPT = 0.1;                   // chance a cell is left empty, at full disorder
final float OVERPRINT = 0.55;                  // chance of a second letter on top, at full disorder

// ---------- CONTOURS ----------
final float CONTOUR_SPACING = 3;       // px between points along an outline
final float CONTOUR_MIN_LENGTH = 50;   // px; slivers shorter than this are not traced

// ---------- THREADS ----------
// Each thread starts on the outline of a letter piece, follows it part
// of the way round, travels on to wrap one to three neighbouring
// pieces, then peels away into a noise current and ends in a curl.
final int   EXTRA_THREADS = 25;                // on top of one per piece
final float OFFSET_MIN = 2, OFFSET_MAX = 12;   // distance kept from an outline (px)
final float WOBBLE = 4;                        // how much that distance breathes
final float LIFT = 18;                         // points over which a thread rises off its first outline
final float WRAP_MIN = 0.25, WRAP_MAX = 0.75;  // share of an outline it travels round
final int   HOPS_MIN = 1, HOPS_MAX = 3;        // neighbouring pieces it goes on to
final float HOP_REACH = 260;                   // how far away (px) a neighbour may be
final float TRAVEL_TURN = 0.16;                // how sharply it can steer towards the next piece
final int   PEEL_MIN = 25, PEEL_MAX = 120;     // steps after the last piece
final float STEP_LEN = 2.2, FLOW_SCALE = 0.006, FLOW_TURN = 0.2, CURL = 0.24;
final int   SMOOTH = 3;
final float TW_MIN = 2.0, TW_MAX = 3.6;        // thread thickness (px)
final float STAGGER = 0.65;                    // threads start somewhere in the first 65% of the growth
final int   CHUNK = 12, OVERLAP = 10;          // laid down in short stitches
final String[] THREAD_COLORS = { "#ff1f8f", "#ff5a1f", "#ffc21a", "#22c55e", "#00b3d6", "#2f5bff",
                                 "#8b3dff", "#e6007e", "#00d18f", "#ff3b3b", "#14b8a6", "#f97316" };

java.awt.Font[] fonts;
ArrayList<Mark> marks = new ArrayList<Mark>();
ArrayList<Ring> rings = new ArrayList<Ring>();
ArrayList<Strand> strands = new ArrayList<Strand>();
PGraphics base, threadLayer;

public void settings() {
  size(OUT_W, OUT_H);
  pixelDensity(1);
}

public void setup() {
  frameRate(FPS);
  loadFonts();
  buildGrid();
  traceLetters();
  buildStrands();

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
//  THE GRID OF LETTERS
// =====================================================================

class Mark {
  java.awt.geom.Area area;     // the piece of letter left inside its cell (canvas pixels)
  float x0, y0, x1, y1;        // the cell
  java.awt.Color col;
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

// From order (top left) to disorder (bottom right); never legible.
void buildGrid() {
  randomSeed(SEED + 9);
  float cell = OUT_W / (float) COLS;
  for (int r = 0; r < ROWS; r++) {
    for (int c = 0; c < COLS; c++) {
      float d = (r / (float) (ROWS - 1)) * 0.7 + (c / (float) (COLS - 1)) * 0.3;
      d = constrain(d + random(-0.1, 0.1), 0, 1);
      if (random(1) < INTERRUPT * d) continue;                       // an interruption
      java.awt.geom.Area box = new java.awt.geom.Area(new java.awt.geom.Rectangle2D.Float(c * cell, r * cell, cell, cell));
      int layers = random(1) < OVERPRINT * d ? 2 : 1;
      int tries = 0;
      for (int l = 0; l < layers && tries < 30; tries++) {
        float zoom = random(ZOOM_MIN, ZOOM_MAX);
        float rot = floor(random(4)) * HALF_PI + random(-1, 1) * lerp(TILT_MIN, TILT_MAX, d);
        float slack = (zoom - 1) * 0.35 * cell;
        java.awt.geom.Area a = new java.awt.geom.Area(letterShape(pickFont(), LETTERS.charAt(floor(random(LETTERS.length()))),
                               (c + 0.5) * cell, (r + 0.5) * cell, zoom, rot, random(-slack, slack), random(-slack, slack)));
        a.intersect(box);
        // keep only pieces that carry some ink: an all-but-empty or all-but-full cell says nothing
        float cover = coverage(a, cell);
        if (cover < 0.18 || cover > 0.82) continue;
        Mark mk = new Mark();
        mk.area = a;
        mk.x0 = c * cell; mk.y0 = r * cell; mk.x1 = (c + 1) * cell; mk.y1 = (r + 1) * cell;
        mk.col = gridColour();
        marks.add(mk);
        l++;
      }
    }
  }
}

// share of a cell that an area covers, by sampling
float coverage(java.awt.geom.Area a, float cell) {
  java.awt.geom.Rectangle2D b = a.getBounds2D();
  if (b.isEmpty()) return 0;
  int in = 0, n = 0;
  float x0 = floor((float) b.getX() / cell) * cell, y0 = floor((float) b.getY() / cell) * cell;
  for (int j = 0; j < 12; j++) for (int i = 0; i < 12; i++) {
    n++;
    if (a.contains(x0 + (i + 0.5) * cell / 12, y0 + (j + 0.5) * cell / 12)) in++;
  }
  return in / (float) n;
}

void drawBase(PGraphics pg) {
  pg.background(PAPER);
  pg.pushMatrix();
  pg.scale(pg.width / (float) OUT_W);
  java.awt.Graphics2D g2 = ((processing.awt.PGraphicsJava2D) pg).g2;
  g2.setRenderingHint(java.awt.RenderingHints.KEY_ANTIALIASING, java.awt.RenderingHints.VALUE_ANTIALIAS_ON);
  for (Mark mk : marks) {
    g2.setColor(mk.col);
    g2.fill(mk.area);
  }
  pg.popMatrix();
}

// =====================================================================
//  CONTOURS — the outlines of the letter pieces, as rings of points
// =====================================================================

class Ring {
  float[][] pts, nrm;      // even points round an outline; normal pointing away from the piece
  boolean[] ok;            // false where the outline is only the cell's edge, not the letter's
  float cx, cy;            // centre
  int mark;                // which piece it belongs to
}

void traceLetters() {
  for (int m = 0; m < marks.size(); m++) {
    java.awt.geom.Area a = marks.get(m).area;
    java.awt.geom.PathIterator it = new java.awt.geom.FlatteningPathIterator(a.getPathIterator(null), 0.4);
    float[] c = new float[6];
    ArrayList<float[]> cur = new ArrayList<float[]>();
    while (!it.isDone()) {
      int type = it.currentSegment(c);
      if (type == java.awt.geom.PathIterator.SEG_MOVETO) cur = new ArrayList<float[]>();
      if (type != java.awt.geom.PathIterator.SEG_CLOSE) cur.add(new float[] { c[0], c[1] });
      else {
        Ring r = resample(cur, a, marks.get(m));
        if (r != null) { r.mark = m; rings.add(r); }
      }
      it.next();
    }
  }
  println(marks.size() + " letter pieces, " + rings.size() + " outlines");
}

Ring resample(ArrayList<float[]> ring, java.awt.geom.Area a, Mark mk) {
  ArrayList<float[]> out = new ArrayList<float[]>();
  float carry = 0;
  for (int i = 0; i < ring.size(); i++) {
    float[] p = ring.get(i), q = ring.get((i + 1) % ring.size());
    float len = dist(p[0], p[1], q[0], q[1]);
    float d = carry;
    while (d < len) {
      float u = d / len;
      out.add(new float[] { p[0] + (q[0] - p[0]) * u, p[1] + (q[1] - p[1]) * u });
      d += CONTOUR_SPACING;
    }
    carry = d - len;
  }
  int n = out.size();
  if (n < 8 || n * CONTOUR_SPACING < CONTOUR_MIN_LENGTH) return null;
  Ring r = new Ring();
  r.pts = out.toArray(new float[n][]);
  r.nrm = new float[n][2];
  r.ok = new boolean[n];
  int inside = 0, good = 0;
  for (int k = 0; k < n; k++) {
    float[] p = r.pts[(k - 2 + n) % n], q = r.pts[(k + 2) % n];
    float dx = q[0] - p[0], dy = q[1] - p[1];
    float l = sqrt(dx * dx + dy * dy);
    if (l == 0) l = 1;
    r.nrm[k][0] = dy / l;
    r.nrm[k][1] = -dx / l;
    if (a.contains(r.pts[k][0] + r.nrm[k][0] * 2, r.pts[k][1] + r.nrm[k][1] * 2)) inside++;
    float px = r.pts[k][0], py = r.pts[k][1];
    r.ok[k] = abs(px - mk.x0) > 1 && abs(px - mk.x1) > 1 && abs(py - mk.y0) > 1 && abs(py - mk.y1) > 1;
    if (r.ok[k]) good++;
    r.cx += r.pts[k][0] / n;
    r.cy += r.pts[k][1] / n;
  }
  if (good < 12) return null;                    // nothing of the letter's own edge
  if (inside > n / 2) for (int k = 0; k < n; k++) { r.nrm[k][0] = -r.nrm[k][0]; r.nrm[k][1] = -r.nrm[k][1]; }
  return r;
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
  if (rings.size() == 0) return;
  // every piece of every letter is traced at least once
  boolean[] done = new boolean[marks.size()];
  for (Ring r : rings) {
    if (done[r.mark]) continue;
    done[r.mark] = true;
    strands.add(makeStrand(r));
  }
  for (int i = 0; i < EXTRA_THREADS; i++) strands.add(makeStrand(rings.get(floor(random(rings.size()))))); 
}

// adds points that follow a ring from index start, at a breathing distance
int follow(ArrayList<float[]> pts, Ring ring, int start, float off, float nz, boolean lift) {
  int n = ring.pts.length;
  int dir = random(1) < 0.5 ? 1 : -1;
  int steps = max(8, floor(n * random(WRAP_MIN, WRAP_MAX)));
  int idx = start;
  for (int k = 0; k < steps; k++) {
    int nx = ((start + dir * k) % n + n) % n;
    if (!ring.ok[nx] && k > 3) break;            // the letter's edge ends at the cell's edge
    idx = nx;
    float l = lift ? min(1, k / LIFT) : 1;
    float o = max(1, (off + (noise(k * 0.03, nz) - 0.5) * 2 * WOBBLE) * l);
    pts.add(new float[] { ring.pts[idx][0] + ring.nrm[idx][0] * o, ring.pts[idx][1] + ring.nrm[idx][1] * o });
  }
  return idx;
}

Strand makeStrand(Ring ring) {
  float nz = random(1000);
  float off = random(OFFSET_MIN, OFFSET_MAX);
  ArrayList<float[]> pts = new ArrayList<float[]>();
  int s0 = floor(random(ring.pts.length));
  for (int t = 0; t < 60 && !ring.ok[s0]; t++) s0 = floor(random(ring.pts.length));
  follow(pts, ring, s0, off, nz, true);

  // travel on to neighbouring pieces and wrap those too
  int hops = floor(random(HOPS_MIN, HOPS_MAX + 1));
  Ring here = ring;
  for (int h = 0; h < hops; h++) {
    float[] p = pts.get(pts.size() - 1);
    Ring next = neighbour(here, p[0], p[1]);
    if (next == null) break;
    // nearest point of the next outline
    int best = 0;
    float bd = 1e9f;
    for (int k = 0; k < next.pts.length; k += 2) {
      if (!next.ok[k]) continue;
      float d = dist(p[0], p[1], next.pts[k][0], next.pts[k][1]);
      if (d < bd) { bd = d; best = k; }
    }
    float tx = next.pts[best][0] + next.nrm[best][0] * off, ty = next.pts[best][1] + next.nrm[best][1] * off;
    float[] q = pts.get(max(0, pts.size() - 3));
    float x = p[0], y = p[1], a = atan2(p[1] - q[1], p[0] - q[0]);
    for (int j = 0; j < 500 && dist(x, y, tx, ty) > STEP_LEN * 2; j++) {
      float da = atan2(ty - y, tx - x) - a;
      while (da > PI) da -= TWO_PI;
      while (da < -PI) da += TWO_PI;
      a += constrain(da, -TRAVEL_TURN, TRAVEL_TURN) + (noise(x * FLOW_SCALE, y * FLOW_SCALE, nz) - 0.5) * 0.3;
      x += cos(a) * STEP_LEN;
      y += sin(a) * STEP_LEN;
      pts.add(new float[] { x, y });
    }
    follow(pts, next, best, off, nz, false);
    here = next;
  }

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

  // soften the corners inherited from the outlines
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

// a random outline of another piece within HOP_REACH
Ring neighbour(Ring from, float x, float y) {
  ArrayList<Ring> near = new ArrayList<Ring>();
  for (Ring r : rings) if (r.mark != from.mark && dist(x, y, r.cx, r.cy) < HOP_REACH) near.add(r);
  return near.size() == 0 ? null : near.get(floor(random(near.size())));
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
//  EXPORT
// =====================================================================

void saveStill() {
  PGraphics big = createGraphics(OUT_W * STILL_SCALE, OUT_H * STILL_SCALE);
  big.beginDraw();
  drawBase(big);
  for (Strand st : strands) drawThread(big, st, 0, st.x.length - 1);
  big.endDraw();
  big.save(sketchPath("output/entangled_alphabet_" + big.width + "x" + big.height + ".png"));
}

void makeMovie() {
  try {
    ProcessBuilder pb = new ProcessBuilder(
      "ffmpeg", "-y", "-framerate", str(FPS),
      "-i", sketchPath("frames/reel-%04d.png"),
      "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "16",
      "-movflags", "+faststart",
      sketchPath("output/entangled_alphabet_reel.mp4"));
    pb.inheritIO();
    pb.start().waitFor();
  }
  catch (Exception e) {
    println("ffmpeg not found - use Tools > Movie Maker on the frames folder (" + FPS + " fps)");
  }
}
