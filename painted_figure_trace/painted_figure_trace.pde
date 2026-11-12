/**
 * NO FORM TWICE — the painted figure
 * ------------------------------------------------------------------
 * Processing 4 (Java mode). The same piece as woven_figure_trace, laid
 * over a different painting and in a different colour scheme.
 *
 * Layers, bottom to top:
 *  1. data/background.jpg — the painting.
 *  2. The type grid, no form used twice, in orange: filled on plain
 *     paper, pale orange outline where it crosses the painting or lies
 *     inside the figure.
 *  3. Fine strands that find the black lines of the figure, lift off
 *     them, follow them part of the way round, then peel away and
 *     curl, with leaves, buds, flowers, fern tips, butterflies,
 *     ladybirds and snails along them. The calligraphy around the
 *     figure and the lettering at the top are not traced.
 *  4. One violet cotton thread that passes over every form.
 *
 * This painting is coloured all over the figure and nowhere else, so
 * the figure is found by its colour: the painted area is taken as the
 * body, and the black lines that belong to it are the ones that touch
 * it. Nothing has to be marked by hand.
 *
 * Format: 1080 x 1920 (9:16), 30 fps — Instagram Reel.
 *
 * Outputs (written next to this sketch):
 *   output/painted_figure_trace_3240x5760.png   high-res still
 *   frames/reel-####.png                       one PNG per frame
 *   output/painted_figure_trace_reel.mp4       via ffmpeg if on PATH
 *
 * The high-res still needs memory: in Preferences raise the maximum
 * available memory to 2048 MB, or set HIRES_SCALE to 2.
 * No ffmpeg? Use Tools > Movie Maker on the frames folder (30 fps).
 */

// ---------- output settings ----------
final int     OUT_W = 1080, OUT_H = 1920;
final int     HIRES_SCALE  = 3;
final int     FPS          = 30;
final int     INTRO_FRAMES = 45;    // drawing and forms alone
final int     GROW_FRAMES  = 900;   // 30 s of searching
final int     HOLD_FRAMES  = 90;
final boolean RECORD       = true;
final int     SEED         = 2026;

// ---------- the forms: orange ----------
final float FORM_R = 255, FORM_G = 112, FORM_B = 0;
final float LINE_R = 255, LINE_G = 170, LINE_B = 92;   // the outline: pale orange

final float OUTLINE      = 5.5;    // weight of the forms' outline (grid units; about 3 px in the reel)
final float OUTLINE_FOOT = 1.7;    // the same for the small print

// ---------- grid (units; the frame is 1932 wide) ----------
final float GRID_W    = 1932;
final float GRID_H    = GRID_W * OUT_H / OUT_W;
final float MARGIN    = 100;
final float CAP       = 172;
final float ROW_TOP   = 230;
final float ROW_PITCH = 202.3;
final int   ROWS      = 14;
final float X_MONO_R  = 1068;
final float X_BOLD_R  = 948;
final float BOLD_W    = 890;
final float MONO_W    = 768;
final float BOLD      = 43;      // stem
final float BAR       = 40;      // bar
final float MONO      = 32;      // monoline stroke
final float FOOT_Y    = 3150;
final float FOOT_S    = 0.2;

final float[] BOLD_X  = { 0, 200, 351, 569, 733 };   // slot origins
final float[] BOLD_SW = { 162, 125, 186, 156, 157 }; // slot widths
final float[] MONO_X  = { 0, 209, 421, 615 };
final float[] MONO_SW = { 175, 181, 161, 153 };


// ---------- thread ----------
final float TW      = 7;
final float STEP    = 2.5;
final int   CHUNK   = 12;
final int   OVERLAP = 10;
final int   COTTON_EDGE  = 0xFF34128F;
final int   COTTON_BODY  = 0xFF6A2CF0;
final int   COTTON_LIGHT = 0xFFA98BFF;
final int   COTTON_TWIST = 0xFF240A66;
final int   COTTON_FUZZ  = 0xFF7A48F2;

// ---------- FINDING THE FIGURE (pixels of the 1080 x 1920 painting) ----------
final float COLOUR_MIN = 55;     // how far apart a pixel's channels must be to count as painted
final float DARK_MAX   = 105;    // brightest a pixel may be and still count as black line
final float CLOSE_R    = 26;     // black lines up to twice this wide inside the painted area are bridged
final float LINE_REACH = 60;     // how far beyond the painted area a figure line may run

// ---------- CONTOURS ----------
final float CONTOUR_MIN_LENGTH = 90;   // px; shorter outlines (flecks) are ignored
final float CONTOUR_SPACING = 3;       // px between points along an outline

// ---------- CONTOUR STRANDS ----------
// Each strand starts on an outline of the figure, lifts off it to a
// small distance, follows it part of the way round, then peels away
// into a noise current and ends in a curl.
final int   STRAND_COUNT = 400;
final float OFFSET_MIN = 4, OFFSET_MAX = 20;   // distance kept from the outline (px)
final float WOBBLE = 5;                        // how much that distance breathes
final float LIFT = 24;                         // points over which a strand rises off the outline
final float WRAP_MIN = 0.10, WRAP_MAX = 0.50;  // share of the outline it travels round
final int   MAX_WRAP = 700;
final int   PEEL_MIN = 30, PEEL_MAX = 150;     // steps after leaving the outline
final float STEP_LEN = 2.2, FLOW_SCALE = 0.006, FLOW_TURN = 0.16, CURL = 0.22;
final int   SMOOTH = 3;
final float STRAND_W_MIN = 0.7, STRAND_W_MAX = 2.4;
final float STRAND_A_MIN = 225, STRAND_A_MAX = 255;
final float STAGGER = 0.65;                    // strands start somewhere in the first 65% of the growth
final String[] STRAND_COLORS = { "#0f8f8f", "#2bb673", "#b5d334", "#ffd400", "#1f6fd6", "#00b3c7", "#8fd14f", "#136f63" };

// ---------- FLORA ----------
final float LEAF_CHANCE = 0.009, LEAF_MIN = 5, LEAF_MAX = 15;
final float BUD_CHANCE = 0.0025, FLOWER_CHANCE = 0.0025, FLOWER_MIN = 4, FLOWER_MAX = 11;
final float FERN_TIP_CHANCE = 0.3;
final String[] LEAF_COLORS   = { "#1f9d8b", "#3fbf7f", "#0f6f6f", "#9fd65a", "#136f63", "#6fc7a0" };
final String[] FLOWER_COLORS = { "#ffffff", "#ffe14a", "#39c6e0", "#b5f04a", "#1f6fd6", "#fff3b0", "#7fe0d0" };
final int   BLOOM_FRAMES = 24;                 // frames a leaf or flower takes to open

