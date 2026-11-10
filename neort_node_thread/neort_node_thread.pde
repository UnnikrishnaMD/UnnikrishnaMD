/**
 * NEORT / NODE — a cotton thread in search
 * ------------------------------------------------------------------
 * Processing 4 (Java mode). No image, no font file: every letterform
 * of the poster is rebuilt from rectangles, arcs and bezier paths.
 *
 * A single strand of unbleached cotton enters from the edge of the
 * sheet, wanders to every letter and every line of small print, wraps
 * each one in a loop (the moment of wanting), moves on to the next
 * nearest thing, and finally leaves the sheet again.
 *
 * Outputs (written next to this sketch):
 *   output/neort_node_thread_4000.png   high-res still of the finished state
 *   frames/thread-####.png              one PNG per video frame
 *   output/neort_node_thread.mp4        assembled with ffmpeg if it is on PATH
 *
 * No ffmpeg? Use Tools > Movie Maker on the frames folder (30 fps).
 * For HIRES_PX above 4000 raise the memory limit in Preferences.
 */

// ---------- output settings ----------
final int     VIDEO_PX    = 1080;
final int     HIRES_PX    = 4000;
final int     FPS         = 30;
final int     GROW_FRAMES = 720;    // 24 s of searching
final int     HOLD_FRAMES = 90;     // 3 s of rest on the finished piece
final boolean RECORD      = true;   // false = just watch it
final int     SEED        = 2026;   // change for a different search

// ---------- poster grid (all geometry is in these units) ----------
final float GRID      = 1932;
final float MARGIN    = 100;
final float CAP       = 172;        // cap height of the big letters
final float ROW_TOP   = 108;
final float ROW_PITCH = 202.3;
final int   ROWS      = 8;
final float X_NODE_R  = 1068;       // NODE when it sits on the right
final float X_NEORT_R = 948;        // NEORT when it sits on the right
final float BOLD      = 43;         // stem of NEORT
final float MONO      = 32;         // stroke of NODE
final float FOOT_Y    = 1803;
final float FOOT_CAP  = 34;

final float[] NEORT_CX = { 81, 262, 444, 640, 811 };
final float[] NODE_CX  = { 87, 300, 501, 691 };

final int BG  = 0xFFEAEAEA;
final int INK = 0xFF0B0B0B;

// ---------- thread ----------
final float TW      = 6;            // thread thickness
final float STEP    = 2.5;          // sample spacing along the thread
final int   CHUNK   = 12;           // samples laid down per "stitch"
final int   OVERLAP = 10;
final int   COTTON_EDGE  = 0xFFAE9C76;
final int   COTTON_BODY  = 0xFFE9DEC2;
final int   COTTON_LIGHT = 0xFFFBF6E9;
final int   COTTON_TWIST = 0xFF8F7D58;
final int   COTTON_FUZZ  = 0xFFD8CBA8;

// z = 1 for a big letter; for a word of small print z = -(half its width)
ArrayList<PVector> anchors = new ArrayList<PVector>();
float[] tx, ty, cost, fuzzLen, fuzzAng;
int nPts;
int shown = 0;
PGraphics poster, threadLayer;

public void settings() {
  size(VIDEO_PX, VIDEO_PX);
  pixelDensity(1);
}

public void setup() {
  frameRate(FPS);
  randomSeed(SEED);
  noiseSeed(SEED);

  collectAnchors();
  buildPath();

  poster = createGraphics(width, height);
  poster.beginDraw();
  drawPoster(poster);
  poster.endDraw();

  threadLayer = createGraphics(width, height);
  threadLayer.beginDraw();
  threadLayer.clear();
  threadLayer.endDraw();
}

public void draw() {
  int f = frameCount - 1;
  float p = constrain(f / (float) GROW_FRAMES, 0, 1);
  int target = sampleAtCost(p * cost[nPts - 1]);
  if (target > shown) {
    threadLayer.beginDraw();
    drawThread(threadLayer, shown, target);
    threadLayer.endDraw();
    shown = target;
  }
  image(poster, 0, 0);
  image(threadLayer, 0, 0);

  if (RECORD) saveFrame("frames/thread-####.png");
  if (f >= GROW_FRAMES + HOLD_FRAMES) {
    if (RECORD) {
      saveHiRes();
      makeMovie();
    }
    exit();
  }
}

// =====================================================================
//  POSTER
// =====================================================================

