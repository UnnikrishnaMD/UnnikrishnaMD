/**
 * UNREADABLE — two words, one row, a red cotton thread
 * ------------------------------------------------------------------
 * Processing 4 (Java mode). No image, no font file.
 *
 * The source poster set two words side by side, row after row, one in
 * a heavy grotesque and one in a monoline face, swapping sides on
 * every row. That grid is kept exactly: same slots, same letter
 * widths, same stem and stroke weights, same cap height.
 *
 * What changes is the letters. Each of the nine is taken apart into
 * its own strokes (stems, bars, bowls, arcs, a diagonal) and put back
 * together inside its own slot as a form that is no letter at all.
 * The result still behaves like a headline, repeats like a campaign,
 * carries small print, and says nothing.
 *
 * A strand of bright red cotton then enters, loops every form, moves
 * on to the next, and leaves the frame.
 *
 * Format: 1080 x 1920 (9:16), 30 fps — Instagram Reel.
 *
 * Outputs (written next to this sketch):
 *   output/asemic_grid_thread_3240x5760.png   high-res still
 *   frames/reel-####.png                      one PNG per frame
 *   output/asemic_grid_thread_reel.mp4        via ffmpeg if on PATH
 *
 * No ffmpeg? Use Tools > Movie Maker on the frames folder (30 fps).
 */

// ---------- output settings ----------
final int     OUT_W = 1080, OUT_H = 1920;
final int     HIRES_SCALE  = 3;
final int     FPS          = 30;
final int     INTRO_FRAMES = 45;    // the forms alone, before the thread
final int     GROW_FRAMES  = 900;   // 30 s of searching
final int     HOLD_FRAMES  = 90;
final boolean RECORD       = true;
final int     SEED         = 2026;

// ---------- grid (units of the source poster; the frame is 1932 wide) ----------
final float GRID_W    = 1932;
final float GRID_H    = GRID_W * OUT_H / OUT_W;
final float MARGIN    = 100;
final float CAP       = 172;
final float ROW_TOP   = 230;
final float ROW_PITCH = 202.3;
final int   ROWS      = 14;
final float X_MONO_R  = 1068;       // monoline word when it sits on the right
final float X_BOLD_R  = 948;        // heavy word when it sits on the right
final float BOLD_W    = 890;        // width of the heavy word
final float MONO_W    = 768;        // width of the monoline word
final float BOLD      = 43;
final float MONO      = 32;
final float FOOT_Y    = 3150;
final float FOOT_S    = 0.2;        // small print = the same words, tiny

final float[] BOLD_X  = { 0, 200, 351, 569, 733 };   // slot origins
final float[] BOLD_CX = { 81, 262, 444, 647, 811 };  // slot centres
final float[] MONO_X  = { 0, 209, 421, 615 };
final float[] MONO_CX = { 87, 300, 501, 691 };

final int BG  = 0xFFF5EFE0;   // ivory
final int INK = 0xFF0B0B0B;

// ---------- thread ----------
final float TW      = 9;
final float STEP    = 2.5;
final int   CHUNK   = 12;
final int   OVERLAP = 10;
final int   COTTON_EDGE  = 0xFFA30F12;
final int   COTTON_BODY  = 0xFFEA1C24;
final int   COTTON_LIGHT = 0xFFFF6A5E;
final int   COTTON_TWIST = 0xFF7E0A0E;
final int   COTTON_FUZZ  = 0xFFE8323A;

// z = 1 for a big form; for a line of small print z = -(half its width)
ArrayList<PVector> anchors = new ArrayList<PVector>();
float[] tx, ty, cost, fuzzLen, fuzzAng;
int nPts;
int shown = 0;
PGraphics poster, threadLayer;

