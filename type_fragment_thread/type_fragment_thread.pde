/**
 * TYPE, TAKEN APART — a bright cotton thread in search
 * ------------------------------------------------------------------
 * Processing 4 (Java mode). No image, no font file.
 *
 * Four lowercase letters (w a n t) are constructed the way a geometric
 * typeface is: stems, bowls, arches, a crossbar, a hook, diagonals.
 * They sit for a moment on their metric lines, as in a font editor,
 * with outline points and curve handles showing. Then the parts let go
 * of each other: each one drifts, turns and grows until no letter is
 * left, only the anatomy of type. The guides and the outline points
 * stay, so the origin stays visible.
 *
 * A strand of bright white cotton then enters, finds every fragment,
 * loops it, moves on to the next, and leaves the frame.
 *
 * Format: 1080 x 1920 (9:16), 30 fps — Instagram Reel.
 *
 * Outputs (written next to this sketch):
 *   output/type_fragment_thread_3240x5760.png   high-res still
 *   frames/reel-####.png                        one PNG per frame
 *   output/type_fragment_thread_reel.mp4        via ffmpeg if on PATH
 *
 * No ffmpeg? Use Tools > Movie Maker on the frames folder (30 fps).
 */

// ---------- output settings ----------
final int     W = 1080, H = 1920;
final int     HIRES_SCALE    = 3;
final int     FPS            = 30;
final int     INTRO_FRAMES   = 45;    // letters whole, on their guides
final int     EXPLODE_FRAMES = 90;    // letters come apart
final int     GROW_FRAMES    = 570;   // the thread searches
final int     HOLD_FRAMES    = 75;
final boolean RECORD         = true;
final int     SEED           = 7;

// ---------- colour ----------
final int BG    = 0xFFE5402A;   // vermilion ground
final int DEEP  = 0xFFB92B1B;   // large fragments, tone on tone
final int INK   = 0xFF15110F;   // small fragments
final int CREAM = 0xFFF8E9D6;   // guides, outlines, points

// ---------- letter construction (units; x-height = 500) ----------
final float XH = 500, STEM = 120, RO = 250, RI = 130;
final float ASC = -190, DESC = 690;

// ---------- thread ----------
final float TW      = 7;
final float STEP    = 2.5;
final int   CHUNK   = 12;
final int   OVERLAP = 10;
final int   COTTON_EDGE  = 0xFFD5CFC2;
final int   COTTON_BODY  = 0xFFFDFBF4;
final int   COTTON_LIGHT = 0xFFFFFFFF;
final int   COTTON_TWIST = 0xFFB4AA96;

ArrayList<Part> parts = new ArrayList<Part>();
float[] guideY;
float[] tx, ty, cost, fuzzLen, fuzzAng;
int nPts;
int shown = 0;
PGraphics still, threadLayer;

public void settings() {
  size(W, H);
  pixelDensity(1);
}

public void setup() {
  frameRate(FPS);
  randomSeed(SEED);
  noiseSeed(SEED);

  // the word is set twice, like two sizes on a specimen sheet
  buildWord(0, 96, 760, 0.372);
  buildWord(1, 96, 1150, 0.22);
  guideY = new float[] {
    760 + ASC * 0.372, 760, 760 + XH * 0.372, 760 + DESC * 0.372,
    1150 + ASC * 0.22, 1150, 1150 + XH * 0.22, 1150 + DESC * 0.22
  };
  scatter();
  buildPath();

  threadLayer = createGraphics(W, H);
  threadLayer.beginDraw();
  threadLayer.clear();
  threadLayer.endDraw();
}