void drawPoster(PGraphics g) {
  g.background(BG);
  g.pushMatrix();
  g.scale(g.width / GRID);
  for (int r = 0; r < ROWS; r++) {
    float y = ROW_TOP + r * ROW_PITCH;
    if (r % 2 == 0) {
      drawNEORT(g, MARGIN, y);
      drawNODE(g, X_NODE_R, y);
    } else {
      drawNODE(g, MARGIN, y);
      drawNEORT(g, X_NEORT_R, y);
    }
  }
  footer(g, true, null);
  g.popMatrix();
}

// adds the points of a circular arc to the shape that is currently open
void arcVerts(PGraphics g, float cx, float cy, float r, float a0, float a1) {
  int n = max(6, ceil(abs(a1 - a0) * r / 3));
  for (int i = 0; i <= n; i++) {
    float a = lerp(a0, a1, i / (float) n);
    g.vertex(cx + r * cos(a), cy + r * sin(a));
  }
}

// ---- NEORT: heavy geometric grotesque, built as filled shapes ----
void drawNEORT(PGraphics g, float x, float y) {
  g.pushMatrix();
  g.translate(x, y);
  g.noStroke();
  g.fill(INK);

  // N
  g.beginShape();
  g.vertex(0, 0);
  g.vertex(48, 0);
  g.vertex(119, 96);
  g.vertex(119, 0);
  g.vertex(162, 0);
  g.vertex(162, CAP);
  g.vertex(114, CAP);
  g.vertex(43, 76);
  g.vertex(43, CAP);
  g.vertex(0, CAP);
  g.endShape(CLOSE);

  // E
  g.rect(200, 0, BOLD, CAP);
  g.rect(200, 0, 125, 40);
  g.rect(200, 66, 118, 40);
  g.rect(200, 132, 125, 40);

  // O (overshoots the cap lines, as a round letter should)
  g.noFill();
  g.stroke(INK);
  g.strokeWeight(BOLD);
  g.ellipse(444, 86, 145, 145);
  g.noStroke();
  g.fill(INK);

  // R: stem, bowl with a slot counter, leg
  g.rect(569, 0, BOLD, CAP);
  g.beginShape();
  g.vertex(569, 0);
  arcVerts(g, 653, 52, 52, -HALF_PI, HALF_PI);
  g.vertex(569, 104);
  g.beginContour();
  g.vertex(612, 40);
  g.vertex(612, 66);
  arcVerts(g, 657, 53, 13, HALF_PI, -HALF_PI);
  g.endContour();
  g.endShape(CLOSE);
  g.beginShape();
  g.vertex(627, 100);
  g.vertex(677, 100);
  g.vertex(725, CAP);
  g.vertex(675, CAP);
  g.endShape(CLOSE);

  // T
  g.rect(733, 0, 157, 40);
  g.rect(790, 0, BOLD, CAP);

  g.popMatrix();
}

// ---- NODE: monoline, each letter a bent piece of one stroke ----
void drawNODE(PGraphics g, float x, float y) {
  g.pushMatrix();
  g.translate(x, y);
  g.noFill();
  g.stroke(INK);
  g.strokeWeight(MONO);
  g.strokeCap(SQUARE);
  g.strokeJoin(ROUND);

  // N: one wave, up, over, down, under, up
  g.beginShape();
  g.vertex(16, CAP);
  g.vertex(16, 48);
  g.bezierVertex(16, -4, 71, -4, 80, 48);
  g.vertex(95, 128);
  g.bezierVertex(104.75, 180, 159, 180, 159, 128);
  g.vertex(159, 0);
  g.endShape();

  // O: a ring cut in two; each half ends on a flat horizontal edge
  g.noStroke();
  g.fill(INK);
  ringPiece(g, 299.5, 86, 90, 58, 11, -16, true);
  ringPiece(g, 299.5, 86, 90, 58, 41, 14, false);
  g.noFill();
  g.stroke(INK);

  // D
  g.pushMatrix();
  g.translate(421, 0);
  g.beginShape();
  g.vertex(75, 16);
  g.bezierVertex(113.7, 16, 145, 47.3, 145, 86);
  g.bezierVertex(145, 124.7, 113.7, 156, 75, 156);
  g.vertex(26, 156);
  g.quadraticVertex(16, 156, 16, 146);
  g.vertex(16, 26);
  g.quadraticVertex(16, 16, 26, 16);
  g.endShape(CLOSE);
  g.popMatrix();

  // E
  g.pushMatrix();
  g.translate(615, 0);
  g.beginShape();
  g.vertex(153, 16);
  g.vertex(86, 16);
  g.bezierVertex(47.3, 16, 16, 47.3, 16, 86);
  g.bezierVertex(16, 124.7, 47.3, 156, 86, 156);
  g.vertex(153, 156);
  g.endShape();
  g.line(16, 86, 147, 86);
  g.popMatrix();

  g.popMatrix();
}