public void settings() {
  size(OUT_W, OUT_H);
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
  float p = constrain((f - INTRO_FRAMES) / (float) GROW_FRAMES, 0, 1);
  int target = sampleAtCost(p * cost[nPts - 1]);
  if (target > shown) {
    threadLayer.beginDraw();
    drawThread(threadLayer, shown, target);
    threadLayer.endDraw();
    shown = target;
  }
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
//  THE GRID
// =====================================================================

void drawPoster(PGraphics g) {
  g.background(BG);
  g.pushMatrix();
  g.scale(g.width / GRID_W);
  for (int r = 0; r < ROWS; r++) {
    float y = ROW_TOP + r * ROW_PITCH;
    if (r % 2 == 0) {
      drawBoldWord(g, MARGIN, y, 1);
      drawMonoWord(g, X_MONO_R, y, 1);
    } else {
      drawMonoWord(g, MARGIN, y, 1);
      drawBoldWord(g, X_BOLD_R, y, 1);
    }
  }
  // small print: left, centre pair, right — as on the source
  drawMonoWord(g, MARGIN, FOOT_Y, FOOT_S);
  drawBoldWord(g, 640, FOOT_Y, FOOT_S);
  drawMonoWord(g, 640 + BOLD_W * FOOT_S + 26, FOOT_Y, FOOT_S);
  drawBoldWord(g, GRID_W - 96 - BOLD_W * FOOT_S, FOOT_Y, FOOT_S);
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

// ---- the heavy word: five forms, each made of one source letter's parts ----
void drawBoldWord(PGraphics g, float x, float y, float s) {
  g.pushMatrix();
  g.translate(x, y);
  g.scale(s);
  g.noStroke();
  g.fill(INK);

  // 1. from N: the diagonal reversed, the two stems cut down to blocks
  g.pushMatrix();
  g.translate(BOLD_X[0], 0);
  g.beginShape();
  g.vertex(114, 0);
  g.vertex(162, 0);
  g.vertex(48, CAP);
  g.vertex(0, CAP);
  g.endShape(CLOSE);
  g.rect(0, 0, BOLD, 76);
  g.rect(119, 96, BOLD, 76);
  g.popMatrix();

  // 2. from E: three bars, the stem moved to the middle and shortened
  g.pushMatrix();
  g.translate(BOLD_X[1], 0);
  g.rect(0, 0, 125, 40);
  g.rect(0, 66, 125, 40);
  g.rect(0, 132, 125, 40);
  g.rect(41, 0, BOLD, 106);
  g.popMatrix();

  // 3. from O: the ring halved, the halves turned back to back
  g.pushMatrix();
  g.translate(BOLD_X[2], 0);
  g.noFill();
  g.stroke(INK);
  g.strokeWeight(BOLD);
  g.strokeCap(SQUARE);
  g.arc(0, 86, 131, 131, -HALF_PI, HALF_PI);
  g.arc(186, 86, 131, 131, HALF_PI, 3 * HALF_PI);
  g.noStroke();
  g.fill(INK);
  g.popMatrix();

  // 4. from R: the stem laid flat on top, the bowl hung from it, the leg reversed
  g.pushMatrix();
  g.translate(BOLD_X[3], 0);
  g.rect(0, 0, 156, BOLD);
  g.beginShape();
  g.vertex(26, 0);
  g.vertex(130, 0);
  arcVerts(g, 78, 84, 52, 0, PI);
  g.beginContour();
  g.vertex(65, 62);
  arcVerts(g, 78, 92, 13, PI, 0);
  g.vertex(91, 62);
  g.endContour();
  g.endShape(CLOSE);
  g.beginShape();
  g.vertex(92, 104);
  g.vertex(42, 104);
  g.vertex(0, CAP);
  g.vertex(50, CAP);
  g.endShape(CLOSE);
  g.popMatrix();

  // 5. from T: the bar dropped to the middle, the stem cut in two,
  //    one half standing on the bar, the other hanging off it
  g.pushMatrix();
  g.translate(BOLD_X[4], 0);
  g.rect(0, 66, 157, 40);
  g.rect(28, 0, BOLD, 66);
  g.rect(86, 106, BOLD, 66);
  g.popMatrix();

  g.popMatrix();
}

// ---- the monoline word: four forms ----
void drawMonoWord(PGraphics g, float x, float y, float s) {
  g.pushMatrix();
  g.translate(x, y);
  g.scale(s);
  g.noFill();
  g.stroke(INK);
  g.strokeWeight(MONO);
  g.strokeCap(SQUARE);
  g.strokeJoin(ROUND);

  // 1. from N: its curves pulled apart into three arcs that widen
  g.pushMatrix();
  g.translate(MONO_X[0], 0);
  float a1 = radians(72), a2 = asin(70 / 100.0), a3 = asin(70 / 150.0);
  g.arc(9, 86, 100, 100, -a1, a1);
  g.arc(9, 86, 200, 200, -a2, a2);
  g.arc(9, 86, 300, 300, -a3, a3);
  g.popMatrix();

  // 2. from O: the ring quartered, every quarter turned inside out
  g.pushMatrix();
  g.translate(MONO_X[1], 0);
  g.arc(10, 6, 161, 160, 0, HALF_PI);
  g.arc(171, 6, 161, 160, HALF_PI, PI);
  g.arc(171, 166, 161, 160, PI, 3 * HALF_PI);
  g.arc(10, 166, 161, 160, 3 * HALF_PI, TWO_PI);
  g.popMatrix();

  // 3. from D: the bowl and the stem change sides and let go
  g.pushMatrix();
  g.translate(MONO_X[2], 0);
  g.arc(16, 86, 140, 140, -HALF_PI, HALF_PI);
  g.line(145, 0, 145, CAP);
  g.popMatrix();

  // 4. from E: the curve tipped onto its back, the middle bar laid over it
  g.pushMatrix();
  g.translate(MONO_X[3], 0);
  g.line(0, 16, 153, 16);
  g.beginShape();
  g.vertex(16, 62);
  g.vertex(16, 95.5);
  g.bezierVertex(16, 128.9, 43.1, 156, 76.5, 156);
  g.bezierVertex(109.9, 156, 137, 128.9, 137, 95.5);
  g.vertex(137, 62);
  g.endShape();
  g.popMatrix();

  g.popMatrix();
}

// =====================================================================
//  THREAD — where it goes
// =====================================================================

// one anchor inside every big form, one on every line of small print
void collectAnchors() {
  for (int r = 0; r < ROWS; r++) {
    float cy = ROW_TOP + r * ROW_PITCH + CAP / 2;
    float xBold = (r % 2 == 0) ? MARGIN : X_BOLD_R;
    float xMono = (r % 2 == 0) ? X_MONO_R : MARGIN;
    for (int i = 0; i < BOLD_CX.length; i++)
      anchors.add(new PVector(xBold + BOLD_CX[i] + random(-18, 18), cy + random(-22, 22), 1));
    for (int i = 0; i < MONO_CX.length; i++)
      anchors.add(new PVector(xMono + MONO_CX[i] + random(-18, 18), cy + random(-22, 22), 1));
  }
  float fy = FOOT_Y + CAP * FOOT_S / 2;
  float hb = BOLD_W * FOOT_S / 2, hm = MONO_W * FOOT_S / 2;
  anchors.add(new PVector(MARGIN + hm, fy, -hm));
  anchors.add(new PVector(640 + hb, fy, -hb));
  anchors.add(new PVector(640 + 2 * hb + 26 + hm, fy, -hm));
  anchors.add(new PVector(GRID_W - 96 - hb, fy, -hb));
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
  PVector cur = new PVector(-110, random(300, 900));
  cp.add(new PVector(cur.x - 80, cur.y - 50, 0));
  cp.add(cur.copy());

  while (todo.size() > 0) {
    PVector a = todo.remove(pickNext(todo, cur));
    addHop(cp, cur, a);

    // the loop of wanting: circle the thing, tightening as it goes.
    // Small print is lassoed from outside.
    boolean small = a.z < 0;
    float a0 = atan2(cur.y - a.y, cur.x - a.x);
    float dir = random(1) < 0.5 ? 1 : -1;
    float turns = small ? random(1.05, 1.3) : random(0.9, 2.1);
    float r0 = random(24, 66);
    float rx = small ? -a.z + 20 : r0;
    float ry = small ? 36 : r0 * 0.85;
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
//  EXPORT
// =====================================================================

void saveHiRes() {
  PGraphics big = createGraphics(OUT_W * HIRES_SCALE, OUT_H * HIRES_SCALE);
  big.beginDraw();
  drawPoster(big);
  drawThread(big, 0, nPts - 1);
  big.endDraw();
  big.save(sketchPath("output/asemic_grid_thread_" + big.width + "x" + big.height + ".png"));
}

void makeMovie() {
  try {
    ProcessBuilder pb = new ProcessBuilder(
      "ffmpeg", "-y", "-framerate", str(FPS),
      "-i", sketchPath("frames/reel-%04d.png"),
      "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "16",
      "-movflags", "+faststart",
      sketchPath("output/asemic_grid_thread_reel.mp4"));
    pb.inheritIO();
    pb.start().waitFor();
  }
  catch (Exception e) {
    println("ffmpeg not found - use Tools > Movie Maker on the frames folder (" + FPS + " fps)");
  }
}
