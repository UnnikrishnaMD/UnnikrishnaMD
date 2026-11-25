/*
 * SIDE BY SIDE
 * A body of work in seven panels. Processing 4
 *
 * A row of middle-class houses on the far bank of a Kerala backwater,
 * seen from across the water and the paddy. From this far away they stop
 * reading as architecture. Each one has a face: curtains drawn halfway
 * like lids, sunshades that droop like brows, monsoon streaks like tears.
 * They stand side by side, close together, and each one is alone.
 * Nobody is out. The scooters on the bund are under covers; petrol is
 * past a hundred and fifteen rupees a litre.
 *
 * Over them stands a hoarding with a smiling face, the only face that
 * smiles. Next to it a mobile tower is dressed up as a coconut palm.
 * The sky carries messages. The water reflects the houses and the offers.
 *
 * Method
 *   1. The world is drawn flat into a reference buffer. No outline stays
 *      geometric: corners are rounded and edges wobble. The water is
 *      a rippled reflection of the reference itself.
 *   2. The reference is repainted as oil, in bristle strokes from coarse
 *      to fine, steered along the image and stopped where the colour
 *      changes. Every bristle also writes into a height map.
 *   3. Lettering, faces and wires are painted last with a pointed brush.
 *      Contours are scratched back to the ground (sgraffito). The height
 *      map is lit, and canvas tooth and varnish are added.
 *
 * The lettering is a hand-built curly alphabet (A-Z, 0-9, Rs, %, heart):
 * spline skeletons with spiral terminals. No fonts are used.
 *
 * The series: same seed, same street. After 01 each panel changes ONE element.
 *   0 Reference      the flat drawing, before paint
 *   1 Side by Side   the base painting
 *   2 Communication  communications design only: the offers multiply
 *   3 Colour         colour only: everything greys, except the brand's red
 *   4 Form           form only: outlines soften, walls sag, eyes droop
 *   5 Texture        surface only: big brushes, impasto, knife, sgraffito
 *   6 Mood           light only: a power cut at dusk; the hoarding stays lit
 *
 * Keys
 *   0-6  paint that panel        n  new street (new seed)
 *   r    reference / painting    s  save current panel
 *   e    export all seven panels + contact sheet
 */

import java.util.Random;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;

// ------------------------------------------------------------ canvas
final int W = 2000, H = 1400;
final float S = 14;                    // pixels per metre at the far bank
final float BASE = 842;                // where the houses stand
final float BUND = 872;                // water's edge below the bund road
final float WATER0 = 874, WATER1 = 1190;

long seed = 3108;
int stage = 1;
boolean AUTO_EXPORT = false;           // true: export everything, then quit

PGraphics ref, cv;
World world;
Look look;
boolean needsRender = true, showRef = false;
int renderPhase = 0;

final String[][] STAGES = {
  {"00", "Reference",     "the flat drawing, before paint"},
  {"01", "Side by Side",  "the base painting"},
  {"02", "Communication", "the offers multiply"},
  {"03", "Colour",        "only the brand's red survives"},
  {"04", "Form",          "the houses soften and sag"},
  {"05", "Texture",       "impasto, knife and sgraffito"},
  {"06", "Mood",          "a power cut at dusk"}
};

// ------------------------------------------------------------ palette
final float[][] WALLS = {{168,204,176},{234,164,142},{152,188,210},{238,212,124},{196,174,208},{242,192,150},{210,220,150},{226,226,214}};
final float[][] TRIMS = {{240,234,218},{92,128,120},{150,62,52},{70,82,110},{236,226,196}};
final float[][] CURTS = {{206,92,86},{228,190,108},{110,140,186},{222,212,196},{150,112,160}};
final float[][] DOORS = {{112,58,38},{86,50,36},{128,80,44}};
final float[][] CWALLS = {{226,220,204},{190,186,174},{176,108,78},{214,206,184},{200,214,200}};
final float[][] INKS = {{198,36,34},{36,66,150},{24,112,72},{30,30,32}};
final float[] TERRA = {178,86,56};
final float[] SKY_TOP = {150,170,186};
final float[] SKY_LOW = {226,220,204};
final float[] HAZE = {146,162,170};
final float[] WATERC = {74,98,94};
final float[] INK_DARK = {38,38,42};

// ===================================================================
void settings() {
  size(1000, 700);
}

void setup() {
  initGlyphs();
  ref = createGraphics(W, H);
  cv = createGraphics(W, H);
  world = new World(seed);
  if (AUTO_EXPORT) {
    exportSeries();
    exit();
  }
}

void draw() {
  if (needsRender) {
    if (renderPhase == 0) {
      background(24);
      fill(200);
      textAlign(CENTER, CENTER);
      text("painting  " + STAGES[stage][0] + "  " + STAGES[stage][1].toUpperCase() + " ...", width/2, height/2);
      renderPhase = 1;
      return;
    }
    renderStage(stage);
    needsRender = false;
    renderPhase = 0;
    surface.setTitle("SIDE BY SIDE   " + STAGES[stage][0] + " " + STAGES[stage][1] + "   seed " + seed);
  }
  background(24);
  image(showRef ? ref : cv, 0, 0, width, height);
}

void keyPressed() {
  if (key >= '0' && key <= '6') {
    stage = key - '0';
    needsRender = true;
  } else if (key == 'n' || key == 'N') {
    seed = (long) random(1, 99999);
    world = new World(seed);
    needsRender = true;
  } else if (key == 'r' || key == 'R') {
    showRef = !showRef;
  } else if (key == 's' || key == 'S') {
    saveStage(stage);
  } else if (key == 'e' || key == 'E') {
    exportSeries();
    needsRender = true;
  }
}

// ===================================================================
//  SERIES
// ===================================================================
void renderStage(int s) {
  look = new Look(s);
  noiseSeed(seed);
  noiseDetail(4, 0.5);
  drawReference(ref);
  if (s == 0) {
    cv.beginDraw();
    cv.image(ref, 0, 0);
    cv.endDraw();
    return;
  }
  Painter p = new Painter(ref, seed + s*101);
  p.paintAll();
  p.paintLines(buildLines(), 0.9);
  p.paintLines(buildType(true), 1.0);
  p.etchAll(etchPaths);
  if (look.knife) p.knife();
  p.finish(cv);
}

String slug(int s) { return STAGES[s][1].toLowerCase().replace(' ', '_'); }

String stageFile(int s) {
  return sketchPath("output/side_by_side_" + seed + "_" + STAGES[s][0] + "_" + slug(s) + ".png");
}

void saveStage(int s) {
  cv.save(stageFile(s));
  println("saved " + stageFile(s));
}

void exportSeries() {
  PImage[] thumbs = new PImage[STAGES.length];
  for (int s = 0; s < STAGES.length; s++) {
    int t0 = millis();
    renderStage(s);
    saveStage(s);
    PImage pv = cv.get();
    pv.resize(1000, 700);
    pv.save(sketchPath("previews/" + STAGES[s][0] + "_" + slug(s) + ".jpg"));
    thumbs[s] = cv.get();
    println("  panel " + STAGES[s][0] + " in " + nf((millis()-t0)/1000.0, 0, 1) + "s");
  }
  contactSheet(thumbs);
}

void contactSheet(PImage[] thumbs) {
  look = new Look(1);
  int tw = 400, th = 280, gut = 32, lab = 44;
  int sw = 4*tw + 5*gut, sh = 2*(th + lab) + 3*gut;
  PGraphics g = createGraphics(sw, sh);
  g.beginDraw();
  g.background(30, 26, 23);
  g.noStroke();
  for (int i = 0; i < 8; i++) {
    int cx = gut + (i % 4)*(tw + gut), cy = gut + (i / 4)*(th + lab + gut);
    if (i < thumbs.length) {
      PImage t = thumbs[i].copy();
      t.resize(tw, th);
      g.image(t, cx, cy);
      String lbl = STAGES[i][0] + " " + STAGES[i][1].toUpperCase();
      renderStrokes(g, typeset(lbl, cx, cy + th + 30, 17, 2.4, color(222, 210, 186), 0, 900 + i*7, false, true));
    } else {
      g.fill(222, 214, 196);
      fillShape(g, organic(new float[]{cx, cy, cx+tw, cy, cx+tw, cy+th, cx, cy+th}, 10, 2.5, 77));
      float th0 = min(42, (tw - 60)/textW("SIDE BY SIDE", 1));
      renderStrokes(g, typeset("SIDE BY SIDE", cx + 28, cy + 92, th0, th0*0.14, color(198, 36, 34), -0.03, 31, false, true));
      renderStrokes(g, typeset("ONE STREET", cx + 30, cy + 160, 22, 3.2, color(36, 66, 150), 0, 41, false, true));
      renderStrokes(g, typeset("FROM A DISTANCE", cx + 30, cy + 198, 22, 3.2, color(36, 66, 150), 0, 43, false, true));
      renderStrokes(g, typeset("SEVEN PANELS", cx + 30, cy + 236, 22, 3.2, color(36, 66, 150), 0, 47, false, true));
      renderStrokes(g, faceStrokes(cx + tw - 56, cy + th - 66, 58, color(30, 30, 32), 5, true));
    }
  }
  g.endDraw();
  g.save(sketchPath("output/side_by_side_" + seed + "_contact_sheet.png"));
  PImage pv = g.get();
  pv.resize(sw/2, sh/2);
  pv.save(sketchPath("previews/contact_sheet.jpg"));
  println("saved contact sheet");
}

// ===================================================================
//  LOOK: what changes from panel to panel
// ===================================================================
class Look {
  int st;
  float wob = 1, sag = 1, round = 1;
  float[] radii = {18, 10, 5.5, 3, 1.6};
  float impasto = 1;
  int etchLevel = 1;
  boolean knife = false, brand = false, dusk = false;
  float comm = 0;          // 0 base, 1 the offers multiply
  float ghostA = 60;

  Look(int s) {
    st = s;
    if (s == 2) { comm = 1; ghostA = 150; }
    if (s == 3) brand = true;
    if (s == 4) { wob = 3.4; sag = 4.0; round = 4.0; }
    if (s == 5) { radii = new float[]{32, 18, 10, 5.5, 3}; impasto = 2.8; etchLevel = 2; knife = true; }
    if (s == 6) dusk = true;
  }

  int tone(float r, float g, float b, float a) {
    if (brand) {
      float[] c = brandMap(r, g, b);
      r = c[0]; g = c[1]; b = c[2];
    }
    if (dusk) {
      float L = 0.3*r + 0.59*g + 0.11*b;
      r = r*0.3 + L*0.05 + 16;
      g = g*0.28 + L*0.06 + 16;
      b = b*0.34 + L*0.12 + 36;
    }
    return color(r, g, b, a);
  }
}

// Colour panel: every colour goes to a grey of the same value,
// except true reds. The advertiser's red, the hibiscus, the scooter
// cover keep theirs. Terracotta sits just outside the window and greys.
float[] brandMap(float r, float g, float b) {
  float L = 0.3*r + 0.59*g + 0.11*b;
  float mx = max(r, max(g, b)), mn = min(r, min(g, b));
  float sat = (mx - mn)/max(mx, 1);
  float hu = 0;
  if (mx - mn > 0.001) {
    if (mx == r) hu = 60*(((g - b)/(mx - mn)) % 6);
    else if (mx == g) hu = 60*((b - r)/(mx - mn) + 2);
    else hu = 60*((r - g)/(mx - mn) + 4);
  }
  if (hu < 0) hu += 360;
  float dh = min(hu, 360 - hu);
  float keep = exp(-sq(dh/7))*constrain((sat - 0.45)*4, 0, 1);
  float[] grey = {L*0.97 + 5, L*0.99 + 3, L*1.03 + 2};
  float[] red = {min(255, r*1.12), g*0.85, b*0.85};
  return mixc(grey, red, keep);
}

int C(float[] c) { return look.tone(c[0], c[1], c[2], 255); }
int C(float[] c, float a) { return look.tone(c[0], c[1], c[2], a); }
int C(float r, float g, float b) { return look.tone(r, g, b, 255); }
int C(float r, float g, float b, float a) { return look.tone(r, g, b, a); }
// the hoarding is lit at dusk: its colours bypass the dusk light
int E(float[] c) { return look.dusk ? color(c[0], c[1], c[2]) : C(c); }
float[] sh(float[] c, float k) { return new float[]{c[0]*k, c[1]*k, c[2]*k}; }
float[] mixc(float[] a, float[] b, float t) {
  return new float[]{lerp(a[0], b[0], t), lerp(a[1], b[1], t), lerp(a[2], b[2], t)};
}
float rr(Random r, float a, float b) { return a + r.nextFloat()*(b - a); }
int[] shuffled(Random r, int n) {
  ArrayList<Integer> l = new ArrayList<Integer>();
  for (int i = 0; i < n; i++) l.add(i);
  Collections.shuffle(l, r);
  int[] o = new int[n];
  for (int i = 0; i < n; i++) o[i] = l.get(i);
  return o;
}

// ===================================================================
//  WORLD
// ===================================================================
class House {
  int id, floors, roof, wallI, trimI, curtI, doorI, stairSide, wallC;
  float x, w, lean, droop, doorOff;
  boolean dish, ac;
  String banner;
  float[] eye = new float[4];
  float cx() { return x + w/2; }
  float slab() { return 0.45 + floors*3.1; }
  float rise() { return floors == 1 ? 2.4 : 2.2; }
  float gx() { return cx() + doorOff; }
}

class Plant {
  int kind;        // 0 palm, 1 banana, 2 shrub, 3 hibiscus, 4 canopy
  float x, h, bx, r, sd;
}

class Board {
  float cx, w, ph, legs, sd;
  String l1, l2;
  float y0() { return BASE - legs - ph; }
  float y1() { return BASE - legs; }
}

class Ghost {
  String txt;
  float x, y, h, rot;
  boolean bubble;
}