// Half of a ring. yL / yR: height (relative to the centre) at which the
// left and right ends are sliced flat. top = upper half, else lower half.
void ringPiece(PGraphics g, float cx, float cy, float R, float r,
               float yL, float yR, boolean top) {
  g.beginShape();
  if (top) {
    arcVerts(g, cx, cy, R, PI - asin(yL / R), TWO_PI + asin(yR / R));
    arcVerts(g, cx, cy, r, TWO_PI + asin(yR / r), PI - asin(yL / r));
  } else {
    arcVerts(g, cx, cy, R, asin(yR / R), PI - asin(yL / R));
    arcVerts(g, cx, cy, r, PI - asin(yL / r), asin(yR / r));
  }
  g.endShape(CLOSE);
}

// =====================================================================
//  SMALL PRINT — a single-stroke alphabet, only the glyphs that are used
// =====================================================================

final float GT = 6, GB = 94;        // centreline of top and bottom strokes
final float TRACK = 36;

// Draws (or only measures) one line. Returns its width in grid units.
// When out != null the centre of every word is added as a thread anchor.
float textLine(PGraphics g, String s, float x, float y, float cap,
               boolean draw, ArrayList<PVector> out) {
  float k = cap / 100;
  float pen = 6;
  float wordStart = pen;
  if (draw) {
    g.pushMatrix();
    g.translate(x, y);
    g.scale(k);
    g.noFill();
    g.stroke(INK);
    g.strokeWeight(12);
    g.strokeCap(PROJECT);
    g.strokeJoin(MITER);
  }
  for (int i = 0; i < s.length(); i++) {
    char c = s.charAt(i);
    if (draw) {
      g.pushMatrix();
      g.translate(pen, 0);
    }
    float w = glyph(g, c, draw);
    if (draw) g.popMatrix();
    boolean last = (i == s.length() - 1);
    if (out != null && (c == ' ' || last)) {
      float wordEnd = (c == ' ') ? pen - TRACK : pen + w;
      out.add(new PVector(x + k * (wordStart + wordEnd) / 2, y + cap / 2, -k * (wordEnd - wordStart) / 2));
      wordStart = pen + w + TRACK;
    }
    pen += w + (last ? 6 : TRACK);
  }
  if (draw) g.popMatrix();
  return pen * k;
}