// ---------- FAUNA ----------
final int   BUTTERFLIES = 8, LADYBIRDS = 10, SNAILS = 4;
final float BUTTERFLY_MIN = 9, BUTTERFLY_MAX = 18, LADYBIRD_MIN = 4, LADYBIRD_MAX = 7, SNAIL_MIN = 7, SNAIL_MAX = 12;
final float FLUTTER = 0.22;
final String[] BUTTERFLY_COLORS = { "#ffe14a", "#39c6e0", "#1f6fd6", "#b5f04a", "#0f8f8f", "#ffffff" };

PImage bg;
float[] outside;                                  // 1 = outside the figure, 0 = inside it
boolean[] dark;                                   // the painting's black line
boolean[] figInk;                                 // the black line that belongs to the figure
ArrayList<Word> words = new ArrayList<Word>();
HashSet<String> used = new HashSet<String>();     // every form's signature
ArrayList<PVector> anchors = new ArrayList<PVector>();
float[] tx, ty, cost, fuzzLen, fuzzAng;
int nPts;
int shown = 0;
PGraphics poster, threadLayer, strandLayer;
ArrayList<Ring> figureRings = new ArrayList<Ring>();
ArrayList<Strand> strands = new ArrayList<Strand>();
ArrayList<Creature> creatures = new ArrayList<Creature>();

public void settings() {
  size(OUT_W, OUT_H);
  pixelDensity(1);
}

public void setup() {
  frameRate(FPS);
  randomSeed(SEED);
  noiseSeed(SEED);

  bg = loadImage("background.jpg");
  if (bg.width != OUT_W || bg.height != OUT_H) bg.resize(OUT_W, OUT_H);
  studyBackground();

  setWords();
  buildPath();
  println("thread passes over " + formsTouched() + " of " + used.size() + " forms");

  traceFigure();
  buildStrands();

  poster = compose(1);

  strandLayer = createGraphics(width, height);
  strandLayer.beginDraw();
  strandLayer.clear();
  strandLayer.endDraw();

  threadLayer = createGraphics(width, height);
  threadLayer.beginDraw();
  threadLayer.clear();
  threadLayer.endDraw();
}