class World {
  ArrayList<House> houses = new ArrayList<House>();
  ArrayList<Plant> plants = new ArrayList<Plant>();
  ArrayList<float[]> far = new ArrayList<float[]>();
  ArrayList<Ghost> ghosts = new ArrayList<Ghost>();
  ArrayList<float[]> scooters = new ArrayList<float[]>();
  Board[] boards = new Board[2];
  float[] poles, crows;
  float towerX, heronX, heronY, boatX, boatY;

  World(long sd) {
    Random r = new Random(sd);
    int[] wo = shuffled(r, WALLS.length);
    float cur = 50;
    int id = 0;
    while (true) {
      float w = S*rr(r, 6.8, 9.4);
      if (cur + w > W - 50) break;
      House h = new House();
      h.id = id;
      h.x = cur;
      h.w = w;
      h.floors = r.nextFloat() < 0.22 ? 1 : 2;
      h.roof = (h.floors == 1) ? 0 : (r.nextBoolean() ? 0 : 1);
      h.lean = radians(rr(r, -1.4, 1.4));
      h.droop = rr(r, 0.3, 0.7);
      h.doorOff = rr(r, -0.2, 0.2)*w;
      h.wallI = (id < wo.length) ? wo[id] : r.nextInt(WALLS.length);
      h.trimI = r.nextInt(TRIMS.length);
      h.curtI = r.nextInt(CURTS.length);
      h.doorI = r.nextInt(DOORS.length);
      h.wallC = r.nextInt(CWALLS.length);
      h.dish = r.nextFloat() < 0.6;
      h.ac = r.nextFloat() < 0.5;
      h.stairSide = r.nextBoolean() ? -1 : 1;
      houses.add(h);
      id++;
      cur += w + rr(r, 14, 44);
    }
    House last = houses.get(houses.size() - 1);
    float shift = (W - (last.x + last.w - 50))/2 - 50;
    for (House h : houses) h.x += shift;
    String[] bn = {"SALE", "EMI", "OFFER", "₹0", "NEW", "LIKE"};
    int b = 0;
    for (int i = 1; i < houses.size(); i += 2) houses.get(i).banner = bn[(b++) % bn.length];

    Board b0 = new Board();
    b0.cx = W*0.66 + rr(r, -40, 40);
    b0.w = 24*S; b0.ph = 10*S; b0.legs = 10*S;
    b0.l1 = "0% EMI"; b0.l2 = "BUY NOW"; b0.sd = 11;
    Board b1 = new Board();
    b1.cx = W*0.2 + rr(r, -30, 30);
    b1.w = 17*S; b1.ph = 8*S; b1.legs = 13*S;
    b1.l1 = "FREE DATA"; b1.l2 = "♥ 99+"; b1.sd = 23;
    boards[0] = b0;
    boards[1] = b1;
    towerX = W*0.43 + rr(r, -30, 30);

    ArrayList<Float> pl = new ArrayList<Float>();
    for (float x = -160 + rr(r, 0, 60); x < W + 500; x += rr(r, 330, 400)) pl.add(x);
    poles = new float[pl.size()];
    for (int i = 0; i < poles.length; i++) poles[i] = pl.get(i);
    crows = new float[]{rr(r, 300, 700), rr(r, 1150, 1350), rr(r, 1500, 1800)};

    for (int k = 0; k < 12; k++) {
      Plant p = new Plant();
      p.kind = 0;
      p.x = rr(r, 30, W - 30);
      p.h = rr(r, 10, 16);
      p.bx = rr(r, -2.6, 2.6);
      p.sd = r.nextFloat()*100;
      plants.add(p);
    }
    for (int k = 0; k < 5; k++) {
      Plant p = new Plant();
      p.kind = 4;
      p.x = rr(r, 60, W - 60);
      p.h = rr(r, 8, 11);
      p.r = rr(r, 3.5, 5.5);
      p.sd = r.nextFloat()*100;
      plants.add(p);
    }
    for (int k = 0; k < 16; k++) {
      Plant p = new Plant();
      p.kind = (k < 5) ? 1 : (k < 9 ? 3 : 2);
      p.x = rr(r, 20, W - 20);
      p.h = (p.kind == 1) ? rr(r, 3.2, 4.4) : rr(r, 1.6, 2.6);
      p.r = rr(r, 0.8, 1.5);
      p.sd = r.nextFloat()*100;
      plants.add(p);
    }
    for (int k = 0; k < 70; k++) {
      float x = rr(r, 0, W);
      far.add(new float[]{x, rr(r, 0, 1), rr(r, 9, 22), rr(r, 7, 14), r.nextInt(WALLS.length)});
    }
    for (int k = 0; k < 3; k++) {
      House h = houses.get(1 + r.nextInt(houses.size() - 2));
      scooters.add(new float[]{h.gx() + (r.nextBoolean() ? 1 : -1)*rr(r, 34, 60), k % 2, r.nextBoolean() ? 1 : -1});
    }
    heronX = rr(r, W*0.6, W*0.84);
    heronY = WATER1 + rr(r, 70, 130);
    boatX = rr(r, W*0.26, W*0.4);
    boatY = WATER0 + rr(r, 120, 180);

    // messages in the sky: 0..6 are the base, all that fit in panel 02
    String[] gw = {"SALE", "LIKE", "0% EMI", "♥ 99+", "BUY NOW", "FOLLOW", "NEW", "OFFER", "SHARE",
                   "FREE", "DEAL", "♥", "SUBSCRIBE", "LIMITED", "BUY", "EMI"};
    for (int k = 0; k < gw.length; k++) {
      Ghost gst = new Ghost();
      gst.txt = gw[k];
      gst.bubble = (k % 3 == 1);
      gst.rot = rr(r, -0.1, 0.1);
      boolean placed = false;
      for (int tries = 0; tries < 400; tries++) {
        gst.h = (k < 7) ? rr(r, 46, 92) : rr(r, 40, 66);
        float tw = textW(gst.txt, gst.h);
        gst.x = rr(r, 30 + gst.h*0.5, max(40, W - 30 - tw - gst.h*0.5));
        gst.y = rr(r, 40 + gst.h*1.5, BASE - 330);
        float ax0 = gst.x - gst.h*0.6, ax1 = gst.x + tw + gst.h*0.6, ay0 = gst.y - gst.h*1.5, ay1 = gst.y + gst.h*1.0;
        boolean ok = !(ax0 < 600 && ay0 < 470);                      // the near palm's crown
        for (Board bd : boards) {
          if (ax0 < bd.cx + bd.w/2 + 20 && ax1 > bd.cx - bd.w/2 - 20 && ay1 > bd.y0() - 30) ok = false;
        }
        if (ax1 > towerX - 60 && ax0 < towerX + 60 && ay1 > BASE - 30*S - 40) ok = false;
        for (Ghost o : ghosts) {
          float ow = textW(o.txt, o.h);
          float bx0 = o.x - o.h*0.6, bx1 = o.x + ow + o.h*0.6, by0 = o.y - o.h*1.5, by1 = o.y + o.h*1.0;
          if (ax0 < bx1 + 18 && bx0 < ax1 + 18 && ay0 < by1 + 18 && by0 < ay1 + 18) { ok = false; break; }
        }
        if (ok) { placed = true; break; }
      }
      if (placed || k < 7) ghosts.add(gst);
    }
  }

  float wireY(float x, int k) {
    for (int i = 0; i < poles.length - 1; i++) {
      if (x >= poles[i] && x <= poles[i+1]) {
        float t = (x - poles[i])/(poles[i+1] - poles[i]);
        return poleTop() + k*0.5*S + 0.6*S*4*t*(1 - t);
      }
    }
    return poleTop() + k*0.5*S;
  }
}

float poleTop() { return BASE + 14 - 8.6*S; }

float hillY(float x) {
  return BASE - 120 - 90*noise(x*0.0014, 3.3) - 50*noise(x*0.006, 7.7);
}

// ===================================================================
//  LAYERS PAINTED LAST: lettering and wires
// ===================================================================
ArrayList<TStroke> buildType(boolean forPaint) {
  ArrayList<TStroke> out = new ArrayList<TStroke>();
  int nb = look.comm > 0 ? 2 : 1;
  for (int k = 0; k < nb; k++) {
    Board b = world.boards[k];
    float x0 = b.cx - b.w/2, y0 = b.y0();
    float textArea = b.w*0.62;
    float h1 = min(b.ph*0.4, (textArea - 24)/textW(b.l1, 1));
    float h2 = min(b.ph*0.2, (textArea - 30)/textW(b.l2, 1));
    out.addAll(typeset(b.l1, x0 + 14, y0 + b.ph*0.52, h1, h1*0.16, E(INKS[0]), -0.02, b.sd, false, true));
    out.addAll(typeset(b.l2, x0 + 16, y0 + b.ph*0.84, h2, h2*0.17, E(INKS[1]), 0, b.sd + 3, false, true));
    out.addAll(faceStrokes(x0 + b.w*0.81, y0 + b.ph*0.5, b.ph*0.56, E(new float[]{250,246,236}), b.sd, true));
  }
  if (look.comm > 0) {
    // banners over the houses' faces
    for (House h : world.houses) {
      if (h.banner == null) continue;
      float[] r = bannerRect(h);
      float hh = min((r[3] - r[1])*0.66, (r[2] - r[0] - 10)/textW(h.banner, 1));
      float tw = textW(h.banner, hh);
      out.addAll(typeset(h.banner, (r[0] + r[2])/2 - tw/2, (r[1] + r[3])/2 + hh/2, hh, max(1.4, hh*0.17), C(INKS[0]), h.lean*look.sag, h.id*7, false, true));
    }
    if (forPaint) {
      for (Ghost gst : world.ghosts) {
        out.addAll(typeset(gst.txt, gst.x, gst.y, gst.h, gst.h*0.13, C(250, 246, 236), gst.rot, gst.x*0.01, false, true));
        if (gst.bubble) out.add(bubble(gst, C(250, 246, 236)));
      }
    }
  }
  return out;
}

// world rect of a house banner: across the mouth of a two-storey house,
// across the eyes of a single-storey one
float[] bannerRect(House h) {
  float y0, y1;
  if (h.floors == 2) { y0 = BASE - 3.05*S; y1 = BASE - 2.0*S; }
  else { y0 = BASE - 2.55*S; y1 = BASE - 1.45*S; }
  return new float[]{h.cx() - h.w*0.4, y0, h.cx() + h.w*0.4, y1};
}

TStroke bubble(Ghost gst, int col) {
  float tw = textW(gst.txt, gst.h);
  float x0 = gst.x - gst.h*0.5, x1 = gst.x + tw + gst.h*0.5;
  float y0 = gst.y - gst.h*1.45, y1 = gst.y + gst.h*0.45;
  float[] b = roundPoly(new float[]{x0, y0, x1, y0, x1, y1, x0 + gst.h*1.1, y1, x0 + gst.h*0.3, y1 + gst.h*0.55, x0 + gst.h*0.5, y1, x0, y1}, gst.h*0.5, true);
  float[] p = resample(b, 2, true);
  float[] c = new float[p.length + 2];
  System.arraycopy(p, 0, c, 0, p.length);
  c[p.length] = p[0];
  c[p.length+1] = p[1];
  wobble(c, 1.5, gst.x);
  return mkStroke(c, gst.h*0.07, col, false);
}

ArrayList<TStroke> buildLines() {
  ArrayList<TStroke> out = new ArrayList<TStroke>();
  int wc = C(INK_DARK);
  float[] P = world.poles;
  for (int k = 0; k < 3; k++) {
    for (int i = 0; i < P.length - 1; i++) {
      int n = max(4, (int)((P[i+1] - P[i])/2));
      float[] p = new float[n*2];
      for (int j = 0; j < n; j++) {
        float t = j/(float)(n - 1);
        p[j*2] = lerp(P[i], P[i+1], t);
        p[j*2+1] = poleTop() + k*0.5*S + 0.6*S*4*t*(1 - t);
      }
      out.add(mkStroke(p, 1.3, wc, false));
    }
  }
  for (House h : world.houses) {
    float pole = P[0];
    for (float x : P) if (abs(x - h.cx()) < abs(pole - h.cx())) pole = x;
    float ax = h.cx() + (pole < h.cx() ? -1 : 1)*h.w*0.36;
    float ah = (h.roof == 0) ? h.slab() - 0.1 : h.slab() + 0.6;
    int n = 50;
    float[] e = new float[n*2];
    for (int j = 0; j < n; j++) {
      float t = j/(float)(n - 1);
      e[j*2] = lerp(pole, ax, t);
      e[j*2+1] = lerp(poleTop() + 1.0*S, BASE - ah*S, t) + 0.3*S*4*t*(1 - t);
    }
    out.add(mkStroke(e, 1.0, wc, false));
  }
  return out;
}

// ===================================================================
//  REFERENCE: the world drawn flat
// ===================================================================
void drawReference(PGraphics g) {
  etchPaths.clear();
  HR = 0; HX = 0; HY = 0;
  g.beginDraw();
  g.noStroke();
  g.background(C(SKY_LOW));
  sky(g);
  hills(g);
  board(g, world.boards[0]);
  if (look.comm > 0) board(g, world.boards[1]);
  tower(g);
  for (Plant p : world.plants) if (p.kind == 4) canopy(g, p);
  for (Plant p : world.plants) if (p.kind == 0) palm(g, p.x, BASE, p.h*S, p.bx*S*(1 + (look.sag - 1)*0.25), p.sd, S, false);
  for (House h : world.houses) house(g, h);
  walls(g);
  for (Plant p : world.plants) if (p.kind == 1 || p.kind == 2 || p.kind == 3) smallPlant(g, p);
  bund(g);
  renderStrokes(g, buildLines());
  renderStrokes(g, buildType(false));
  crows(g);
  reflect(g);
  water(g);
  paddy(g);
  HR = 0; HX = 0; HY = 0;
  recLevel = 2;
  palm(g, 70, H + 30, H - 120, 240, 4.4, 62, true);
  recLevel = 0;
  if (look.dusk) dusk(g);
  g.endDraw();
}