float glyph(PGraphics g, char c, boolean d) {
  switch (c) {
  case 'T':
    if (d) { g.line(0, GT, 60, GT); g.line(30, GT, 30, GB); }
    return 60;
  case 'O':
    if (d) g.ellipse(39, 50, 78, 90);
    return 78;
  case 'K':
    if (d) { g.line(0, GT, 0, GB); g.line(56, GT, 0, 60); g.line(20, 42, 58, GB); }
    return 58;
  case 'Y':
    if (d) { g.line(0, GT, 31, 54); g.line(62, GT, 31, 54); g.line(31, 54, 31, GB); }
    return 62;
  case 'C':
    if (d) { g.strokeCap(SQUARE); g.arc(39, 50, 78, 90, radians(48), radians(312)); g.strokeCap(PROJECT); }
    return 70;
  case 'I':
    if (d) g.line(0, GT, 0, GB);
    return 0;
  case 'E':
    if (d) { g.line(0, GT, 0, GB); g.line(0, GT, 52, GT); g.line(0, 50, 47, 50); g.line(0, GB, 52, GB); }
    return 52;
  case 'S':
    if (d) {
      g.strokeCap(SQUARE);
      g.beginShape();
      g.vertex(54, 26);
      g.bezierVertex(50, -2, 3, -2, 3, 28);
      g.bezierVertex(3, 54, 56, 44, 56, 72);
      g.bezierVertex(56, 104, 2, 102, 0, 72);
      g.endShape();
      g.strokeCap(PROJECT);
    }
    return 56;
  case 'A':
    if (d) { g.line(0, GB, 35, GT); g.line(35, GT, 70, GB); g.line(12, 66, 58, 66); }
    return 70;
  case 'N':
    if (d) { g.beginShape(); g.vertex(0, GB); g.vertex(0, GT); g.vertex(60, GB); g.vertex(60, GT); g.endShape(); }
    return 60;
  case 'D':
    if (d) {
      g.beginShape();
      g.vertex(0, GT);
      g.vertex(22, GT);
      g.bezierVertex(54, GT, 66, 26, 66, 50);
      g.bezierVertex(66, 74, 54, GB, 22, GB);
      g.vertex(0, GB);
      g.endShape(CLOSE);
    }
    return 66;
  case 'P':
    if (d) {
      g.line(0, GT, 0, GB);
      g.beginShape();
      g.vertex(0, GT);
      g.vertex(28, GT);
      g.bezierVertex(62, GT, 62, 54, 28, 54);
      g.vertex(0, 54);
      g.endShape();
    }
    return 54;
  case 'L':
    if (d) { g.line(0, GT, 0, GB); g.line(0, GB, 46, GB); }
    return 46;
  case '1':
    if (d) { g.line(0, 24, 24, GT); g.line(24, GT, 24, GB); }
    return 24;
  case '2':
    if (d) {
      g.beginShape();
      g.vertex(2, 28);
      g.bezierVertex(4, -4, 52, -4, 50, 28);
      g.bezierVertex(48, 52, 8, 66, 0, GB);
      g.vertex(52, GB);
      g.endShape();
    }
    return 52;
  case '4':
    if (d) { g.beginShape(); g.vertex(42, GB); g.vertex(42, GT); g.vertex(0, 68); g.vertex(58, 68); g.endShape(); }
    return 58;
  case '5':
    if (d) {
      g.beginShape();
      g.vertex(48, GT);
      g.vertex(8, GT);
      g.vertex(3, 46);
      g.bezierVertex(18, 30, 54, 34, 52, 66);
      g.bezierVertex(50, 102, 6, 102, 0, 76);
      g.endShape();
    }
    return 52;
  case '6':
    if (d) {
      g.strokeCap(SQUARE);
      g.beginShape();
      g.vertex(48, 20);
      g.bezierVertex(34, -4, 0, 6, 0, 62);
      g.endShape();
      g.strokeCap(PROJECT);
      g.ellipse(27, 65, 54, 60);
    }
    return 54;
  case '0':
    if (d) g.ellipse(25, 50, 50, 90);
    return 50;
  case '.':
    if (d) { g.noStroke(); g.fill(INK); g.rect(-6, 87, 13, 13); g.noFill(); g.stroke(INK); }
    return 0;
  case '-':
    if (d) { g.strokeCap(SQUARE); g.line(0, 56, 30, 56); g.strokeCap(PROJECT); }
    return 30;
  default:   // space
    return 6;
  }
}

// The four pieces of small print. Draws them, and/or collects their anchors.
void footer(PGraphics g, boolean draw, ArrayList<PVector> out) {
  textLine(g, "TOKYO", MARGIN, FOOT_Y, FOOT_CAP, draw, out);
  textLine(g, "CITIES AS NODES", 556, FOOT_Y, FOOT_CAP, draw, out);
  textLine(g, "11.14-15.2026", 1012, FOOT_Y, FOOT_CAP, draw, out);
  String s = "PALO ALTO";
  float w = textLine(g, s, 0, 0, FOOT_CAP, false, null);
  textLine(g, s, GRID - 96 - w, FOOT_Y, FOOT_CAP, draw, out);
}

// =====================================================================
//  THREAD — where it goes
// =====================================================================

// one anchor inside every big letter, one on every word of small print
void collectAnchors() {
  for (int r = 0; r < ROWS; r++) {
    float cy = ROW_TOP + r * ROW_PITCH + CAP / 2;
    float xNeort = (r % 2 == 0) ? MARGIN : X_NEORT_R;
    float xNode  = (r % 2 == 0) ? X_NODE_R : MARGIN;
    for (int i = 0; i < NEORT_CX.length; i++)
      anchors.add(new PVector(xNeort + NEORT_CX[i] + random(-18, 18), cy + random(-22, 22), 1));
    for (int i = 0; i < NODE_CX.length; i++)
      anchors.add(new PVector(xNode + NODE_CX[i] + random(-18, 18), cy + random(-22, 22), 1));
  }
  footer(null, false, anchors);
}