public void draw() {
  int f = frameCount - 1;
  int t0 = INTRO_FRAMES + EXPLODE_FRAMES;
  if (f < t0) {
    drawScene(g, constrain((f - INTRO_FRAMES) / (float) EXPLODE_FRAMES, 0, 1));
  } else {
    if (still == null) {
      still = createGraphics(W, H);
      still.beginDraw();
      drawScene(still, 1);
      still.endDraw();
    }
    float p = constrain((f - t0) / (float) GROW_FRAMES, 0, 1);
    int target = sampleAtCost(p * cost[nPts - 1]);
    if (target > shown) {
      threadLayer.beginDraw();
      drawThread(threadLayer, shown, target);
      threadLayer.endDraw();
      shown = target;
    }
    image(still, 0, 0);
    image(threadLayer, 0, 0);
  }

  if (RECORD) saveFrame("frames/reel-####.png");
  if (f >= t0 + GROW_FRAMES + HOLD_FRAMES) {
    if (RECORD) {
      saveHiRes();
      makeMovie();
    }
    exit();
  }
}

// =====================================================================
//  A PART OF A LETTER
// =====================================================================

class Part {
  ArrayList<PVector> pts = new ArrayList<PVector>();     // outline
  ArrayList<PVector> nodes = new ArrayList<PVector>();   // on-curve points
  ArrayList<float[]> handles = new ArrayList<float[]>(); // node -> off-curve point
  PVector c = new PVector();
  int layer;
  boolean outline;
  float x0, y0, s0;            // as part of the letter
  float x1, y1, s1, rot;       // as a fragment
  float delay;

  void finish(int layer, float ox, float oy, float s) {
    for (PVector p : pts) c.add(p);
    c.div(pts.size());
    this.layer = layer;
    s0 = s;
    x0 = ox + c.x * s;
    y0 = oy + c.y * s;
  }

  // position of a local point when the part is e of the way to a fragment
  float[] at(float px, float py, float e) {
    float s = s0 * pow(s1 / s0, e);
    float a = rot * e;
    float dx = (px - c.x) * s, dy = (py - c.y) * s;
    return new float[] {
      lerp(x0, x1, e) + dx * cos(a) - dy * sin(a),
      lerp(y0, y1, e) + dx * sin(a) + dy * cos(a)
    };
  }

  float progress(float t) {
    float u = constrain((t - delay) / 0.65, 0, 1);
    return u * u * (3 - 2 * u);
  }

  void drawFill(PGraphics pg, float t) {
    float e = progress(t);
    if (outline) {
      pg.noFill();
      pg.stroke(CREAM);
      pg.strokeWeight(2.5);
      pg.strokeJoin(MITER);
    } else {
      pg.noStroke();
      pg.fill(layer == 0 ? DEEP : INK);
    }
    pg.beginShape();
    for (PVector p : pts) {
      float[] q = at(p.x, p.y, e);
      pg.vertex(q[0], q[1]);
    }
    pg.endShape(CLOSE);
  }

  // what a font editor shows: curve handles and outline points
  void drawNodes(PGraphics pg, float t) {
    float e = progress(t);
    pg.stroke(CREAM, 170);
    pg.strokeWeight(1);
    for (float[] h : handles) {
      float[] a = at(h[0], h[1], e), b = at(h[2], h[3], e);
      pg.line(a[0], a[1], b[0], b[1]);
    }
    pg.noStroke();
    pg.fill(CREAM);
    for (float[] h : handles) {
      float[] b = at(h[2], h[3], e);
      pg.ellipse(b[0], b[1], 5, 5);
    }
    pg.rectMode(CENTER);
    pg.stroke(CREAM);
    pg.strokeWeight(1.4);
    pg.fill(BG);
    for (PVector n : nodes) {
      float[] q = at(n.x, n.y, e);
      pg.rect(q[0], q[1], 7, 7);
    }
    pg.rectMode(CORNER);
  }
}

Part rectPart(float x, float y, float w, float h) {
  return polyPart(new float[] { x, y, x + w, y, x + w, y + h, x, y + h });
}

Part polyPart(float[] xy) {
  Part p = new Part();
  for (int i = 0; i < xy.length; i += 2) {
    p.pts.add(new PVector(xy[i], xy[i + 1]));
    p.nodes.add(new PVector(xy[i], xy[i + 1]));
  }
  return p;
}