public void draw() {
  int f = frameCount - 1;
  float p = constrain((f - INTRO_FRAMES) / (float) GROW_FRAMES, 0, 1);
  int target = sampleAtCost(p * cost[nPts - 1]);
  if (target > shown) {
    threadLayer.beginDraw();
    drawThread(threadLayer, shown, target);
    threadLayer.endDraw();
    shown = target;
  }
  image(poster, 0, 0);

  // the figure's strands and what grows on them, under the cotton thread
  float tt = f - INTRO_FRAMES;
  strandLayer.beginDraw();
  growStep(strandLayer, tt);
  strandLayer.endDraw();
  image(strandLayer, 0, 0);
  drawLiveFlora(g, tt);
  drawCreatures(g, tt, true);

  image(threadLayer, 0, 0);

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
//  DRAWING + FORMS
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

  outside = new float[n];
  for (int i = 0; i < n; i++) outside[i] = (db[i] < 2 || figInk[i]) ? 0 : 1;
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

// Drawing + forms at sc times the base size. The forms are first drawn
// with their fill and outline marked; then, pixel by pixel, the fill is
// kept on plain paper outside the figure and the outline everywhere else.
PGraphics compose(int sc) {
  int w = OUT_W * sc, h = OUT_H * sc;
  PGraphics pg = createGraphics(w, h);
  pg.beginDraw();
  pg.clear();
  pg.pushMatrix();
  pg.scale(w / GRID_W);
  for (Word wd : words) wd.draw(pg);
  pg.popMatrix();
  pg.loadPixels();
  int bw = bg.width, bh = bg.height;
  for (int y = 0; y < h; y++) {
    float v = constrain((y + 0.5) / sc - 0.5, 0, bh - 1);
    int y0 = floor(v), y1 = min(bh - 1, y0 + 1);
    float fy = v - y0;
    for (int x = 0; x < w; x++) {
      float u = constrain((x + 0.5) / sc - 0.5, 0, bw - 1);
      int x0 = floor(u), x1 = min(bw - 1, x0 + 1);
      float fx = u - x0;
      int i00 = y0 * bw + x0, i10 = y0 * bw + x1, i01 = y1 * bw + x0, i11 = y1 * bw + x1;
      float w00 = (1 - fx) * (1 - fy), w10 = fx * (1 - fy), w01 = (1 - fx) * fy, w11 = fx * fy;

      // the drawing, on white paper
      float r = 0, g = 0, b = 0;
      int c;
      float a;
      c = bg.pixels[i00]; a = ((c >>> 24) & 255) / 255.0 * w00;
      r += w00 * 255 + a * (((c >> 16) & 255) - 255); g += w00 * 255 + a * (((c >> 8) & 255) - 255); b += w00 * 255 + a * ((c & 255) - 255);
      c = bg.pixels[i10]; a = ((c >>> 24) & 255) / 255.0 * w10;
      r += w10 * 255 + a * (((c >> 16) & 255) - 255); g += w10 * 255 + a * (((c >> 8) & 255) - 255); b += w10 * 255 + a * ((c & 255) - 255);
      c = bg.pixels[i01]; a = ((c >>> 24) & 255) / 255.0 * w01;
      r += w01 * 255 + a * (((c >> 16) & 255) - 255); g += w01 * 255 + a * (((c >> 8) & 255) - 255); b += w01 * 255 + a * ((c & 255) - 255);
      c = bg.pixels[i11]; a = ((c >>> 24) & 255) / 255.0 * w11;
      r += w11 * 255 + a * (((c >> 16) & 255) - 255); g += w11 * 255 + a * (((c >> 8) & 255) - 255); b += w11 * 255 + a * ((c & 255) - 255);

      int i = y * w + x;
      float fa = ((pg.pixels[i] >>> 24) & 255) / 255.0;
      if (fa > 0) {
        int m = pg.pixels[i];
        float oOut = fa * (m & 255) / 255.0;                   // outline, the half outside the form
        float oIn = fa * ((m >> 8) & 255) / 255.0;             // outline, the half inside the form
        float paper = constrain(1 - 1.6 * (1 - min(r, g, b) / 255.0), 0, 1);
        float out = outside[i00] * w00 + outside[i10] * w10 + outside[i01] * w01 + outside[i11] * w11;
        float allow = paper * out;                             // 1 = plain paper outside the body
        float kf = (fa - oOut) * allow;                        // fill: the form itself, no outline
        r += (FORM_R - r) * kf;
        g += (FORM_G - g) * kf;
        b += (FORM_B - b) * kf;
        float ko = (oOut + oIn) * (1 - allow);                 // outline: only where there is no fill
        r += (LINE_R - r) * ko;
        g += (LINE_G - g) * ko;
        b += (LINE_B - b) * ko;
      }
      pg.pixels[i] = 0xFF000000 | (round(r) << 16) | (round(g) << 8) | round(b);
    }
  }
  pg.updatePixels();
  pg.endDraw();
  return pg;
}

// =====================================================================
//  FORMS
// =====================================================================

class Glyph {
  ArrayList<float[]> prims = new ArrayList<float[]>();
  java.awt.geom.Area outline;      // all strokes of the form merged into one shape
  float w;
  boolean mono;
  String sig = "";
  Glyph(float w, boolean mono) { this.w = w; this.mono = mono; }
  void rect(float x, float y, float rw, float rh) { prims.add(new float[] { 0, x, y, rw, rh }); }
  void quad(float x1, float y1, float x2, float y2, float x3, float y3, float x4, float y4) {
    prims.add(new float[] { 1, x1, y1, x2, y2, x3, y3, x4, y4 });
  }
  void arc(float cx, float cy, float dw, float dh, float a0, float a1) { prims.add(new float[] { 2, cx, cy, dw, dh, a0, a1 }); }
  void line(float x1, float y1, float x2, float y2) { prims.add(new float[] { 3, x1, y1, x2, y2 }); }
  // the form as one shape: every stroke turned into its own area, then united
  java.awt.geom.Area shape() {
    if (outline != null) return outline;
    outline = new java.awt.geom.Area();
    java.awt.BasicStroke pen = new java.awt.BasicStroke(mono ? MONO : BOLD,
      java.awt.BasicStroke.CAP_BUTT, java.awt.BasicStroke.JOIN_MITER);
    for (float[] p : prims) {
      int t = (int) p[0];
      java.awt.Shape sh;
      if (t == 0) sh = new java.awt.geom.Rectangle2D.Float(p[1], p[2], p[3], p[4]);
      else if (t == 1) {
        java.awt.geom.Path2D.Float q = new java.awt.geom.Path2D.Float();
        q.moveTo(p[1], p[2]);
        q.lineTo(p[3], p[4]);
        q.lineTo(p[5], p[6]);
        q.lineTo(p[7], p[8]);
        q.closePath();
        sh = q;
      } else if (t == 2) {
        // Java measures arc angles counter-clockwise, Processing clockwise
        sh = pen.createStrokedShape(new java.awt.geom.Arc2D.Float(p[1] - p[3] / 2, p[2] - p[4] / 2, p[3], p[4],
          -degrees(p[5]), -degrees(p[6] - p[5]), java.awt.geom.Arc2D.OPEN));
      } else sh = pen.createStrokedShape(new java.awt.geom.Line2D.Float(p[1], p[2], p[3], p[4]));
      outline.add(new java.awt.geom.Area(sh));
    }
    return outline;
  }

  // Draws the form in three marker colours so that compose() can tell
  // the parts apart: blue = the half of the outline outside the form,
  // green = the half inside it, red = the body of the form.
  // weight is in the glyph's own units
  void draw(PGraphics g, float weight) {
    java.awt.Graphics2D g2 = ((processing.awt.PGraphicsJava2D) g).g2;
    java.awt.BasicStroke pen = new java.awt.BasicStroke(weight, java.awt.BasicStroke.CAP_BUTT, java.awt.BasicStroke.JOIN_MITER);
    java.awt.geom.Area band = new java.awt.geom.Area(pen.createStrokedShape(shape()));
    java.awt.geom.Area inner = new java.awt.geom.Area(band);
    inner.intersect(shape());
    g2.setColor(new java.awt.Color(255, 0, 255));
    g2.fill(band);
    g2.setColor(new java.awt.Color(255, 0, 0));
    g2.fill(shape());
    g2.setColor(new java.awt.Color(255, 255, 0));
    g2.fill(inner);
  }
}

class Word {
  Glyph[] glyphs;
  float x, y, s;
  boolean mono;
  Word(boolean mono, float x, float y, float s) {
    this.mono = mono; this.x = x; this.y = y; this.s = s;
    float[] sw = mono ? MONO_SW : BOLD_SW;
    glyphs = new Glyph[sw.length];
    for (int i = 0; i < sw.length; i++) glyphs[i] = unique(sw[i], mono);
  }
  void draw(PGraphics g) {
    float[] sx = mono ? MONO_X : BOLD_X;
    for (int i = 0; i < glyphs.length; i++) {
      g.pushMatrix();
      g.translate(x + sx[i] * s, y);
      g.scale(s);
      glyphs[i].draw(g, (s == 1 ? OUTLINE : OUTLINE_FOOT / s));
      g.popMatrix();
    }
  }
}

// asks the generators until they give a form that has not been used
Glyph unique(float w, boolean mono) {
  for (int tries = 0; tries < 5000; tries++) {
    Glyph g = mono ? genMono(w) : genBold(w);
    if (g == null || used.contains(g.sig)) continue;
    used.add(g.sig);
    return g;
  }
  return new Glyph(w, mono);   // never reached in practice
}

void setWords() {
  for (int r = 0; r < ROWS; r++) {
    float y = ROW_TOP + r * ROW_PITCH;
    Word wb = new Word(false, (r % 2 == 0) ? MARGIN : X_BOLD_R, y, 1);
    Word wm = new Word(true, (r % 2 == 0) ? X_MONO_R : MARGIN, y, 1);
    words.add(wb);
    words.add(wm);
    for (Word wd : new Word[] { wb, wm }) {
      float[] sx = wd.mono ? MONO_X : BOLD_X;
      float[] sw = wd.mono ? MONO_SW : BOLD_SW;
      for (int i = 0; i < sx.length; i++) {
        float lx = sw[i] / 2 + random(-18, 18), ly = CAP / 2 + random(-22, 22);
        PVector pt = onForm(wd.glyphs[i], lx, ly);
        anchors.add(new PVector(wd.x + sx[i] + pt.x, y + pt.y, 1));
      }
    }
  }
  // small print: left, centre pair, right
  float[] fx = { MARGIN, 640, 640 + BOLD_W * FOOT_S + 26, GRID_W - 96 - BOLD_W * FOOT_S };
  boolean[] fm = { true, false, true, false };
  for (int i = 0; i < 4; i++) {
    Word wd = new Word(fm[i], fx[i], FOOT_Y, FOOT_S);
    words.add(wd);
    float[] sx = wd.mono ? MONO_X : BOLD_X;
    float[] sw = wd.mono ? MONO_SW : BOLD_SW;
    for (int j = 0; j < sx.length; j++) {          // every small form is visited too
      PVector pt = onForm(wd.glyphs[j], sw[j] / 2, CAP / 2);
      anchors.add(new PVector(fx[i] + (sx[j] + pt.x) * FOOT_S, FOOT_Y + pt.y * FOOT_S, 0.3));
    }
  }
}

// A point that lies on the form itself, as near to (lx, ly) as can be
// found, so that the thread sent there really lands on the form.
// (Own random source: the forms keep the numbers they were made with.)
java.util.Random picker = new java.util.Random(SEED);
PVector onForm(Glyph gl, float lx, float ly) {
  java.awt.geom.Area a = gl.shape();
  if (a.contains(lx - 6, ly - 6, 12, 12)) return new PVector(lx, ly);
  PVector best = null;
  float bd = 99999999;
  for (int pass = 0; pass < 2 && best == null; pass++) {
    for (int t = 0; t < 600; t++) {
      float x = picker.nextFloat() * gl.w, y = picker.nextFloat() * CAP;
      boolean in = (pass == 0) ? a.contains(x - 6, y - 6, 12, 12) : a.contains(x, y);
      if (!in) continue;
      float d = dist(x, y, lx, ly);
      if (d < bd) { bd = d; best = new PVector(x, y); }
    }
  }
  return best != null ? best : new PVector(lx, ly);
}

// How many forms the thread actually passes over.
int formsTouched() {
  int touched = 0;
  for (Word wd : words) {
    float[] sx = wd.mono ? MONO_X : BOLD_X;
    for (int i = 0; i < wd.glyphs.length; i++) {
      java.awt.geom.Area a = wd.glyphs[i].shape();
      float ox = wd.x + sx[i] * wd.s, hw = TW / 2 / wd.s;
      boolean hit = false;
      for (int k = 0; k < nPts && !hit; k++) {
        float lx = (tx[k] - ox) / wd.s, ly = (ty[k] - wd.y) / wd.s;
        if (lx < -hw || ly < -hw || lx > wd.glyphs[i].w + hw || ly > CAP + hw) continue;
        hit = a.intersects(lx - hw, ly - hw, 2 * hw, 2 * hw);
      }
      if (hit) touched++;
    }
  }
  return touched;
}

// ---------------------------------------------------------------------
//  Heavy forms. Rules that keep them from becoming letters:
//  no stem runs the full height; a stem may only grow out of the middle
//  bar; top and bottom bars float; one diagonal at most.
// ---------------------------------------------------------------------

// bar on row 0/1/2, span 0 full, 1 left, 2 right, 3 centre
void addBar(Glyph g, int row, int span) {
  float xC = (g.w - BOLD) / 2;
  float x0 = (span == 2) ? xC : (span == 3) ? xC - 22 : 0;
  float x1 = (span == 1) ? xC + BOLD : (span == 3) ? xC + BOLD + 22 : g.w;
  g.rect(x0, row * 66, x1 - x0, BAR);
}

boolean barCovers(int span, int col) {
  if (span == 0) return true;
  if (span == 1) return col <= 1;
  if (span == 2) return col >= 1;
  return col == 1;
}

Glyph genBold(float w) {
  Glyph g = new Glyph(w, false);
  float xC = (w - BOLD) / 2;
  float[] colX = { 0, xC, w - BOLD };
  float roll = random(1);

  if (roll < 0.34) {
    // --- middle bar with half stems standing on it or hanging from it ---
    int mid = floor(random(3));
    addBar(g, 1, mid);
    int[] side = { 0, 0, 0 };                 // -1 above, +1 below
    int want = random(1) < 0.6 ? 2 : 1, placed = 0;
    for (int t = 0; t < 12 && placed < want; t++) {
      int c = floor(random(3));
      if (!barCovers(mid, c) || side[c] != 0) continue;
      int s = random(1) < 0.5 ? -1 : 1;
      if (c != 1 && side[2 - c] == s) continue;       // no cup, no gate
      side[c] = s;
      placed++;
      g.rect(colX[c], s < 0 ? 0 : 86, BOLD, 86);
    }
    if (placed == 0) return null;
    g.sig = "a" + mid + "," + side[0] + side[1] + side[2];
    int extras = 0, outerRow = -1;
    if (random(1) < 0.75) {                    // a floating outer bar
      int row = random(1) < 0.5 ? 0 : 2;
      int s = (row == 0) ? -1 : 1;
      int span = floor(random(4));
      boolean clash = false;
      for (int c = 0; c < 3; c++) if (side[c] == s && barCovers(span, c)) clash = true;
      if (!clash) {
        addBar(g, row, span);
        g.sig += "o" + row + span;
        outerRow = row;
        extras++;
      }
    }
    if (extras == 0 || random(1) < 0.3) {      // a block in a free corner
      int c = random(1) < 0.5 ? 0 : 2;
      int row = random(1) < 0.5 ? 0 : 2;
      int s = (row == 0) ? -1 : 1;
      if (side[c] != s && outerRow != row) {
        g.rect(colX[c], row == 0 ? 0 : 129, BOLD, BOLD);
        g.sig += "k" + c + row;
        extras++;
      }
    }
    return extras > 0 ? g : null;
  }

  if (roll < 0.56) {
    // --- one diagonal, with pieces in the corners it leaves free ---
    int dir = floor(random(2));                // 0 falls to the right, 1 to the left
    int span = floor(random(3));               // 0 full, 1 upper half, 2 lower half
    float xm = (w - 48) / 2;
    float[] q;
    if (span == 0) q = new float[] { 0, 0, 48, 0, w, CAP, w - 48, CAP };
    else if (span == 1) q = new float[] { 0, 0, 48, 0, xm + 48, 86, xm, 86 };
    else q = new float[] { xm, 86, xm + 48, 86, w, CAP, w - 48, CAP };
    if (dir == 1) for (int i = 0; i < 8; i += 2) q[i] = w - q[i];
    g.quad(q[0], q[1], q[2], q[3], q[4], q[5], q[6], q[7]);
    g.sig = "b" + dir + span;
    if (span == 0) {
      int ka = floor(random(3)), kb = floor(random(3));   // 0 block, 1 stem, 2 bar
      if (ka == kb && ka != 0) return null;                // two stems would spell N, two bars Z
      float[] wa = { BOLD, BOLD, 70 }, ha = { BOLD, 76, BAR };
      float ax = w - wa[ka], bx = 0;                       // top far corner, bottom near corner
      if (dir == 1) { ax = 0; bx = w - wa[kb]; }
      g.rect(ax, 0, wa[ka], ha[ka]);
      g.rect(bx, CAP - ha[kb], wa[kb], ha[kb]);
      g.sig += "," + ka + kb;
    } else {
      int row = (span == 1) ? 2 : 0;                       // bar on the side the diagonal leaves empty
      int bs = floor(random(4));
      addBar(g, row, bs);
      g.sig += "," + bs;
      if (random(1) < 0.5) {
        float bx = ((span == 1) == (dir == 0)) ? w - BOLD : 0;
        g.rect(bx, span == 1 ? 0 : 129, BOLD, BOLD);
        g.sig += "k";
      }
    }
    return g;
  }

  if (roll < 0.9) {
    // --- bowls cut in half and set against the edges of the slot ---
    int n = random(1) < 0.45 ? 2 : 1;
    int[] o = new int[2];
    boolean[] big = new boolean[2];
    for (int i = 0; i < n; i++) {
      o[i] = floor(random(4));                 // 0 left edge, 1 right edge, 2 top, 3 bottom
      big[i] = random(1) < 0.6;
      if (o[i] >= 2 && w < 150) big[i] = false;
    }
    if (n == 2) {
      if (o[0] == o[1] && big[0] == big[1]) return null;
      if (big[0] && big[1] && o[0] + o[1] == 1 && w < 180) big[1] = false;
      if (o[0] == o[1] && big[0] == big[1]) return null;
    }
    for (int i = 0; i < n; i++) {
      float d = big[i] ? 131 : 58;
      if (o[i] == 0) g.arc(0, 86, d, d, -HALF_PI, HALF_PI);
      else if (o[i] == 1) g.arc(w, 86, d, d, HALF_PI, 3 * HALF_PI);
      else if (o[i] == 2) g.arc(w / 2, 0, d, d, 0, PI);
      else g.arc(w / 2, CAP, d, d, PI, TWO_PI);
      g.sig += "c" + o[i] + (big[i] ? "B" : "s");
    }
    int opposite = o[0] ^ 1;
    boolean farFree = (n == 1) || (o[1] != opposite);
    if (n == 1 && !farFree) return null;
    if (farFree && (n == 1 || random(1) < 0.4)) {          // something on the far side
      if (random(1) < 0.4) {
        if (o[0] == 0) g.rect(w - BOLD, 64.5, BOLD, BOLD);
        else if (o[0] == 1) g.rect(0, 64.5, BOLD, BOLD);
        else if (o[0] == 2) g.rect(xC, 129, BOLD, BOLD);
        else g.rect(xC, 0, BOLD, BOLD);
        g.sig += "k";
      } else if (o[0] < 2) {
        int top = floor(random(2));
        g.rect(o[0] == 0 ? w - BOLD : 0, top == 1 ? 0 : 86, BOLD, 86);
        g.sig += "v" + top;
      } else {
        int bs = floor(random(4));
        addBar(g, o[0] == 2 ? 2 : 0, bs);
        g.sig += "h" + bs;
      }
    }
    return g;
  }

  // --- three bars that refuse to line up ---
  int s0 = floor(random(4)), s1 = floor(random(4)), s2 = floor(random(4));
  if (s0 == s1 || s1 == s2) return null;
  addBar(g, 0, s0);
  addBar(g, 1, s1);
  addBar(g, 2, s2);
  g.sig = "d" + s0 + s1 + s2;
  return g;
}

// ---------------------------------------------------------------------
//  Monoline forms: arcs and straight strokes of one weight, flat ends.
// ---------------------------------------------------------------------

Glyph genMono(float w) {
  Glyph g = new Glyph(w, true);
  float cx = w / 2, cy = CAP / 2;
  float roll = random(1);

  if (roll < 0.22) {
    // --- arcs widening from an edge or a corner ---
    int c = floor(random(8));
    int sub = floor(random(4));
    boolean[] use = { sub != 1, sub != 2, sub != 0 };
    for (int k = 1; k <= 3; k++) {
      if (!use[k - 1]) continue;
      if (c < 2) {
        float r = min(50 * k, (w - 25) * k / 3);
        float a = (r <= 70) ? radians(72) : asin(70 / r);
        if (c == 0) g.arc(9, cy, 2 * r, 2 * r, -a, a);
        else g.arc(w - 9, cy, 2 * r, 2 * r, PI - a, PI + a);
      } else if (c < 4) {
        float r = 49 * k;
        float lim = w / 2 - 16;
        float a = (r <= lim) ? radians(72) : asin(lim / r);
        if (c == 2) g.arc(cx, 9, 2 * r, 2 * r, HALF_PI - a, HALF_PI + a);
        else g.arc(cx, CAP - 9, 2 * r, 2 * r, 3 * HALF_PI - a, 3 * HALF_PI + a);
      } else {
        float r = k * (min(w, CAP) - 32) / 3;
        if (c == 4) g.arc(16, 16, 2 * r, 2 * r, 0, HALF_PI);
        else if (c == 5) g.arc(w - 16, 16, 2 * r, 2 * r, HALF_PI, PI);
        else if (c == 6) g.arc(w - 16, CAP - 16, 2 * r, 2 * r, PI, 3 * HALF_PI);
        else g.arc(16, CAP - 16, 2 * r, 2 * r, 3 * HALF_PI, TWO_PI);
      }
    }
    g.sig = "m1," + c + sub;
    return g;
  }

  if (roll < 0.5) {
    // --- a ring in quarters, some of them turned inside out ---
    int[] st = new int[4];                     // 0 absent, 1 inside out, 2 as in a ring
    int present = 0, inside = 0, ringlike = 0;
    for (int q = 0; q < 4; q++) {
      st[q] = floor(random(3));
      if (st[q] > 0) present++;
      if (st[q] == 1) inside++;
      if (st[q] == 2) ringlike++;
    }
    if (present < 2 || inside < 1 || ringlike > 2) return null;
    float[] ccx = { 10, w - 10, w - 10, 10 }, ccy = { 6, 6, CAP - 6, CAP - 6 };
    float[] cs = { 0, HALF_PI, PI, 3 * HALF_PI };          // inside out: centred on the corner
    float[] rs = { PI, 3 * HALF_PI, 0, HALF_PI };          // ring-like: centred on the slot
    for (int q = 0; q < 4; q++) {
      if (st[q] == 1) g.arc(ccx[q], ccy[q], w - 20, 160, cs[q], cs[q] + HALF_PI);
      if (st[q] == 2) g.arc(cx, cy, w - 32, 140, rs[q], rs[q] + HALF_PI);
    }
    g.sig = "m2," + st[0] + st[1] + st[2] + st[3];
    return g;
  }

  if (roll < 0.65) {
    // --- a cup and a stroke that does not close it, in four positions ---
    int k = floor(random(4)), v = floor(random(3));
    g.arc(cx, cy, 121, 121, k * HALF_PI, k * HALF_PI + PI);
    float[][] seg;
    if (v == 0) seg = new float[][] { { -60.5, -34, -60.5, 0 }, { 60.5, -34, 60.5, 0 }, { -76, -70, 76, -70 } };
    else if (v == 1) seg = new float[][] { { -60.5, -34, -60.5, 0 }, { 60.5, -34, 60.5, 0 }, { -26, -34, 26, -34 } };
    else seg = new float[][] { { -60.5, -34, -60.5, 0 }, { 60.5, -34, 60.5, 0 }, { -76, -70, -30, -70 }, { 30, -70, 76, -70 } };
    float dy = (k % 2 == 0) ? (k == 0 ? 9.5 : -9.5) : 0;   // keep it inside the cap height
    float dx = (k % 2 == 1) ? (k == 1 ? -9.5 : 9.5) : 0;
    float[] last = g.prims.get(g.prims.size() - 1);
    last[1] += dx;
    last[2] += dy;
    for (float[] s : seg) {
      float[] p = { s[0], s[1], s[2], s[3] };
      for (int t = 0; t < k; t++)
        for (int i = 0; i < 4; i += 2) { float px = p[i]; p[i] = -p[i + 1]; p[i + 1] = px; }
      g.line(cx + dx + p[0], cy + dy + p[1], cx + dx + p[2], cy + dy + p[3]);
    }
    g.sig = "m3," + k + v;
    return g;
  }

  if (roll < 0.85) {
    // --- slanted strokes in step, each cut to its own length ---
    int dir = floor(random(2)), n = 2 + floor(random(2));
    float lean = 46;
    float[][] cut = { { 0, CAP }, { 0, 100 }, { 72, CAP }, { 40, 132 } };
    g.sig = "m4," + dir + n;
    int full = 0;
    for (int i = 0; i < n; i++) {
      int p = floor(random(4));
      if (p == 0) full++;
      float bx = 16 + i * (w - 32 - lean) / (n - 1);
      float y0 = cut[p][0], y1 = cut[p][1];
      float xa = bx + lean * y0 / CAP, xb = bx + lean * y1 / CAP;
      if (dir == 1) { xa = w - xa; xb = w - xb; }
      g.line(xa, y0, xb, y1);
      g.sig += p;
    }
    return full == n ? null : g;
  }

  // --- a small ring with a larger arc keeping its distance ---
  int k = floor(random(4)), v = floor(random(3));
  g.arc(cx, cy, 58, 58, 0, TWO_PI);
  if (v == 0) g.arc(cx, cy, 140, 140, k * HALF_PI, k * HALF_PI + PI);
  else if (v == 1) g.arc(cx, cy, 140, 140, k * HALF_PI + 0.3, k * HALF_PI + HALF_PI - 0.3);
  else {
    if (k > 1) return null;
    g.arc(cx, cy, 140, 140, k * HALF_PI, k * HALF_PI + HALF_PI);
    g.arc(cx, cy, 140, 140, k * HALF_PI + PI, k * HALF_PI + 3 * HALF_PI);
  }
  g.sig = "m5," + k + v;
  return g;
}

// =====================================================================
//  THREAD — where it goes
// =====================================================================

int pickNext(ArrayList<PVector> todo, PVector c) {
  int[] best = { -1, -1, -1 };
  for (int k = 0; k < 3; k++) {
    float bd = 99999999;
    for (int i = 0; i < todo.size(); i++) {
      if (i == best[0] || i == best[1]) continue;
      float d = dist(c.x, c.y, todo.get(i).x, todo.get(i).y);
      if (d < bd) { bd = d; best[k] = i; }
    }
  }
  float roll = random(1);
  int k = (roll < 0.62) ? 0 : (roll < 0.9) ? 1 : 2;
  while (best[k] < 0) k--;
  return best[k];
}

void buildPath() {
  ArrayList<PVector> todo = new ArrayList<PVector>(anchors);
  ArrayList<PVector> cp = new ArrayList<PVector>();   // z = 1 while looping
  PVector cur = new PVector(-110, random(300, 900));
  cp.add(new PVector(cur.x - 80, cur.y - 50, 0));
  cp.add(cur.copy());

  while (todo.size() > 0) {
    PVector a = todo.remove(pickNext(todo, cur));
    addHop(cp, cur, a);

    // the loop of wanting: circle the thing, tightening as it goes,
    // and come to rest on it. Small print gets a small loop.
    float a0 = atan2(cur.y - a.y, cur.x - a.x);
    float dir = random(1) < 0.5 ? 1 : -1;
    float turns = random(0.9, 2.1);
    float r0 = random(20, 54) * a.z;
    int steps = ceil(turns * 8);
    for (int k = 0; k <= steps; k++) {
      float u = k / (float) steps;
      float ang = a0 + dir * TWO_PI * turns * u;
      float m = (1 - 0.4 * u) * (1 + random(-0.14, 0.14));
      cp.add(new PVector(a.x + r0 * m * cos(ang), a.y + r0 * 0.85 * m * sin(ang), 1));
    }
    cp.add(new PVector(a.x, a.y, 1));              // the thread lands on the form
    cur = cp.get(cp.size() - 1).copy();
    cur.z = 0;
  }

  // the way out: the nearest edge of the frame
  float dl = cur.x, dr = GRID_W - cur.x, dt = cur.y, db = GRID_H - cur.y;
  float m = min(min(dl, dr), min(dt, db));
  PVector out = cur.copy();
  if (m == dl) out.x = -130;
  else if (m == dr) out.x = GRID_W + 130;
  else if (m == dt) out.y = -130;
  else out.y = GRID_H + 130;
  addHop(cp, cur, out);
  cp.add(out);
  cp.add(new PVector(out.x + (out.x - cur.x) * 0.2, out.y + (out.y - cur.y) * 0.2, 0));

  // Catmull-Rom through the control points, sampled every STEP units
  FloatList xs = new FloatList();
  FloatList ys = new FloatList();
  FloatList cs = new FloatList();
  for (int i = 1; i < cp.size() - 2; i++) {
    PVector p0 = cp.get(i - 1), p1 = cp.get(i), p2 = cp.get(i + 1), p3 = cp.get(i + 2);
    int n = max(2, ceil(dist(p1.x, p1.y, p2.x, p2.y) * 1.15 / STEP));
    float c = (p1.z > 0 && p2.z > 0) ? 2.2 : 1;   // it lingers while it loops
    for (int k = 0; k < n; k++) {
      float t = k / (float) n;
      xs.append(curvePoint(p0.x, p1.x, p2.x, p3.x, t));
      ys.append(curvePoint(p0.y, p1.y, p2.y, p3.y, t));
      cs.append(c);
    }
  }

  nPts = xs.size();
  tx = new float[nPts];
  ty = new float[nPts];
  cost = new float[nPts];
  fuzzLen = new float[nPts];
  fuzzAng = new float[nPts];
  float acc = 0;
  for (int i = 0; i < nPts; i++) {
    // a soft thread never lies perfectly straight
    tx[i] = xs.get(i) + (noise(i * 0.012, 3.1) - 0.5) * 10;
    ty[i] = ys.get(i) + (noise(i * 0.012, 9.7) - 0.5) * 10;
    acc += cs.get(i);
    cost[i] = acc;
    fuzzLen[i] = random(1) < 0.32 ? random(4, 15) * (random(1) < 0.5 ? 1 : -1) : 0;
    fuzzAng[i] = random(-0.9, 0.9);
  }
}

// slack between two points: a few wandering control points across the hop
void addHop(ArrayList<PVector> cp, PVector from, PVector to) {
  float d = dist(from.x, from.y, to.x, to.y);
  if (d < 1) return;
  int nMid = floor(d / 240);
  float nx = -(to.y - from.y) / d, ny = (to.x - from.x) / d;
  for (int j = 1; j <= nMid; j++) {
    float t = j / (nMid + 1.0);
    float off = randomGaussian() * min(d * 0.14, 60);
    cp.add(new PVector(lerp(from.x, to.x, t) + nx * off, lerp(from.y, to.y, t) + ny * off, 0));
  }
}

int sampleAtCost(float c) {
  int i = shown;
  while (i < nPts - 1 && cost[i] < c) i++;
  return i;
}

// =====================================================================
//  THREAD — what it looks like
// =====================================================================

void poly(PGraphics g, int a, int b, float ox, float oy) {
  g.beginShape();
  for (int i = a; i <= b; i++) g.vertex(tx[i] + ox, ty[i] + oy);
  g.endShape();
}

// Lays down samples a..b in short stitches, so that where the thread
// crosses itself the later pass sits on top and drops its shadow on the
// earlier one.
void drawThread(PGraphics g, int a, int b) {
  g.pushMatrix();
  g.scale(g.width / GRID_W);
  g.noFill();
  g.strokeJoin(ROUND);
  for (int s = a; s < b; s += CHUNK) {
    int e = min(b, s + CHUNK);
    int s0 = max(0, s - OVERLAP);

    // shadow
    g.strokeCap(SQUARE);
    g.stroke(30, 0, 0, 24);
    g.strokeWeight(TW * 1.8);
    poly(g, s, e, TW * 0.30, TW * 0.44);
    g.stroke(30, 0, 0, 38);
    g.strokeWeight(TW * 1.2);
    poly(g, s, e, TW * 0.22, TW * 0.32);

    // fibres that escape the twist
    g.strokeCap(ROUND);
    g.stroke(COTTON_FUZZ, 210);
    g.strokeWeight(0.8);
    for (int i = max(1, s0); i < e && i < nPts - 1; i++) {
      if (fuzzLen[i] == 0) continue;
      float ta = atan2(ty[i + 1] - ty[i - 1], tx[i + 1] - tx[i - 1]);
      float side = fuzzLen[i] > 0 ? 1 : -1;
      float na = ta + side * (HALF_PI + fuzzAng[i]);
      float bx = tx[i] + cos(ta + side * HALF_PI) * TW * 0.35;
      float by = ty[i] + sin(ta + side * HALF_PI) * TW * 0.35;
      float len = abs(fuzzLen[i]);
      g.bezier(bx, by,
               bx + cos(na) * len * 0.5, by + sin(na) * len * 0.5,
               bx + cos(na + 0.6) * len * 0.8, by + sin(na + 0.6) * len * 0.8,
               bx + cos(na + 0.9) * len, by + sin(na + 0.9) * len);
    }

    // body
    g.stroke(COTTON_EDGE);
    g.strokeWeight(TW);
    poly(g, s0, e, 0, 0);
    g.stroke(COTTON_BODY);
    g.strokeWeight(TW * 0.78);
    poly(g, s0, e, 0, 0);
    g.stroke(COTTON_LIGHT, 200);
    g.strokeWeight(TW * 0.26);
    poly(g, s0, e, -TW * 0.15, -TW * 0.17);

    // the twist of the ply
    g.stroke(COTTON_TWIST, 130);
    g.strokeWeight(0.9);
    g.strokeCap(SQUARE);
    for (int i = max(1, s0); i < e && i < nPts - 1; i++) {
      if (i % 2 != 0) continue;
      float ta = atan2(ty[i + 1] - ty[i - 1], tx[i + 1] - tx[i - 1]) + 0.95;
      float h = TW * 0.36;
      g.line(tx[i] - cos(ta) * h, ty[i] - sin(ta) * h, tx[i] + cos(ta) * h, ty[i] + sin(ta) * h);
    }
  }
  g.popMatrix();
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
//  CONTOUR STRANDS, FLORA, FAUNA
// =====================================================================

class Flora {
  int k, kind, petals;         // kind: 0 leaf, 1 bud, 2 flower, 3 fern tip
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

class Creature {
  int kind, k;                 // kind: 0 butterfly, 1 ladybird, 2 snail
  Strand th;
  float size, a, phase;
  float[] col, col2;
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
  randomSeed(SEED + 7);
  place(0, BUTTERFLIES, BUTTERFLY_MIN, BUTTERFLY_MAX);
  place(1, LADYBIRDS, LADYBIRD_MIN, LADYBIRD_MAX);
  place(2, SNAILS, SNAIL_MIN, SNAIL_MAX);
}

void place(int kind, int n, float smin, float smax) {
  for (int i = 0; i < n; i++) {
    Creature c = new Creature();
    c.kind = kind;
    c.th = strands.get(floor(random(strands.size())));
    c.k = floor(random(c.th.pts.length * 0.3, c.th.pts.length));
    c.size = random(smin, smax);
    c.a = c.th.ang[c.k] + random(-0.6, 0.6);
    c.col = rgba(pick(BUTTERFLY_COLORS), 235);
    c.col2 = rgba(pick(BUTTERFLY_COLORS), 235);
    c.phase = random(TWO_PI);
    creatures.add(c);
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

  // plant forms along the way
  for (int k = 6; k < m - 2; k++) {
    float side = random(1) < 0.5 ? -1 : 1;
    if (random(1) < LEAF_CHANCE) {
      Flora f = new Flora(); f.k = k; f.kind = 0; f.a = th.ang[k] + side * random(0.5, 1.1);
      f.size = random(LEAF_MIN, LEAF_MAX); f.col = rgba(pick(LEAF_COLORS), 225); th.flora.add(f);
    } else if (random(1) < BUD_CHANCE) {
      Flora f = new Flora(); f.k = k; f.kind = 1; f.a = th.ang[k] + side * random(0.6, 1.2);
      f.size = random(4, 8); f.col = rgba(pick(FLOWER_COLORS), 235); f.col2 = rgba(pick(LEAF_COLORS), 235); th.flora.add(f);
    } else if (random(1) < FLOWER_CHANCE) {
      Flora f = new Flora(); f.k = k; f.kind = 2; f.a = random(TWO_PI); f.size = random(FLOWER_MIN, FLOWER_MAX);
      f.col = rgba(pick(FLOWER_COLORS), 240); f.col2 = rgba(pick(FLOWER_COLORS), 255); f.petals = floor(random(5, 8)); th.flora.add(f);
    }
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
  drawCreatures(g, frame, true);
}

void drawFlora(PGraphics g, Strand th, Flora f, float grow) {
  float x = th.pts[f.k][0], y = th.pts[f.k][1], s = f.size * grow;
  g.pushMatrix();
  g.translate(x, y);
  g.rotate(f.a);
  if (f.kind == 0) {
    g.noStroke();
    g.fill(f.col[0], f.col[1], f.col[2], f.col[3]);
    g.beginShape();
    g.vertex(0, 0);
    g.bezierVertex(s * 0.3, -s * 0.42, s * 0.8, -s * 0.34, s, 0);
    g.bezierVertex(s * 0.8, s * 0.34, s * 0.3, s * 0.42, 0, 0);
    g.endShape(CLOSE);
    g.stroke(f.col[0] * 0.6, f.col[1] * 0.6, f.col[2] * 0.6, 150);
    g.strokeWeight(0.6);
    g.line(0, 0, s * 0.85, 0);
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
    g.noStroke();
    g.fill(f.col[0], f.col[1], f.col[2], f.col[3]);
    for (int i = 0; i < f.petals; i++) {
      float u = i * TWO_PI / f.petals;
      g.ellipse(cos(u) * s * 0.34, sin(u) * s * 0.34, s * 0.5, s * 0.5);
    }
    g.fill(f.col2[0], f.col2[1], f.col2[2], f.col2[3]);
    g.ellipse(0, 0, s * 0.32, s * 0.32);
  } else {
    // a small spiral continuing the strand's direction
    g.noFill();
    g.stroke(f.col[0], f.col[1], f.col[2], f.col[3]);
    g.strokeWeight(max(0.5, widthAt(th, f.k) * 0.8 + 0.4));
    g.beginShape();
    float turns = 1.6 * grow;
    for (float u = 0; u <= turns * TWO_PI; u += 0.2) {
      float r = s * (1 - u / (TWO_PI * 2.2));
      g.vertex(sin(u) * r, -(1 - cos(u)) * r);
    }
    g.endShape();
  }
  g.popMatrix();
}

void drawCreatures(PGraphics g, float frame, boolean live) {
  for (Creature c : creatures) {
    if (frame < reachedAt(c.th, c.k) + BLOOM_FRAMES) continue;
    float s = c.size;
    g.pushMatrix();
    g.translate(c.th.pts[c.k][0], c.th.pts[c.k][1]);
    g.rotate(c.a);
    if (c.kind == 0) {
      float beat = live ? 0.35 + 0.65 * abs(sin(frame * FLUTTER + c.phase)) : 1;
      g.noStroke();
      for (int side = -1; side <= 1; side += 2) {
        g.fill(c.col[0], c.col[1], c.col[2], c.col[3]);
        g.ellipse(-s * 0.15, side * s * 0.42 * beat, s * 0.75, s * 0.8 * beat);
        g.fill(c.col2[0], c.col2[1], c.col2[2], c.col2[3]);
        g.ellipse(s * 0.32, side * s * 0.3 * beat, s * 0.5, s * 0.55 * beat);
      }
      g.stroke(10);
      g.strokeWeight(max(0.8, s * 0.09));
      g.line(-s * 0.45, 0, s * 0.45, 0);
      g.strokeWeight(0.6);
      g.line(s * 0.45, 0, s * 0.75, -s * 0.22);
      g.line(s * 0.45, 0, s * 0.75, s * 0.22);
    } else if (c.kind == 1) {
      g.noStroke();
      g.fill(10);
      g.ellipse(s * 0.55, 0, s * 0.6, s * 0.6);
      g.fill(255, 214, 0);
      g.ellipse(0, 0, s * 1.3, s * 1.1);
      g.stroke(10);
      g.strokeWeight(max(0.4, s * 0.08));
      g.line(-s * 0.65, 0, s * 0.62, 0);
      g.noStroke();
      g.fill(10);
      float[][] dots = { { -0.25, -0.28 }, { -0.25, 0.28 }, { 0.18, -0.24 }, { 0.18, 0.24 } };
      for (float[] d : dots) g.ellipse(d[0] * s, d[1] * s, s * 0.22, s * 0.22);
    } else {
      // snail: soft body with feelers, shell drawn as a spiral
      g.noStroke();
      g.fill(196, 172, 150, 240);
      g.ellipse(s * 0.2, s * 0.35, s * 2.0, s * 0.45);
      g.stroke(120, 100, 90);
      g.strokeWeight(0.6);
      g.line(s * 1.1, s * 0.25, s * 1.35, -s * 0.15);
      g.line(s * 1.0, s * 0.25, s * 1.15, -s * 0.2);
      g.noStroke();
      g.fill(c.col[0], c.col[1], c.col[2], 255);
      g.ellipse(0, -s * 0.15, s * 1.2, s * 1.2);
      g.noFill();
      g.stroke(20);
      g.strokeWeight(max(0.6, s * 0.08));
      g.beginShape();
      for (float u = 0; u < TWO_PI * 2.2; u += 0.25) {
        float r = s * 0.55 * (1 - u / (TWO_PI * 2.4));
        g.vertex(cos(u) * r, -s * 0.15 + sin(u) * r);
      }
      g.endShape();
    }
    g.popMatrix();
  }
}

// =====================================================================
//  EXPORT
// =====================================================================

void saveHiRes() {
  PGraphics big = compose(HIRES_SCALE);
  big.beginDraw();
  big.pushMatrix();
  big.scale(HIRES_SCALE);
  drawStrandsAt(big, GROW_FRAMES + HOLD_FRAMES);
  big.popMatrix();
  drawThread(big, 0, nPts - 1);
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