void sky(PGraphics g) {
  for (int y = 0; y < BASE + 4; y++) {
    float t = pow(y/BASE, 0.8);
    g.fill(C(mixc(SKY_TOP, SKY_LOW, t)));
    g.rect(0, y, W, 1.5);
  }
  Random r = new Random(seed*7 + 1);
  for (int k = 0; k < 11; k++) {
    float cx = rr(r, -100, W + 100), cy = rr(r, 50, 520);
    boolean dark = r.nextFloat() < 0.45;
    g.fill(dark ? C(120, 132, 142, 46) : C(248, 244, 232, 62));
    blob(g, cx, cy, rr(r, 170, 420), rr(r, 36, 90), 0.35, k*3.3);
  }
  int n = look.comm > 0 ? world.ghosts.size() : min(7, world.ghosts.size());
  for (int k = 0; k < n; k++) {
    Ghost gst = world.ghosts.get(k);
    int col = C(250, 248, 240, look.ghostA);
    renderStrokes(g, typeset(gst.txt, gst.x, gst.y, gst.h, gst.h*0.13, col, gst.rot, gst.x*0.01, false, true));
    if (gst.bubble) {
      ArrayList<TStroke> b = new ArrayList<TStroke>();
      b.add(bubble(gst, col));
      renderStrokes(g, b);
    }
  }
}

void hills(PGraphics g) {
  // far hills, crowded with more houses no one sees either
  g.fill(C(HAZE));
  g.beginShape();
  for (int x = -10; x <= W + 10; x += 6) g.vertex(x, hillY(x));
  g.vertex(W + 10, BASE + 2);
  g.vertex(-10, BASE + 2);
  g.endShape(CLOSE);
  for (float[] f : world.far) {
    float x = f[0];
    float top = hillY(x);
    float y = lerp(top + 14, BASE - 40, f[1]);
    float[] c = mixc(WALLS[(int)f[4]], HAZE, 0.55);
    g.fill(C(c));
    fillShape(g, organic(rectP(x - f[2]/2, y - f[3], x + f[2]/2, y), 2, 0.6, x));
    g.fill(C(mixc(TERRA, HAZE, 0.5)));
    fillShape(g, organic(new float[]{x - f[2]/2 - 2, y - f[3], x + f[2]/2 + 2, y - f[3], x, y - f[3] - f[2]*0.4}, 2, 0.5, x + 1));
    g.fill(C(mixc(new float[]{40,44,52}, HAZE, 0.5)));
    g.rect(x - f[2]*0.3, y - f[3]*0.65, 2, 2);
    g.rect(x + f[2]*0.15, y - f[3]*0.65, 2, 2);
  }
  // near tree line behind the row
  g.fill(C(96, 124, 104));
  g.beginShape();
  for (int x = -10; x <= W + 10; x += 6) g.vertex(x, BASE - 46 - 34*noise(x*0.01, 1.1) - 12*noise(x*0.05, 2.2));
  g.vertex(W + 10, BASE + 2);
  g.vertex(-10, BASE + 2);
  g.endShape(CLOSE);
}

void board(PGraphics g, Board b) {
  float x0 = b.cx - b.w/2, x1 = b.cx + b.w/2, y0 = b.y0(), y1 = b.y1();
  int steel = C(70, 72, 76);
  for (int s = -1; s <= 1; s += 2) {
    float lx = b.cx + s*b.w*0.25;
    g.fill(steel);
    fillShape(g, organic(rectP(lx - 3.5, y1 - 4, lx + 3.5, BASE + 2), 2, 0.8*look.wob, b.sd + s));
  }
  wline(g, new float[]{b.cx - b.w*0.25, y1 + 10, b.cx + b.w*0.25, BASE - 20}, 2, steel, 0.8, b.sd + 5);
  wline(g, new float[]{b.cx + b.w*0.25, y1 + 10, b.cx - b.w*0.25, BASE - 20}, 2, steel, 0.8, b.sd + 6);
  g.fill(steel);
  fillShape(g, organic(rectP(x0 - 4, y1 - 2, x1 + 4, y1 + 5), 2, 0.8, b.sd + 7));
  recLevel = 1;
  g.fill(look.dusk ? color(60, 60, 64) : C(58, 58, 62));
  fillShape(g, organic(rectP(x0 - 5, y0 - 5, x1 + 5, y1 + 3), 6, 1.0*look.wob, b.sd + 8));
  recLevel = 0;
  g.fill(E(new float[]{244, 240, 226}));
  fillShape(g, organic(rectP(x0, y0, x1, y1 - 2), 6, 1.0*look.wob, b.sd + 9));
  // the brand's red blob, carrying the smiling face
  g.fill(E(INKS[0]));
  blob(g, x0 + b.w*0.81, y0 + b.ph*0.5, b.w*0.15, b.ph*0.44, 0.18*look.wob, b.sd + 10);
  // floodlights on arms over the top edge
  for (int k = 0; k < 3; k++) {
    float lx = lerp(x0 + b.w*0.15, x1 - b.w*0.15, k/2.0);
    wline(g, new float[]{lx, y0 - 4, lx, y0 - 14, lx + 6, y0 - 18}, 1.6, steel, 0.4, b.sd + 20 + k);
    g.fill(look.dusk ? color(255, 244, 210) : C(196, 198, 196));
    blob(g, lx + 7, y0 - 18, 3.5, 2.2, 0.1, b.sd + 30 + k);
  }
}

void tower(PGraphics g) {
  // a mobile tower dressed up as a coconut palm
  float x = world.towerX, top = BASE - 30*S;
  int n = 40;
  float[] tr = new float[n*4];
  for (int i = 0; i < n; i++) {
    float t = i/(float)(n - 1);
    float cx = x + sin(t*2.2)*3*look.sag;
    float w = lerp(7, 3.5, t);
    tr[i*2] = cx - w;
    tr[i*2+1] = lerp(BASE, top, t);
    tr[(2*n - 1 - i)*2] = cx + w;
    tr[(2*n - 1 - i)*2+1] = lerp(BASE, top, t);
  }
  wobble(tr, 0.8*look.wob, 91);
  recLevel = 1;
  g.fill(C(118, 110, 100));
  fillShape(g, tr);
  recLevel = 0;
  Random R = new Random(seed + 5);
  for (int f = 0; f < 14; f++) {
    float ang = radians(-170 + f*(160/13.0) + rr(R, -5, 5));
    float[] sp = arcSpine(x, top + 10, ang, 3.4*S*rr(R, 0.85, 1.1), 0.18, 14);
    g.fill(C(f % 2 == 0 ? new float[]{84,132,92} : new float[]{70,116,82}));
    blade(g, sp, 0.36*S, 0.2, 91 + f);
  }
  for (int k = 0; k < 6; k++) {
    float a = -1.2 + k*0.48;
    float ax = x + cos(a)*10, ay = top + 14 + abs(sin(a))*4 + (k % 2)*16;
    g.fill(C(206, 206, 200));
    fillShape(g, organic(rectP(ax - 2.5, ay - 9, ax + 2.5, ay + 9), 2, 0.4, 95 + k));
  }
  g.fill(look.dusk ? color(255, 60, 40) : C(200, 40, 36));
  blob(g, x, top - 4, 2.6, 2.6, 0.1, 99);
}

void palm(PGraphics g, float x, float by, float hpx, float bx, float sd, float sc, boolean near) {
  float tx = x + bx, ty = by - hpx;
  int n = 48;
  float[] tr = new float[n*4];
  float[] cxs = new float[n], ys = new float[n];
  for (int i = 0; i < n; i++) {
    float t = i/(float)(n - 1);
    float cx = x + bx*(t*t*0.7 + t*0.3) + sin(t*PI)*bx*0.25;
    float y = lerp(by, ty, t);
    float w = max(1.4, (near ? lerp(0.62, 0.3, t) : lerp(0.38, 0.22, t))*sc*0.5);
    cxs[i] = cx; ys[i] = y;
    tr[i*2] = cx - w; tr[i*2+1] = y;
    tr[(2*n - 1 - i)*2] = cx + w; tr[(2*n - 1 - i)*2+1] = y;
  }
  wobble(tr, (near ? 2.5 : 0.8)*look.wob, sd);
  g.fill(near ? C(70, 62, 52) : C(132, 120, 102));
  fillShape(g, tr);
  if (near) {
    g.fill(C(96, 86, 72));
    for (int i = 2; i < n - 2; i += 2) blob(g, cxs[i] + 4, ys[i], sc*0.1, 2.2, 0.3, sd + i);
  }
  Random R = new Random((long)(sd*1000));
  float[][] greens = near ? new float[][]{{40,62,36},{58,86,44},{30,50,30},{50,76,40}}
                          : new float[][]{{70,104,52},{96,128,60},{52,80,44},{84,116,58}};
  for (int f = 0; f < 18; f++) {
    float ang = (f < 13) ? radians(-172 + f*(164/12.0) + rr(R, -6, 6)) : radians(rr(R, 20, 160));
    float len = 4.6*sc*rr(R, 0.8, 1.1);
    float grav = (f < 13) ? 0.7 + 0.35*abs(cos(ang)) : 0.2;
    float[] sp = arcSpine(tx, ty, ang, len, grav*(0.8 + 0.2*look.sag), 26);
    boolean dry = R.nextFloat() < 0.12;
    g.fill(dry ? C(near ? new float[]{110,86,52} : new float[]{150,122,72}) : C(greens[f % 4]));
    blade(g, sp, 0.42*sc, 0.75, sd + f);
  }
  g.fill(C(120, 96, 50));
  for (int k = 0; k < 6; k++) blob(g, tx + rr(R, -0.35, 0.35)*sc, ty + rr(R, 0.05, 0.45)*sc, sc*0.18, sc*0.18, 0.15, k + sd);
}

void canopy(PGraphics g, Plant p) {
  float cx = p.x, cy = BASE - (p.h - p.r*0.9)*S;
  Random R = new Random((long)(p.sd*1000) + 3);
  for (int k = 0; k < 10; k++) {
    float a = rr(R, 0, TWO_PI), d = rr(R, 0, p.r*0.55)*S;
    float r0 = p.r*S*rr(R, 0.38, 0.6);
    boolean lit = sin(a) < 0 && cos(a) < 0.3;
    g.fill(C(lit ? new float[]{78,112,58} : new float[]{44,72,42}));
    blob(g, cx + cos(a)*d, cy + sin(a)*d*0.8, r0, r0*0.85, 0.3*look.wob, p.sd + k);
  }
}

void smallPlant(PGraphics g, Plant p) {
  Random R = new Random((long)(p.sd*1000) + 11);
  if (p.kind == 1) {
    float top = BASE - p.h*0.55*S;
    g.fill(C(120, 140, 70));
    fillShape(g, organic(rectP(p.x - 2, top, p.x + 2, BASE), 2, 0.6, p.sd));
    for (int k = 0; k < 7; k++) {
      float ang = radians(-90 + (k - 3)*26 + rr(R, -8, 8));
      float[] sp = arcSpine(p.x, top, ang, rr(R, 2.0, 2.6)*S, 0.5 + 0.25*look.sag, 14);
      g.fill(C(k % 2 == 0 ? new float[]{134,166,70} : new float[]{108,142,58}));
      blade(g, sp, 0.3*S, 0.25, p.sd + k);
    }
    return;
  }
  float hh = p.h*S;
  for (int k = 0; k < 4; k++) {
    float x = p.x + rr(R, -0.5, 0.5)*p.r*S;
    float y = BASE - hh*rr(R, 0.35, 0.65);
    g.fill(C(k % 2 == 0 ? new float[]{66,100,52} : new float[]{88,122,60}));
    blob(g, x, y, p.r*S*0.8, hh*0.45, 0.35*look.wob, p.sd + k);
  }
  if (p.kind == 3) {
    g.fill(C(214, 36, 44));
    for (int k = 0; k < 7; k++) blob(g, p.x + rr(R, -0.8, 0.8)*p.r*S, BASE - hh*rr(R, 0.3, 0.9), 1.8, 1.6, 0.2, k);
  }
}

