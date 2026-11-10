/**
 * NO FORM TWICE — contour threads
 * ------------------------------------------------------------------
 * Processing 4 (Java mode). A second version of woven_figure_thread.
 * The drawing and the blue forms are exactly as in that sketch. Only
 * the thread behaves differently.
 *
 * There the thread was one strand hopping from form to form. Here
 * there are many strands, and each one traces: it starts on the
 * outline of a blue form, lifts off it to a small distance, follows
 * the outline part of the way round, then peels away into a slow
 * current and ends in a curl. Only the blue forms are traced; the
 * drawing's own lines are not.
 *
 * Layers:
 *  1. data/background.png — the drawing.
 *  2. The type grid: two "words" per row, a heavy one of five forms
 *     and a monoline one of four, swapping sides on every row, with a
 *     line of small print. No form is used twice. Each is filled blue
 *     on plain paper and drawn as a light blue outline where it
 *     crosses the drawing or lies inside the figure.
 *  3. Bright red cotton strands tracing the contours of those forms.
 *
 * Format: 1080 x 1920 (9:16), 30 fps — Instagram Reel.
 *
 * Outputs (written next to this sketch):
 *   output/woven_figure_trace_3240x5760.png     high-res still
 *   frames/reel-####.png                       one PNG per frame
 *   output/woven_figure_trace_reel.mp4         via ffmpeg if on PATH
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
final int     GROW_FRAMES  = 900;   // 30 s for every strand to finish
final int     HOLD_FRAMES  = 90;
final boolean RECORD       = true;
final int     SEED         = 2026;

// ---------- the forms: bright blue ----------
final float FORM_R = 10, FORM_G = 60, FORM_B = 255;
final float LINE_R = 112, LINE_G = 160, LINE_B = 255;  // the outline: light blue

final float GAP_CLOSE    = 13;     // px: breaks in the drawing's line narrower than twice this count as closed
final float BODY_TOP     = 556;    // px from the top: above this line is the cloud; nothing there counts as body
final float OUTLINE      = 5.5;    // weight of the blue outline (grid units; about 3 px in the reel)
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
final float TW      = 4.2;      // strand thickness
final int   CHUNK   = 12;
final int   OVERLAP = 10;
final int   COTTON_EDGE  = 0xFFA30F12;
final int   COTTON_BODY  = 0xFFEA1C24;
final int   COTTON_LIGHT = 0xFFFF6A5E;
final int   COTTON_TWIST = 0xFF7E0A0E;
final int   COTTON_FUZZ  = 0xFFE8323A;

// ---------- contours (grid units) ----------
final float CONTOUR_SPACING    = 4;    // distance between points along an outline
final float CONTOUR_MIN_LENGTH = 60;   // shorter outlines are ignored

// ---------- tracing ----------
// Each strand starts on an outline, lifts off it to a small distance,
// follows it part of the way round, then peels away and curls.
final int   THREAD_COUNT = 330;        // every outline gets one strand; any left over go to the longer outlines
final float OFFSET_MIN = 4, OFFSET_MAX = 13;   // distance kept from the outline
final float WOBBLE = 3;                // how much that distance breathes
final float LIFT = 24;                 // points over which a strand rises off the outline
final float WRAP_MIN = 0.35, WRAP_MAX = 0.95;  // share of the outline it travels round
final int   MAX_WRAP = 900;
final int   PEEL_MIN = 14, PEEL_MAX = 64;      // steps after leaving the outline
final float STEP_LEN = 3.6, FLOW_SCALE = 0.0035, FLOW_TURN = 0.16, CURL = 0.34;
final int   SMOOTH = 3;
final float STAGGER = 0.65;            // strands start somewhere in the first 65% of the growth

PImage bg;
float[] outside;                                  // 1 = paper outside the figure, 0 = inside it
ArrayList<Word> words = new ArrayList<Word>();
HashSet<String> used = new HashSet<String>();     // every form's signature
ArrayList<PVector> anchors = new ArrayList<PVector>();
ArrayList<Ring> rings = new ArrayList<Ring>();
ArrayList<Strand> strands = new ArrayList<Strand>();
PGraphics poster, threadLayer;

public void settings() {
  size(OUT_W, OUT_H);
  pixelDensity(1);
}

public void setup() {
  frameRate(FPS);
  randomSeed(SEED);
  noiseSeed(SEED);

  bg = loadImage("background.png");
  if (bg.width != OUT_W || bg.height != OUT_H) bg.resize(OUT_W, OUT_H);
  studyBackground();

  setWords();
  traceForms();
  buildThreads();

  poster = compose(1);

  threadLayer = createGraphics(width, height);
  threadLayer.beginDraw();
  threadLayer.clear();
  threadLayer.endDraw();
}

public void draw() {
  int f = frameCount - 1;
  threadLayer.beginDraw();
  for (Strand st : strands) {
    int target = revealAt(st, f - INTRO_FRAMES);
    if (target > st.drawn) {
      drawStrand(threadLayer, st, st.drawn, target);
      st.drawn = target;
    }
  }
  threadLayer.endDraw();
  image(poster, 0, 0);
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

// Finds the paper that lies outside the figure.
void studyBackground() {
  bg.loadPixels();
  int w = bg.width, h = bg.height, n = w * h;
  float[] inkDist = new float[n];              // distance to the nearest line or colour
  for (int i = 0; i < n; i++) {
    int c = bg.pixels[i];
    float a = ((c >>> 24) & 255) / 255.0;
    float m = min((c >> 16) & 255, (c >> 8) & 255, c & 255);
    m = 255 + (m - 255) * a;                   // transparent counts as paper
    inkDist[i] = (255 - m) > 64 ? 0 : 99999;
  }
  chamfer(inkDist, w, h);

  // flood the paper from the frame edge, keeping GAP_CLOSE away from all
  // ink so that the flood cannot slip through small breaks in a line
  boolean[] reached = new boolean[n];
  int[] stack = new int[n];
  int top = 0;
  for (int x = 0; x < w; x++) { stack[top++] = x; stack[top++] = (h - 1) * w + x; }
  for (int y = 0; y < h; y++) { stack[top++] = y * w; stack[top++] = y * w + w - 1; }
  while (top > 0) {
    int i = stack[--top];
    if (reached[i] || inkDist[i] < GAP_CLOSE) continue;
    reached[i] = true;
    int x = i % w;
    if (x > 0) stack[top++] = i - 1;
    if (x < w - 1) stack[top++] = i + 1;
    if (i >= w) stack[top++] = i - w;
    if (i < n - w) stack[top++] = i + w;
    if (top > n - 8) top = n - 8;              // never overruns: each pixel is accepted once
  }

  // grow the flooded area back out to the line itself
  float[] d = new float[n];
  for (int i = 0; i < n; i++) d[i] = reached[i] ? 0 : 99999;
  chamfer(d, w, h);
  outside = new float[n];
  for (int i = 0; i < n; i++) outside[i] = d[i] < GAP_CLOSE + 1.5 ? 1 : 0;

  // everything above the top of the head is the cloud, not the body:
  // there the forms may be filled wherever the paper is plain
  for (int i = 0; i < n; i++) if (i / w < BODY_TOP) outside[i] = 1;
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
//  CONTOURS — the outlines of the blue forms, as rings of points
// =====================================================================

class Ring {
  float[][] pts, nrm;      // even points round the outline; normal pointing away from the form
  float scale;             // 1 for the big forms, smaller for the small print
  float weight;
}

// Walks the outline of every form and stores each closed ring.
void traceForms() {
  int forms = 0, traced = 0;
  for (Word wd : words) {
    float[] sx = wd.mono ? MONO_X : BOLD_X;
    for (int i = 0; i < wd.glyphs.length; i++) {
      java.awt.geom.Area a = wd.glyphs[i].shape();
      float ox = wd.x + sx[i] * wd.s, oy = wd.y;
      java.awt.geom.PathIterator it = new java.awt.geom.FlatteningPathIterator(a.getPathIterator(null), 0.5);
      float[] c = new float[6];
      ArrayList<float[]> cur = new ArrayList<float[]>();
      boolean any = false;
      while (!it.isDone()) {
        int type = it.currentSegment(c);
        if (type == java.awt.geom.PathIterator.SEG_MOVETO) cur = new ArrayList<float[]>();
        if (type != java.awt.geom.PathIterator.SEG_CLOSE) cur.add(new float[] { ox + c[0] * wd.s, oy + c[1] * wd.s });
        else {
          Ring r = resample(cur, a, ox, oy, wd.s);
          if (r != null) { rings.add(r); any = true; }
        }
        it.next();
      }
      forms++;
      if (any) traced++;
    }
  }
  println("outlines traced on " + traced + " of " + forms + " forms (" + rings.size() + " rings)");
}

// even points round a closed ring, each with the normal that points away
// from the form (tested against the form itself, so holes work too)
Ring resample(ArrayList<float[]> ring, java.awt.geom.Area a, float ox, float oy, float s) {
  ArrayList<float[]> out = new ArrayList<float[]>();
  float carry = 0;
  float spacing = CONTOUR_SPACING * max(s, 0.5);
  for (int i = 0; i < ring.size(); i++) {
    float[] p = ring.get(i), q = ring.get((i + 1) % ring.size());
    float len = dist(p[0], p[1], q[0], q[1]);
    float d = carry;
    while (d < len) {
      float u = d / len;
      out.add(new float[] { p[0] + (q[0] - p[0]) * u, p[1] + (q[1] - p[1]) * u });
      d += spacing;
    }
    carry = d - len;
  }
  int n = out.size();
  if (n < 8 || n * spacing < CONTOUR_MIN_LENGTH * s) return null;
  Ring r = new Ring();
  r.scale = (s == 1) ? 1 : 0.3;
  r.pts = out.toArray(new float[n][]);
  r.nrm = new float[n][2];
  int inside = 0;
  for (int k = 0; k < n; k++) {
    float[] p = r.pts[(k - 2 + n) % n], q = r.pts[(k + 2) % n];
    float dx = q[0] - p[0], dy = q[1] - p[1];
    float l = sqrt(dx * dx + dy * dy);
    if (l == 0) l = 1;
    r.nrm[k][0] = dy / l;
    r.nrm[k][1] = -dx / l;
    float tx = r.pts[k][0] + r.nrm[k][0] * 3 * s, ty = r.pts[k][1] + r.nrm[k][1] * 3 * s;
    if (a.contains((tx - ox) / s, (ty - oy) / s)) inside++;
  }
  if (inside > n / 2) for (int k = 0; k < n; k++) { r.nrm[k][0] = -r.nrm[k][0]; r.nrm[k][1] = -r.nrm[k][1]; }
  r.weight = pow(n, 0.8);
  return r;
}

// =====================================================================
//  CONTOUR THREADS — where they go
// =====================================================================

class Strand {
  float[] x, y, fuzzLen, fuzzAng;
  float start, dur;        // frame it starts on, frames it takes
  int drawn;
}

void buildThreads() {
  randomSeed(SEED + 6);
  noiseSeed(SEED + 6);
  float total = 0;
  for (Ring r : rings) total += r.weight;
  for (Ring r : rings) strands.add(makeStrand(r));           // every outline is traced at least once
  while (strands.size() < THREAD_COUNT) {                    // the rest go to the longer outlines
    float pk = random(total);
    Ring ring = rings.get(0);
    for (Ring r : rings) { pk -= r.weight; if (pk < 0) { ring = r; break; } }
    strands.add(makeStrand(ring));
  }
}

Strand makeStrand(Ring ring) {
  int n = ring.pts.length;
  int start = floor(random(n));
  int dir = random(1) < 0.5 ? 1 : -1;
  int steps = min(MAX_WRAP, floor(n * random(WRAP_MIN, WRAP_MAX)));
  float off = random(OFFSET_MIN, OFFSET_MAX) * ring.scale;
  float nz = random(1000);
  ArrayList<float[]> pts = new ArrayList<float[]>();

  // follow the outline at a breathing distance, rising off it at the start
  for (int k = 0; k < steps; k++) {
    int idx = ((start + dir * k) % n + n) % n;
    float lift = min(1, k / LIFT);
    float o = max(1, (off + (noise(k * 0.02, nz) - 0.5) * 2 * WOBBLE * ring.scale) * lift);
    pts.add(new float[] { ring.pts[idx][0] + ring.nrm[idx][0] * o, ring.pts[idx][1] + ring.nrm[idx][1] * o });
  }
  if (pts.size() < 2) { pts.clear(); pts.add(ring.pts[start].clone()); pts.add(ring.pts[(start + 1) % n].clone()); }

  // peel away into the current and end in a tightening curl
  float[] last = pts.get(pts.size() - 1), prev = pts.get(pts.size() - 2);
  float x = last[0], y = last[1], a = atan2(last[1] - prev[1], last[0] - prev[0]);
  int peel = floor(random(PEEL_MIN, PEEL_MAX) * (ring.scale < 1 ? 0.4 : 1));
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
  for (int k = 0; k < m; k++) {
    float sx = 0, sy = 0;
    int c = 0;
    for (int q = max(0, k - SMOOTH); q <= min(m - 1, k + SMOOTH); q++) { sx += pts.get(q)[0]; sy += pts.get(q)[1]; c++; }
    st.x[k] = sx / c;
    st.y[k] = sy / c;
    st.fuzzLen[k] = random(1) < 0.22 ? random(3, 9) * (random(1) < 0.5 ? 1 : -1) : 0;
    st.fuzzAng[k] = random(-0.9, 0.9);
  }
  st.start = random(GROW_FRAMES * STAGGER);
  st.dur = max(30, GROW_FRAMES - st.start);
  return st;
}

// index of the last point a strand has reached on a given growth frame
int revealAt(Strand st, float frame) {
  float u = constrain((frame - st.start) / st.dur, 0, 1);
  return floor(u * (st.x.length - 1));
}

// =====================================================================
//  CONTOUR THREADS — what they look like
// =====================================================================

void poly(PGraphics g, Strand st, int a, int b, float ox, float oy) {
  g.beginShape();
  for (int i = a; i <= b; i++) g.vertex(st.x[i] + ox, st.y[i] + oy);
  g.endShape();
}

// Lays down points a..b of one strand in short stitches, so that where
// strands cross, the later pass sits on top and drops its shadow.
void drawStrand(PGraphics g, Strand st, int a, int b) {
  int n = st.x.length;
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
    poly(g, st, s, e, TW * 0.30, TW * 0.44);
    g.stroke(30, 0, 0, 38);
    g.strokeWeight(TW * 1.2);
    poly(g, st, s, e, TW * 0.22, TW * 0.32);

    // fibres that escape the twist
    g.strokeCap(ROUND);
    g.stroke(COTTON_FUZZ, 210);
    g.strokeWeight(0.7);
    for (int i = max(1, s0); i < e && i < n - 1; i++) {
      if (st.fuzzLen[i] == 0) continue;
      float ta = atan2(st.y[i + 1] - st.y[i - 1], st.x[i + 1] - st.x[i - 1]);
      float side = st.fuzzLen[i] > 0 ? 1 : -1;
      float na = ta + side * (HALF_PI + st.fuzzAng[i]);
      float bx = st.x[i] + cos(ta + side * HALF_PI) * TW * 0.35;
      float by = st.y[i] + sin(ta + side * HALF_PI) * TW * 0.35;
      float len = abs(st.fuzzLen[i]);
      g.bezier(bx, by,
               bx + cos(na) * len * 0.5, by + sin(na) * len * 0.5,
               bx + cos(na + 0.6) * len * 0.8, by + sin(na + 0.6) * len * 0.8,
               bx + cos(na + 0.9) * len, by + sin(na + 0.9) * len);
    }

    // body
    g.stroke(COTTON_EDGE);
    g.strokeWeight(TW);
    poly(g, st, s0, e, 0, 0);
    g.stroke(COTTON_BODY);
    g.strokeWeight(TW * 0.78);
    poly(g, st, s0, e, 0, 0);
    g.stroke(COTTON_LIGHT, 200);
    g.strokeWeight(TW * 0.26);
    poly(g, st, s0, e, -TW * 0.15, -TW * 0.17);

    // the twist of the ply
    g.stroke(COTTON_TWIST, 130);
    g.strokeWeight(0.7);
    g.strokeCap(SQUARE);
    for (int i = max(1, s0); i < e && i < n - 1; i++) {
      if (i % 2 != 0) continue;
      float ta = atan2(st.y[i + 1] - st.y[i - 1], st.x[i + 1] - st.x[i - 1]) + 0.95;
      float h = TW * 0.36;
      g.line(st.x[i] - cos(ta) * h, st.y[i] - sin(ta) * h, st.x[i] + cos(ta) * h, st.y[i] + sin(ta) * h);
    }
  }
  g.popMatrix();
}

// =====================================================================
//  EXPORT
// =====================================================================

void saveHiRes() {
  PGraphics big = compose(HIRES_SCALE);
  big.beginDraw();
  for (Strand st : strands) drawStrand(big, st, 0, st.x.length - 1);
  big.endDraw();
  big.save(sketchPath("output/woven_figure_trace_" + big.width + "x" + big.height + ".png"));
}

void makeMovie() {
  try {
    ProcessBuilder pb = new ProcessBuilder(
      "ffmpeg", "-y", "-framerate", str(FPS),
      "-i", sketchPath("frames/reel-%04d.png"),
      "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "16",
      "-movflags", "+faststart",
      sketchPath("output/woven_figure_trace_reel.mp4"));
    pb.inheritIO();
    pb.start().waitFor();
  }
  catch (Exception e) {
    println("ffmpeg not found - use Tools > Movie Maker on the frames folder (" + FPS + " fps)");
  }
}