// a piece of a ring between two angles (a multiple of 90 degrees apart)
Part arcPart(float cx, float cy, float a0, float a1) {
  Part p = new Part();
  int n = ceil((a1 - a0) / 0.03);
  for (int i = 0; i <= n; i++) {
    float a = lerp(a0, a1, i / (float) n);
    p.pts.add(new PVector(cx + RO * cos(a), cy + RO * sin(a)));
  }
  for (int i = n; i >= 0; i--) {
    float a = lerp(a0, a1, i / (float) n);
    p.pts.add(new PVector(cx + RI * cos(a), cy + RI * sin(a)));
  }
  int q = round((a1 - a0) / HALF_PI);
  float[] radii = { RO, RI };
  for (float r : radii) {
    for (int i = 0; i <= q; i++) {
      float a = a0 + i * HALF_PI;
      float nx = cx + r * cos(a), ny = cy + r * sin(a);
      float hx = -sin(a) * r * 0.5523, hy = cos(a) * r * 0.5523;
      p.nodes.add(new PVector(nx, ny));
      if (i < q) p.handles.add(new float[] { nx, ny, nx + hx, ny + hy });
      if (i > 0) p.handles.add(new float[] { nx, ny, nx - hx, ny - hy });
    }
  }
  return p;
}

// Sets "want" at (ox, oy = x-height line) and scale s. y runs downward;
// x-height line is y = 0, baseline is y = XH.
void buildWord(int layer, float ox, float oy, float s) {
  ArrayList<Part> w = new ArrayList<Part>();
  float gx;

  // w: four diagonals
  w.add(polyPart(new float[] { 0, 0, 130, 0, 290, XH, 160, XH }));
  w.add(polyPart(new float[] { 320, 0, 450, 0, 290, XH, 160, XH }));
  w.add(polyPart(new float[] { 320, 0, 450, 0, 610, XH, 480, XH }));
  w.add(polyPart(new float[] { 640, 0, 770, 0, 610, XH, 480, XH }));

  // a: bowl in three pieces, stem
  gx = 830;
  w.add(arcPart(gx + 250, 250, HALF_PI, 3 * HALF_PI));
  w.add(arcPart(gx + 250, 250, 3 * HALF_PI, TWO_PI));
  w.add(arcPart(gx + 250, 250, 0, HALF_PI));
  w.add(rectPart(gx + 380, 0, STEM, XH));

  // n: stem, arch in two pieces, leg
  gx = 1390;
  w.add(rectPart(gx, 0, STEM, XH));
  w.add(arcPart(gx + 250, 250, PI, 3 * HALF_PI));
  w.add(arcPart(gx + 250, 250, 3 * HALF_PI, TWO_PI));
  w.add(rectPart(gx + 380, 250, STEM, 250));

  // t: stem, crossbar, hook, terminal
  gx = 2060;
  w.add(rectPart(gx, ASC, STEM, 250 - ASC));
  w.add(rectPart(gx - 110, 0, 400, 110));
  w.add(arcPart(gx + 250, 250, HALF_PI, PI));
  w.add(rectPart(gx + 250, 380, 90, STEM));

  for (int i = 0; i < w.size(); i++) {
    Part p = w.get(i);
    p.finish(layer, ox, oy, s);
    p.outline = (layer == 1 && i % 3 == 1);
    parts.add(p);
  }
}

// Gives every part its place as a fragment: one per cell of a loose
// grid, turned mostly by quarter turns, the first setting much enlarged.
void scatter() {
  int cols = 4, rows = 8;
  IntList cells = new IntList();
  for (int i = 0; i < cols * rows; i++) cells.append(i);
  for (int i = cells.size() - 1; i > 0; i--) {     // seeded shuffle
    int j = floor(random(i + 1));
    int tmp = cells.get(i);
    cells.set(i, cells.get(j));
    cells.set(j, tmp);
  }
  float cw = W / (float) cols, ch = H / (float) rows;
  for (int i = 0; i < parts.size(); i++) {
    Part p = parts.get(i);
    int cell = cells.get(i % cells.size());
    p.x1 = (cell % cols + 0.5) * cw + random(-70, 70);
    p.y1 = (cell / cols + 0.5) * ch + random(-60, 60);
    p.s1 = (p.layer == 0) ? random(1.1, 2.2) : random(0.42, 0.85);
    p.rot = floor(random(-1, 3)) * HALF_PI;
    if (random(1) < 0.3) p.rot += random(-0.5, 0.5);
    p.delay = random(0, 0.35);
  }
}