void house(PGraphics g, House h) {
  HR = h.lean*look.sag;
  HX = h.cx();
  HY = BASE;
  float hw = h.w/2, sl = h.slab()*S, amp = 0.9*look.wob, sd = h.id*17.3 + 5;
  float[] wall = WALLS[h.wallI], trim = TRIMS[h.trimI];
  float bulge = (look.sag - 1)*2.2;
  float sx = h.stairSide*(hw - 1.9*S);
  if (h.roof == 1) {
    float stTop = sl + 0.2*S + 2.7*S;
    g.fill(C(sh(wall, 0.9)));
    orect(g, sx - 1.6*S, -stTop, sx + 1.6*S, -sl, 3, amp, sd + 30);
    g.fill(C(trim));
    orect(g, sx - 1.85*S, -stTop - 0.2*S, sx + 1.85*S, -stTop + 0.05*S, 2, amp, sd + 31);
    g.fill(C(30, 34, 44));
    orect(g, sx - 0.35*S, -stTop + 0.7*S, sx + 0.35*S, -stTop + 1.4*S, 2, amp*0.5, sd + 32);
    float tb = -stTop - 0.2*S;
    g.fill(C(32, 34, 38));
    fillShape(g, organic(L(sx + 0.2*S, tb - 1.3*S, sx + 1.4*S, tb - 1.3*S, sx + 1.4*S, tb, sx + 0.2*S, tb), 6, amp*0.6, sd + 33));
  }
  recLevel = 1;
  g.fill(C(wall));
  fillShape(g, organic(L(-hw, -sl, 0, -sl - bulge, hw, -sl, hw + bulge, -sl*0.5, hw, 0, -hw, 0, -hw - bulge, -sl*0.5), 4, amp, sd));
  recLevel = 0;
  for (int k = 0; k < 6; k++) {
    g.fill(C(0, 0, 0, 7));
    orect(g, lerp(-hw, hw, 0.4 + k*0.1), -sl, hw, 0, 2, amp*0.5, sd + k);
  }
  Random R = new Random((long)(sd*77));
  for (int k = 0; k < 5; k++) {
    float x = rr(R, -hw + 4, hw - 4);
    g.fill(C(52, 60, 50, 40));
    orect(g, x - rr(R, 1, 2.4), -sl, x + rr(R, 1, 2.4), -sl + rr(R, 0.8, 2.4)*S, 2, 1.0, sd + 40 + k);
  }
  g.fill(C(sh(wall, 0.72)));
  orect(g, -hw - 2, -0.45*S, hw + 2, 0, 2, amp, sd + 1);
  if (h.floors == 2) {
    float y = -(0.45 + 3.1)*S;
    g.fill(C(0, 0, 0, 40));
    orect(g, -hw, y, hw, y + 0.45*S, 2, amp, sd + 2);
    g.fill(C(trim));
    orect(g, -hw - 0.3*S, y - 0.22*S, hw + 0.3*S, y, 2, amp, sd + 3);
  }
  float doorX = h.doorOff;
  float dr = h.droop*look.sag;
  if (h.floors == 2) {
    float ex = max(h.w*0.25, 1.6*S);
    eye(g, h, -ex, 4.25, 5.9, 1.8, dr, -1, 0.42 + h.droop*0.12, sd + 50, true);
    eye(g, h, ex, 4.25, 5.9, 1.8, dr*0.8, 1, 0.5, sd + 60, false);
    float lx = (doorX < 0) ? h.w*0.27 : -h.w*0.27;
    eye(g, h, lx, 1.2, 2.5, 1.6, dr*0.6, (lx < 0) ? -1 : 1, 0.3, sd + 70, false);
    if (h.ac) {
      float ax = ex*((h.id % 2 == 0) ? 1 : -1);
      g.fill(C(212, 212, 206));
      orect(g, ax - 0.45*S, -4.05*S, ax + 0.45*S, -3.45*S, 2, amp*0.5, sd + 80);
      g.fill(C(48, 56, 48, 55));
      orect(g, ax + 0.3*S, -3.45*S, ax + 0.3*S + 2, -2.0*S, 1, 0.8, sd + 82);
    }
  } else {
    float ex = h.w*0.27;
    eye(g, h, -ex, 1.0, 2.6, 1.8, dr, -1, 0.45, sd + 50, true);
    eye(g, h, ex, 1.0, 2.6, 1.8, dr*0.8, 1, 0.52, sd + 60, false);
  }
  g.fill(C(sh(trim, 0.92)));
  orect(g, doorX - 0.7*S, -2.85*S, doorX + 0.7*S, -2.65*S, 2, amp, sd + 90);
  g.fill(C(DOORS[h.doorI]));
  orect(g, doorX - 0.55*S, -2.6*S, doorX + 0.55*S, -0.45*S, 2, amp, sd + 92);
  g.fill(C(sh(DOORS[h.doorI], 0.7)));
  orect(g, doorX - 0.5, -2.5*S, doorX + 0.5, -0.5*S, 1, 0.3, sd + 93);
  if (look.comm > 0 && h.banner != null) {
    float[] r = bannerRect(h);
    HR = h.lean*look.sag; HX = h.cx(); HY = BASE;
    g.fill(C(250, 224, 70));
    orect(g, r[0] - h.cx(), r[1] - BASE, r[2] - h.cx(), r[3] - BASE, 2, amp*0.8, sd + 95);
    g.fill(C(0, 0, 0, 50));
    orect(g, r[0] - h.cx(), r[3] - BASE, r[2] - h.cx(), r[3] - BASE + 3, 1, amp*0.5, sd + 96);
  }
  if (h.roof == 0) {
    float eave = -(h.slab() + 0.1)*S, ov = 0.8*S;
    float ridge = eave - h.rise()*S*(1 + (look.sag - 1)*0.08);
    float rt = max(0.4*S, (h.w - 10*S)/2);
    g.fill(C(0, 0, 0, 60));
    orect(g, -hw, eave, hw, eave + 0.55*S, 2, amp, sd + 100);
    recLevel = 1;
    g.fill(C(TERRA));
    float slump = (look.sag - 1)*3;
    fillShape(g, organic(L(-hw - ov, eave, -hw*0.5, eave + slump, hw*0.5, eave + slump, hw + ov, eave, rt, ridge, -rt, ridge), 5, amp*1.2, sd + 101));
    recLevel = 0;
    g.fill(C(sh(TERRA, 1.14), 120));
    fillShape(g, organic(L(-hw - ov*0.4, eave - 3, -rt*0.4, ridge + 4, -rt*0.2, ridge + 7, -hw*0.2, eave - 3), 4, amp, sd + 102));
    g.fill(C(90, 48, 36));
    orect(g, -hw - ov, eave - 0.06*S, hw + ov, eave + 0.16*S, 1, amp, sd + 103);
    g.fill(C(188, 184, 172));
    fillShape(g, organic(L(-rt - 2, ridge + 2, rt + 2, ridge + 2, rt + 1, ridge - 3, -rt - 1, ridge - 3), 2, 0.5, sd + 120));
    if (h.dish) {
      g.fill(C(206, 206, 200));
      blob(g, L(hw - 0.6*S, 0)[0], BASE + eave - 0.9*S, 2.2, 4.2, 0.05, sd + 130);
    }
  } else {
    float top = sl + 0.2*S;
    g.fill(C(0, 0, 0, 55));
    orect(g, -hw, -sl, hw, -sl + 0.45*S, 2, amp, sd + 100);
    recLevel = 1;
    g.fill(C(mixc(wall, new float[]{250,248,240}, 0.18)));
    orect(g, -hw, -top - 0.95*S, hw, -top, 2, amp, sd + 101);
    recLevel = 0;
    g.fill(C(trim));
    orect(g, -hw - 0.25*S, -top, hw + 0.25*S, -sl, 1, amp, sd + 102);
    for (int k = 0; k < 4; k++) {
      float x = rr(R, -hw + 4, hw - 4);
      g.fill(C(48, 56, 46, 55));
      orect(g, x - 1.5, -top - 0.9*S, x + 1.8, -top - 0.9*S + rr(R, 0.4, 0.9)*S, 1, 0.6, sd + 104 + k);
    }
    if (h.dish) {
      float dx = -h.stairSide*(hw - 0.9*S);
      g.fill(C(206, 206, 200));
      float[] c = L(dx, -top - 1.4*S);
      blob(g, c[0], c[1], 2.2, 4.2, 0.05, sd + 130);
    }
  }
  HR = 0; HX = 0; HY = 0;
}

// a window read as an eye: curtain for a lid, sunshade for a brow
void eye(PGraphics g, House h, float cx, float sillM, float topM, float wM, float droop,
         int outer, float lid, float sd, boolean record) {
  float x0 = cx - wM*S/2, x1 = cx + wM*S/2, y0 = -topM*S, y1 = -sillM*S;
  float amp = 0.7*look.wob;
  float[] trim = TRIMS[h.trimI], curt = CURTS[h.curtI];
  g.fill(C(0, 0, 0, 50));
  orect(g, x0 - 0.3*S, y0 - 0.35*S, x1 + 0.3*S, y0 + 0.2*S, 2, amp, sd);
  g.fill(C(trim));
  orect(g, x0 - 0.16*S, y0 - 0.16*S, x1 + 0.16*S, y1 + 0.16*S, 2.5, amp, sd + 1);
  g.fill(C(30, 34, 44));
  orect(g, x0, y0, x1, y1, 2.5, amp, sd + 2);
  if (record) {
    float[] a = L(x0, y0), b = L(x1, y1);
    h.eye[0] = min(a[0], b[0]); h.eye[1] = min(a[1], b[1]);
    h.eye[2] = max(a[0], b[0]); h.eye[3] = max(a[1], b[1]);
  }
  float hgt = y1 - y0;
  float lo = lid*(1 + droop*0.5), li = lid*(1 - droop*0.25);
  float lL = (outer < 0) ? lo : li, lR = (outer < 0) ? li : lo;
  float lm = max(lL, lR)*1.08;
  g.fill(C(curt));
  fillShape(g, organic(L(x0, y0, x1, y0, x1, y0 + hgt*lR, lerp(x0, x1, 0.5), y0 + hgt*lm, x0, y0 + hgt*lL), 2.5, amp, sd + 4));
  float inner = -outer;
  float cxl = cx + inner*wM*S*0.18;
  g.fill(C(236, 238, 240, 190));
  fillShape(g, organic(L(cxl - 1.5, y0 + hgt*lm + 2, cxl + 1.5, y0 + hgt*lm + 2, cxl + 1.5, y0 + hgt*lm + 4, cxl - 1.5, y0 + hgt*lm + 4), 1, 0.1, sd + 8));
  g.fill(C(sh(trim, 0.95)));
  orect(g, x0 - 0.22*S, y1 + 0.05*S, x1 + 0.22*S, y1 + 0.25*S, 1, amp, sd + 9);
  float by = y0 - 0.3*S, bt = max(2.4, 0.2*S), fall = droop*0.6*S;
  float bxIn = (outer < 0) ? x1 + 0.4*S : x0 - 0.4*S;
  float bxOut = (outer < 0) ? x0 - 0.4*S : x1 + 0.4*S;
  g.fill(C(sh(trim, 0.88)));
  fillShape(g, organic(L(bxIn, by, cx, by + fall*0.3, bxOut, by + fall, bxOut, by + fall + bt, cx, by + fall*0.3 + bt, bxIn, by + bt), 2, amp, sd + 10));
  Random R = new Random((long)(sd*131));
  float tx = (outer < 0) ? x0 + 2 : x1 - 2;
  float len = (0.8 + droop*1.5 + R.nextFloat()*0.6)*S;
  g.fill(C(44, 52, 44, 66));
  fillShape(g, organic(L(tx - 1.3, y1 + 0.25*S, tx + 1.6, y1 + 0.25*S, tx + 1, y1 + 0.25*S + len, tx - 0.8, y1 + 0.25*S + len), 1, 0.8, sd + 11));
}

void walls(PGraphics g) {
  float wt = BASE - 1.4*S, gh = 1.3*S;
  ArrayList<House> hs = world.houses;
  for (int i = 0; i <= hs.size(); i++) {
    float a = (i == 0) ? -20 : hs.get(i-1).gx() + gh + 0.4*S;
    float b = (i == hs.size()) ? W + 20 : hs.get(i).gx() - gh - 0.4*S;
    // each owner paints their own stretch, split halfway between houses
    float mid = (i == 0 || i == hs.size()) ? -999 : (hs.get(i-1).x + hs.get(i-1).w + hs.get(i).x)/2;
    for (int part = 0; part < 2; part++) {
      float pa = (part == 0) ? a : max(a, mid), pb = (part == 0) ? (mid > a ? min(b, mid) : b) : b;
      if (part == 1 && mid < a) continue;
      if (pb - pa < 2) continue;
      int owner = constrain((part == 0) ? i - 1 : i, 0, hs.size() - 1);
      float[] wc = CWALLS[hs.get(owner).wallC];
      recLevel = 2;
      g.fill(C(wc));
      fillShape(g, organic(rectP(pa, wt, pb, BASE + 2), 1.5, 0.8*look.wob, i*9 + part));
      recLevel = 0;
      g.fill(C(sh(wc, 0.85)));
      fillShape(g, organic(rectP(pa - 1, wt - 0.15*S, pb + 1, wt + 0.08*S), 1, 0.6*look.wob, i*9 + part + 50));
      g.fill(C(60, 58, 48, 50));
      fillShape(g, organic(rectP(pa, BASE - 0.45*S, pb, BASE + 2), 1, 1.2, i*9 + part + 60));
    }
  }
  for (House h : hs) {
    float[] wc = CWALLS[h.wallC];
    for (int s = -1; s <= 1; s += 2) {
      float px = h.gx() + s*(gh + 0.2*S);
      g.fill(C(mixc(wc, new float[]{250,248,240}, 0.2)));
      fillShape(g, organic(rectP(px - 0.22*S, BASE - 1.8*S, px + 0.22*S, BASE + 2), 1.5, 0.6*look.wob, h.id*5 + s));
      float hx = h.gx() + s*gh, lw = gh*cos(radians(55));
      g.fill(C(58, 82, 70));
      fillShape(g, organic(rectP(min(hx, hx - s*lw), BASE - 1.25*S, max(hx, hx - s*lw), BASE - 0.1*S), 1.5, 0.6*look.wob, h.id*5 + s + 40));
    }
  }
}

void bund(PGraphics g) {
  g.fill(C(156, 104, 78));
  fillShape(g, organic(rectP(-10, BASE, W + 10, BUND + 3), 2, 1.2, 501));
  g.fill(C(98, 124, 66));
  fillShape(g, organic(rectP(-10, BUND - 6, W + 10, BUND + 4), 2, 2.2*look.wob, 502));
  Random R = new Random(seed*13 + 5);
  for (int k = 0; k < 8; k++) {
    g.fill(C(mixc(SKY_TOP, new float[]{156,104,78}, 0.4), 170));
    blob(g, rr(R, 0, W), rr(R, BASE + 6, BUND - 10), rr(R, 10, 34), rr(R, 2, 4), 0.3, k + 510);
  }
  // poles on the bund
  for (float x : world.poles) {
    if (x < -20 || x > W + 20) continue;
    recLevel = 2;
    g.fill(C(170, 168, 160));
    fillShape(g, organic(rectP(x - 2.2, poleTop() - 4, x + 2.2, BASE + 16), 1, 0.5*look.wob, x));
    recLevel = 0;
    g.fill(C(80, 82, 86));
    fillShape(g, organic(rectP(x - 1, poleTop() - 2, x + 5, poleTop() + 1.4*S), 1, 0.3, x + 1));
  }
  // covered scooters, going nowhere
  for (float[] s : world.scooters) {
    float x = s[0], f = s[2], by = BASE + 16;
    float[] c = (s[1] == 0) ? new float[]{128, 40, 44} : new float[]{150, 152, 156};
    g.fill(C(30, 30, 32));
    blob(g, x - f*0.62*S, by - 0.27*S, 0.26*S, 0.27*S, 0.06, x);
    blob(g, x + f*0.62*S, by - 0.27*S, 0.26*S, 0.27*S, 0.06, x + 1);
    g.fill(C(c));
    fillShape(g, organic(new float[]{
      x - f*0.98*S, by - 0.42*S, x - f*0.95*S, by - 0.78*S, x - f*0.55*S, by - 0.96*S,
      x + f*0.05*S, by - 0.92*S, x + f*0.38*S, by - 0.86*S, x + f*0.6*S, by - 1.22*S,
      x + f*0.9*S, by - 1.0*S, x + f*0.98*S, by - 0.45*S, x + f*0.55*S, by - 0.3*S, x - f*0.6*S, by - 0.32*S}, 3, 0.7*look.wob, x + 2));
  }
}

