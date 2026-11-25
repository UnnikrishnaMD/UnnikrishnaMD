/*
 * SURROGATES
 * A body of work in seven panels. Processing 4
 *
 * Five middle-class houses on one Kerala street. Nobody is outside.
 * The scooters are under covers and the car has not moved since
 * petrol went past a hundred rupees a litre. The walls are full of
 * offers addressed to everyone.
 *
 * Every panel is a diptych of the SAME street, from ONE world model:
 *   top     elevation: standing across the road, eye level, looking in
 *   bottom  plan: directly overhead, the street running along the top
 * Both views share one horizontal axis at one scale (PX pixels per
 * metre), so each house, palm, pole, crow, gate, scooter and parcel
 * sits at exactly the same x in both halves. From above the houses get
 * small, and the roofs start to look like heads.
 *
 * Method
 *   1. The world is drawn flat into a reference buffer. No straight
 *      edges survive: every corner is rounded and every outline wobbles.
 *   2. The reference is repainted as oil: bristle strokes, coarse to
 *      fine, steered along the edges of the image and stopped where
 *      the colour changes. Each bristle also writes into a height map.
 *   3. Lettering, faces and wires are painted last with a pointed
 *      sign-writer's brush. Contours are scratched back to the ground
 *      (sgraffito). The height map is lit, and canvas tooth and varnish
 *      are added.
 *
 * The lettering is a hand-built curly alphabet (A-Z, 0-9, Rs, %, heart):
 * spline skeletons with spiral terminals. No fonts are used.
 *
 * The series: same seed, same street. After 01 each panel changes ONE element.
 *   0 Reference   the flat drawing, before paint
 *   1 Surrogates  the base painting
 *   2 Colour      colour only: every hue turned to its complement, values kept
 *   3 Form        form only: walls sag, eyes droop, outlines soften
 *   4 Texture     surface only: big brushes, impasto, knife, sgraffito
 *   5 Mood        light only: a power cut at night, two screens awake
 *   6 Type        lettering only: the offers take over the street
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
final int W = 1600, H = 2000;
final float PX = 28;                    // pixels per metre, shared by BOTH views
final float E_GROUND = 818;             // elevation: ground line
final float E_BOTTOM = 860;             // elevation panel ends
final float A_TOP = 882;                // plan panel starts (far kerb of the road)
final float A_D0 = A_TOP + 6*PX;        // plan: house-side road edge, depth d = 0
final float SUNX = 0.42, SUNY = 0.58;   // plan shadow offset per metre of height

long seed = 2511;
int stage = 1;
boolean AUTO_EXPORT = false;            // true: export everything, then quit

PGraphics ref, cv, shadeLo, shadeHi;
World world;
Look look;
boolean needsRender = true, showRef = false;
int renderPhase = 0;

final String[][] STAGES = {
  {"00", "Reference",  "the flat drawing, before paint"},
  {"01", "Surrogates", "the base painting"},
  {"02", "Colour",     "every hue turned to its complement"},
  {"03", "Form",       "the walls sag, the eyes droop"},
  {"04", "Texture",    "impasto, knife and sgraffito"},
  {"05", "Mood",       "a power cut, two screens awake"},
  {"06", "Type",       "the offers take over the street"}
};

// ------------------------------------------------------------ palette
final float[][] WALLS  = {{168,204,176},{234,164,142},{152,188,210},{238,212,124},{196,174,208},{242,192,150},{210,220,150}};
final float[][] TRIMS  = {{240,234,218},{92,128,120},{150,62,52},{70,82,110},{236,226,196}};
final float[][] CURTS  = {{206,92,86},{228,190,108},{110,140,186},{222,212,196},{150,112,160}};
final float[][] DOORS  = {{112,58,38},{86,50,36},{128,80,44}};
final float[][] CWALLS = {{226,220,204},{190,186,174},{176,108,78},{214,206,184},{200,214,200}};
final float[][] GATES  = {{58,82,70},{120,44,40},{60,64,72},{150,140,120}};
final float[][] INKS   = {{196,40,36},{36,66,150},{24,112,72},{30,30,32}};
final float[] TERRA = {178,86,56};
final float[] CONCRETE = {176,172,160};
final float[] EARTH = {164,104,74};
final float[] GRASS = {104,132,66};
final float[] ASPHALT = {92,90,86};
final float[] SKY_TOP = {164,180,190};
final float[] SKY_LOW = {224,218,200};
final float[] INK_DARK = {38,38,42};

// ===================================================================
void settings() {
  size(800, 1000);
}

void setup() {
  initGlyphs();
  ref = createGraphics(W, H);
  cv = createGraphics(W, H);
  shadeLo = createGraphics(W, H);
  shadeHi = createGraphics(W, H);
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
    surface.setTitle("SURROGATES   " + STAGES[stage][0] + " " + STAGES[stage][1] + "   seed " + seed);
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

String stageFile(int s) {
  return sketchPath("output/surrogates_" + seed + "_" + STAGES[s][0] + "_" + STAGES[s][1].toLowerCase() + ".png");
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
    pv.resize(800, 1000);
    pv.save(sketchPath("previews/" + STAGES[s][0] + "_" + STAGES[s][1].toLowerCase() + ".jpg"));
    thumbs[s] = cv.get();
    println("  panel " + STAGES[s][0] + " in " + nf((millis()-t0)/1000.0, 0, 1) + "s");
  }
  contactSheet(thumbs);
}

void contactSheet(PImage[] thumbs) {
  look = new Look(1);
  int tw = 360, th = 450, gut = 32, lab = 44;
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
      // title card, lettered in the same curly hand as the walls
      g.fill(222, 214, 196);
      fillShape(g, organic(new float[]{cx, cy, cx+tw, cy, cx+tw, cy+th, cx, cy+th}, 10, 2.5, 77));
      float th0 = min(46, (tw - 56)/textW("SURROGATES", 1));
      renderStrokes(g, typeset("SURROGATES", cx + 28, cy + 150, th0, th0*0.14, color(196, 40, 36), -0.04, 31, false, true));
      renderStrokes(g, typeset("ONE STREET", cx + 24, cy + 250, 24, 3.4, color(36, 66, 150), 0, 41, false, true));
      renderStrokes(g, typeset("TWO VIEWS", cx + 24, cy + 292, 24, 3.4, color(36, 66, 150), 0, 43, false, true));
      renderStrokes(g, typeset("SEVEN PANELS", cx + 24, cy + 334, 24, 3.4, color(36, 66, 150), 0, 47, false, true));
      renderStrokes(g, faceStrokes(cx + tw - 70, cy + th - 70, 70, color(30, 30, 32), 5, true));
    }
  }
  g.endDraw();
  g.save(sketchPath("output/surrogates_" + seed + "_contact_sheet.png"));
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
  float wob = 1;           // outline wobble
  float sag = 1;           // lean, droop, slump
  float[] radii = {20, 11, 6, 3.2, 1.8};
  float impasto = 1;
  int etchLevel = 1;       // 1: houses only, 2: everything, twice
  boolean knife = false, night = false, complement = false;
  float type = 0;          // 0 base lettering, 1 the offers take over
  float ghostA = 64;
  float round = 1;         // corner softness, multiplied into every outline

  Look(int s) {
    st = s;
    if (s == 2) complement = true;
    if (s == 3) { wob = 3.6; sag = 4.2; round = 4.0; }
    if (s == 4) { radii = new float[]{36, 20, 11, 6, 3.2}; impasto = 2.8; etchLevel = 2; knife = true; }
    if (s == 5) night = true;
    if (s == 6) { type = 1; ghostA = 150; }
  }

  int tone(float r, float g, float b, float a) {
    if (complement) {
      float[] c = complementMap(r, g, b);
      r = c[0]; g = c[1]; b = c[2];
    }
    if (night) {
      float L = 0.3*r + 0.59*g + 0.11*b;
      r = r*0.2 + L*0.05 + 12;
      g = g*0.24 + L*0.08 + 17;
      b = b*0.32 + L*0.14 + 38;
    }
    return color(r, g, b, a);
  }
}

// Colour panel: every hue is turned to its complement in YIQ space.
// Luma (Y) is kept exactly, so values, light and drawing are untouched;
// only the chroma (I, Q) is turned half a circle and lifted a little.
float[] complementMap(float r, float g, float b) {
  float Y = 0.299*r + 0.587*g + 0.114*b;
  float I = 0.596*r - 0.274*g - 0.322*b;
  float Q = 0.211*r - 0.523*g + 0.312*b;
  I *= -1.3;
  Q *= -1.3;
  return new float[]{
    constrain(Y + 0.956*I + 0.621*Q, 0, 255),
    constrain(Y - 0.272*I - 0.647*Q, 0, 255),
    constrain(Y - 1.106*I + 1.703*Q, 0, 255)};
}

int C(float[] c) { return look.tone(c[0], c[1], c[2], 255); }
int C(float[] c, float a) { return look.tone(c[0], c[1], c[2], a); }
int C(float r, float g, float b) { return look.tone(r, g, b, 255); }
int C(float r, float g, float b, float a) { return look.tone(r, g, b, a); }
float[] sh(float[] c, float k) { return new float[]{c[0]*k, c[1]*k, c[2]*k}; }
float[] mixc(float[] a, float[] b, float t) {
  return new float[]{lerp(a[0], b[0], t), lerp(a[1], b[1], t), lerp(a[2], b[2], t)};
}
float ey(float m) { return E_GROUND - m*PX; }
float ay(float d) { return A_D0 + d*PX; }

// ===================================================================
//  WORLD: one model, two projections
// ===================================================================
class House {
  int id, floors, roof, wallI, trimI, curtI, doorI, gateI, stairSide;
  float cx, w, d0, depth, lean, droop, gx;
  boolean dish, ac;
  float[] eyeU = new float[4];      // world rect of one upper eye (night lights)
  float slab() { return 0.45 + floors*3.1; }
  float rise() { return floors == 1 ? 2.4 : 2.2; }
}

class Plant {
  int kind;            // 0 palm, 1 banana, 2 shrub, 3 hibiscus, 4 canopy tree
  float x, d, h, bx, bd, r, sd;
}

class Thing {
  int kind;            // 0 car, 1 scooter, 2 parcel, 3 well, 4 clothesline
  float x, d, sd, a, b;
  int col;
}

class Ad {
  float x0, x1;
  String txt;
  int ink;
  boolean face;
}

class Ghost {
  String txt;
  float x, y, h, rot;
  boolean bubble;
}

class World {
  House[] houses = new House[5];
  ArrayList<Plant> plants = new ArrayList<Plant>();
  ArrayList<Thing> things = new ArrayList<Thing>();
  ArrayList<Ad> ads = new ArrayList<Ad>();
  ArrayList<Ghost> ghosts = new ArrayList<Ghost>();
  float[] poles;
  float[] crows;
  float[] segX0, segX1;
  int[] lotWall = new int[5];
  float lotW = W/5.0;

  World(long sd) {
    Random r = new Random(sd);
    int single = r.nextInt(5);
    int[] wallOrder = shuffled(r, WALLS.length);
    boolean flat = r.nextBoolean();
    for (int i = 0; i < 5; i++) {
      House h = new House();
      h.id = i;
      h.cx = lotW*(i + 0.5) + rr(r, -14, 14);
      h.w = PX*rr(r, 7.4, 9.0);
      h.floors = (i == single) ? 1 : 2;
      if (h.floors == 1) h.roof = 0;
      else { h.roof = flat ? 1 : 0; flat = !flat; }
      h.d0 = rr(r, 4.7, 6.0);
      h.depth = rr(r, 9.2, 11.0);
      h.lean = radians(rr(r, -1.1, 1.1));
      h.droop = rr(r, 0.3, 0.65);
      h.gx = h.cx + rr(r, -0.2, 0.2)*h.w;
      h.wallI = wallOrder[i];
      h.trimI = r.nextInt(TRIMS.length);
      h.curtI = r.nextInt(CURTS.length);
      h.doorI = r.nextInt(DOORS.length);
      h.gateI = r.nextInt(GATES.length);
      h.dish = r.nextFloat() < 0.65;
      h.ac = r.nextFloat() < 0.55;
      h.stairSide = r.nextBoolean() ? -1 : 1;
      houses[i] = h;
      lotWall[i] = r.nextInt(CWALLS.length);
    }

    // wall segments between gates
    float gh = 1.3*PX + 0.42*PX;              // half gate + pillar
    segX0 = new float[6];
    segX1 = new float[6];
    for (int i = 0; i <= 5; i++) {
      segX0[i] = (i == 0) ? -20 : houses[i-1].gx + gh;
      segX1[i] = (i == 5) ? W + 20 : houses[i].gx - gh;
    }

    // offers painted on the walls; ads[0..2] are the base, the rest join in panel 06
    String[] copy = {"0% EMI", "PETROL ₹115", "MEGA SALE", "BUY NOW", "FREE DATA", "FOR SALE"};
    int[] order = {2, 3, 1, 4, 0, 5};
    int[] txtOrder = {1, 0, 5, 2, 4, 3};
    for (int k = 0; k < 6; k++) {
      int sIdx = order[k];
      Ad a = new Ad();
      a.x0 = max(segX0[sIdx], 4);
      a.x1 = min(segX1[sIdx], W - 4);
      a.txt = copy[txtOrder[k]];
      if (sIdx == 0 || sIdx == 5) a.txt = (k % 2 == 0) ? "SALE" : "♥ 99+";
      a.ink = (txtOrder[k] == 1) ? 3 : r.nextInt(3);
      a.face = (k == 2 || k == 4);
      ads.add(a);
    }

    // poles stand at the kerb, d = -0.4; wires run along the road
    poles = new float[]{-340, 300, 975, 1640, 2300};
    for (int k = 1; k <= 2; k++) {
      for (House h : houses) {
        if (abs(poles[k] - h.gx) < 70) poles[k] += (poles[k] < h.gx ? -1 : 1)*(70 - abs(poles[k] - h.gx));
      }
    }
    crows = new float[]{rr(r, 420, 860), rr(r, 1080, 1500)};

    // palms: some in the gaps between houses, most behind
    for (int k = 0; k < 7; k++) {
      Plant p = new Plant();
      p.kind = 0;
      if (k < 3) {
        int gap = 1 + r.nextInt(4);
        p.x = gap*lotW + rr(r, -22, 22);
        p.d = rr(r, 6, 13);
      } else {
        p.x = rr(r, 40, W - 40);
        p.d = rr(r, 18, 27);
      }
      p.h = rr(r, 10.5, 15.5);
      p.bx = rr(r, -2.4, 2.4);
      p.bd = rr(r, -1.6, 1.6);
      p.sd = r.nextFloat()*100;
      plants.add(p);
    }
    for (int k = 0; k < 2; k++) {
      Plant p = new Plant();
      p.kind = 4;
      p.x = rr(r, 120, W - 120);
      p.d = rr(r, 19, 26);
      p.h = rr(r, 8.5, 11);
      p.r = rr(r, 3.6, 5.2);
      p.sd = r.nextFloat()*100;
      plants.add(p);
    }
    for (int k = 0; k < 7; k++) addFree(r, 1, 1.6, 27, 3.2, 4.6, 0, 0);
    for (int k = 0; k < 4; k++) addFree(r, 3, 0.9, 3.6, 2.1, 2.8, 0.8, 1.3);
    for (int k = 0; k < 30; k++) addFree(r, 2, 0.6, 28, 0.8, 2.2, 0.6, 1.5);

    // things
    House hc = houses[0];
    for (House h : houses) if (h.d0 > hc.d0) hc = h;
    Thing car = new Thing();
    car.kind = 0;
    float side = (hc.gx < hc.cx) ? 1 : -1;
    car.x = hc.cx + side*hc.w*0.27;
    car.d = 0.6;
    car.sd = r.nextFloat()*100;
    things.add(car);

    int[] sc = {r.nextInt(5), 0};
    sc[1] = (sc[0] + 2 + r.nextInt(2)) % 5;
    for (int k = 0; k < 2; k++) {
      House h = houses[sc[k]];
      Thing t = new Thing();
      t.kind = 1;
      float dir = (h.gx < W/2) ? 1 : -1;
      t.x = h.gx + dir*(gh + 38 + r.nextFloat()*30);
      t.d = -1.15;
      t.a = r.nextBoolean() ? 1 : -1;       // facing
      t.col = k;
      t.sd = r.nextFloat()*100;
      things.add(t);
    }
    Thing parcel = new Thing();
    parcel.kind = 2;
    House hp = houses[(sc[0] + 1) % 5];
    parcel.x = hp.gx + gh + 16;
    parcel.d = -0.32;
    parcel.sd = 3;
    things.add(parcel);

    for (int k = 0; k < 2; k++) {
      Thing wl = new Thing();
      wl.kind = 3;
      House h = houses[1 + k*2];
      wl.x = h.cx + rr(r, -0.25, 0.25)*h.w;
      wl.d = h.d0 + h.depth + rr(r, 3.5, 7);
      wl.sd = r.nextFloat()*100;
      things.add(wl);
    }
    for (int k = 0; k < 2; k++) {
      Thing cl = new Thing();
      cl.kind = 4;
      House h = houses[k*2 + (r.nextBoolean() ? 0 : 1)];
      cl.x = h.cx - h.w*0.35;
      cl.a = h.cx + h.w*0.35;
      cl.d = h.d0 + h.depth + rr(r, 1.6, 2.6);
      cl.b = rr(r, -0.6, 0.6);
      cl.sd = r.nextFloat()*100;
      things.add(cl);
    }

    // the sky is full of messages; 0..6 are the base, all of them in panel 06
    String[] gw = {"SALE", "LIKE", "0% EMI", "♥ 99+", "BUY NOW", "FOLLOW", "NEW", "OFFER", "SHARE",
                   "FREE", "DEAL", "♥", "SUBSCRIBE", "LIMITED", "BUY", "EMI"};
    for (int k = 0; k < gw.length; k++) {
      Ghost gst = new Ghost();
      gst.txt = gw[k];
      gst.bubble = (k % 3 == 1);
      gst.rot = rr(r, -0.1, 0.1);
      boolean placed = false;
      for (int tries = 0; tries < 400; tries++) {
        gst.h = (k < 7) ? rr(r, 54, 104) : rr(r, 42, 74);
        if (tries > 200) gst.h *= 0.82;
        float tw = textW(gst.txt, gst.h);
        gst.x = rr(r, 30 + gst.h*0.5, max(40, W - 30 - tw - gst.h*0.5));
        gst.y = rr(r, 40 + gst.h*1.5, E_GROUND - 310);
        boolean ok = true;
        for (Ghost o : ghosts) {
          float pad = 18;
          float ax0 = gst.x - gst.h*0.6, ax1 = gst.x + tw + gst.h*0.6, ay0 = gst.y - gst.h*1.5, ay1 = gst.y + gst.h*1.0;
          float ow = textW(o.txt, o.h);
          float bx0 = o.x - o.h*0.6, bx1 = o.x + ow + o.h*0.6, by0 = o.y - o.h*1.5, by1 = o.y + o.h*1.0;
          if (ax0 < bx1 + pad && bx0 < ax1 + pad && ay0 < by1 + pad && by0 < ay1 + pad) { ok = false; break; }
        }
        if (ok) { placed = true; break; }
      }
      if (placed || k < 7) ghosts.add(gst);     // a message with no room of its own is left out
    }
  }

  void addFree(Random r, int kind, float dmin, float dmax, float hmin, float hmax, float rmin, float rmax) {
    for (int tries = 0; tries < 40; tries++) {
      float x = rr(r, 20, W - 20), d = rr(r, dmin, dmax);
      boolean ok = true;
      for (House h : houses) {
        if (abs(x - h.cx) < h.w/2 + 0.9*PX && d > h.d0 - 0.9 && d < h.d0 + h.depth + 0.9) ok = false;
        if (abs(x - h.gx) < 1.2*PX && d < h.d0) ok = false;          // keep the path clear
      }
      if (!ok) continue;
      Plant p = new Plant();
      p.kind = kind;
      p.x = x;
      p.d = d;
      p.h = rr(r, hmin, hmax);
      p.r = rr(r, rmin, rmax);
      p.sd = r.nextFloat()*100;
      plants.add(p);
      return;
    }
  }

  // elevation height of the top wire at x (for the crows)
  float wireY(float x, int k) {
    for (int i = 0; i < poles.length - 1; i++) {
      if (x >= poles[i] && x <= poles[i+1]) {
        float t = (x - poles[i])/(poles[i+1] - poles[i]);
        return ey(wireH(k)) + 0.75*PX*4*t*(1 - t);
      }
    }
    return ey(wireH(k));
  }
}

float wireH(int k) { return 8.7 - k*0.5; }
float wireD(int k) { return (k % 2 == 0) ? -0.28 : -0.52; }

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
//  LAYERS PAINTED LAST: lettering and wires
// ===================================================================
ArrayList<TStroke> buildType(boolean forPaint) {
  ArrayList<TStroke> out = new ArrayList<TStroke>();
  int nAds = look.type > 0 ? 6 : 3;
  for (int k = 0; k < nAds; k++) {
    Ad a = world.ads.get(k);
    float len = a.x1 - a.x0;
    float faceW = a.face ? 34 : 0;
    float hh = look.type > 0 ? 25 : 22;
    hh = min(hh, (len - 24 - faceW)/max(1, textW(a.txt, 1)));
    float tw = textW(a.txt, hh);
    float tx = a.x0 + (len - faceW - tw)/2;
    float base = ey(0.36);
    out.addAll(typeset(a.txt, tx, base, hh, hh*0.17, C(INKS[a.ink]), 0, 11 + k*3.7, false, true));
    if (a.face) out.addAll(faceStrokes(tx + tw + 20, ey(0.72), 24, C(INKS[(a.ink + 1) % 3]), k*5.1, true));
  }
  // the parcel's printed smile
  for (Thing t : world.things) {
    if (t.kind != 2) continue;
    out.addAll(faceStrokes(t.x, ey(0.2), 7.5, C(40, 34, 30), 4, true));
    out.addAll(faceStrokes(t.x, ay(t.d), 6.5, C(40, 34, 30), 4, true));
  }
  // curly scrolls on the gate leaves
  for (House h : world.houses) {
    for (int sd = -1; sd <= 1; sd += 2) {
      float hx = h.gx + sd*1.3*PX;
      float lw = 1.3*PX*cos(radians(55));
      float mx = hx - sd*lw*0.5;
      ArrayList<float[]> sc = new ArrayList<float[]>();
      sc.add(new float[]{mx, ey(0.35)});
      sc.add(new float[]{mx - sd*4, ey(0.75)});
      sc.add(new float[]{mx + sd*2, ey(1.05)});
      float[] c = catmull(sc, false, 0.8);
      ArrayList<Float> all = new ArrayList<Float>();
      for (float v : c) all.add(v);
      int e = c.length - 2;
      all.addAll(curl(c[e], c[e+1], c[e] - c[e-2], c[e+1] - c[e-1], 4, mx - sd*6, ey(0.9)));
      float[] arr = new float[all.size()];
      for (int i = 0; i < arr.length; i++) arr[i] = all.get(i);
      out.add(mkStroke(arr, 1.8, C(sh(GATES[h.gateI], 0.55)), true));
    }
  }
  if (look.type > 0 && forPaint) {
    for (Ghost gst : world.ghosts) {
      out.addAll(typeset(gst.txt, gst.x, gst.y, gst.h, gst.h*0.13, C(250, 246, 236), gst.rot, gst.x*0.01, false, true));
      if (gst.bubble) out.add(bubble(gst, C(250, 246, 236)));
    }
    canalGhosts(out, C(220, 232, 226));
    // a terrace lettered for satellites
    for (House h : world.houses) {
      if (h.roof != 1) continue;
      float x0 = h.cx - h.w/2 + 0.6*PX, x1 = h.cx + h.w/2 - 0.6*PX;
      float hh = min(66, (x1 - x0)/textW("BUY", 1));
      float tw = textW("BUY", hh);
      out.addAll(typeset("BUY", (x0 + x1)/2 - tw/2, ay(h.d0 + h.depth*0.42) + hh/2, hh, hh*0.17, C(INKS[0]), 0, 71, false, true));
      break;
    }
  }
  return out;
}

void canalGhosts(ArrayList<TStroke> out, int col) {
  for (int k = 0; k < 3; k++) {
    Ghost gst = world.ghosts.get(k*2);
    float hh = 44;
    out.addAll(typeset(gst.txt, gst.x*0.8 + 60, ay(31.4), hh, hh*0.12, col, -gst.rot, gst.x*0.02, true, true));
  }
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
  for (int k = 0; k < 4; k++) {
    // elevation: catenaries between poles
    for (int i = 0; i < P.length - 1; i++) {
      int n = (int)((P[i+1] - P[i])/2);
      float[] p = new float[n*2];
      for (int j = 0; j < n; j++) {
        float t = j/(float)(n - 1);
        p[j*2] = lerp(P[i], P[i+1], t);
        p[j*2+1] = ey(wireH(k)) + 0.75*PX*4*t*(1 - t);
      }
      out.add(mkStroke(p, 1.5, wc, false));
    }
  }
  // plan: the same wires seen from above, two lines over the kerb
  for (int k = 0; k < 2; k++) {
    float y = ay(wireD(k));
    out.add(mkStroke(resample(new float[]{-20, y, W + 20, y + 1}, 2, false), 1.5, wc, false));
  }
  // service drops, matched in both views
  for (House h : world.houses) {
    float pole = nearestPole(h.cx);
    float ax = h.cx + (pole < h.cx ? -1 : 1)*h.w*0.38;
    float ah = (h.roof == 0) ? h.slab() - 0.1 : h.slab() + 0.6;
    int n = 60;
    float[] e = new float[n*2], a = new float[n*2];
    for (int j = 0; j < n; j++) {
      float t = j/(float)(n - 1);
      e[j*2] = lerp(pole, ax, t);
      e[j*2+1] = lerp(ey(wireH(3)), ey(ah), t) + 0.35*PX*4*t*(1 - t);
      a[j*2] = lerp(pole, ax, t);
      a[j*2+1] = lerp(ay(wireD(1)), ay(h.d0), t);
    }
    out.add(mkStroke(e, 1.2, wc, false));
    out.add(mkStroke(a, 1.2, wc, false));
  }
  return out;
}

float nearestPole(float x) {
  float best = world.poles[1];
  for (int i = 1; i <= 2; i++) if (abs(world.poles[i] - x) < abs(best - x)) best = world.poles[i];
  return best;
}

// ===================================================================
//  REFERENCE: the world drawn flat
// ===================================================================
void drawReference(PGraphics g) {
  etchPaths.clear();
  g.beginDraw();
  g.noStroke();
  g.background(C(SKY_LOW));
  g.clip(0, 0, W, E_BOTTOM);
  drawElevation(g);
  g.noClip();
  g.fill(C(52, 40, 32));
  g.rect(0, E_BOTTOM, W, A_TOP - E_BOTTOM);
  g.clip(0, A_TOP, W, H - A_TOP);
  drawPlan(g);
  g.noClip();
  renderStrokes(g, buildLines());
  renderStrokes(g, buildType(false));
  if (look.night) nightLights(g);
  g.endDraw();
}

// ------------------------------------------------------------ elevation
void drawElevation(PGraphics g) {
  HR = 0; HX = 0; HY = 0;
  // sky
  for (int y = 0; y < E_GROUND; y++) {
    float t = pow(y/E_GROUND, 0.8);
    g.fill(C(mixc(SKY_TOP, SKY_LOW, t)));
    g.rect(0, y, W, 1.5);
  }
  // monsoon cloud masses
  Random r = new Random(seed*7 + 1);
  for (int k = 0; k < 9; k++) {
    float cx = rr(r, -100, W + 100), cy = rr(r, 60, 460);
    float rx = rr(r, 160, 380), ry = rr(r, 40, 90);
    boolean dark = r.nextFloat() < 0.45;
    g.fill(dark ? C(120, 132, 140, 46) : C(246, 242, 230, 60));
    blob(g, cx, cy, rx, ry, 0.35, k*3.3);
  }
  // messages in the sky
  for (int k = 0; k < (look.type > 0 ? world.ghosts.size() : 7); k++) {
    Ghost gst = world.ghosts.get(k);
    int col = C(250, 248, 240, look.ghostA);
    renderStrokes(g, typeset(gst.txt, gst.x, gst.y, gst.h, gst.h*0.13, col, gst.rot, gst.x*0.01, false, true));
    if (gst.bubble) {
      ArrayList<TStroke> b = new ArrayList<TStroke>();
      b.add(bubble(gst, col));
      renderStrokes(g, b);
    }
  }
  // distant tree line across the paddy
  g.fill(C(132, 152, 140));
  float[] tl = new float[(W/8 + 3)*2];
  int n = 0;
  for (int x = -8; x <= W + 8; x += 8) {
    float hh = 5.5 + 4.5*noise(x*0.004, 1.7) + 1.6*noise(x*0.03, 4.4);
    tl[n*2] = x;
    tl[n*2+1] = ey(hh);
    n++;
  }
  g.beginShape();
  for (int i = 0; i < n; i++) g.vertex(tl[i*2], tl[i*2+1]);
  g.vertex(W + 8, E_GROUND);
  g.vertex(-8, E_GROUND);
  g.endShape(CLOSE);

  // everything, far to near
  ArrayList<float[]> order = new ArrayList<float[]>();     // {d, type, index}
  for (int i = 0; i < world.plants.size(); i++) order.add(new float[]{world.plants.get(i).d, 0, i});
  for (int i = 0; i < 5; i++) order.add(new float[]{world.houses[i].d0, 1, i});
  for (int i = 0; i < world.things.size(); i++) order.add(new float[]{world.things.get(i).d, 2, i});
  order.add(new float[]{0, 3, 0});                          // front walls and gates
  order.add(new float[]{-0.4, 4, 0});                       // poles
  Collections.sort(order, new java.util.Comparator<float[]>() {
    public int compare(float[] a, float[] b) { return Float.compare(b[0], a[0]); }
  });
  for (float[] o : order) {
    int t = (int)o[1], i = (int)o[2];
    if (t == 0) plantE(g, world.plants.get(i));
    else if (t == 1) houseE(g, world.houses[i]);
    else if (t == 2) thingE(g, world.things.get(i));
    else if (t == 3) wallsE(g);
    else if (t == 4) polesE(g);
  }
  // road edge
  g.fill(C(ASPHALT));
  fillShape(g, organic(rectP(-10, E_GROUND, W + 10, E_BOTTOM + 10), 2, 1.5, 9));
  g.fill(C(176, 172, 162));
  fillShape(g, organic(rectP(-10, E_GROUND - 1, W + 10, E_GROUND + 5), 2, 1.0, 10));
  Random pr = new Random(seed*13 + 5);
  for (int k = 0; k < 7; k++) {
    g.fill(C(mixc(SKY_TOP, ASPHALT, 0.35), 150));
    blob(g, rr(pr, 0, W), rr(pr, E_GROUND + 14, E_BOTTOM - 8), rr(pr, 20, 70), rr(pr, 3, 7), 0.3, k);
  }
  // crows on the top wire
  for (float cx : world.crows) {
    float wy = world.wireY(cx, 0);
    g.fill(C(24, 24, 28));
    blob(g, cx, wy - 6, 7, 5, 0.15, cx);
    blob(g, cx + 6, wy - 11, 3.6, 3.4, 0.1, cx + 1);
    g.triangle(cx - 6, wy - 6, cx - 15, wy + 3, cx - 9, wy - 2);
    g.triangle(cx + 9, wy - 12, cx + 13, wy - 10.5, cx + 9, wy - 9.5);
  }
}

void plantE(PGraphics g, Plant p) {
  if (p.kind == 0) palmE(g, p);
  else if (p.kind == 1) bananaE(g, p);
  else if (p.kind == 4) canopyE(g, p);
  else shrubE(g, p);
}

void palmE(PGraphics g, Plant p) {
  float bx = p.bx*PX*(1 + (look.sag - 1)*0.25);
  float tx = p.x + bx, ty = ey(p.h);
  int n = 40;
  float[] l = new float[n*2], r = new float[n*2];
  for (int i = 0; i < n; i++) {
    float t = i/(float)(n - 1);
    float x = p.x + bx*(t*t*0.7 + t*0.3) + sin(t*PI)*bx*0.25;
    float y = lerp(E_GROUND, ty, t);
    float w = lerp(0.36, 0.2, t)*PX*0.5;
    l[i*2] = x - w; l[i*2+1] = y;
    r[i*2] = x + w; r[i*2+1] = y;
  }
  recLevel = 2;
  float[] trunk = new float[n*4];
  for (int i = 0; i < n; i++) { trunk[i*2] = l[i*2]; trunk[i*2+1] = l[i*2+1]; }
  for (int i = 0; i < n; i++) { trunk[(n + i)*2] = r[(n - 1 - i)*2]; trunk[(n + i)*2+1] = r[(n - 1 - i)*2+1]; }
  wobble(trunk, 1.2*look.wob, p.sd);
  g.fill(C(132, 120, 102));
  fillShape(g, trunk);
  recLevel = 0;
  g.fill(C(96, 88, 76, 120));
  for (int i = 2; i < n; i += 5) {
    float t = i/(float)(n - 1);
    float x = (l[i*2] + r[i*2])/2;
    blob(g, x + 1.2, l[i*2+1], 3.5, 1.2, 0.3, p.sd + i);
  }
  // crown
  Random R = new Random((long)(p.sd*1000));
  float[][] greens = {{70,104,52},{96,128,60},{52,80,44},{84,116,58}};
  for (int f = 0; f < 18; f++) {
    float ang;
    if (f < 13) ang = radians(-172 + f*(164/12.0) + rr(R, -6, 6));
    else ang = radians(rr(R, 20, 160));
    float len = 4.6*PX*rr(R, 0.8, 1.1);
    float grav = (f < 13) ? 0.7 + 0.35*abs(cos(ang)) : 0.2;
    float[] sp = arcSpine(tx, ty, ang, len, grav*(0.8 + 0.2*look.sag), 22);
    boolean dry = R.nextFloat() < 0.12;
    g.fill(dry ? C(150, 122, 72) : C(greens[f % 4]));
    blade(g, sp, 0.42*PX, 0.75, p.sd + f);
  }
  g.fill(C(120, 96, 50));
  for (int k = 0; k < 6; k++) blob(g, tx + rr(R, -9, 9), ty + rr(R, 2, 12), 5, 5, 0.15, k + p.sd);
}

void canopyE(PGraphics g, Plant p) {
  float cx = p.x, cy = ey(p.h - p.r*0.9);
  g.fill(C(84, 70, 56));
  fillShape(g, organic(rectP(cx - 0.25*PX, cy, cx + 0.25*PX, E_GROUND), 3, 1.5*look.wob, p.sd));
  Random R = new Random((long)(p.sd*1000) + 3);
  for (int k = 0; k < 10; k++) {
    float a = rr(R, 0, TWO_PI), d = rr(R, 0, p.r*0.55)*PX;
    float rr0 = p.r*PX*rr(R, 0.38, 0.6);
    float lift = (sin(a) < 0 && cos(a) < 0.3) ? 1.0 : 0.0;
    g.fill(C(lift > 0 ? new float[]{78,112,58} : new float[]{44,72,42}));
    blob(g, cx + cos(a)*d, cy + sin(a)*d*0.8, rr0, rr0*0.85, 0.3*look.wob, p.sd + k);
  }
}

void bananaE(PGraphics g, Plant p) {
  float top = ey(p.h*0.55);
  g.fill(C(120, 140, 70));
  fillShape(g, organic(rectP(p.x - 0.15*PX, top, p.x + 0.15*PX, E_GROUND), 3, 1.2*look.wob, p.sd));
  Random R = new Random((long)(p.sd*1000) + 9);
  for (int k = 0; k < 7; k++) {
    float ang = radians(-90 + (k - 3)*26 + rr(R, -8, 8));
    float len = rr(R, 2.0, 2.6)*PX;
    float[] sp = arcSpine(p.x, top, ang, len, 0.5 + 0.25*look.sag, 16);
    g.fill(C(k % 2 == 0 ? new float[]{134,166,70} : new float[]{108,142,58}));
    blade(g, sp, 0.3*PX, 0.25, p.sd + k);
  }
}

void shrubE(PGraphics g, Plant p) {
  Random R = new Random((long)(p.sd*1000) + 11);
  float hh = p.h*PX;
  for (int k = 0; k < 4; k++) {
    float x = p.x + rr(R, -0.5, 0.5)*p.r*PX;
    float y = E_GROUND - hh*rr(R, 0.35, 0.65);
    g.fill(C(k % 2 == 0 ? new float[]{66,100,52} : new float[]{88,122,60}));
    blob(g, x, y, p.r*PX*0.7, hh*0.45, 0.35*look.wob, p.sd + k);
  }
  if (p.kind == 3) {
    g.fill(C(214, 40, 48));
    for (int k = 0; k < 9; k++) blob(g, p.x + rr(R, -0.8, 0.8)*p.r*PX, E_GROUND - hh*rr(R, 0.3, 0.9), 3.2, 2.8, 0.2, k);
  }
}

void houseE(PGraphics g, House h) {
  HR = h.lean*look.sag;
  HX = h.cx;
  HY = E_GROUND;
  float hw = h.w/2, sl = h.slab()*PX, amp = 1.3*look.wob, sd = h.id*17.3 + 5;
  float[] wall = WALLS[h.wallI], trim = TRIMS[h.trimI];
  float bulge = (look.sag - 1)*3;

  // stair room behind the parapet
  float sx = h.stairSide*(hw - 1.9*PX);
  if (h.roof == 1) {
    float stTop = sl + 0.2*PX + 2.7*PX;
    g.fill(C(sh(wall, 0.9)));
    orect(g, sx - 1.6*PX, -stTop, sx + 1.6*PX, -sl, 4, amp, sd + 30);
    g.fill(C(trim));
    orect(g, sx - 1.85*PX, -stTop - 0.18*PX, sx + 1.85*PX, -stTop + 0.05*PX, 3, amp, sd + 31);
    g.fill(C(30, 34, 44));
    orect(g, sx - 0.32*PX, -stTop + 0.7*PX, sx + 0.32*PX, -stTop + 1.3*PX, 4, amp, sd + 32);
    // the water tank
    float tb = -stTop - 0.18*PX;
    g.fill(C(32, 34, 38));
    fillShape(g, organic(L(sx + 0.3*PX, tb - 1.25*PX, sx + 1.4*PX, tb - 1.25*PX, sx + 1.4*PX, tb, sx + 0.3*PX, tb), 10, amp, sd + 33));
    g.fill(C(92, 98, 106));
    orect(g, sx + 0.42*PX, tb - 1.1*PX, sx + 0.55*PX, tb - 0.15*PX, 2, 0.5, sd + 34);
  }

  // body
  recLevel = 1;
  g.fill(C(wall));
  fillShape(g, organic(L(-hw, -sl, 0, -sl - bulge, hw, -sl, hw + bulge, -sl*0.5, hw, 0, -hw, 0, -hw - bulge, -sl*0.5), 5, amp, sd));
  recLevel = 0;
  for (int k = 0; k < 6; k++) {
    g.fill(C(0, 0, 0, 7));
    orect(g, lerp(-hw, hw, 0.4 + k*0.1), -sl, hw, 0, 2, amp*0.5, sd + k);
  }
  // monsoon streaks from the top
  Random R = new Random((long)(sd*77));
  for (int k = 0; k < 7; k++) {
    float x = rr(R, -hw + 6, hw - 6);
    float len = rr(R, 0.6, 2.2)*PX;
    g.fill(C(52, 60, 50, 38));
    orect(g, x - rr(R, 1.5, 3.5), -sl, x + rr(R, 1.5, 3.5), -sl + len, 3, 1.4, sd + 40 + k);
  }
  // plinth
  g.fill(C(sh(wall, 0.72)));
  orect(g, -hw - 3, -0.45*PX, hw + 3, 0, 2, amp, sd + 1);
  // floor band
  if (h.floors == 2) {
    float y = -(0.45 + 3.1)*PX;
    g.fill(C(0, 0, 0, 40));
    orect(g, -hw, y, hw, y + 0.4*PX, 2, amp, sd + 2);
    g.fill(C(trim));
    orect(g, -hw - 0.25*PX, y - 0.2*PX, hw + 0.25*PX, y, 2, amp, sd + 3);
  }

  float doorX = h.gx - h.cx;
  float dr = h.droop*look.sag;
  if (h.floors == 2) {
    float ex = max(h.w*0.24, 1.6*PX);
    eyeE(g, h, -ex, 4.35, 5.85, 1.65, dr, -1, 0.42 + h.droop*0.12, sd + 50, true);
    eyeE(g, h, ex, 4.35, 5.85, 1.65, dr*0.8, 1, 0.5, sd + 60, false);
    float lx = (doorX < 0) ? h.w*0.27 : -h.w*0.27;
    eyeE(g, h, lx, 1.2, 2.45, 1.4, dr*0.6, (lx < 0) ? -1 : 1, 0.3, sd + 70, false);
    if (h.ac) {
      float ax = ex*((h.id % 2 == 0) ? 1 : -1);
      g.fill(C(212, 212, 206));
      orect(g, ax - 0.42*PX, -4.25*PX, ax + 0.42*PX, -3.7*PX, 4, amp, sd + 80);
      g.fill(C(70, 72, 74));
      fillShape(g, organic(L(ax - 0.2*PX, -4.15*PX, ax + 0.18*PX, -4.15*PX, ax + 0.18*PX, -3.8*PX, ax - 0.2*PX, -3.8*PX), 8, 0.6, sd + 81));
      g.fill(C(48, 56, 48, 50));
      orect(g, ax + 0.3*PX, -3.7*PX, ax + 0.3*PX + 4, -2.2*PX, 2, 1.2, sd + 82);
    }
  } else {
    float ex = h.w*0.27;
    eyeE(g, h, -ex, 1.15, 2.45, 1.45, dr, -1, 0.45, sd + 50, true);
    eyeE(g, h, ex, 1.15, 2.45, 1.45, dr*0.8, 1, 0.52, sd + 60, false);
  }
  // door: a mouth behind the gate
  g.fill(C(sh(trim, 0.92)));
  orect(g, doorX - 0.62*PX, -2.75*PX, doorX + 0.62*PX, -2.6*PX, 2, amp, sd + 90);
  g.fill(C(0, 0, 0, 40));
  orect(g, doorX - 0.6*PX, -2.6*PX, doorX + 0.6*PX, -2.35*PX, 2, amp, sd + 91);
  g.fill(C(DOORS[h.doorI]));
  orect(g, doorX - 0.5*PX, -2.55*PX, doorX + 0.5*PX, -0.45*PX, 3, amp, sd + 92);
  g.fill(C(sh(DOORS[h.doorI], 0.7)));
  orect(g, doorX - 0.03*PX, -2.5*PX, doorX + 0.03*PX, -0.5*PX, 1, 0.5, sd + 93);
  g.fill(C(220, 190, 110));
  orect(g, doorX + 0.25*PX, -1.45*PX, doorX + 0.32*PX, -1.32*PX, 1, 0.3, sd + 94);

  // roof
  if (h.roof == 0) {
    float eave = -(h.slab() + 0.1)*PX, ov = 0.75*PX;
    float ridge = eave - h.rise()*PX*(1 + (look.sag - 1)*0.08);
    float rt = max(0.35*PX, (h.w - h.depth*PX)/2);
    g.fill(C(0, 0, 0, 60));
    orect(g, -hw, eave, hw, eave + 0.5*PX, 2, amp, sd + 100);
    recLevel = 1;
    g.fill(C(TERRA));
    float slump = (look.sag - 1)*4;
    fillShape(g, organic(L(-hw - ov, eave, -hw*0.5, eave + slump, hw*0.5, eave + slump, hw + ov, eave, rt, ridge, -rt, ridge), 7, amp*1.2, sd + 101));
    recLevel = 0;
    g.fill(C(sh(TERRA, 1.12), 120));
    fillShape(g, organic(L(-hw - ov*0.4, eave - 4, -rt*0.4, ridge + 6, -rt*0.2, ridge + 10, -hw*0.2, eave - 4), 6, amp, sd + 102));
    g.fill(C(90, 48, 36));
    orect(g, -hw - ov, eave - 0.05*PX, hw + ov, eave + 0.12*PX, 2, amp, sd + 103);
    for (int k = 0; k < 5; k++) {
      float x = rr(R, -hw*0.8, hw*0.8);
      g.fill(C(70, 64, 48, 70));
      fillShape(g, organic(L(x - 2, lerp(ridge, eave, 0.3), x + 3, lerp(ridge, eave, 0.3), x + 4, eave - 3, x - 3, eave - 3), 2, 1.2, sd + 110 + k));
    }
    g.fill(C(188, 184, 172));
    fillShape(g, organic(L(-rt - 3, ridge + 2, rt + 3, ridge + 2, rt + 1, ridge - 4, -rt - 1, ridge - 4), 3, 0.8, sd + 120));
    if (h.dish) dishE(g, hw - 0.6*PX, eave - 0.9*PX, sd + 130, -1);
  } else {
    float top = sl + 0.2*PX;
    g.fill(C(0, 0, 0, 55));
    orect(g, -hw, -sl, hw, -sl + 0.4*PX, 2, amp, sd + 100);
    recLevel = 1;
    g.fill(C(mixc(wall, new float[]{250,248,240}, 0.18)));
    orect(g, -hw, -top - 0.9*PX, hw, -top, 3, amp, sd + 101);
    recLevel = 0;
    g.fill(C(trim));
    orect(g, -hw - 0.22*PX, -top, hw + 0.22*PX, -sl, 2, amp, sd + 102);
    g.fill(C(sh(trim, 0.9)));
    orect(g, -hw - 0.05*PX, -top - 0.98*PX, hw + 0.05*PX, -top - 0.86*PX, 2, amp, sd + 103);
    for (int k = 0; k < 6; k++) {
      float x = rr(R, -hw + 6, hw - 6);
      g.fill(C(48, 56, 46, 52));
      orect(g, x - 2, -top - 0.86*PX, x + 2.5, -top - 0.86*PX + rr(R, 0.3, 0.8)*PX, 2, 1, sd + 104 + k);
    }
    if (h.dish) dishE(g, -h.stairSide*(hw - 0.9*PX), -top - 1.4*PX, sd + 130, h.stairSide);
  }
  HR = 0; HX = 0; HY = 0;
}

void dishE(PGraphics g, float x, float y, float sd, float face) {
  g.fill(C(120, 118, 112));
  orect(g, x - 1, y, x + 1.5, y + 0.8*PX, 1, 0.4, sd);
  g.fill(C(206, 206, 200));
  float[] d = new float[40*2];
  for (int i = 0; i < 40; i++) {
    float a = TWO_PI*i/40;
    d[i*2] = x + cos(a)*0.14*PX + face*2;
    d[i*2+1] = y + sin(a)*0.34*PX;
  }
  fillShape(g, organic(L(d), 0, 0.4, sd));
  g.fill(C(90, 90, 86));
  orect(g, x + face*0.45*PX - 1.5, y - 1.5, x + face*0.45*PX + 1.5, y + 1.5, 1, 0.2, sd + 1);
}

// one window, read as an eye: curtain for a lid, a sunshade for a brow
void eyeE(PGraphics g, House h, float cx, float sillM, float topM, float wM, float droop,
          int outer, float lid, float sd, boolean record) {
  float x0 = cx - wM*PX/2, x1 = cx + wM*PX/2, y0 = -topM*PX, y1 = -sillM*PX;
  float amp = 1.0*look.wob;
  float[] trim = TRIMS[h.trimI], curt = CURTS[h.curtI];
  g.fill(C(0, 0, 0, 48));
  orect(g, x0 - 0.3*PX, y0 - 0.3*PX, x1 + 0.3*PX, y0 + 0.16*PX, 3, amp, sd);
  g.fill(C(trim));
  orect(g, x0 - 0.12*PX, y0 - 0.12*PX, x1 + 0.12*PX, y1 + 0.12*PX, 4, amp, sd + 1);
  g.fill(C(30, 34, 44));
  orect(g, x0, y0, x1, y1, 4, amp, sd + 2);
  g.fill(C(92, 104, 116, 70));
  orect(g, x0 + 3, lerp(y0, y1, 0.55), lerp(x0, x1, 0.5), y1 - 3, 6, amp, sd + 3);
  if (record) {
    float[] a = L(x0, y0), b = L(x1, y1);
    h.eyeU[0] = min(a[0], b[0]); h.eyeU[1] = min(a[1], b[1]);
    h.eyeU[2] = max(a[0], b[0]); h.eyeU[3] = max(a[1], b[1]);
  }
  // lid
  float hgt = y1 - y0;
  float lo = lid*(1 + droop*0.5), li = lid*(1 - droop*0.25);
  float lL = (outer < 0) ? lo : li, lR = (outer < 0) ? li : lo;
  float lm = max(lL, lR)*1.08;
  g.fill(C(curt));
  recLevel = 2;
  fillShape(g, organic(L(x0, y0, x1, y0, x1, y0 + hgt*lR, lerp(x0, x1, 0.5), y0 + hgt*lm, x0, y0 + hgt*lL), 4, amp, sd + 4));
  recLevel = 0;
  g.fill(C(sh(curt, 0.8)));
  for (int k = 1; k <= 2; k++) {
    float fx = lerp(x0, x1, k/3.0);
    orect(g, fx - 1.2, y0, fx + 1.2, y0 + hgt*lm*0.85, 1, 0.6, sd + 5 + k);
  }
  // catchlight
  float inner = -outer;
  float cxl = cx + inner*wM*PX*0.18;
  g.fill(C(236, 238, 240, 170));
  fillShape(g, organic(L(cxl - 2, y0 + hgt*lm + 3, cxl + 2, y0 + hgt*lm + 3, cxl + 2, y0 + hgt*lm + 6, cxl - 2, y0 + hgt*lm + 6), 2, 0.2, sd + 8));
  // sill
  g.fill(C(sh(trim, 0.95)));
  orect(g, x0 - 0.18*PX, y1 + 0.06*PX, x1 + 0.18*PX, y1 + 0.2*PX, 2, amp, sd + 9);
  // brow: the outer end falls
  float by = y0 - 0.24*PX, bt = 0.16*PX, fall = droop*0.5*PX;
  float bxIn = (outer < 0) ? x1 + 0.35*PX : x0 - 0.35*PX;
  float bxOut = (outer < 0) ? x0 - 0.35*PX : x1 + 0.35*PX;
  g.fill(C(sh(trim, 0.9)));
  fillShape(g, organic(L(bxIn, by, cx, by + fall*0.3, bxOut, by + fall, bxOut, by + fall + bt, cx, by + fall*0.3 + bt, bxIn, by + bt), 3, amp, sd + 10));
  // tears
  Random R = new Random((long)(sd*131));
  float tx = (outer < 0) ? x0 + 3 : x1 - 3;
  float len = (0.7 + droop*1.4 + R.nextFloat()*0.6)*PX;
  g.fill(C(44, 52, 44, 60));
  fillShape(g, organic(L(tx - 2, y1 + 0.2*PX, tx + 2.5, y1 + 0.2*PX, tx + 1.5, y1 + 0.2*PX + len, tx - 1, y1 + 0.2*PX + len), 2, 1.5, sd + 11));
  float tx2 = bxOut + ((outer < 0) ? 3 : -3);
  g.fill(C(44, 52, 44, 44));
  fillShape(g, organic(L(tx2 - 1.5, by + fall + bt, tx2 + 2, by + fall + bt, tx2 + 1, by + fall + bt + len*0.7, tx2 - 1, by + fall + bt + len*0.7), 2, 1.2, sd + 12));
}

void wallsE(PGraphics g) {
  HR = 0; HX = 0; HY = 0;
  float wt = ey(1.4), gh = 1.3*PX;
  int nAds = look.type > 0 ? 6 : 3;
  for (int s = 0; s < 6; s++) {
    float x0 = world.segX0[s], x1 = world.segX1[s];
    // split at lot boundaries: each owner paints their own stretch
    for (int lot = 0; lot < 5; lot++) {
      float a = max(x0, lot*world.lotW), b = min(x1, (lot + 1)*world.lotW);
      if (b - a < 2) continue;
      float[] wc = CWALLS[world.lotWall[lot]];
      recLevel = 2;
      g.fill(C(wc));
      fillShape(g, organic(rectP(a, wt, b, E_GROUND + 3), 2, 1.2*look.wob, s*9 + lot));
      recLevel = 0;
      g.fill(C(sh(wc, 0.86)));
      fillShape(g, organic(rectP(a - 2, wt - 0.12*PX, b + 2, wt + 0.06*PX), 2, 1.0*look.wob, s*9 + lot + 50));
      g.fill(C(60, 58, 48, 46));
      fillShape(g, organic(rectP(a, ey(0.45), b, E_GROUND + 2), 2, 2.5, s*9 + lot + 60));
      Random R = new Random(seed + s*31 + lot);
      for (int k = 0; k < (int)((b - a)/40); k++) {
        float x = rr(R, a + 4, b - 4);
        g.fill(C(56, 62, 50, 40));
        fillShape(g, organic(rectP(x - 1.5, wt, x + 2, wt + rr(R, 0.3, 1.0)*PX), 2, 1.2, s*9 + lot + 70 + k));
      }
    }
  }
  // whitewashed patches for the offers
  for (int k = 0; k < nAds; k++) {
    Ad a = world.ads.get(k);
    g.fill(C(240, 236, 222));
    fillShape(g, organic(rectP(a.x0 + 6, ey(1.27), a.x1 - 6, ey(0.14)), 5, 1.6*look.wob, k*13 + 3));
  }
  // gate pillars and open leaves
  for (House h : world.houses) {
    float[] wc = CWALLS[world.lotWall[h.id]];
    for (int sd = -1; sd <= 1; sd += 2) {
      float px = h.gx + sd*(gh + 0.21*PX);
      g.fill(C(mixc(wc, new float[]{250,248,240}, 0.2)));
      fillShape(g, organic(rectP(px - 0.21*PX, ey(1.75), px + 0.21*PX, E_GROUND + 2), 3, 1.0*look.wob, h.id*5 + sd));
      g.fill(C(sh(wc, 0.85)));
      fillShape(g, organic(rectP(px - 0.3*PX, ey(1.9), px + 0.3*PX, ey(1.72)), 3, 1.0*look.wob, h.id*5 + sd + 20));
      float hx = h.gx + sd*gh;
      float lw = gh*cos(radians(55));
      g.fill(C(sh(GATES[h.gateI], 0.85)));
      fillShape(g, organic(rectP(min(hx, hx - sd*lw), ey(1.25), max(hx, hx - sd*lw), ey(0.1)), 3, 1.0*look.wob, h.id*5 + sd + 40));
    }
  }
}

void polesE(PGraphics g) {
  for (int i = 1; i <= 2; i++) {
    float x = world.poles[i];
    recLevel = 2;
    g.fill(C(170, 168, 160));
    fillShape(g, organic(rectP(x - 0.15*PX, ey(9.1), x + 0.15*PX, E_GROUND + 2), 2, 0.8*look.wob, i*3));
    recLevel = 0;
    g.fill(C(0, 0, 0, 40));
    fillShape(g, organic(rectP(x + 0.02*PX, ey(9.1), x + 0.15*PX, E_GROUND + 2), 2, 0.6, i*3 + 1));
    g.fill(C(80, 82, 86));
    fillShape(g, organic(rectP(x - 0.05*PX, ey(8.95), x + 0.32*PX, ey(7.0)), 2, 0.6, i*3 + 2));
    for (int k = 0; k < 4; k++) {
      g.fill(C(224, 222, 214));
      blob(g, x + 0.3*PX, ey(wireH(k)) - 1, 2.6, 3.2, 0.1, i*10 + k);
    }
  }
}

void thingE(PGraphics g, Thing t) {
  if (t.kind == 0) {
    // the covered car: only its roof shows over the wall
    g.fill(C(170, 174, 178));
    blob(g, t.x, ey(1.36), 0.92*PX, 0.22*PX, 0.15, t.sd);
  } else if (t.kind == 1) {
    float f = t.a, x = t.x;
    g.fill(C(30, 30, 32));
    blob(g, x - f*0.62*PX, ey(0.27), 0.26*PX, 0.27*PX, 0.06, t.sd);
    blob(g, x + f*0.62*PX, ey(0.27), 0.26*PX, 0.27*PX, 0.06, t.sd + 1);
    float[] c = (t.col == 0) ? new float[]{128,42,46} : new float[]{150,152,156};
    g.fill(C(c));
    recLevel = 2;
    fillShape(g, organic(new float[]{
      x - f*0.98*PX, ey(0.42), x - f*0.95*PX, ey(0.78), x - f*0.55*PX, ey(0.96),
      x + f*0.05*PX, ey(0.92), x + f*0.38*PX, ey(0.86), x + f*0.6*PX, ey(1.22),
      x + f*0.9*PX, ey(1.0), x + f*0.98*PX, ey(0.45), x + f*0.55*PX, ey(0.3), x - f*0.6*PX, ey(0.32)}, 6, 1.4*look.wob, t.sd + 2));
    recLevel = 0;
    g.fill(C(sh(c, 0.75)));
    for (int k = 0; k < 4; k++) {
      float fx = x + f*(-0.7 + k*0.45)*PX;
      fillShape(g, organic(rectP(fx - 1, ey(0.88), fx + 1.5, ey(0.36)), 1, 1.2, t.sd + 3 + k));
    }
  } else if (t.kind == 2) {
    g.fill(C(184, 140, 92));
    fillShape(g, organic(rectP(t.x - 0.26*PX, ey(0.4), t.x + 0.26*PX, E_GROUND + 1), 2, 0.5, 33));
    g.fill(C(214, 190, 150));
    fillShape(g, organic(rectP(t.x - 0.26*PX, ey(0.4), t.x + 0.26*PX, ey(0.34)), 1, 0.3, 34));
  }
}

// ------------------------------------------------------------ plan
void drawPlan(PGraphics g) {
  HR = 0; HX = 0; HY = 0;
  // road
  g.fill(C(ASPHALT));
  g.rect(0, A_TOP, W, A_D0 - A_TOP + 4);
  Random R = new Random(seed*17 + 2);
  for (int k = 0; k < 14; k++) {
    g.fill(k % 2 == 0 ? C(104, 100, 94) : C(80, 78, 74));
    blob(g, rr(R, 0, W), rr(R, A_TOP + 10, A_D0 - 30), rr(R, 30, 110), rr(R, 10, 30), 0.4, k*1.7);
  }
  for (int k = 0; k < 6; k++) {
    g.fill(C(mixc(SKY_TOP, ASPHALT, 0.5), 190));
    blob(g, rr(R, 0, W), rr(R, A_TOP + 20, A_D0 - 40), rr(R, 12, 38), rr(R, 5, 13), 0.45, k*2.9 + 40);
  }
  g.fill(C(156, 152, 142));
  fillShape(g, organic(rectP(-10, ay(-0.7), W + 10, ay(0)), 2, 1.2, 5));
  // lots
  for (int lot = 0; lot < 5; lot++) {
    float x0 = lot*world.lotW, x1 = x0 + world.lotW;
    g.fill(C(EARTH));
    g.rect(x0, ay(0), world.lotW, ay(29.6) - ay(0));
    Random L2 = new Random(seed*31 + lot);
    for (int k = 0; k < 14; k++) {
      g.fill(C(k % 3 == 0 ? new float[]{122,146,74} : GRASS));
      blob(g, rr(L2, x0, x1), rr(L2, ay(1), ay(29)), rr(L2, 0.8, 2.6)*PX, rr(L2, 0.6, 2.0)*PX, 0.45*look.wob, lot*20 + k);
    }
    for (int k = 0; k < 30; k++) {
      g.fill(C(132, 92, 58, 120));
      blob(g, rr(L2, x0, x1), rr(L2, ay(14), ay(29)), 2.5, 1.6, 0.4, lot*50 + k);
    }
  }
  for (House h : world.houses) {
    g.fill(C(194, 160, 120, 210));
    blob(g, h.cx + h.w*0.08, ay(h.d0*0.6), h.w*0.5, h.d0*0.36*PX, 0.42*look.wob, h.id*3.3);
    g.fill(C(186, 168, 136));
    fillShape(g, organic(rectP(h.gx - 0.6*PX, ay(0), h.gx + 0.6*PX, ay(h.d0)), 3, 1.2*look.wob, h.id*4 + 1));
  }
  // back wall and canal
  g.fill(C(166, 102, 74));
  fillShape(g, organic(rectP(-10, ay(29.6), W + 10, ay(30.4)), 3, 2.5*look.wob, 61));
  g.fill(C(92, 116, 104));
  g.rect(0, ay(30.4), W, H - ay(30.4) + 4);
  for (int k = 0; k < 8; k++) {
    g.fill(C(mixc(SKY_LOW, new float[]{92,116,104}, 0.5), 90));
    blob(g, rr(R, 0, W), rr(R, ay(31), H - 10), rr(R, 80, 240), rr(R, 6, 16), 0.3, k*5.5 + 80);
  }
  if (look.type == 0) {
    ArrayList<TStroke> cg = new ArrayList<TStroke>();
    canalGhosts(cg, C(220, 232, 226, look.ghostA));
    renderStrokes(g, cg);
  }
  for (int k = 0; k < 9; k++) {
    float hx = rr(R, 0, W), hy = rr(R, ay(30.9), H - 12);
    g.fill(C(84, 128, 62));
    blob(g, hx, hy, rr(R, 14, 34), rr(R, 9, 18), 0.4, k*3.1 + 120);
    g.fill(C(186, 160, 206));
    blob(g, hx + 4, hy - 3, 3, 3, 0.2, k + 130);
  }

  // low shadows: houses, walls, cars, scooters, poles, small plants
  shadeLo.beginDraw();
  shadeLo.clear();
  shadeLo.noStroke();
  shadeLo.fill(C(30, 30, 52));
  for (House h : world.houses) houseShadow(shadeLo, h);
  for (int s = 0; s < 6; s++) {
    float o = 1.4*PX;
    shadeLo.quad(world.segX0[s], ay(0.2), world.segX1[s], ay(0.2), world.segX1[s] + o*SUNX, ay(0.2) + o*SUNY, world.segX0[s] + o*SUNX, ay(0.2) + o*SUNY);
  }
  for (int k = 1; k < 5; k++) {
    float x = k*world.lotW, o = 1.4*PX;
    shadeLo.quad(x, ay(0.2), x + 6, ay(0.2), x + 6 + o*SUNX, ay(29.6) + o*SUNY, x + o*SUNX, ay(29.6) + o*SUNY);
  }
  for (Thing t : world.things) thingShadow(shadeLo, t);
  for (Plant p : world.plants) if (p.kind == 1 || p.kind == 2 || p.kind == 3) {
    float o = p.h*PX;
    shadeLo.ellipse(p.x + o*SUNX*0.6, ay(p.d) + o*SUNY*0.6, p.r*PX*1.6 + (p.kind == 1 ? 2.2*PX : 0), p.r*PX*1.4 + (p.kind == 1 ? 2.0*PX : 0));
  }
  for (int i = 1; i <= 2; i++) {
    float x = world.poles[i], y = ay(-0.4), o = 9.1*PX;
    shadeLo.strokeWeight(7);
    shadeLo.stroke(C(30, 30, 52));
    shadeLo.line(x, y, x + o*SUNX, y + o*SUNY);
    shadeLo.noStroke();
  }
  shadeLo.endDraw();
  g.tint(255, look.night ? 60 : 105);
  g.image(shadeLo, 0, 0);
  g.noTint();

  // walls from above
  for (int s = 0; s < 6; s++) {
    recLevel = 2;
    g.fill(C(214, 206, 188));
    fillShape(g, organic(rectP(world.segX0[s], ay(0), world.segX1[s], ay(0.24)), 2, 0.8*look.wob, s + 200));
    recLevel = 0;
  }
  for (int k = 1; k < 5; k++) {
    float x = k*world.lotW;
    g.fill(C(186, 172, 150));
    fillShape(g, organic(rectP(x, ay(0.24), x + 4, ay(29.6)), 2, 1.8*look.wob, k + 210));
  }
  for (House h : world.houses) {
    float gh = 1.3*PX;
    for (int sd = -1; sd <= 1; sd += 2) {
      float px = h.gx + sd*(gh + 0.21*PX);
      g.fill(C(232, 226, 210));
      fillShape(g, organic(rectP(px - 0.3*PX, ay(-0.06), px + 0.3*PX, ay(0.3)), 3, 0.8, h.id*7 + sd));
      // open leaves swing into the yard
      float hx = h.gx + sd*gh, a = radians(55);
      float ex = hx - sd*gh*cos(a), eyy = ay(0.12) + gh*sin(a);
      g.stroke(C(sh(GATES[h.gateI], 0.9)));
      g.strokeWeight(4);
      g.line(hx, ay(0.12), ex, eyy);
      g.noStroke();
    }
  }
  for (Thing t : world.things) thingA(g, t);
  for (Plant p : world.plants) if (p.kind == 1 || p.kind == 2 || p.kind == 3) plantA(g, p);
  for (House h : world.houses) roofA(g, h);

  // high shadows: palms, trees, wires, crows, falling on roofs too
  shadeHi.beginDraw();
  shadeHi.clear();
  shadeHi.noStroke();
  shadeHi.fill(C(30, 30, 52));
  for (Plant p : world.plants) if (p.kind == 0 || p.kind == 4) {
    float o = p.h*PX;
    float cx = p.x + (p.kind == 0 ? p.bx*PX : 0), cy = ay(p.d + (p.kind == 0 ? p.bd : 0));
    if (p.kind == 0) {
      shadeHi.strokeWeight(6);
      shadeHi.stroke(C(30, 30, 52));
      shadeHi.line(p.x, ay(p.d), cx + o*SUNX, cy + o*SUNY);
      shadeHi.noStroke();
      palmCrownA(shadeHi, p, cx + o*SUNX, cy + o*SUNY, true);
    } else {
      canopyA(shadeHi, p, cx + o*SUNX*0.85, cy + o*SUNY*0.85, true);
    }
  }
  shadeHi.strokeWeight(1.6);
  shadeHi.stroke(C(30, 30, 52));
  for (int k = 0; k < 4; k++) {
    float o = wireH(k)*PX;
    shadeHi.line(0, ay(wireD(k)) + o*SUNY, W, ay(wireD(k)) + o*SUNY);
  }
  shadeHi.noStroke();
  for (float cx : world.crows) {
    float o = wireH(0)*PX;
    shadeHi.ellipse(cx + o*SUNX, ay(wireD(0)) + o*SUNY, 13, 7);
  }
  shadeHi.endDraw();
  g.tint(255, look.night ? 50 : 92);
  g.image(shadeHi, 0, 0);
  g.noTint();

  for (Plant p : world.plants) {
    if (p.kind == 4) canopyA(g, p, p.x, ay(p.d), false);
    if (p.kind == 0) palmCrownA(g, p, p.x + p.bx*PX*(1 + (look.sag - 1)*0.25), ay(p.d + p.bd), false);
  }
  // poles and crows from above
  for (int i = 1; i <= 2; i++) {
    g.fill(C(186, 184, 176));
    blob(g, world.poles[i], ay(-0.4), 0.2*PX, 0.2*PX, 0.1, i);
    g.fill(C(80, 82, 86));
    fillShape(g, organic(rectP(world.poles[i] - 2, ay(-0.62), world.poles[i] + 2, ay(-0.18)), 1, 0.4, i + 5));
  }
  for (float cx : world.crows) {
    float y = ay(wireD(0));
    g.fill(C(24, 24, 28));
    blob(g, cx, y, 6.5, 3.6, 0.15, cx);
    blob(g, cx + 7, y, 3, 2.6, 0.1, cx + 1);
    g.triangle(cx - 5, y - 2, cx - 13, y, cx - 5, y + 2);
  }
}

void houseShadow(PGraphics s, House h) {
  float x0 = h.cx - h.w/2 - 0.5*PX, x1 = h.cx + h.w/2 + 0.5*PX;
  float y0 = ay(h.d0) - 0.5*PX, y1 = ay(h.d0 + h.depth) + 0.5*PX;
  float hh = (h.roof == 0) ? h.slab() + 0.1 : h.slab() + 1.1;
  float dx = hh*PX*SUNX, dy = hh*PX*SUNY;
  s.beginShape();
  s.vertex(x0, y0); s.vertex(x1, y0); s.vertex(x1 + dx, y0 + dy);
  s.vertex(x1 + dx, y1 + dy); s.vertex(x0 + dx, y1 + dy); s.vertex(x0, y1);
  s.endShape(CLOSE);
  float top = (h.roof == 0) ? h.slab() + h.rise() : h.slab() + 3.0;
  float ddx = top*PX*SUNX, ddy = top*PX*SUNY;
  float xm = (h.roof == 0) ? h.cx : h.cx + h.stairSide*(h.w/2 - 1.9*PX);
  float hw = (h.roof == 0) ? h.w*0.18 : 1.6*PX;
  float ym0 = (h.roof == 0) ? y0 + h.w*0.5 : y1 - 4*PX, ym1 = (h.roof == 0) ? y1 - h.w*0.5 : y1 - 0.5*PX;
  s.beginShape();
  s.vertex(xm - hw, ym0); s.vertex(xm + hw, ym0); s.vertex(xm + hw + ddx, ym0 + ddy);
  s.vertex(xm + hw + ddx, ym1 + ddy); s.vertex(xm - hw + ddx, ym1 + ddy); s.vertex(xm - hw, ym1);
  s.endShape(CLOSE);
}

void thingShadow(PGraphics s, Thing t) {
  if (t.kind == 0) {
    float o = 1.5*PX;
    s.ellipse(t.x + o*SUNX, ay(t.d + 1.9) + o*SUNY, 2.0*PX, 4.2*PX);
  } else if (t.kind == 1) {
    float o = 1.1*PX;
    s.ellipse(t.x + o*SUNX, ay(t.d) + o*SUNY, 1.9*PX, 0.8*PX);
  } else if (t.kind == 2) {
    s.ellipse(t.x + 6, ay(t.d) + 8, 16, 13);
  } else if (t.kind == 3) {
    float o = 0.8*PX;
    s.ellipse(t.x + o*SUNX, ay(t.d) + o*SUNY, 2.0*PX, 2.0*PX);
  } else if (t.kind == 4) {
    float o = 1.8*PX;
    s.strokeWeight(5);
    s.stroke(C(30, 30, 52));
    s.line(t.x + o*SUNX, ay(t.d) + o*SUNY, t.a + o*SUNX, ay(t.d + t.b) + o*SUNY);
    s.noStroke();
  }
}

void thingA(PGraphics g, Thing t) {
  if (t.kind == 0) {
    recLevel = 2;
    g.fill(C(170, 174, 178));
    fillShape(g, organic(rectP(t.x - 0.95*PX, ay(t.d), t.x + 0.95*PX, ay(t.d + 3.9)), 0.8*PX, 1.6*look.wob, t.sd));
    recLevel = 0;
    g.fill(C(140, 144, 150));
    for (int k = 0; k < 4; k++) {
      float y = ay(t.d + 0.6 + k*0.85);
      fillShape(g, organic(rectP(t.x - 0.8*PX, y, t.x + 0.8*PX, y + 2), 1, 1.4, t.sd + k));
    }
    g.fill(C(196, 198, 200));
    blob(g, t.x - 0.3*PX, ay(t.d + 1.6), 0.4*PX, 0.9*PX, 0.3, t.sd + 9);
  } else if (t.kind == 1) {
    float f = t.a;
    float[] c = (t.col == 0) ? new float[]{128,42,46} : new float[]{150,152,156};
    recLevel = 2;
    g.fill(C(c));
    fillShape(g, organic(new float[]{t.x - f*0.95*PX, ay(t.d - 0.22), t.x + f*0.55*PX, ay(t.d - 0.26), t.x + f*0.62*PX, ay(t.d - 0.42),
                                     t.x + f*0.95*PX, ay(t.d - 0.2), t.x + f*0.95*PX, ay(t.d + 0.2), t.x + f*0.62*PX, ay(t.d + 0.42),
                                     t.x + f*0.55*PX, ay(t.d + 0.26), t.x - f*0.95*PX, ay(t.d + 0.22)}, 5, 1.0*look.wob, t.sd));
    recLevel = 0;
    g.fill(C(sh(c, 1.18)));
    blob(g, t.x - f*0.2*PX, ay(t.d - 0.06), 0.5*PX, 0.1*PX, 0.2, t.sd + 1);
  } else if (t.kind == 2) {
    g.fill(C(184, 140, 92));
    fillShape(g, organic(rectP(t.x - 0.26*PX, ay(t.d) - 0.2*PX, t.x + 0.26*PX, ay(t.d) + 0.2*PX), 2, 0.4, 35));
    g.fill(C(214, 190, 150));
    fillShape(g, organic(rectP(t.x - 0.26*PX, ay(t.d) - 1.5, t.x + 0.26*PX, ay(t.d) + 1.5), 1, 0.3, 36));
  } else if (t.kind == 3) {
    g.fill(C(164, 96, 68));
    blob(g, t.x, ay(t.d), 0.95*PX, 0.95*PX, 0.06, t.sd);
    g.fill(C(28, 42, 40));
    blob(g, t.x, ay(t.d), 0.66*PX, 0.66*PX, 0.05, t.sd + 1);
    g.fill(C(mixc(SKY_LOW, SKY_TOP, 0.3), 120));
    blob(g, t.x - 4, ay(t.d) - 4, 5, 3, 0.2, t.sd + 2);
    g.stroke(C(92, 70, 52));
    g.strokeWeight(3);
    g.line(t.x - 0.8*PX, ay(t.d) - 2, t.x + 0.8*PX, ay(t.d) + 2);
    g.noStroke();
  } else if (t.kind == 4) {
    float x0 = t.x, x1 = t.a, y0 = ay(t.d), y1 = ay(t.d + t.b);
    g.stroke(C(70, 66, 60));
    g.strokeWeight(1.2);
    g.line(x0, y0, x1, y1);
    g.noStroke();
    float[][] cols = {{196,52,60},{40,90,170},{236,196,70},{240,236,226},{60,140,110},{220,120,60}};
    Random R = new Random((long)(t.sd*100));
    for (int k = 0; k < 6; k++) {
      float u = 0.12 + k*0.15 + rr(R, -0.03, 0.03);
      float x = lerp(x0, x1, u), y = lerp(y0, y1, u);
      g.fill(C(cols[(k + (int)t.sd) % 6]));
      fillShape(g, organic(rectP(x - 0.3*PX, y - 0.12*PX, x + 0.3*PX, y + 0.14*PX), 2, 0.6, t.sd + k));
    }
  }
}

void plantA(PGraphics g, Plant p) {
  Random R = new Random((long)(p.sd*1000) + 21);
  float cx = p.x, cy = ay(p.d);
  if (p.kind == 1) {
    for (int k = 0; k < 7; k++) {
      float ang = TWO_PI*k/7 + rr(R, -0.3, 0.3);
      float len = rr(R, 1.8, 2.4)*PX;
      float[] sp = arcSpine(cx, cy, ang, len, 0.05, 14);
      boolean lit = (cos(ang) + sin(ang)) < 0;
      g.fill(C(lit ? new float[]{150,180,80} : new float[]{108,140,58}));
      blade(g, sp, 0.3*PX, 0.25, p.sd + k);
    }
  } else {
    for (int k = 0; k < 4; k++) {
      float a = rr(R, 0, TWO_PI), d = rr(R, 0, 0.4)*p.r*PX;
      g.fill(C(k == 3 ? new float[]{96,130,64} : new float[]{64,96,50}));
      blob(g, cx + cos(a)*d, cy + sin(a)*d, p.r*PX*0.7, p.r*PX*0.65, 0.35*look.wob, p.sd + k);
    }
    g.fill(C(92, 126, 62, 160));
    blob(g, cx - p.r*PX*0.2, cy - p.r*PX*0.2, p.r*PX*0.35, p.r*PX*0.3, 0.3, p.sd + 9);
    if (p.kind == 3) {
      g.fill(C(214, 40, 48));
      for (int k = 0; k < 8; k++) blob(g, cx + rr(R, -0.8, 0.8)*p.r*PX, cy + rr(R, -0.8, 0.8)*p.r*PX, 3, 3, 0.2, k + p.sd);
    }
  }
}

void canopyA(PGraphics g, Plant p, float cx, float cy, boolean shadow) {
  Random R = new Random((long)(p.sd*1000) + 3);
  for (int k = 0; k < 10; k++) {
    float a = rr(R, 0, TWO_PI), d = rr(R, 0, p.r*0.55)*PX;
    float r0 = p.r*PX*rr(R, 0.38, 0.6);
    if (!shadow) {
      boolean lit = (cos(a) + sin(a)) < 0;
      g.fill(C(lit ? new float[]{78,112,58} : new float[]{44,72,42}));
    }
    blob(g, cx + cos(a)*d, cy + sin(a)*d, r0, r0, 0.3*look.wob, p.sd + k);
  }
  if (!shadow) {
    g.fill(C(98, 134, 66, 150));
    blob(g, cx - p.r*PX*0.3, cy - p.r*PX*0.3, p.r*PX*0.35, p.r*PX*0.3, 0.3, p.sd + 20);
  }
}

void palmCrownA(PGraphics g, Plant p, float cx, float cy, boolean shadow) {
  Random R = new Random((long)(p.sd*1000) + 7);
  float[][] greens = {{70,104,52},{96,128,60},{52,80,44},{84,116,58}};
  int n = 17;
  for (int f = 0; f < n; f++) {
    float ang = TWO_PI*f/n + rr(R, -0.15, 0.15);
    float len = 4.5*PX*rr(R, 0.8, 1.05);
    int m = 18;
    float[] sp = new float[m*2];
    float bend = rr(R, -0.25, 0.25);
    for (int i = 0; i < m; i++) {
      float t = i/(float)(m - 1);
      float a = ang + bend*t*t;
      sp[i*2] = cx + cos(a)*len*t;
      sp[i*2+1] = cy + sin(a)*len*t;
    }
    if (!shadow) {
      boolean lit = (cos(ang) + sin(ang)) < -0.2;
      boolean dry = R.nextFloat() < 0.1;
      g.fill(dry ? C(150, 122, 72) : C(lit ? new float[]{110,142,66} : greens[f % 4]));
    } else {
      R.nextFloat();
    }
    blade(g, sp, 0.44*PX, 0.7, p.sd + f);
  }
  if (!shadow) {
    g.fill(C(124, 100, 52));
    for (int k = 0; k < 6; k++) blob(g, cx + rr(R, -8, 8), cy + rr(R, -8, 8), 5, 5, 0.15, k + p.sd);
  }
}

void roofA(PGraphics g, House h) {
  float shift = sin(h.lean*look.sag)*h.slab()*PX;
  float sd = h.id*23.1 + 3, amp = 1.3*look.wob;
  float[] wall = WALLS[h.wallI];
  if (h.roof == 0) {
    float ov = 0.75*PX;
    float X0 = h.cx - h.w/2 - ov + shift, X1 = h.cx + h.w/2 + ov + shift;
    float Y0 = ay(h.d0) - ov, Y1 = ay(h.d0 + h.depth) + ov;
    float xm = (X0 + X1)/2, ym = (Y0 + Y1)/2;
    float hw = (X1 - X0)/2, hd = (Y1 - Y0)/2;
    float[] top, right, bottom, left;
    if (hw <= hd) {
      float r0 = Y0 + hw, r1 = Y1 - hw;
      top = new float[]{X0, Y0, X1, Y0, xm, r0};
      right = new float[]{X1, Y0, X1, Y1, xm, r1, xm, r0};
      bottom = new float[]{X1, Y1, X0, Y1, xm, r1};
      left = new float[]{X0, Y1, X0, Y0, xm, r0, xm, r1};
    } else {
      float r0 = X0 + hd, r1 = X1 - hd;
      top = new float[]{X0, Y0, X1, Y0, r1, ym, r0, ym};
      right = new float[]{X1, Y0, X1, Y1, r1, ym};
      bottom = new float[]{X1, Y1, X0, Y1, r0, ym, r1, ym};
      left = new float[]{X0, Y1, X0, Y0, r0, ym};
    }
    recLevel = 1;
    g.fill(C(TERRA));
    fillShape(g, organic(rectP(X0, Y0, X1, Y1), 8, amp, sd));
    recLevel = 0;
    g.fill(C(sh(TERRA, 1.18)));
    fillShape(g, organic(top, 4, amp, sd + 1));
    g.fill(C(sh(TERRA, 1.08)));
    fillShape(g, organic(left, 4, amp, sd + 2));
    g.fill(C(sh(TERRA, 0.78)));
    fillShape(g, organic(right, 4, amp, sd + 3));
    g.fill(C(sh(TERRA, 0.68)));
    fillShape(g, organic(bottom, 4, amp, sd + 4));
    Random R = new Random((long)(sd*91));
    for (int k = 0; k < 6; k++) {
      g.fill(C(62, 70, 48, 80));
      blob(g, rr(R, X0 + 10, X1 - 10), rr(R, Y0 + 10, Y1 - 10), rr(R, 6, 18), rr(R, 4, 12), 0.5, sd + 10 + k);
    }
    int rc = C(196, 192, 180);
    if (hw <= hd) {
      wline(g, new float[]{xm, Y0 + hw, xm, Y1 - hw}, 4, rc, 0.8, sd + 20);
      wline(g, new float[]{X0, Y0, xm, Y0 + hw, X1, Y0}, 3, rc, 0.8, sd + 21);
      wline(g, new float[]{X0, Y1, xm, Y1 - hw, X1, Y1}, 3, rc, 0.8, sd + 22);
    } else {
      wline(g, new float[]{X0 + hd, ym, X1 - hd, ym}, 4, rc, 0.8, sd + 20);
      wline(g, new float[]{X0, Y0, X0 + hd, ym, X0, Y1}, 3, rc, 0.8, sd + 21);
      wline(g, new float[]{X1, Y0, X1 - hd, ym, X1, Y1}, 3, rc, 0.8, sd + 22);
    }
    if (h.dish) {
      float dx = h.cx + h.w/2 - 0.6*PX + shift, dy = ay(h.d0) + 0.2*PX;
      g.fill(C(206, 206, 200));
      blob(g, dx, dy, 0.34*PX, 0.3*PX, 0.05, sd + 30);
      g.stroke(C(90, 90, 86));
      g.strokeWeight(1.5);
      g.line(dx, dy, dx - 0.4*PX, dy - 0.2*PX);
      g.noStroke();
    }
  } else {
    float X0 = h.cx - h.w/2 - 0.22*PX + shift, X1 = h.cx + h.w/2 + 0.22*PX + shift;
    float Y0 = ay(h.d0) - 0.22*PX, Y1 = ay(h.d0 + h.depth) + 0.22*PX;
    recLevel = 1;
    g.fill(C(CONCRETE));
    fillShape(g, organic(rectP(X0, Y0, X1, Y1), 4, amp, sd));
    recLevel = 0;
    float i0 = 0.22*PX + 0.2*PX;
    g.fill(C(mixc(wall, new float[]{250,248,240}, 0.25)));
    fillShape(g, organic(rectP(X0 + 0.22*PX, Y0 + 0.22*PX, X1 - 0.22*PX, Y1 - 0.22*PX), 3, amp, sd + 1));
    g.fill(C(152, 148, 138));
    fillShape(g, organic(rectP(X0 + i0, Y0 + i0, X1 - i0, Y1 - i0), 3, amp, sd + 2));
    g.fill(C(40, 40, 60, 70));
    fillShape(g, organic(rectP(X0 + i0, Y0 + i0, X1 - i0, Y0 + i0 + 0.9*PX*SUNY), 2, amp, sd + 3));
    fillShape(g, organic(rectP(X0 + i0, Y0 + i0, X0 + i0 + 0.9*PX*SUNX, Y1 - i0), 2, amp, sd + 4));
    Random R = new Random((long)(sd*91));
    for (int k = 0; k < 9; k++) {
      g.fill(C(58, 62, 54, rr(R, 50, 110)));
      blob(g, rr(R, X0 + 14, X1 - 14), rr(R, Y0 + 14, Y1 - 14), rr(R, 6, 24), rr(R, 4, 14), 0.55, sd + 10 + k);
    }
    // stair room with the tank on top
    float sx = h.cx + h.stairSide*(h.w/2 - 1.9*PX) + shift;
    float sy0 = Y1 - i0 - 3.6*PX, sy1 = Y1 - i0;
    g.fill(C(40, 40, 60, 80));
    fillShape(g, organic(rectP(sx - 1.6*PX + 2.7*PX*SUNX, sy0 + 2.7*PX*SUNY, sx + 1.6*PX + 2.7*PX*SUNX, sy1), 3, amp, sd + 39));
    g.fill(C(CONCRETE));
    fillShape(g, organic(rectP(sx - 1.85*PX, sy0 - 0.25*PX, sx + 1.85*PX, sy1), 3, amp, sd + 40));
    g.fill(C(144, 140, 130));
    fillShape(g, organic(rectP(sx - 1.6*PX, sy0, sx + 1.6*PX, sy1 - 0.2*PX), 3, amp, sd + 41));
    float tx = sx + 0.85*PX, ty = sy0 + 1.2*PX;
    g.fill(C(40, 40, 60, 90));
    blob(g, tx + 1.2*PX*SUNX + 3, ty + 1.2*PX*SUNY + 3, 0.6*PX, 0.6*PX, 0.05, sd + 42);
    g.fill(C(32, 34, 38));
    blob(g, tx, ty, 0.56*PX, 0.56*PX, 0.04, sd + 43);
    g.fill(C(70, 74, 80));
    blob(g, tx, ty, 0.24*PX, 0.24*PX, 0.05, sd + 44);
    g.fill(C(120, 126, 134));
    blob(g, tx - 0.25*PX, ty - 0.25*PX, 3, 2, 0.2, sd + 45);
    if (h.dish) {
      float dx = h.cx - h.stairSide*(h.w/2 - 0.9*PX) + shift, dy = Y0 + i0 + 0.5*PX;
      g.fill(C(206, 206, 200));
      blob(g, dx, dy, 0.34*PX, 0.3*PX, 0.05, sd + 30);
      g.stroke(C(90, 90, 86));
      g.strokeWeight(1.5);
      g.line(dx, dy, dx + h.stairSide*0.4*PX, dy + 0.3*PX);
      g.noStroke();
    }
  }
}

// ------------------------------------------------------------ night
void nightLights(PGraphics g) {
  g.blendMode(ADD);
  g.noStroke();
  int phone = -1, lamp = -1;
  for (House h : world.houses) {
    if (h.floors == 2 && phone < 0) phone = h.id;
    else if (lamp < 0) lamp = h.id;
  }
  int[] who = {phone, lamp};
  float[][] tint = {{70, 110, 190}, {190, 110, 40}};
  for (int k = 0; k < 2; k++) {
    if (who[k] < 0) continue;
    House h = world.houses[who[k]];
    float x0 = h.eyeU[0], y0 = h.eyeU[1], x1 = h.eyeU[2], y1 = h.eyeU[3];
    float cx = (x0 + x1)/2, cy = (y0 + y1)/2;
    for (int r = 12; r >= 1; r--) {
      g.fill(tint[k][0], tint[k][1], tint[k][2], 13);
      g.ellipse(cx, cy, (x1 - x0)*0.7*r, (y1 - y0)*0.7*r);
    }
    g.fill(tint[k][0], tint[k][1], tint[k][2], 220);
    g.rect(x0 + 2, lerp(y0, y1, 0.5), x1 - x0 - 4, (y1 - y0)*0.45);
    // the same light, spilling into the yard, seen from above
    for (int r = 7; r >= 1; r--) {
      g.fill(tint[k][0], tint[k][1], tint[k][2], 12);
      g.ellipse(cx, ay(h.d0 - 0.6), 0.9*PX*r, 0.5*PX*r);
    }
  }
  g.blendMode(BLEND);
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
        float spread = (wy < E_GROUND) ? 0.9 : (wy > ay(30.4) || wy < A_D0) ? 0.6 : 2.6;
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
      if (zone == 0) { cx = R.nextFloat()*W; cy = 20 + R.nextFloat()*(E_GROUND - 360); }
      else if (zone == 1) { cx = R.nextFloat()*W; cy = A_TOP + 10 + R.nextFloat()*(A_D0 - A_TOP - 40); }
      else { cx = R.nextFloat()*W; cy = ay(30.8) + R.nextFloat()*(H - ay(30.8) - 10); }
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