// t = 0: letters whole.  t = 1: fragments.
void drawScene(PGraphics pg, float t) {
  pg.background(BG);
  pg.pushMatrix();
  pg.scale(pg.width / (float) W);
  for (Part p : parts) if (p.layer == 0) p.drawFill(pg, t);

  // metric lines: ascender, x-height, baseline, descender
  pg.stroke(CREAM, 120);
  pg.strokeWeight(1.2);
  for (int i = 0; i < guideY.length; i++) {
    pg.line(0, guideY[i], W, guideY[i]);
    pg.line(96, guideY[i] - 9, 96, guideY[i] + 9);
  }

  for (Part p : parts) if (p.layer == 1) p.drawFill(pg, t);
  for (Part p : parts) p.drawNodes(pg, t);
  pg.popMatrix();
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
  // one anchor on every fragment; z = how generous its loop is
  ArrayList<PVector> todo = new ArrayList<PVector>();
  for (Part p : parts)
    todo.add(new PVector(constrain(p.x1, 70, W - 70), constrain(p.y1, 90, H - 90),
                         p.layer == 0 ? 1.5 : 0.8));

  ArrayList<PVector> cp = new ArrayList<PVector>();   // z = 1 while looping
  PVector cur = new PVector(-110, random(500, 900));
  cp.add(new PVector(cur.x - 80, cur.y - 50, 0));
  cp.add(cur.copy());

  while (todo.size() > 0) {
    PVector a = todo.remove(pickNext(todo, cur));
    addHop(cp, cur, a);

    // the loop of wanting: circle the thing, tightening as it goes
    float a0 = atan2(cur.y - a.y, cur.x - a.x);
    float dir = random(1) < 0.5 ? 1 : -1;
    float turns = random(0.9, 2.1);
    float r0 = random(30, 62) * a.z;
    int steps = ceil(turns * 8);
    for (int k = 0; k <= steps; k++) {
      float u = k / (float) steps;
      float ang = a0 + dir * TWO_PI * turns * u;
      float m = (1 - 0.4 * u) * (1 + random(-0.14, 0.14));
      cp.add(new PVector(a.x + r0 * m * cos(ang), a.y + r0 * 0.85 * m * sin(ang), 1));
    }
    cur = cp.get(cp.size() - 1).copy();
    cur.z = 0;
  }

  // the way out: the nearest edge of the frame
  float dl = cur.x, dr = W - cur.x, dt = cur.y, db = H - cur.y;
  float m = min(min(dl, dr), min(dt, db));
  PVector out = cur.copy();
  if (m == dl) out.x = -130;
  else if (m == dr) out.x = W + 130;
  else if (m == dt) out.y = -130;
  else out.y = H + 130;
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
    tx[i] = xs.get(i) + (noise(i * 0.012, 3.1) - 0.5) * 12;
    ty[i] = ys.get(i) + (noise(i * 0.012, 9.7) - 0.5) * 12;
    acc += cs.get(i);
    cost[i] = acc;
    fuzzLen[i] = random(1) < 0.34 ? random(3, 13) * (random(1) < 0.5 ? 1 : -1) : 0;
    fuzzAng[i] = random(-0.9, 0.9);
  }
}