void crows(PGraphics g) {
  for (float cx : world.crows) {
    float wy = world.wireY(cx, 0);
    g.fill(C(24, 24, 28));
    blob(g, cx, wy - 4, 4.6, 3.4, 0.15, cx);
    blob(g, cx + 4, wy - 7.5, 2.4, 2.2, 0.1, cx + 1);
    g.triangle(cx - 4, wy - 4, cx - 10, wy + 2, cx - 6, wy - 1);
  }
}

// the water is the reference itself, mirrored at the water's edge and rippled
void reflect(PGraphics g) {
  g.loadPixels();
  int[] px = g.pixels;
  float[] wc = look.dusk ? new float[]{18, 22, 34} : WATERC;
  int wci = C(wc);
  float wr = (wci >> 16) & 255, wg = (wci >> 8) & 255, wb = wci & 255;
  for (int y = (int)WATER0; y < (int)WATER1; y++) {
    float t = (y - WATER0)/(WATER1 - WATER0);
    int sy = constrain((int)(2*BUND - y), 0, H - 1);
    float amp = 1.5 + t*10;
    float k = 0.3 + 0.28*t;
    for (int x = 0; x < W; x++) {
      float off = amp*sin(y*0.5 + noise(x*0.004, y*0.03)*9);
      int sx = constrain((int)(x + off), 0, W - 1);
      int c = px[sy*W + sx];
      float r = ((c >> 16) & 255)*0.9, gg = ((c >> 8) & 255)*0.9, b = (c & 255)*0.9;
      px[y*W + x] = color(lerp(r, wr, k), lerp(gg, wg, k), lerp(b, wb, k));
    }
  }
  g.updatePixels();
}

void water(PGraphics g) {
  Random R = new Random(seed*17 + 3);
  for (int k = 0; k < 26; k++) {
    float y = rr(R, WATER0 + 6, WATER1 - 6);
    float x = rr(R, -50, W);
    int c = C(mixc(SKY_LOW, WATERC, 0.3), 110);
    float len = rr(R, 60, 260)*(0.5 + (y - WATER0)/(WATER1 - WATER0));
    recLevel = 2;
    g.fill(c);
    fillShape(g, organic(rectP(x, y, x + len, y + 1.6 + (y - WATER0)*0.006), 1, 1.0, k + 700));
    recLevel = 0;
  }
  for (int k = 0; k < 10; k++) {
    float hx = rr(R, 0, W), hy = rr(R, WATER0 + 30, WATER1 - 14);
    float sc = 0.6 + (hy - WATER0)/(WATER1 - WATER0);
    g.fill(C(84, 128, 62));
    blob(g, hx, hy, rr(R, 14, 34)*sc, rr(R, 5, 10)*sc, 0.4, k*3.1 + 120);
    g.fill(C(186, 160, 206));
    blob(g, hx + 4, hy - 2, 2.5*sc, 2*sc, 0.2, k + 130);
  }
  // an empty country boat, tied up
  float bx = world.boatX, by = world.boatY;
  g.fill(C(40, 30, 24, 120));
  blob(g, bx + 4, by + 10, 70, 6, 0.2, 140);
  recLevel = 1;
  g.fill(C(64, 44, 32));
  fillShape(g, organic(new float[]{bx - 78, by - 12, bx - 40, by, bx + 40, by, bx + 80, by - 14, bx + 60, by + 6, bx - 58, by + 6}, 8, 1.0*look.wob, 141));
  recLevel = 0;
  g.fill(C(96, 70, 50));
  fillShape(g, organic(new float[]{bx - 66, by - 8, bx + 68, by - 9, bx + 50, by - 2, bx - 48, by - 2}, 4, 0.8, 142));
  wline(g, new float[]{bx - 76, by - 10, bx - 120, by - 40, bx - 150, by - 60}, 1.2, C(60, 54, 46), 1.0, 143);
}

void paddy(PGraphics g) {
  g.fill(C(118, 104, 72));
  fillShape(g, organic(rectP(-10, WATER1 - 6, W + 10, WATER1 + 12), 3, 3*look.wob, 801));
  g.fill(C(124, 158, 66));
  g.rect(0, WATER1 + 10, W, H - WATER1);
  Random R = new Random(seed*19 + 7);
  // young, mature, harvested straw, young again, ripening
  float[][] fields = {{164,198,84},{92,128,52},{200,178,104},{140,178,70},{176,184,86}};
  float yPrev = WATER1 + 10;
  for (int k = 0; k < 4; k++) {
    // bunds spread apart as they come nearer, and swing in long curves
    float y0 = WATER1 + 10 + (H - WATER1)*pow((k + 1)/4.6, 1.35);
    float amp = 14 + k*18, ph = rr(R, 0, TWO_PI), fr = rr(R, 0.003, 0.0055);
    float[] top = new float[(W/40 + 3)*2];
    int n = 0;
    for (int x = -40; x <= W + 40; x += 40) {
      top[n*2] = x;
      top[n*2+1] = y0 + amp*sin(x*fr + ph) + amp*0.6*noise(x*0.006, k*3.1);
      n++;
    }
    g.fill(C(fields[k % 5]));
    g.beginShape();
    g.vertex(-40, yPrev - 4);
    g.vertex(W + 40, yPrev - 4);
    for (int i = n - 1; i >= 0; i--) g.vertex(top[i*2], top[i*2+1]);
    g.endShape(CLOSE);
    // a flooded patch holding the sky
    if (k % 2 == 1) {
      g.fill(C(mixc(SKY_LOW, SKY_TOP, 0.5), 170));
      blob(g, rr(R, 200, W - 200), lerp(yPrev, y0, 0.5), rr(R, 160, 320), 8 + k*4, 0.45, 840 + k);
    }
    float[] bund = new float[n*2];
    System.arraycopy(top, 0, bund, 0, n*2);
    recLevel = 2;
    wline(g, bund, 6 + k*4, C(150, 118, 82), 2.0*look.wob, 810 + k);
    recLevel = 0;
    yPrev = top[n];
  }
  g.fill(C(fields[4]));
  g.rect(-10, yPrev + 2, W + 20, H - yPrev);
  // clumps of rice and weeds
  for (int k = 0; k < 520; k++) {
    float x = rr(R, 0, W), y = rr(R, WATER1 + 14, H);
    float sc = 0.3 + pow((y - WATER1)/(H - WATER1), 1.5)*2.0;
    g.fill(C(k % 3 == 0 ? new float[]{96,132,52} : (k % 3 == 1 ? new float[]{160,192,86} : new float[]{120,156,62}), 200));
    blob(g, x, y, 9*sc, 3*sc, 0.5, k + 820);
  }
  // the heron, standing alone
  float hx = world.heronX, hy = world.heronY;
  g.stroke(C(70, 66, 50));
  g.strokeWeight(1.6);
  g.line(hx - 2, hy, hx - 4, hy + 34);
  g.line(hx + 4, hy, hx + 5, hy + 34);
  g.noStroke();
  recLevel = 1;
  g.fill(C(244, 242, 234));
  blob(g, hx, hy - 6, 16, 9, 0.15, 830);
  float[] neck = {hx + 10, hy - 10, hx + 16, hy - 24, hx + 10, hy - 34, hx + 15, hy - 44};
  wline(g, neck, 5, C(244, 242, 234), 0.6, 831);
  recLevel = 0;
  blob(g, hx + 16, hy - 46, 4.5, 3.5, 0.1, 832);
  g.fill(C(224, 180, 60));
  g.triangle(hx + 19, hy - 48, hx + 33, hy - 45, hx + 19, hy - 44);
  g.fill(C(170, 180, 168, 150));
  blob(g, hx - 6, hy - 3, 9, 4, 0.2, 833);
  // tall grass along the bottom edge
  for (int k = 0; k < 70; k++) {
    float x = rr(R, -20, W + 20);
    float[] sp = arcSpine(x, H + 10, radians(-90 + rr(R, -28, 28)), rr(R, 50, 150), rr(R, 0.05, 0.35), 12);
    g.fill(C(k % 2 == 0 ? new float[]{52,82,40} : new float[]{80,112,48}));
    blade(g, sp, rr(R, 3, 7), 0.2, k + 900);
  }
}

// power cut at dusk: mist, the hoarding on its own floodlights, two screens
void dusk(PGraphics g) {
  g.noStroke();
  for (int y = 0; y < H; y += 2) {
    float d = abs(y - BASE)/420.0;
    g.fill(130, 118, 160, 70*exp(-d*d*2.5));
    g.rect(0, y, W, 2);
  }
  g.blendMode(ADD);
  Board b = world.boards[0];
  float x0 = b.cx - b.w/2, y0 = b.y0(), y1 = b.y1();
  for (int r = 10; r >= 1; r--) {
    g.fill(120, 100, 60, 9);
    g.ellipse(b.cx, (y0 + y1)/2, b.w*(0.8 + r*0.14), b.ph*(0.8 + r*0.22));
  }
  for (int k = 0; k < 3; k++) {
    float lx = lerp(x0 + b.w*0.15, x0 + b.w*0.85, k/2.0) + 7;
    g.fill(200, 180, 120, 26);
    g.triangle(lx, y0 - 18, lx - 60, y1, lx + 60, y1);
  }
  // its reflection, broken by the ripples
  for (int k = 0; k < 14; k++) {
    float ry = 2*BUND - lerp(y0, y1, k/13.0);
    if (ry > WATER1) continue;
    g.fill(160, 130, 80, 30);
    g.ellipse(b.cx + sin(k*1.7)*8, ry, b.w*(0.9 - k*0.02), 4);
  }
  float[][] tint = {{70, 110, 200}, {200, 116, 40}};
  int found = 0;
  for (House h : world.houses) {
    if (found >= 2) break;
    if (h.id % 4 != 1) continue;
    float x0e = h.eye[0], y0e = h.eye[1], x1e = h.eye[2], y1e = h.eye[3];
    float cx = (x0e + x1e)/2, cy = (y0e + y1e)/2;
    float[] t = tint[found];
    for (int r = 8; r >= 1; r--) {
      g.fill(t[0], t[1], t[2], 14);
      g.ellipse(cx, cy, (x1e - x0e)*0.8*r, (y1e - y0e)*0.8*r);
    }
    g.fill(t[0], t[1], t[2], 230);
    g.rect(x0e + 1, lerp(y0e, y1e, 0.5), x1e - x0e - 2, (y1e - y0e)*0.45);
    for (int r = 4; r >= 1; r--) {
      g.fill(t[0], t[1], t[2], 16);
      g.ellipse(cx, 2*BUND - cy, (x1e - x0e)*0.5*r, 3*r);
    }
    found++;
  }
  float tx = world.towerX, ty = BASE - 30*S - 4;
  for (int r = 6; r >= 1; r--) {
    g.fill(255, 50, 30, 22);
    g.ellipse(tx, ty, 5*r, 5*r);
  }
  g.fill(255, 50, 30, 40);
  g.ellipse(tx, 2*BUND - ty, 10, 4);
  g.blendMode(BLEND);
}

// ===================================================================
//  ORGANIC GEOMETRY: rounded, resampled, wobbled outlines
// ===================================================================
ArrayList<float[]> etchPaths = new ArrayList<float[]>();
int recLevel = 0;            // >0: outlines filled now are kept for sgraffito
float HX = 0, HY = 0, HR = 0; // local transform for leaning houses

float[] L(float... v) {
  float[] o = new float[v.length];
  float c = cos(HR), s = sin(HR);
  for (int i = 0; i < v.length; i += 2) {
    o[i] = HX + v[i]*c - v[i+1]*s;
    o[i+1] = HY + v[i]*s + v[i+1]*c;
  }
  return o;
}

float[] roundPoly(float[] p, float rad, boolean closed) {
  int n = p.length/2;
  if (n < 3 || rad <= 0) return p;
  ArrayList<Float> o = new ArrayList<Float>();
  for (int i = 0; i < n; i++) {
    if (!closed && (i == 0 || i == n - 1)) {
      o.add(p[i*2]); o.add(p[i*2+1]);
      continue;
    }
    int a = (i - 1 + n) % n, b = (i + 1) % n;
    float ax = p[a*2], ay2 = p[a*2+1], cx = p[i*2], cy = p[i*2+1], bx = p[b*2], by = p[b*2+1];
    float la = dist(ax, ay2, cx, cy), lb = dist(bx, by, cx, cy);
    float ra = min(rad, la*0.45), rb = min(rad, lb*0.45);
    float sx = cx + (ax - cx)/max(la, 0.001)*ra, sy = cy + (ay2 - cy)/max(la, 0.001)*ra;
    float ex = cx + (bx - cx)/max(lb, 0.001)*rb, ey2 = cy + (by - cy)/max(lb, 0.001)*rb;
    for (int k = 0; k <= 6; k++) {
      float t = k/6.0;
      float x = sq(1 - t)*sx + 2*(1 - t)*t*cx + t*t*ex;
      float y = sq(1 - t)*sy + 2*(1 - t)*t*cy + t*t*ey2;
      o.add(x); o.add(y);
    }
  }
  float[] r = new float[o.size()];
  for (int i = 0; i < r.length; i++) r[i] = o.get(i);
  return r;
}