// index of one of the three nearest unvisited anchors: mostly the nearest,
// sometimes distracted by the second or third
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
  PVector cur = new PVector(-110, random(700, 1200));
  cp.add(new PVector(cur.x - 80, cur.y - 50, 0));
  cp.add(cur.copy());

  while (todo.size() > 0) {
    PVector a = todo.remove(pickNext(todo, cur));
    addHop(cp, cur, a);

    // the loop of wanting: circle the thing, tightening as it goes.
    // Small print is lassoed from outside so it stays readable.
    boolean small = a.z < 0;
    float a0 = atan2(cur.y - a.y, cur.x - a.x);
    float dir = random(1) < 0.5 ? 1 : -1;
    float turns = small ? random(1.05, 1.3) : random(0.9, 2.1);
    float r0 = random(24, 66);
    float rx = small ? -a.z + 20 : r0;
    float ry = small ? FOOT_CAP : r0 * 0.85;
    float tighten = small ? 0.08 : 0.4;
    float wobble = small ? 0.05 : 0.14;
    int steps = ceil(turns * (small ? 12 : 8));
    for (int k = 0; k <= steps; k++) {
      float u = k / (float) steps;
      float ang = a0 + dir * TWO_PI * turns * u;
      float m = (1 - tighten * u) * (1 + random(-wobble, wobble));
      cp.add(new PVector(a.x + rx * m * cos(ang), a.y + ry * m * sin(ang), 1));
    }
    cur = cp.get(cp.size() - 1).copy();
    cur.z = 0;
  }

  // the way out: the nearest edge of the sheet
  float dl = cur.x, dr = GRID - cur.x, dt = cur.y, db = GRID - cur.y;
  float m = min(min(dl, dr), min(dt, db));
  PVector out = cur.copy();
  if (m == dl) out.x = -130;
  else if (m == dr) out.x = GRID + 130;
  else if (m == dt) out.y = -130;
  else out.y = GRID + 130;
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
    fuzzLen[i] = random(1) < 0.3 ? random(3, 11) * (random(1) < 0.5 ? 1 : -1) : 0;
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
  g.scale(g.width / GRID);
  g.noFill();
  g.strokeJoin(ROUND);
  for (int s = a; s < b; s += CHUNK) {
    int e = min(b, s + CHUNK);
    int s0 = max(0, s - OVERLAP);

    // shadow
    g.strokeCap(SQUARE);
    g.stroke(0, 22);
    g.strokeWeight(TW * 1.8);
    poly(g, s, e, TW * 0.30, TW * 0.44);
    g.stroke(0, 34);
    g.strokeWeight(TW * 1.2);
    poly(g, s, e, TW * 0.22, TW * 0.32);

    // fibres that escape the twist
    g.strokeCap(ROUND);
    g.stroke(COTTON_FUZZ, 170);
    g.strokeWeight(0.55);
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
    g.strokeWeight(TW * 0.76);
    poly(g, s0, e, 0, 0);
    g.stroke(COTTON_LIGHT, 170);
    g.strokeWeight(TW * 0.28);
    poly(g, s0, e, -TW * 0.15, -TW * 0.17);

    // the twist of the ply
    g.stroke(COTTON_TWIST, 120);
    g.strokeWeight(0.7);
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
//  EXPORT
// =====================================================================

void saveHiRes() {
  PGraphics big = createGraphics(HIRES_PX, HIRES_PX);
  big.beginDraw();
  drawPoster(big);
  drawThread(big, 0, nPts - 1);
  big.endDraw();
  big.save(sketchPath("output/neort_node_thread_" + HIRES_PX + ".png"));
}

void makeMovie() {
  try {
    ProcessBuilder pb = new ProcessBuilder(
      "ffmpeg", "-y", "-framerate", str(FPS),
      "-i", sketchPath("frames/thread-%04d.png"),
      "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "16",
      "-movflags", "+faststart",
      sketchPath("output/neort_node_thread.mp4"));
    pb.inheritIO();
    pb.start().waitFor();
  }
  catch (Exception e) {
    println("ffmpeg not found - use Tools > Movie Maker on the frames folder (" + FPS + " fps)");
  }
}