// slack between two points: a few wandering control points across the hop
void addHop(ArrayList<PVector> cp, PVector from, PVector to) {
  float d = dist(from.x, from.y, to.x, to.y);
  if (d < 1) return;
  int nMid = floor(d / 220);
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

void poly(PGraphics pg, int a, int b, float ox, float oy) {
  pg.beginShape();
  for (int i = a; i <= b; i++) pg.vertex(tx[i] + ox, ty[i] + oy);
  pg.endShape();
}

// Lays down samples a..b in short stitches, so that where the thread
// crosses itself the later pass sits on top and drops its shadow on the
// earlier one.
void drawThread(PGraphics pg, int a, int b) {
  pg.pushMatrix();
  pg.scale(pg.width / (float) W);
  pg.noFill();
  pg.strokeJoin(ROUND);
  for (int s = a; s < b; s += CHUNK) {
    int e = min(b, s + CHUNK);
    int s0 = max(0, s - OVERLAP);

    // shadow
    pg.strokeCap(SQUARE);
    pg.stroke(40, 0, 0, 30);
    pg.strokeWeight(TW * 1.9);
    poly(pg, s, e, TW * 0.34, TW * 0.5);
    pg.stroke(40, 0, 0, 46);
    pg.strokeWeight(TW * 1.2);
    poly(pg, s, e, TW * 0.24, TW * 0.36);

    // fibres that escape the twist
    pg.strokeCap(ROUND);
    pg.stroke(COTTON_LIGHT, 200);
    pg.strokeWeight(0.6);
    for (int i = max(1, s0); i < e && i < nPts - 1; i++) {
      if (fuzzLen[i] == 0) continue;
      float ta = atan2(ty[i + 1] - ty[i - 1], tx[i + 1] - tx[i - 1]);
      float side = fuzzLen[i] > 0 ? 1 : -1;
      float na = ta + side * (HALF_PI + fuzzAng[i]);
      float bx = tx[i] + cos(ta + side * HALF_PI) * TW * 0.35;
      float by = ty[i] + sin(ta + side * HALF_PI) * TW * 0.35;
      float len = abs(fuzzLen[i]);
      pg.bezier(bx, by,
                bx + cos(na) * len * 0.5, by + sin(na) * len * 0.5,
                bx + cos(na + 0.6) * len * 0.8, by + sin(na + 0.6) * len * 0.8,
                bx + cos(na + 0.9) * len, by + sin(na + 0.9) * len);
    }

    // body
    pg.stroke(COTTON_EDGE);
    pg.strokeWeight(TW);
    poly(pg, s0, e, 0, 0);
    pg.stroke(COTTON_BODY);
    pg.strokeWeight(TW * 0.8);
    poly(pg, s0, e, 0, 0);
    pg.stroke(COTTON_LIGHT);
    pg.strokeWeight(TW * 0.34);
    poly(pg, s0, e, -TW * 0.13, -TW * 0.15);

    // the twist of the ply
    pg.stroke(COTTON_TWIST, 110);
    pg.strokeWeight(0.8);
    pg.strokeCap(SQUARE);
    for (int i = max(1, s0); i < e && i < nPts - 1; i++) {
      if (i % 2 != 0) continue;
      float ta = atan2(ty[i + 1] - ty[i - 1], tx[i + 1] - tx[i - 1]) + 0.95;
      float h = TW * 0.36;
      pg.line(tx[i] - cos(ta) * h, ty[i] - sin(ta) * h, tx[i] + cos(ta) * h, ty[i] + sin(ta) * h);
    }
  }
  pg.popMatrix();
}

// =====================================================================
//  EXPORT
// =====================================================================

void saveHiRes() {
  PGraphics big = createGraphics(W * HIRES_SCALE, H * HIRES_SCALE);
  big.beginDraw();
  drawScene(big, 1);
  drawThread(big, 0, nPts - 1);
  big.endDraw();
  big.save(sketchPath("output/type_fragment_thread_" + big.width + "x" + big.height + ".png"));
}

void makeMovie() {
  try {
    ProcessBuilder pb = new ProcessBuilder(
      "ffmpeg", "-y", "-framerate", str(FPS),
      "-i", sketchPath("frames/reel-%04d.png"),
      "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "16",
      "-movflags", "+faststart",
      sketchPath("output/type_fragment_thread_reel.mp4"));
    pb.inheritIO();
    pb.start().waitFor();
  }
  catch (Exception e) {
    println("ffmpeg not found - use Tools > Movie Maker on the frames folder (" + FPS + " fps)");
  }
}