float[] resample(float[] p, float step, boolean closed) {
  int n = p.length/2;
  ArrayList<Float> o = new ArrayList<Float>();
  int segs = closed ? n : n - 1;
  for (int i = 0; i < segs; i++) {
    float ax = p[i*2], ay2 = p[i*2+1];
    int j = (i + 1) % n;
    float bx = p[j*2], by = p[j*2+1];
    float l = dist(ax, ay2, bx, by);
    int k = max(1, (int)(l/step));
    for (int m = 0; m < k; m++) {
      float t = m/(float)k;
      o.add(lerp(ax, bx, t)); o.add(lerp(ay2, by, t));
    }
  }
  if (!closed) { o.add(p[(n-1)*2]); o.add(p[(n-1)*2+1]); }
  float[] r = new float[o.size()];
  for (int i = 0; i < r.length; i++) r[i] = o.get(i);
  return r;
}

void wobble(float[] p, float amp, float sd) {
  float f = 0.016;
  for (int i = 0; i < p.length; i += 2) {
    float x = p[i], y = p[i+1];
    p[i] += amp*(noise(x*f + sd, y*f, 3.1)*2 - 1)*1.6;
    p[i+1] += amp*(noise(x*f, y*f + sd, 7.7)*2 - 1)*1.6;
  }
}

float[] organic(float[] xy, float rad, float amp, float sd) {
  float[] p = resample(roundPoly(xy, rad*look.round, true), 3, true);
  wobble(p, amp, sd);
  return p;
}

float[] organicOpen(float[] xy, float rad, float amp, float sd) {
  float[] p = resample(roundPoly(xy, rad, false), 2, false);
  wobble(p, amp, sd);
  return p;
}

void fillShape(PGraphics g, float[] p) {
  g.beginShape();
  for (int i = 0; i < p.length; i += 2) g.vertex(p[i], p[i+1]);
  g.endShape(CLOSE);
  if (recLevel > 0 && recLevel <= look.etchLevel) {
    float[] c = new float[p.length + 2];
    System.arraycopy(p, 0, c, 0, p.length);
    c[p.length] = p[0];
    c[p.length+1] = p[1];
    etchPaths.add(c);
  }
}

void blob(PGraphics g, float cx, float cy, float rx, float ry, float irr, float sd) {
  int n = max(18, (int)((rx + ry)*0.5));
  float[] p = new float[n*2];
  for (int i = 0; i < n; i++) {
    float a = TWO_PI*i/n;
    float k = 1 + irr*(noise(cos(a)*1.3 + sd, sin(a)*1.3 + sd*0.7, 5.5)*2 - 1);
    p[i*2] = cx + cos(a)*rx*k;
    p[i*2+1] = cy + sin(a)*ry*k;
  }
  fillShape(g, p);
}

float[] rectP(float x0, float y0, float x1, float y1) {
  return new float[]{x0, y0, x1, y0, x1, y1, x0, y1};
}

void orect(PGraphics g, float x0, float y0, float x1, float y1, float rad, float amp, float sd) {
  fillShape(g, organic(L(rectP(x0, y0, x1, y1)), rad, amp, sd));
}

void wline(PGraphics g, float[] xy, float wgt, int col, float amp, float sd) {
  float[] p = organicOpen(xy, 6, amp, sd);
  g.noFill();
  g.stroke(col);
  g.strokeWeight(wgt);
  g.beginShape();
  for (int i = 0; i < p.length; i += 2) g.vertex(p[i], p[i+1]);
  g.endShape();
  g.noStroke();
}

// leaf / frond blade along a spine
void blade(PGraphics g, float[] spine, float wmax, float jag, float sd) {
  int n = spine.length/2;
  float[] l = new float[n*2], r = new float[n*2];
  for (int i = 0; i < n; i++) {
    int a = max(0, i - 1), b = min(n - 1, i + 1);
    float dx = spine[b*2] - spine[a*2], dy = spine[b*2+1] - spine[a*2+1];
    float len = max(0.001, sqrt(dx*dx + dy*dy));
    float nx = -dy/len, ny = dx/len;
    float t = i/(float)(n - 1);
    float w = wmax*pow(sin(PI*min(1, t*1.05)), 0.7);
    float jl = 1 - jag*noise(t*14 + sd, 1.3), jr = 1 - jag*noise(t*14 + sd, 9.1);
    l[i*2] = spine[i*2] + nx*w*jl;
    l[i*2+1] = spine[i*2+1] + ny*w*jl;
    r[i*2] = spine[i*2] - nx*w*jr;
    r[i*2+1] = spine[i*2+1] - ny*w*jr;
  }
  g.beginShape();
  for (int i = 0; i < n; i++) g.vertex(l[i*2], l[i*2+1]);
  for (int i = n - 1; i >= 0; i--) g.vertex(r[i*2], r[i*2+1]);
  g.endShape(CLOSE);
}

float[] arcSpine(float x, float y, float ang, float len, float grav, int n) {
  float[] s = new float[n*2];
  for (int i = 0; i < n; i++) {
    float t = i/(float)(n - 1);
    float d = t*len;
    s[i*2] = x + cos(ang)*d;
    s[i*2+1] = y + sin(ang)*d + grav*len*t*t;
  }
  return s;
}

// ===================================================================
//  THE CURLY ALPHABET
//  Skeletons on a 4 x 6 grid (y down, baseline 6). Strokes split by |.
//  Splines run through the points; open terminals end in a spiral.
// ===================================================================
HashMap<Character, String> GLYPH = new HashMap<Character, String>();

void initGlyphs() {
  GLYPH.put('A', "0,6 1.4,1.4 2,0 2.6,1.4 4,6|0.9,3.9 3.1,3.7");
  GLYPH.put('B', "0.5,6 0.4,0|0.4,0 2.6,0 3.4,0.8 3.4,2 2.6,2.9 0.5,3|0.5,3 2.9,3 3.8,3.9 3.8,5.1 2.9,6 0.5,6");
  GLYPH.put('C', "3.8,1.1 3,0.1 1.8,0 0.6,0.8 0,2.4 0,3.8 0.6,5.3 1.8,6 3,5.9 3.9,5");
  GLYPH.put('D', "0.5,6 0.4,0|0.4,0 2,0 3.4,0.9 4,3 3.4,5.1 2,6 0.5,6");
  GLYPH.put('E', "3.6,0 0.4,0 0.5,6 3.8,6|0.5,3 2.8,2.9");
  GLYPH.put('F', "3.8,0 0.4,0 0.5,6|0.5,3 2.8,2.9");
  GLYPH.put('G', "3.8,1.1 3,0.1 1.8,0 0.6,0.8 0,2.4 0,3.8 0.6,5.3 1.8,6 3,5.9 3.9,4.8 3.9,3.4 2.4,3.4");
  GLYPH.put('H', "0.3,0 0.4,6|3.7,0 3.6,6|0.4,3 3.6,2.9");
  GLYPH.put('I', "1.5,0 1.5,6");
  GLYPH.put('J', "3.4,0 3.4,4.4 2.8,5.6 1.8,6 0.8,5.6 0.2,4.6");
  GLYPH.put('K', "0.4,0 0.5,6|3.6,0 0.5,3.4|1.5,2.4 3.8,6");
  GLYPH.put('L', "0.4,0 0.5,6 3.8,6");
  GLYPH.put('M', "0,6 0.4,0 2,3.6 3.6,0 4,6");
  GLYPH.put('N', "0.3,6 0.3,0 3.7,6 3.7,0");
  GLYPH.put('O', "2,0 3.4,0.7 4,3 3.4,5.3 2,6 0.6,5.3 0,3 0.6,0.7 2,0");
  GLYPH.put('P', "0.5,6 0.4,0 2.6,0 3.6,0.9 3.6,2.4 2.6,3.3 0.5,3.3");
  GLYPH.put('Q', "2,0 3.4,0.7 4,3 3.4,5.3 2,6 0.6,5.3 0,3 0.6,0.7 2,0|2.4,4.4 4,6.4");
  GLYPH.put('R', "0.5,6 0.4,0 2.6,0 3.6,0.9 3.6,2.4 2.6,3.3 0.5,3.3|1.8,3.3 3.8,6");
  GLYPH.put('S', "3.7,0.9 2.8,0.05 1.4,0.05 0.4,0.9 0.4,2.1 1.4,2.8 2.6,3.2 3.6,3.9 3.7,5.1 2.7,6 1.2,6 0.2,5.1");
  GLYPH.put('T', "0,0.1 4,0|2,0 2,6");
  GLYPH.put('U', "0.3,0 0.3,4.2 0.9,5.5 2,6 3.1,5.5 3.7,4.2 3.7,0");
  GLYPH.put('V', "0,0 2,6 4,0");
  GLYPH.put('W', "0,0 0.9,6 2,2 3.1,6 4,0");
  GLYPH.put('X', "0.2,0 3.8,6|3.8,0 0.2,6");
  GLYPH.put('Y', "0,0 2,3.2 4,0|2,3.2 2,6");
  GLYPH.put('Z', "0.2,0 3.8,0 0.2,6 3.8,6");
  GLYPH.put('0', "2,0 3.3,0.8 3.8,3 3.3,5.2 2,6 0.7,5.2 0.2,3 0.7,0.8 2,0");
  GLYPH.put('1', "0.4,1.3 1.5,0 1.5,6");
  GLYPH.put('2', "0.4,1.2 1.2,0.2 2.6,0.1 3.5,1 3.4,2.3 0.3,6 3.8,6");
  GLYPH.put('3', "0.4,0.8 1.4,0 2.8,0 3.6,0.8 3.4,2.2 2,3 3.6,3.8 3.8,5 2.8,6 1.3,6 0.3,5.2");
  GLYPH.put('4', "3,6 3,0 0,4.2 4,4.2");
  GLYPH.put('5', "3.6,0 0.6,0 0.4,2.8 1.8,2.4 3,2.6 3.8,3.8 3.6,5.3 2.4,6 1.1,6 0.2,5.2");
  GLYPH.put('6', "3.3,0.4 2.2,0 1,0.6 0.2,2.4 0.1,4.2 0.7,5.6 2,6 3.3,5.5 3.8,4.3 3.3,3.2 2,2.8 0.8,3.4 0.15,4.3");
  GLYPH.put('7', "0.2,0 3.8,0 1.6,6");
  GLYPH.put('8', "2,3 3.2,2.2 3.3,0.9 2,0 0.7,0.9 0.8,2.2 2,3 3.6,3.9 3.7,5.2 2,6 0.3,5.2 0.4,3.9 2,3");
  GLYPH.put('9', "3.8,1.7 3.3,2.7 2,3.1 0.7,2.6 0.2,1.6 0.7,0.4 2,0 3.3,0.5 3.9,1.8 3.9,3.6 3.3,5.4 2,6 0.7,5.6");
  GLYPH.put('%', "0.4,6 3.6,0|0.9,0.2 1.5,0.8 0.9,1.5 0.3,0.8 0.9,0.2|3.1,4.5 3.7,5.2 3.1,5.9 2.5,5.2 3.1,4.5");
  GLYPH.put('₹', "0.2,0 3.8,0|0.2,1.6 3.8,1.6|0.6,0 2,0 3,0.8 3,2.2 2,3 0.6,3 3.4,6");
  GLYPH.put('♥', "2,6 0.5,3.9 0,2 0.6,0.6 1.4,0.4 2,1.3 2.6,0.4 3.4,0.6 4,2 3.5,3.9 2,6");
  GLYPH.put('+', "2,1.6 2,4.4|0.6,3 3.4,3");
  GLYPH.put('!', "1.5,0 1.5,4.2|1.5,5.5 1.5,6");
  GLYPH.put('.', "1.5,5.5 1.5,6");
  GLYPH.put('-', "0.8,3 3.2,3");
}

float glyphAdv(char ch) {
  if (ch == ' ') return 2.8;
  if ("I1!.".indexOf(ch) >= 0) return 3.0;
  return 5.3;
}

float textW(String s, float h) {
  float u = h/6, w = 0;
  for (int i = 0; i < s.length(); i++) w += glyphAdv(s.charAt(i))*u;
  return w - 1.3*u;
}

class TStroke {
  float[] p;      // x,y pairs, dense
  float[] w;      // width per point
  int col;
}

float[] catmull(ArrayList<float[]> pts, boolean closed, float spacing) {
  ArrayList<Float> o = new ArrayList<Float>();
  int n = pts.size();
  int segs = closed ? n - 1 : n - 1;
  for (int i = 0; i < segs; i++) {
    float[] p0 = pts.get(closed ? (i - 1 + (n - 1)) % (n - 1) : max(i - 1, 0));
    float[] p1 = pts.get(i);
    float[] p2 = pts.get(i + 1);
    float[] p3 = pts.get(closed ? (i + 2) % (n - 1) : min(i + 2, n - 1));
    float l = dist(p1[0], p1[1], p2[0], p2[1]);
    int k = max(2, (int)(l/spacing));
    for (int m = 0; m < k; m++) {
      float t = m/(float)k;
      o.add(crv(p0[0], p1[0], p2[0], p3[0], t));
      o.add(crv(p0[1], p1[1], p2[1], p3[1], t));
    }
  }
  float[] last = pts.get(n - 1);
  o.add(last[0]); o.add(last[1]);
  float[] r = new float[o.size()];
  for (int i = 0; i < r.length; i++) r[i] = o.get(i);
  return r;
}

float crv(float a, float b, float c, float d, float t) {
  return 0.5*((2*b) + (-a + c)*t + (2*a - 5*b + 4*c - d)*t*t + (-a + 3*b - 3*c + d)*t*t*t);
}

// spiral terminal: continues the stroke and winds toward (tx,ty)
ArrayList<Float> curl(float x, float y, float dx, float dy, float r0, float tx, float ty) {
  ArrayList<Float> o = new ArrayList<Float>();
  float a = atan2(dy, dx);
  float cr = dx*(ty - y) - dy*(tx - x);
  float s = (cr >= 0) ? 1 : -1;
  float r = r0;
  for (int k = 0; k < 26; k++) {
    a += s*0.24;
    r *= 0.955;
    x += cos(a)*r*0.24*1.6;
    y += sin(a)*r*0.24*1.6;
    o.add(x); o.add(y);
  }
  return o;
}

ArrayList<TStroke> typeset(String s, float x, float base, float h, float weight, int col,
                           float rot, float sd, boolean flipY, boolean curls) {
  ArrayList<TStroke> out = new ArrayList<TStroke>();
  float u = h/6;
  float tw = textW(s, h);
  float pen = 0;
  float gc = cos(rot), gs = sin(rot);
  for (int i = 0; i < s.length(); i++) {
    char ch = Character.toUpperCase(s.charAt(i));
    String def = GLYPH.get(ch);
    float adv = glyphAdv(ch);
    if (def == null) { pen += adv*u; continue; }
    float dy = (noise(sd + i*0.71, 2.2) - 0.5)*0.5*u;
    float lr = (noise(sd + i*1.37, 5.3) - 0.5)*0.18;
    float sc = 0.94 + noise(sd + i*0.53, 8.8)*0.12;
    float lcx = pen + (adv - 1.3)*u*0.5, lcy = -3*u;
    String[] parts = def.split("\\|");
    for (int pi = 0; pi < parts.length; pi++) {
      String[] tok = parts[pi].trim().split(" ");
      ArrayList<float[]> pts = new ArrayList<float[]>();
      for (String tk : tok) {
        String[] xy = tk.split(",");
        float gx = Float.parseFloat(xy[0]), gy = Float.parseFloat(xy[1]);
        float lx = pen + gx*u*sc, ly = (gy - 6)*u*sc + dy;
        float rx = lcx + (lx - lcx)*cos(lr) - (ly - lcy)*sin(lr);
        float ry = lcy + (lx - lcx)*sin(lr) + (ly - lcy)*cos(lr);
        pts.add(new float[]{rx, ry});
      }
      float[] f = pts.get(0), l = pts.get(pts.size() - 1);
      boolean closed = dist(f[0], f[1], l[0], l[1]) < 0.01 && pts.size() > 3;
      boolean dot = pts.size() == 2 && dist(f[0], f[1], l[0], l[1]) < u*0.8;
      float[] core = catmull(pts, closed, max(0.8, u*0.12));
      ArrayList<Float> all = new ArrayList<Float>();
      int nCore = core.length/2;
      int pre = 0;
      if (curls && !closed && !dot && nCore > 3) {
        float ddx = core[0] - core[4], ddy = core[1] - core[5];
        float dl = max(0.001, sqrt(ddx*ddx + ddy*ddy));
        ArrayList<Float> c0 = curl(core[0], core[1], ddx/dl, ddy/dl, u*0.5, lcx, lcy);
        for (int k = c0.size() - 2; k >= 0; k -= 2) { all.add(c0.get(k)); all.add(c0.get(k+1)); }
        pre = c0.size()/2;
      }
      for (float v : core) all.add(v);
      int post = 0;
      if (curls && !closed && !dot && nCore > 3) {
        int e = core.length - 2;
        float ddx = core[e] - core[e-4], ddy = core[e+1] - core[e-3];
        float dl = max(0.001, sqrt(ddx*ddx + ddy*ddy));
        ArrayList<Float> c1 = curl(core[e], core[e+1], ddx/dl, ddy/dl, u*0.5, lcx, lcy);
        all.addAll(c1);
        post = c1.size()/2;
      }
      int n = all.size()/2;
      TStroke ts = new TStroke();
      ts.p = new float[n*2];
      ts.w = new float[n];
      ts.col = col;
      for (int k = 0; k < n; k++) {
        float lx = all.get(k*2), ly = all.get(k*2+1);
        lx += (noise(lx*0.05 + sd, ly*0.05) - 0.5)*u*0.12*look.wob;
        ly += (noise(lx*0.05, ly*0.05 + sd) - 0.5)*u*0.12*look.wob;
        float cx0 = lx - tw/2, cy0 = ly + h/2;
        float wx = tw/2 + cx0*gc - cy0*gs, wy = -h/2 + cx0*gs + cy0*gc;
        if (flipY) wy = -h - wy;
        ts.p[k*2] = x + wx;
        ts.p[k*2+1] = base + wy;
        float wt;
        if (k < pre) wt = weight*lerp(0.25, 0.7, k/(float)max(1, pre));
        else if (k >= n - post) wt = weight*lerp(0.7, 0.25, (k - (n - post))/(float)max(1, post));
        else {
          float t = (k - pre)/(float)max(1, nCore - 1);
          wt = weight*(0.62 + 0.38*pow(sin(PI*t), 0.6));
          if (closed) wt = weight*(0.78 + 0.22*sin(TWO_PI*t + 0.8));
          if (dot) wt = weight*1.25;
        }
        ts.w[k] = wt;
      }
      out.add(ts);
    }
    pen += adv*u;
  }
  return out;
}

// the wiggly face: on the offers it smiles, nowhere else
ArrayList<TStroke> faceStrokes(float cx, float cy, float s, int col, float sd, boolean smile) {
  ArrayList<TStroke> out = new ArrayList<TStroke>();
  float wgt = max(1.2, s*0.07);
  ArrayList<float[]> head = new ArrayList<float[]>();
  for (int i = 0; i <= 14; i++) {
    float a = TWO_PI*(i % 14)/14.0 - HALF_PI;
    float r = s*0.5*(0.86 + 0.24*noise(cos(a) + sd, sin(a) + sd));
    head.add(new float[]{cx + cos(a)*r*0.92, cy + sin(a)*r});
  }
  out.add(mkStroke(catmull(head, true, 1.2), wgt, col, false));
  for (int e = -1; e <= 1; e += 2) {
    ArrayList<float[]> eye = new ArrayList<float[]>();
    float ex = cx + e*s*0.17, eyy = cy - s*0.1;
    eye.add(new float[]{ex, eyy - s*0.06});
    eye.add(new float[]{ex + e*s*0.02, eyy + s*0.03});
    eye.add(new float[]{ex - e*s*0.03, eyy + s*0.05});
    out.add(mkStroke(catmull(eye, false, 0.8), wgt*1.05, col, false));
  }
  ArrayList<float[]> m = new ArrayList<float[]>();
  float k = smile ? 1 : -1;
  m.add(new float[]{cx - s*0.24, cy + s*0.12 - (smile ? 0 : s*0.1)});
  m.add(new float[]{cx - s*0.08, cy + s*0.12 + k*s*0.1});
  m.add(new float[]{cx + s*0.1, cy + s*0.11 + k*s*0.1});
  m.add(new float[]{cx + s*0.25, cy + s*0.1 - (smile ? 0 : s*0.1)});
  float[] mc = catmull(m, false, 0.8);
  ArrayList<Float> all = new ArrayList<Float>();
  for (float v : mc) all.add(v);
  int e = mc.length - 2;
  all.addAll(curl(mc[e], mc[e+1], mc[e] - mc[e-2], mc[e+1] - mc[e-1], s*0.07, cx, cy));
  float[] arr = new float[all.size()];
  for (int i = 0; i < arr.length; i++) arr[i] = all.get(i);
  out.add(mkStroke(arr, wgt, col, true));
  ArrayList<float[]> hair = new ArrayList<float[]>();
  hair.add(new float[]{cx - s*0.05, cy - s*0.44});
  hair.add(new float[]{cx + s*0.02, cy - s*0.6});
  hair.add(new float[]{cx + s*0.13, cy - s*0.62});
  float[] hc = catmull(hair, false, 0.8);
  ArrayList<Float> ha = new ArrayList<Float>();
  for (float v : hc) ha.add(v);
  int he = hc.length - 2;
  ha.addAll(curl(hc[he], hc[he+1], 1, 0.2, s*0.09, cx + s*0.1, cy - s*0.5));
  float[] harr = new float[ha.size()];
  for (int i = 0; i < harr.length; i++) harr[i] = ha.get(i);
  out.add(mkStroke(harr, wgt*0.9, col, true));
  return out;
}

TStroke mkStroke(float[] p, float wgt, int col, boolean taper) {
  TStroke t = new TStroke();
  t.p = p;
  int n = p.length/2;
  t.w = new float[n];
  for (int i = 0; i < n; i++) {
    float tt = i/(float)max(1, n - 1);
    t.w[i] = taper ? wgt*(0.45 + 0.55*pow(sin(PI*tt), 0.5)) : wgt;
  }
  t.col = col;
  return t;
}

void renderStrokes(PGraphics g, ArrayList<TStroke> list) {
  g.noStroke();
  for (TStroke t : list) {
    g.fill(t.col);
    int n = t.p.length/2;
    for (int i = 0; i < n; i++) g.ellipse(t.p[i*2], t.p[i*2+1], t.w[i], t.w[i]);
  }
}


// ===================================================================
//  PAINTER: oil, bristle by bristle
// ===================================================================
class Painter {
  int[] ref;
  float[] cr, cg, cb, ht, grain;
  float[] angS, cohS, angL, cohL, fall;
  int fw, fh;
  Random R;

  Painter(PGraphics refG, long sd) {
    refG.loadPixels();
    ref = refG.pixels.clone();
    R = new Random(sd);
    cr = new float[W*H];
    cg = new float[W*H];
    cb = new float[W*H];
    ht = new float[W*H];
    for (int i = 0; i < W*H; i++) {
      cr[i] = 116; cg[i] = 80; cb[i] = 54;     // warm imprimatura
    }
    makeGrain();
    makeFlow();
  }

  void makeGrain() {
    grain = new float[W*H];
    float[] a = new float[W*H], b = new float[W*H];
    for (int i = 0; i < W*H; i++) { a[i] = R.nextFloat(); b[i] = R.nextFloat(); }
    for (int y = 0; y < H; y++) {
      for (int x = 0; x < W; x++) {
        float s1 = 0, s2 = 0;
        for (int k = -2; k <= 2; k++) {
          s1 += a[y*W + constrain(x + k, 0, W - 1)];
          s2 += b[constrain(y + k, 0, H - 1)*W + x];
        }
        grain[y*W + x] = (s1 + s2)/10;
      }
    }
  }

  void makeFlow() {
    float[] jxx = new float[W*H], jxy = new float[W*H], jyy = new float[W*H];
    for (int y = 1; y < H - 1; y++) {
      for (int x = 1; x < W - 1; x++) {
        int i = y*W + x;
        float sxx = 0, sxy = 0, syy = 0;
        for (int c = 0; c < 3; c++) {
          int sh = 16 - c*8;
          float gx = ((ref[i+1] >> sh) & 255) - ((ref[i-1] >> sh) & 255);
          float gy = ((ref[i+W] >> sh) & 255) - ((ref[i-W] >> sh) & 255);
          sxx += gx*gx; sxy += gx*gy; syy += gy*gy;
        }
        jxx[i] = sxx; jxy[i] = sxy; jyy[i] = syy;
      }
    }
    angS = new float[W*H]; cohS = new float[W*H];
    angL = new float[W*H]; cohL = new float[W*H];
    tensor(jxx, jxy, jyy, 3, angS, cohS);
    tensor(jxx, jxy, jyy, 9, angL, cohL);
    // fallback field where the picture is flat
    fw = W/8 + 1; fh = H/8 + 1;
    fall = new float[fw*fh];
    for (int y = 0; y < fh; y++) {
      for (int x = 0; x < fw; x++) {
        float wy = y*8;
        float spread = (wy < BASE - 40) ? 0.9 : (wy > WATER0 && wy < WATER1) ? 0.3 : 2.4;
        fall[y*fw + x] = (noise(x*0.025, y*0.025, 4.4) - 0.5)*spread;
      }
    }
  }

  void tensor(float[] jxx, float[] jxy, float[] jyy, int r, float[] ang, float[] coh) {
    float[] a = boxBlur(jxx, r), b = boxBlur(jxy, r), c = boxBlur(jyy, r);
    for (int i = 0; i < W*H; i++) {
      float d = a[i] - c[i];
      float th = 0.5*atan2(2*b[i], d);
      ang[i] = th + HALF_PI;
      float m = a[i] + c[i];
      float co = sqrt(d*d + 4*b[i]*b[i])/(m + 1e-3);
      coh[i] = co*constrain(m/400.0, 0, 1);
    }
  }

  float[] boxBlur(float[] s, int r) {
    float[] t = new float[W*H], o = new float[W*H];
    for (int y = 0; y < H; y++) {
      float acc = 0;
      int row = y*W;
      for (int x = -r; x <= r; x++) acc += s[row + constrain(x, 0, W - 1)];
      for (int x = 0; x < W; x++) {
        t[row + x] = acc/(2*r + 1);
        acc += s[row + min(x + r + 1, W - 1)] - s[row + max(x - r, 0)];
      }
    }
    for (int x = 0; x < W; x++) {
      float acc = 0;
      for (int y = -r; y <= r; y++) acc += t[constrain(y, 0, H - 1)*W + x];
      for (int y = 0; y < H; y++) {
        o[y*W + x] = acc/(2*r + 1);
        acc += t[min(y + r + 1, H - 1)*W + x] - t[max(y - r, 0)*W + x];
      }
    }
    return o;
  }

  float dirAt(float x, float y, boolean large) {
    int ix = constrain((int)x, 0, W - 1), iy = constrain((int)y, 0, H - 1);
    int i = iy*W + ix;
    float a = large ? angL[i] : angS[i], c = constrain((large ? cohL[i] : cohS[i])*1.6, 0, 1);
    float f = fall[(iy/8)*fw + ix/8];
    float vx = c*cos(2*a) + (1 - c)*cos(2*f), vy = c*sin(2*a) + (1 - c)*sin(2*f);
    return 0.5*atan2(vy, vx);
  }

  int refAt(float x, float y) {
    return ref[constrain((int)y, 0, H - 1)*W + constrain((int)x, 0, W - 1)];
  }

  float cdiff(int a, int b) {
    float dr = ((a >> 16) & 255) - ((b >> 16) & 255);
    float dg = ((a >> 8) & 255) - ((b >> 8) & 255);
    float db = (a & 255) - (b & 255);
    return sqrt(dr*dr + dg*dg + db*db);
  }

  float errAt(int i) {
    int c = ref[i];
    return abs(((c >> 16) & 255) - cr[i]) + abs(((c >> 8) & 255) - cg[i]) + abs((c & 255) - cb[i]);
  }

  void paintAll() {
    float[] radii = look.radii;
    for (int p = 0; p < radii.length; p++) {
      float r = radii[p];
      boolean large = r > 7;
      float grid = max(1.2, r*0.95);
      float thr = (p == 0) ? -1 : lerp(48, 30, p/(float)(radii.length - 1));
      ArrayList<float[]> pts = new ArrayList<float[]>();
      for (float gy = 0; gy < H; gy += grid) {
        for (float gx = 0; gx < W; gx += grid) {
          if (p == 0) {
            pts.add(new float[]{gx + R.nextFloat()*grid, gy + R.nextFloat()*grid});
            continue;
          }
          float best = -1, bx = 0, by = 0, sum = 0;
          int ns = 0;
          for (int k = 0; k < 5; k++) {
            float x = gx + R.nextFloat()*grid, y = gy + R.nextFloat()*grid;
            if (x >= W || y >= H) continue;
            float e = errAt((int)y*W + (int)x);
            sum += e;
            ns++;
            if (e > best) { best = e; bx = x; by = y; }
          }
          if (ns > 0 && sum/ns > thr) pts.add(new float[]{bx, by});
        }
      }
      Collections.shuffle(pts, R);
      float alpha = (p == 0) ? 0.9 : 0.94;
      for (float[] q : pts) brushStroke(q[0], q[1], r, large, alpha);
    }
  }

  void brushStroke(float x0, float y0, float r, boolean large, float alpha) {
    int c = refAt(x0, y0);
    float maxLen = r*7 + 12;
    ArrayList<float[]> fwd = trace(x0, y0, r, c, 1, maxLen*0.5, large);
    ArrayList<float[]> bwd = trace(x0, y0, r, c, -1, maxLen*0.5, large);
    ArrayList<float[]> path = new ArrayList<float[]>();
    for (int i = bwd.size() - 1; i >= 1; i--) path.add(bwd.get(i));
    path.addAll(fwd);
    if (path.size() < 2) {
      float a = dirAt(x0, y0, large);
      path.clear();
      path.add(new float[]{x0 - cos(a)*r*0.6, y0 - sin(a)*r*0.6});
      path.add(new float[]{x0 + cos(a)*r*0.6, y0 + sin(a)*r*0.6});
    }
    float[] flat = new float[path.size()*2];
    for (int i = 0; i < path.size(); i++) { flat[i*2] = path.get(i)[0]; flat[i*2+1] = path.get(i)[1]; }
    float[] dense = resample(flat, 0.8, false);
    int i0 = constrain((int)y0, 0, H - 1)*W + constrain((int)x0, 0, W - 1);
    float pr = ((c >> 16) & 255), pg = ((c >> 8) & 255), pb = (c & 255);
    // wet-in-wet: the brush picks up a little of what is already there
    pr = lerp(pr, cr[i0], 0.12); pg = lerp(pg, cg[i0], 0.12); pb = lerp(pb, cb[i0], 0.12);
    float v = (float)R.nextGaussian()*6;
    pr += v + (float)R.nextGaussian()*4; pg += v + (float)R.nextGaussian()*4; pb += v + (float)R.nextGaussian()*4;
    bristles(dense, null, r, pr, pg, pb, alpha, look.impasto, 9);
  }

  ArrayList<float[]> trace(float x, float y, float r, int c, int sgn, float maxLen, boolean large) {
    ArrayList<float[]> o = new ArrayList<float[]>();
    o.add(new float[]{x, y});
    float a = dirAt(x, y, large);
    float vx = cos(a)*sgn, vy = sin(a)*sgn;
    float step = max(1.2, r*0.5), len = 0;
    while (len < maxLen) {
      float na = dirAt(x, y, large);
      float nx = cos(na), ny = sin(na);
      if (nx*vx + ny*vy < 0) { nx = -nx; ny = -ny; }
      vx = vx*0.6 + nx*0.4;
      vy = vy*0.6 + ny*0.4;
      float l = sqrt(vx*vx + vy*vy);
      vx /= l; vy /= l;
      x += vx*step;
      y += vy*step;
      if (x < 0 || y < 0 || x >= W || y >= H) break;
      if (cdiff(refAt(x, y), c) > 30 && len > r*0.6) break;
      o.add(new float[]{x, y});
      len += step;
    }
    return o;
  }

  void bristles(float[] P, float[] wprof, float r, float pr, float pg, float pb, float alpha, float imp, float jit) {
    int n = P.length/2;
    if (n < 2) return;
    float[] nx = new float[n], ny = new float[n];
    for (int i = 0; i < n; i++) {
      int a = max(0, i - 2), b = min(n - 1, i + 2);
      float dx = P[b*2] - P[a*2], dy = P[b*2+1] - P[a*2+1];
      float l = max(0.0001, sqrt(dx*dx + dy*dy));
      nx[i] = -dy/l; ny[i] = dx/l;
    }
    int nb = constrain(round(r*1.5), 2, 44);
    for (int b = 0; b < nb; b++) {
      float u = (nb == 1) ? 0 : b/(float)(nb - 1)*2 - 1;
      float off = u*r + (float)R.nextGaussian()*0.3*r/nb;
      float v = (float)R.nextGaussian()*jit*0.6;
      float br = constrain(pr + (float)R.nextGaussian()*jit*0.5 + v, 0, 255);
      float bg = constrain(pg + (float)R.nextGaussian()*jit*0.5 + v, 0, 255);
      float bb = constrain(pb + (float)R.nextGaussian()*jit*0.5 + v, 0, 255);
      float t0 = R.nextFloat()*0.12*(1 + abs(u)), t1 = 1 - R.nextFloat()*0.18*(1 + abs(u));
      float a0 = alpha*(0.78 + 0.22*R.nextFloat())*(1 - 0.3*u*u);
      float bimp = imp*(0.3 + 0.9*R.nextFloat());
      int i0 = (int)(t0*(n - 1)), i1 = max(i0 + 1, (int)(t1*(n - 1)));
      for (int i = i0; i <= i1; i++) {
        float t = (i - i0)/(float)max(1, i1 - i0);
        float fade = min(1, t*7)*min(1, (1 - t)*5);
        float ws = (wprof == null) ? 1 : wprof[i];
        float x = P[i*2] + nx[i]*off*ws, y = P[i*2+1] + ny[i]*off*ws;
        int ix = (int)x, iy = (int)y;
        if (ix < 0 || iy < 0 || ix >= W - 1 || iy >= H - 1) continue;
        float tooth = lerp(1, 0.45 + 0.75*grain[iy*W + ix], t*0.8);
        float a = a0*fade*(1 - 0.35*t)*constrain(tooth, 0, 1);
        splat(x, y, br, bg, bb, a, bimp);
      }
    }
  }

  void splat(float x, float y, float r, float g, float b, float a, float imp) {
    int ix = (int)x, iy = (int)y;
    float fx = x - ix, fy = y - iy;
    put(iy*W + ix, r, g, b, a*(1 - fx)*(1 - fy), imp);
    put(iy*W + ix + 1, r, g, b, a*fx*(1 - fy), imp);
    put((iy + 1)*W + ix, r, g, b, a*(1 - fx)*fy, imp);
    put((iy + 1)*W + ix + 1, r, g, b, a*fx*fy, imp);
  }

  void put(int i, float r, float g, float b, float a, float imp) {
    if (a <= 0) return;
    a = min(a*1.6, 1);
    cr[i] += (r - cr[i])*a;
    cg[i] += (g - cg[i])*a;
    cb[i] += (b - cb[i])*a;
    if (imp > 0) ht[i] += (imp - ht[i])*a*0.85;
  }

  // lettering, faces and wires: a pointed brush, loaded with ink
  void paintLines(ArrayList<TStroke> list, float imp) {
    for (TStroke t : list) {
      int n = t.w.length;
      if (n < 2) continue;
      float mw = 0;
      for (float v : t.w) mw = max(mw, v);
      float[] prof = new float[n];
      for (int i = 0; i < n; i++) prof[i] = t.w[i]/max(mw, 0.001);
      float r = max(0.7, mw*0.5);
      float a = ((t.col >> 24) & 255)/255.0;
      bristles(t.p, prof, r, (t.col >> 16) & 255, (t.col >> 8) & 255, t.col & 255, 0.97*a, imp*look.impasto*1.2, 4);
    }
  }

  // sgraffito: scratch back to the imprimatura along recorded outlines
  void etchAll(ArrayList<float[]> paths) {
    int passes = (look.etchLevel > 1) ? 2 : 1;
    for (int ps = 0; ps < passes; ps++) {
      for (int k = 0; k < paths.size(); k++) {
        float[] p = resample(paths.get(k), 1, false);
        float sd = k*3.7 + ps*50;
        float ox = (ps == 0) ? 0 : (noise(sd, 1) - 0.5)*6, oy = (ps == 0) ? 0 : (noise(sd, 2) - 0.5)*6;
        int n = p.length/2;
        for (int i = 0; i < n; i++) {
          if (noise(i*0.012 + sd, 5.5) < 0.42) continue;
          float x = p[i*2] + ox + (noise(i*0.05, sd) - 0.5)*2.2;
          float y = p[i*2+1] + oy + (noise(sd, i*0.05) - 0.5)*2.2;
          int ix = (int)x, iy = (int)y;
          if (ix < 2 || iy < 2 || ix >= W - 3 || iy >= H - 3) continue;
          splat(x, y, 96, 62, 40, 0.75, 0);
          int ii = iy*W + ix;
          ht[ii] -= 0.8;
          ht[ii - 2] += 0.25; ht[ii + 2] += 0.25;
          ht[ii - 2*W] += 0.25; ht[ii + 2*W] += 0.25;
        }
      }
    }
  }

  // palette knife: drags across sky, road and water carrying colour
  void knife() {
    for (int k = 0; k < 70; k++) {
      float cx, cy;
      int zone = k % 3;
      if (zone == 0) { cx = R.nextFloat()*W; cy = 20 + R.nextFloat()*(BASE - 400); }
      else if (zone == 1) { cx = R.nextFloat()*W; cy = WATER0 + 10 + R.nextFloat()*(WATER1 - WATER0 - 20); }
      else { cx = R.nextFloat()*W; cy = WATER1 + 20 + R.nextFloat()*(H - WATER1 - 30); }
      float len = 120 + R.nextFloat()*260, wid = 14 + R.nextFloat()*36;
      float a = (R.nextFloat() - 0.5)*0.25;
      float dx = cos(a), dy = sin(a);
      for (int lane = 0; lane < (int)wid; lane++) {
        float o = lane - wid/2;
        float sx = cx - dx*len/2 - dy*o, sy = cy - dy*len/2 + dx*o;
        int si = constrain((int)sy, 0, H - 1)*W + constrain((int)sx, 0, W - 1);
        float kr = cr[si], kg = cg[si], kb = cb[si];
        float edge = 1 - pow(abs(o)/(wid/2), 6);
        for (int s = 0; s < (int)len; s++) {
          int x = (int)(sx + dx*s), y = (int)(sy + dy*s);
          if (x < 0 || y < 0 || x >= W || y >= H) continue;
          int i = y*W + x;
          float pick = 0.06, lay = 0.55*edge*(1 - s/len*0.6);
          cr[i] += (kr - cr[i])*lay; cg[i] += (kg - cg[i])*lay; cb[i] += (kb - cb[i])*lay;
          kr += (cr[i] - kr)*pick; kg += (cg[i] - kg)*pick; kb += (cb[i] - kb)*pick;
          ht[i] = lerp(ht[i], 0.8, 0.8*edge) + ((abs(o) > wid/2 - 2) ? 0.5 : 0);
        }
      }
    }
  }

  void finish(PGraphics out) {
    float[] hb = boxBlur(ht, 1);
    out.beginDraw();
    out.loadPixels();
    float k = 0.3;
    for (int y = 0; y < H; y++) {
      for (int x = 0; x < W; x++) {
        int i = y*W + x;
        float dx = hb[min(i + 1, W*H - 1)] - hb[max(i - 1, 0)];
        float dy = hb[min(i + W, W*H - 1)] - hb[max(i - W, 0)];
        float s = constrain((dx + dy)*k, -0.5, 0.5);
        float spec = max(0, s - 0.1)*0.8;
        float gr = (grain[i] - 0.5)*16;
        float r = cr[i]*(1 + s*0.55) + spec*140 + gr;
        float g = cg[i]*(1 + s*0.55) + spec*140 + gr;
        float b = cb[i]*(1 + s*0.55) + spec*130 + gr;
        // varnish and vignette
        float vx = (x - W/2.0)/(W/2.0), vy = (y - H/2.0)/(H/2.0);
        float vig = 1 - 0.16*pow(vx*vx*0.8 + vy*vy*0.6, 1.4);
        r = r*1.0*vig; g = g*0.985*vig; b = b*0.94*vig;
        out.pixels[i] = color(constrain(r, 0, 255), constrain(g, 0, 255), constrain(b, 0, 255));
      }
    }
    out.updatePixels();
    out.endDraw();
  }
}
