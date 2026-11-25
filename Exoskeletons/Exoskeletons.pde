/*
 * EXOSKELETONS
 * A body of work in seven panels — Processing 4
 *
 * One suburban block, seen in strict orthographic plan from above.
 * Nobody is ever on the street. The houses stand in for the people
 * inside them: shells set side by side, facing a road no one walks.
 *
 * Method (mirrors the photographic workflow):
 *   1. A flat "aerial capture" of the block is drawn into an off-screen
 *      reference buffer — the prompt.
 *   2. That reference is repainted as oil: layered passes of bristle
 *      strokes, coarse to fine, each stroke steered along the edges of
 *      the image and stopped where the colour changes.
 *   3. A height buffer records every bristle; it is embossed at the end
 *      so the paint catches the same low sun as the roofs.
 *
 * The series: the block (same seed) is held constant. Each panel after
 * 01 changes ONE element only.
 *   0  Prompt       the reference, before paint
 *   1  Exoskeleton  the base painting
 *   2  Colour       same everything, re-keyed to a cold winter chord
 *   3  Shape        same everything, reduced to plan geometry
 *   4  Texture      same everything, impasto + palette knife
 *   5  Mood         same everything, after dark
 *   6  Type         same everything, plus the only words on the street
 *
 * Keys
 *   0–6   paint that panel           n   new block (new seed)
 *   r     toggle reference / paint   s   save current panel
 *   e     export all seven panels + contact sheet to /output
 *
 * Rendering is deliberately slow (a few seconds to ~1 min per panel).
 */

import java.util.Random;

// ------------------------------------------------------------- canvas
final int W = 1600, H = 2000;          // painting size (4:5)
final float Z = 1.32;                  // zoom: the block is laid out in a smaller
final float VW = W/Z, VH = H/Z;        // virtual world, then scaled up to the canvas
long seed = 1406;
int stage = 1;
boolean AUTO_EXPORT = false;           // true = export everything and quit

PGraphics ref, cv, hgt, shadowLayer;
World world;
Look look;
PFont fontRoad, fontNum, fontTitle, fontBody, fontMono;

boolean needsRender = true, showRef = false;
int renderPhase = 0;

// unit vector pointing TOWARD the sun: upper left, late afternoon
final float TLX = -0.6, TLY = -0.8;
// shadows fall the other way
final float SDX = 0.6, SDY = 0.8;

final String[][] STAGES = {
  {"00", "Prompt",      "the aerial capture, before paint"},
  {"01", "Exoskeleton", "the base painting"},
  {"02", "Colour",      "re-keyed to a cold winter chord"},
  {"03", "Shape",       "reduced to plan geometry"},
  {"04", "Texture",     "impasto and palette knife"},
  {"05", "Mood",        "the same street after dark"},
  {"06", "Type",        "the only words on the street"}
};

// ===================================================================
void settings() {
  size(800, 1000);
}

void setup() {
  ref = createGraphics(W, H);
  cv = createGraphics(W, H);
  hgt = createGraphics(W, H);
  shadowLayer = createGraphics(W, H);
  loadFonts();
  world = new World(seed);
  if (AUTO_EXPORT) {
    exportSeries();
    exit();
  }
}

void draw() {
  if (needsRender) {
    if (renderPhase == 0) {               // show a note, paint next frame
      background(22);
      fill(190);
      textAlign(CENTER, CENTER);
      textFont(fontBody, 14);
      text("painting  " + STAGES[stage][0] + "  " + STAGES[stage][1].toUpperCase() + "  …", width/2, height/2);
      renderPhase = 1;
      return;
    }
    renderStage(stage);
    needsRender = false;
    renderPhase = 0;
    surface.setTitle("EXOSKELETONS   " + STAGES[stage][0] + " " + STAGES[stage][1] + "   seed " + seed);
  }
  background(22);
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
  look = makeLook(s);
  renderReference(ref, look);
  if (look.reference) {
    cv.beginDraw();
    cv.image(ref, 0, 0);
    cv.endDraw();
  } else {
    paint(ref, look);
  }
}

String stageFile(int s) {
  return savePath("output/exoskeletons_" + seed + "_" + STAGES[s][0] + "_" + STAGES[s][1].toLowerCase() + ".png");
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
    thumbs[s] = cv.get();
    println("  panel " + STAGES[s][0] + " in " + nf((millis()-t0)/1000.0, 0, 1) + "s");
  }
  contactSheet(thumbs);
}

// -------------------------------------------------------------------
class Look {
  Palette pal;
  float[] radii = {22, 11, 5.5, 2.8};   // brush radii, coarse to fine
  float strokeLen = 2.3;                // max stroke half-length, in radii
  float jitter = 9;                     // colour wander per stroke
  float tone = 8;                       // light-side lift across a stroke
  float impasto = 1;                    // emboss strength
  float thresh = 22;                    // repaint where error exceeds this
  boolean reference, simplify, night, type, knife;
}

Look makeLook(int s) {
  Look L = new Look();
  L.pal = basePalette();
  switch (s) {
  case 0:
    L.reference = true;
    break;
  case 2:                       // COLOUR — nothing else changes
    L.pal = frostPalette();
    break;
  case 3:                       // SHAPE
    L.simplify = true;
    break;
  case 4:                       // TEXTURE
    L.radii = new float[]{36, 18, 9, 4.5};
    L.strokeLen = 3.0;
    L.impasto = 3.2;
    L.jitter = 13;
    L.tone = 16;
    L.thresh = 28;
    L.knife = true;
    break;
  case 5:                       // MOOD
    L.pal = nightPalette();
    L.night = true;
    break;
  case 6:                       // TYPE
    L.type = true;
    L.radii = new float[]{22, 11, 5.5, 2.8, 1.6};
    break;
  }
  return L;
}

// ===================================================================
//  PALETTES
// ===================================================================
class Palette {
  int ground;                           // imprimatura showing between strokes
  int[] lawn = new int[3];
  int dryLawn, asphalt, patch, curb, sidewalk, concrete, soil, deck, fence;
  int[] roofs = new int[7];
  int chimney, skylight, solar, shedRoof;
  int pool, poolDeep, coping;
  int[] foliage = new int[3];           // dark, mid, light
  int shadow;
  float shadowAlpha;
  int lightTint, shadeTint;             // warm light / cool shade on roof planes
  int bin1, bin2, parcel, tramp, paint, ink;
  int glaze;
  float glazeAlpha;
  int lampGlow, windowGlow, poolGlow;
}

Palette basePalette() {             // late afternoon, autumn-warm
  Palette p = new Palette();
  p.ground = 0xFF8E5E40;
  p.lawn[0] = 0xFF717650;
  p.lawn[1] = 0xFF7E8257;
  p.lawn[2] = 0xFF8D8C62;
  p.dryLawn = 0xFFAE9F72;
  p.asphalt = 0xFF5C595B;
  p.patch = 0xFF4E4B4E;
  p.curb = 0xFFCCC3B1;
  p.sidewalk = 0xFFB8AE9A;
  p.concrete = 0xFFB2A792;
  p.soil = 0xFF65503F;
  p.deck = 0xFF94735A;
  p.fence = 0xFF9C9177;
  p.roofs = new int[]{0xFFA4603F, 0xFF6D6F73, 0xFF48474C, 0xFF7C6352, 0xFFC9BB9E, 0xFF87503F, 0xFF6A705F};
  p.chimney = 0xFF8A4C3A;
  p.skylight = 0xFF2C3A4A;
  p.solar = 0xFF1F2A44;
  p.shedRoof = 0xFF8C8E86;
  p.pool = 0xFF4FA5A6;
  p.poolDeep = 0xFF2F7D86;
  p.coping = 0xFFE4DDCB;
  p.foliage = new int[]{0xFF2A3826, 0xFF465736, 0xFF838A57};
  p.shadow = 0xFF1C2038;
  p.shadowAlpha = 128;
  p.lightTint = 0xFFFFE0AC;
  p.shadeTint = 0xFF46578A;
  p.bin1 = 0xFF2F4B3B;
  p.bin2 = 0xFF3A3D46;
  p.parcel = 0xFFC79B62;
  p.tramp = 0xFF1D1E22;
  p.paint = 0xFFEDE7D8;
  p.ink = 0xFF1B1B1F;
  p.glaze = 0xFFE9C38A;
  p.glazeAlpha = 0.06;
  p.lampGlow = 0xFFFFB45A;
  p.windowGlow = 0xFFFF9A40;
  p.poolGlow = 0xFF40E0E0;
  return p;
}

Palette frostPalette() {            // COLOUR: one cold, raised chord
  Palette p = basePalette();
  p.ground = 0xFF5B6A88;
  p.lawn[0] = 0xFFB4B8A6;
  p.lawn[1] = 0xFFC3C5B3;
  p.lawn[2] = 0xFFAAB19E;
  p.dryLawn = 0xFFD5CDB5;
  p.asphalt = 0xFF696B7A;
  p.patch = 0xFF5C5E6C;
  p.curb = 0xFFE8E6E0;
  p.sidewalk = 0xFFDDDAD1;
  p.concrete = 0xFFD3CFC5;
  p.soil = 0xFF887C86;
  p.deck = 0xFFA79899;
  p.fence = 0xFFB3B2B4;
  p.roofs = new int[]{0xFFC48A86, 0xFF8B96A8, 0xFF5E6378, 0xFFA38D93, 0xFFE1D6CF, 0xFFB06F6F, 0xFF8EA0A2};
  p.chimney = 0xFFA06A6E;
  p.skylight = 0xFF3C4766;
  p.solar = 0xFF2E3660;
  p.shedRoof = 0xFFA9AAB2;
  p.pool = 0xFF7FB5BE;
  p.poolDeep = 0xFF5A8C9E;
  p.coping = 0xFFF3EFE9;
  p.foliage = new int[]{0xFF3D485A, 0xFF656F7C, 0xFF9DA6A6};
  p.shadow = 0xFF464C8C;
  p.shadowAlpha = 118;
  p.lightTint = 0xFFFFF0E6;
  p.shadeTint = 0xFF6A6FA9;
  p.bin1 = 0xFF4E5A6E;
  p.bin2 = 0xFF5A5866;
  p.parcel = 0xFFC9A79E;
  p.tramp = 0xFF34384A;
  p.glaze = 0xFFDCE4F2;
  p.glazeAlpha = 0.07;
  return p;
}

Palette nightPalette() {            // MOOD: after dark
  Palette p = basePalette();
  p.ground = 0xFF141826;
  p.lawn[0] = 0xFF243231;
  p.lawn[1] = 0xFF293733;
  p.lawn[2] = 0xFF212C2E;
  p.dryLawn = 0xFF2B2F2A;
  p.asphalt = 0xFF17181F;
  p.patch = 0xFF121318;
  p.curb = 0xFF4A4C55;
  p.sidewalk = 0xFF393B44;
  p.concrete = 0xFF34363E;
  p.soil = 0xFF1D191B;
  p.deck = 0xFF2D2725;
  p.fence = 0xFF34363C;
  p.roofs = new int[]{0xFF4A3537, 0xFF363B47, 0xFF272830, 0xFF423536, 0xFF5E5A60, 0xFF443136, 0xFF353D39};
  p.chimney = 0xFF2E2224;
  p.skylight = 0xFF0D1220;
  p.solar = 0xFF0B1022;
  p.shedRoof = 0xFF33353A;
  p.pool = 0xFF3CC8CC;
  p.poolDeep = 0xFF1D8B9A;
  p.coping = 0xFF70767C;
  p.foliage = new int[]{0xFF0D1411, 0xFF17231B, 0xFF2D3B31};
  p.shadow = 0xFF04050B;
  p.shadowAlpha = 80;
  p.lightTint = 0xFF8EA0C8;
  p.shadeTint = 0xFF090B17;
  p.bin1 = 0xFF18221C;
  p.bin2 = 0xFF1C1E24;
  p.parcel = 0xFF5A4532;
  p.tramp = 0xFF0B0B0E;
  p.glaze = 0xFF2B3662;
  p.glazeAlpha = 0.07;
  return p;
}

// ===================================================================
//  THE BLOCK  (layout is generated once per seed and never changes
//  between panels — only how it is seen changes)
// ===================================================================
class R {
  float x, y, w, h;
  R(float x, float y, float w, float h) {
    this.x = x; this.y = y; this.w = w; this.h = h;
  }
  float cx() { return x + w/2; }
  float cy() { return y + h/2; }
}

class Tree {
  float x, y, r, h;
  long s;
  Tree(float x, float y, float r, float h, long s) {
    this.x = x; this.y = y; this.r = r; this.h = h; this.s = s;
  }
}

class House {
  R main, wing;
  boolean hipMain, hipWing;
  int roof;
  float height;
  boolean chimney, skylights, solar, vents;
  float chimU, chimV;
  float doorX, doorY;
  boolean lit;                          // a window still on, after dark
  int litSide;
}

class Lot {
  float x0, x1, frontY, depth;
  int dir;                              // +1 top row (front faces down), -1 bottom row
  int lawn, number;
  boolean stripes, dry, kidney, garage, oilStain, parcel, bins, driveLeft;
  House house;
  R drive, path, patio, pool, shed, bed, hedgeA, hedgeB, tramp;
  float binsX, binsY, numX, numY, fenceFrom;
  ArrayList<Tree> trees = new ArrayList<Tree>();
}

class World {
  Random rng;
  float cy, roadHalf, curbW, vergeW, walkW;
  float streetTop, streetBot, frontTop, frontBot, rearTop, rearBot;
  ArrayList<Lot> lots = new ArrayList<Lot>();
  ArrayList<Tree> streetTrees = new ArrayList<Tree>();
  ArrayList<Tree> farTrees = new ArrayList<Tree>();
  ArrayList<Float> farFencesTop = new ArrayList<Float>();
  ArrayList<Float> farFencesBot = new ArrayList<Float>();
  ArrayList<float[]> lamps = new ArrayList<float[]>();
  float slowTopX, slowBotX;

  World(long s) {
    rng = new Random(s);
    build();
  }

  float rr(float a, float b) { return a + rng.nextFloat()*(b - a); }
  boolean chance(float p) { return rng.nextFloat() < p; }

  // rectangle given in lot depth (d measured from the front property line
  // into the lot) -> world rectangle
  R dr(int dir, float frontY, float xa, float xb, float d1, float d2) {
    float ya, yb;
    if (dir > 0) { ya = frontY - d2; yb = frontY - d1; }
    else         { ya = frontY + d1; yb = frontY + d2; }
    return new R(min(xa, xb), ya, abs(xb - xa), yb - ya);
  }
  float dy(int dir, float frontY, float d) {
    return dir > 0 ? frontY - d : frontY + d;
  }

  void build() {
    cy = VH * rr(0.47, 0.53);
    roadHalf = 86; curbW = 7; vergeW = 26; walkW = 34;
    streetTop = cy - roadHalf;
    streetBot = cy + roadHalf;
    frontTop = streetTop - curbW - vergeW - walkW;
    frontBot = streetBot + curbW + vergeW + walkW;
    rearTop = rr(70, 120);
    rearBot = VH - rr(70, 120);

    makeRow(+1, frontTop, frontTop - rearTop, 11);
    makeRow(-1, frontBot, rearBot - frontBot, 12);

    // the neighbouring backyards, beyond the rear fences
    float x = -rr(0, 200);
    while (x < VW) { farFencesTop.add(x); x += rr(230, 320); }
    x = -rr(0, 200);
    while (x < VW) { farFencesBot.add(x); x += rr(230, 320); }
    for (int i = 0; i < 6; i++) {
      float r = rr(30, 60);
      farTrees.add(new Tree(rr(0, VW), rr(-10, rearTop - 18), r, r*rr(1.4, 2.0), rng.nextLong()));
      r = rr(30, 60);
      farTrees.add(new Tree(rr(0, VW), rr(rearBot + 18, VH + 10), r, r*rr(1.4, 2.0), rng.nextLong()));
    }

    // street trees on the verges
    for (Lot L : lots) {
      if (chance(0.22)) {
        float r = rr(30, 44);
        float vy = L.dir > 0 ? streetTop - curbW - vergeW*0.5 : streetBot + curbW + vergeW*0.5;
        streetTrees.add(new Tree(rr(L.x0 + 30, L.x1 - 30), vy, r, r*rr(1.6, 2.2), rng.nextLong()));
      }
    }
    // street lamps, alternating verges
    boolean top = chance(0.5);
    for (float lx = rr(80, 260); lx < VW; lx += rr(330, 420)) {
      float ly = top ? streetTop - curbW - 6 : streetBot + curbW + 6;
      lamps.add(new float[]{lx, ly});
      top = !top;
    }
    slowTopX = VW * rr(0.18, 0.32);
    slowBotX = VW * rr(0.66, 0.82);
  }

  void makeRow(int dir, float frontY, float depth, int firstNumber) {
    float x = -rr(40, 170);
    int n = firstNumber;
    while (x < VW + 10) {
      float w = rr(250, 335);
      Lot L = makeLot(dir, frontY, depth, x, x + w);
      L.number = n;
      n += 2;
      lots.add(L);
      x += w;
    }
  }

  Lot makeLot(int dir, float frontY, float depth, float x0, float x1) {
    Lot L = new Lot();
    L.x0 = x0; L.x1 = x1; L.dir = dir; L.frontY = frontY; L.depth = depth;
    float lw = x1 - x0;
    L.lawn = rng.nextInt(3);
    L.stripes = chance(0.3);
    L.dry = chance(0.25);
    L.driveLeft = chance(0.5);

    float margin = rr(12, 22);
    float driveW = rr(44, 54);
    float setback = rr(80, 135);
    float hw = lw * rr(0.48, 0.6);
    float hd = rr(135, 182);
    float hx0, driveA, driveB;
    if (L.driveLeft) {
      driveA = x0 + margin;
      driveB = driveA + driveW;
      hx0 = max(driveB + rr(6, 30), x1 - margin - hw - rr(0, 24));
      hw = min(hw, x1 - margin - hx0);
    } else {
      driveB = x1 - margin;
      driveA = driveB - driveW;
      float hx1 = min(driveA - rr(6, 30), x0 + margin + hw + rr(0, 24));
      hx0 = max(x0 + margin, hx1 - hw);
      hw = hx1 - hx0;
    }

    House h = new House();
    h.main = dr(dir, frontY, hx0, hx0 + hw, setback, setback + hd);
    h.hipMain = chance(0.62);
    h.roof = rng.nextInt(7);
    h.height = rr(44, 58);

    L.garage = chance(0.6);
    float driveEnd;
    float backExtra = 0;
    if (L.garage) {                       // garage wing on the driveway side
      float gd1 = setback - rr(8, 42), gd2 = setback + rr(72, 104);
      float ga = L.driveLeft ? driveA - 3 : hx0 + hw - 12;
      float gb = L.driveLeft ? hx0 + 12 : driveB + 3;
      h.wing = dr(dir, frontY, ga, gb, gd1, gd2);
      h.hipWing = chance(0.5);
      driveEnd = gd1;
    } else {
      if (chance(0.45)) {                 // or a wing out the back
        float ww = hw * rr(0.35, 0.55);
        float wa = chance(0.5) ? hx0 : hx0 + hw - ww;
        float ext = rr(45, 85);
        h.wing = dr(dir, frontY, wa, wa + ww, setback + hd - 15, setback + hd + ext);
        h.hipWing = chance(0.5);
        backExtra = ext;
      }
      driveEnd = setback + rr(20, hd*0.8);
    }
    L.drive = dr(dir, frontY, driveA, driveB, -(walkW + vergeW + curbW*0.5), driveEnd);
    L.oilStain = chance(0.55);

    float doorX = hx0 + hw * rr(0.38, 0.62);
    L.path = dr(dir, frontY, doorX - 6, doorX + 6, 0, setback);
    h.doorX = doorX;
    h.doorY = dy(dir, frontY, setback - 8);
    L.parcel = chance(0.55);

    h.chimney = chance(0.42);
    h.chimU = rr(0.22, 0.78);
    h.chimV = chance(0.5) ? rr(0.16, 0.32) : rr(0.68, 0.84);
    h.skylights = chance(0.3);
    h.solar = !h.skylights && chance(0.28);
    h.vents = chance(0.6);
    h.lit = chance(0.4);
    h.litSide = rng.nextInt(4);
    L.house = h;

    // back garden
    float back = setback + hd + backExtra + 10;
    float yard = depth - back;
    if (chance(0.65)) {
      L.patio = dr(dir, frontY, hx0 + hw*rr(0.05, 0.3), hx0 + hw*rr(0.65, 0.95), setback + hd - 2, setback + hd + rr(28, 50));
    }
    if (chance(0.4) && yard > 230) {
      float pw = rr(80, 118), ph = rr(42, 60);
      float pcx = x0 + lw * rr(0.32, 0.68);
      float pd = back + rr(70, min(170, yard - 120));
      L.pool = dr(dir, frontY, pcx - pw/2, pcx + pw/2, pd, pd + ph);
      L.kidney = chance(0.32);
    }
    if (chance(0.45)) {
      float sw = rr(38, 58), sd = rr(28, 42);
      float sa = chance(0.5) ? x0 + rr(8, 18) : x1 - rr(8, 18) - sw;
      float sdep = depth - rr(10, 22) - sd;
      L.shed = dr(dir, frontY, sa, sa + sw, sdep, sdep + sd);
    }
    if (chance(0.13) && yard > 200) {
      float tr = rr(21, 27);
      float tx = rr(x0 + 40, x1 - 40), td = rr(back + 40, depth - 50);
      float ty = dy(dir, frontY, td);
      L.tramp = new R(tx - tr, ty - tr, tr*2, tr*2);
    }
    if (chance(0.42)) {
      boolean left = chance(0.5);
      float bx = left ? x0 + 4 : x1 - 18;
      L.bed = dr(dir, frontY, bx, bx + 14, back + 15, back + 15 + rr(80, 220));
    }
    int nt = rng.nextInt(3);
    for (int i = 0; i < nt; i++) {
      float r = rr(24, 52);
      float td = rr(back + 30, depth - 18);
      L.trees.add(new Tree(rr(x0 + 20, x1 - 20), dy(dir, frontY, td), r, r*rr(1.4, 2.2), rng.nextLong()));
    }
    if (chance(0.5) && setback > 95) {
      float r = rr(22, 38);
      float tx = L.driveLeft ? rr(hx0 + 20, x1 - 25) : rr(x0 + 25, hx0 + hw - 20);
      L.trees.add(new Tree(tx, dy(dir, frontY, rr(26, setback - 32)), r, r*rr(1.4, 2.0), rng.nextLong()));
    }
    if (chance(0.28)) {
      float a = L.driveLeft ? driveB + 4 : x0 + 4;
      float b = L.driveLeft ? x1 - 4 : driveA - 4;
      L.hedgeA = dr(dir, frontY, a, doorX - 11, 2, 13);
      L.hedgeB = dr(dir, frontY, doorX + 11, b, 2, 13);
    }
    L.bins = chance(0.55);
    L.binsX = L.driveLeft ? driveB + 5 : driveA - 5 - 24;
    L.binsY = dy(dir, frontY, -(walkW + vergeW*0.55));
    L.numX = hx0 + hw * 0.5;
    L.numY = dir > 0 ? streetTop - curbW*0.5 : streetBot + curbW*0.5;
    L.fenceFrom = setback + hd*0.55;
    return L;
  }
}

// ===================================================================
//  REFERENCE  — the "aerial capture"
// ===================================================================
void renderReference(PGraphics pg, Look lk) {
  Palette p = lk.pal;
  World w = world;
  boolean simp = lk.simplify;
  Random gr = new Random(seed * 31 + 7);      // ground texture, stage-independent

  pg.beginDraw();
  pg.noStroke();
  pg.background(p.lawn[1]);
  pg.pushMatrix();
  pg.scale(Z);

  // far gardens
  for (int side = 0; side < 2; side++) {
    ArrayList<Float> fx = side == 0 ? w.farFencesTop : w.farFencesBot;
    for (int i = 0; i < fx.size(); i++) {
      float a = fx.get(i), b = i + 1 < fx.size() ? fx.get(i + 1) : VW + 10;
      pg.fill(p.lawn[(i + side) % 3]);
      if (side == 0) pg.rect(a, -2, b - a, w.rearTop + 2);
      else pg.rect(a, w.rearBot, b - a, VH - w.rearBot + 2);
    }
  }
  // lot lawns
  for (Lot L : w.lots) {
    int c = (L.dry && !simp) ? lerpColor(p.lawn[L.lawn], p.dryLawn, 0.5) : p.lawn[L.lawn];
    pg.fill(c);
    R a = w.dr(L.dir, L.frontY, L.x0, L.x1, -1, L.depth);
    pg.rect(a.x, a.y, a.w, a.h);
  }
  if (!simp) {
    // grass mottling
    for (int i = 0; i < 2600; i++) {
      float x = gr.nextFloat()*VW, y = gr.nextFloat()*VH, s = 10 + gr.nextFloat()*90;
      int c = gr.nextFloat() < 0.2 ? p.dryLawn : p.lawn[gr.nextInt(3)];
      pg.fill(c, 34);
      pg.ellipse(x, y, s, s*(0.6 + gr.nextFloat()*0.8));
    }
    // mowing stripes
    for (Lot L : w.lots) {
      if (!L.stripes) continue;
      R a = w.dr(L.dir, L.frontY, L.x0 + 4, L.x1 - 4, 0, L.depth - 4);
      for (float x = a.x; x < a.x + a.w; x += 28) {
        pg.fill(255, 12);
        pg.rect(x, a.y, 14, a.h);
      }
    }
  }

  // ground-level things in each lot
  for (Lot L : w.lots) {
    pg.noStroke();
    pg.fill(p.concrete);
    rectR(pg, L.drive);
    if (!simp) {
      pg.stroke(darker(p.concrete, 0.85), 120);
      pg.strokeWeight(1.2);
      for (float t = L.drive.y + 52; t < L.drive.y + L.drive.h - 10; t += 52) pg.line(L.drive.x + 1, t, L.drive.x + L.drive.w - 1, t);
      pg.noStroke();
      if (L.oilStain) {                   // where a car usually stands
        float ex = L.drive.cx();
        float ey = L.dir > 0 ? L.drive.y + 40 : L.drive.y + L.drive.h - 40;
        pg.fill(darker(p.concrete, 0.7), 60);
        pg.ellipse(ex, ey, 22, 30);
        pg.fill(darker(p.concrete, 0.6), 50);
        pg.ellipse(ex + 2, ey + 3, 10, 14);
      }
    }
    pg.fill(p.sidewalk);
    rectR(pg, L.path);
    if (L.patio != null) {
      pg.fill(simp ? p.concrete : p.deck);
      rectR(pg, L.patio);
      if (!simp) {
        pg.stroke(darker(p.deck, 0.82), 110);
        pg.strokeWeight(1);
        for (float x = L.patio.x + 6; x < L.patio.x + L.patio.w; x += 6) pg.line(x, L.patio.y + 1, x, L.patio.y + L.patio.h - 1);
        pg.noStroke();
      }
    }
    if (L.bed != null && !simp) {
      pg.fill(p.soil);
      rectR(pg, L.bed);
      Random br = new Random(L.number * 977L + seed);
      for (int i = 0; i < L.bed.h / 9; i++) {
        pg.fill(p.foliage[1 + br.nextInt(2)]);
        float s = 5 + br.nextFloat()*7;
        pg.ellipse(L.bed.x + 3 + br.nextFloat()*(L.bed.w - 6), L.bed.y + br.nextFloat()*L.bed.h, s, s);
      }
    }
    if (L.pool != null) drawPool(pg, L.pool, L.kidney, p, simp);
  }

  // the street
  pg.noStroke();
  pg.fill(p.sidewalk);
  pg.rect(-2, w.frontTop, VW + 4, w.walkW);
  pg.rect(-2, w.frontBot - w.walkW, VW + 4, w.walkW);
  if (!simp) {
    pg.stroke(darker(p.sidewalk, 0.82), 140);
    pg.strokeWeight(1.2);
    for (float x = 0; x < VW; x += 38) {
      pg.line(x, w.frontTop, x, w.frontTop + w.walkW);
      pg.line(x + 17, w.frontBot - w.walkW, x + 17, w.frontBot);
    }
    pg.noStroke();
  }
  pg.fill(p.curb);
  pg.rect(-2, w.streetTop - w.curbW, VW + 4, w.curbW);
  pg.rect(-2, w.streetBot, VW + 4, w.curbW);
  pg.fill(p.asphalt);
  pg.rect(-2, w.streetTop, VW + 4, w.streetBot - w.streetTop);
  pg.fill(darker(p.asphalt, 0.8), 120);                  // gutters
  pg.rect(-2, w.streetTop, VW + 4, 8);
  pg.rect(-2, w.streetBot - 8, VW + 4, 8);
  if (!simp) {
    for (int i = 0; i < 14; i++) {                        // patched asphalt
      float px = gr.nextFloat()*VW, py = w.streetTop + 10 + gr.nextFloat()*(w.streetBot - w.streetTop - 60);
      pg.fill(p.patch, 90);
      pg.rect(px, py, 40 + gr.nextFloat()*120, 20 + gr.nextFloat()*40);
    }
    pg.noFill();
    pg.stroke(darker(p.asphalt, 0.62), 150);              // crack seal
    pg.strokeWeight(1.6);
    for (int i = 0; i < 10; i++) {
      float x = gr.nextFloat()*VW, y = w.streetTop + 6 + gr.nextFloat()*(w.streetBot - w.streetTop - 12);
      pg.beginShape();
      for (int k = 0; k < 7; k++) {
        pg.vertex(x, y);
        x += 6 + gr.nextFloat()*22;
        y += (gr.nextFloat() - 0.5)*18;
        y = constrain(y, w.streetTop + 4, w.streetBot - 4);
      }
      pg.endShape();
    }
    pg.noStroke();
  }

  if (lk.type) drawStreetType(pg, lk);

  // shadows — built opaque on their own layer, laid down once
  shadowLayer.beginDraw();
  shadowLayer.clear();
  shadowLayer.pushMatrix();
  shadowLayer.scale(Z);
  shadowLayer.noStroke();
  shadowLayer.fill(255);
  for (Lot L : w.lots) {
    House h = L.house;
    if (h.wing != null) shadowRect(shadowLayer, h.wing, h.height*0.85);
    shadowRect(shadowLayer, h.main, h.height);
    if (L.shed != null) shadowRect(shadowLayer, L.shed, 15);
    if (L.tramp != null) shadowCircle(shadowLayer, L.tramp.cx(), L.tramp.cy(), L.tramp.w/2, 12);
    if (L.hedgeA != null) { shadowRect(shadowLayer, L.hedgeA, 10); shadowRect(shadowLayer, L.hedgeB, 10); }
    // fences
    R fl = w.dr(L.dir, L.frontY, L.x0 - 1.2, L.x0 + 1.2, L.fenceFrom, L.depth);
    shadowRect(shadowLayer, fl, 7);
    R rf = w.dr(L.dir, L.frontY, L.x0, L.x1, L.depth - 1.2, L.depth + 1.2);
    shadowRect(shadowLayer, rf, 7);
    if (!simp) {
      if (L.bins) { shadowRect(shadowLayer, new R(L.binsX, L.binsY - 6, 24, 12), 5); }
      if (L.parcel) shadowRect(shadowLayer, new R(L.house.doorX - 5, L.house.doorY - 4, 10, 8), 3);
    }
    for (Tree t : L.trees) shadowCircle(shadowLayer, t.x, t.y, t.r*0.92, t.h*0.55);
  }
  for (Tree t : w.streetTrees) shadowCircle(shadowLayer, t.x, t.y, t.r*0.92, t.h*0.55);
  for (Tree t : w.farTrees) shadowCircle(shadowLayer, t.x, t.y, t.r*0.92, t.h*0.55);
  for (float fx : w.farFencesTop) shadowRect(shadowLayer, new R(fx - 1.2, -5, 2.4, w.rearTop + 5), 7);
  for (float fx : w.farFencesBot) shadowRect(shadowLayer, new R(fx - 1.2, w.rearBot, 2.4, VH - w.rearBot + 5), 7);
  shadowLayer.popMatrix();
  shadowLayer.endDraw();
  if (!simp) shadowLayer.filter(BLUR, 1.6);
  pg.tint(p.shadow, p.shadowAlpha);
  pg.image(shadowLayer, 0, 0, VW, VH);
  pg.noTint();

  if (lk.night) drawNightLight(pg, p);

  // fences
  pg.stroke(p.fence);
  pg.strokeWeight(2.4);
  pg.strokeCap(SQUARE);
  for (Lot L : w.lots) {
    float ya = w.dy(L.dir, L.frontY, L.fenceFrom), yb = w.dy(L.dir, L.frontY, L.depth);
    pg.line(L.x0, ya, L.x0, yb);
    pg.line(L.x0, yb, L.x1, yb);
  }
  for (float fx : w.farFencesTop) pg.line(fx, -5, fx, w.rearTop);
  for (float fx : w.farFencesBot) pg.line(fx, w.rearBot, fx, VH + 5);
  pg.noStroke();

  // small things a person leaves outside
  for (Lot L : w.lots) {
    if (L.tramp != null) {
      pg.fill(p.tramp);
      pg.ellipse(L.tramp.cx(), L.tramp.cy(), L.tramp.w, L.tramp.h);
      pg.noFill();
      pg.stroke(lighter(p.tramp, 2.6));
      pg.strokeWeight(2.5);
      pg.ellipse(L.tramp.cx(), L.tramp.cy(), L.tramp.w - 2, L.tramp.h - 2);
      pg.noStroke();
    }
    if (L.hedgeA != null) {
      drawHedge(pg, L.hedgeA, p, simp, L.number);
      drawHedge(pg, L.hedgeB, p, simp, L.number + 1);
    }
    if (!simp && L.bins) {
      pg.fill(p.bin1);
      pg.rect(L.binsX, L.binsY - 6, 11, 12, 2);
      pg.fill(p.bin2);
      pg.rect(L.binsX + 13, L.binsY - 6, 11, 12, 2);
      pg.stroke(lighter(p.bin1, 1.5), 140);
      pg.strokeWeight(1);
      pg.line(L.binsX + 1, L.binsY - 3, L.binsX + 10, L.binsY - 3);
      pg.line(L.binsX + 14, L.binsY - 3, L.binsX + 23, L.binsY - 3);
      pg.noStroke();
    }
    if (!simp && L.parcel) {               // a delivery, waiting
      pg.fill(p.parcel);
      pg.rect(L.house.doorX - 5, L.house.doorY - 4, 10, 8);
      pg.stroke(lighter(p.parcel, 1.2), 200);
      pg.strokeWeight(1.2);
      pg.line(L.house.doorX - 5, L.house.doorY, L.house.doorX + 5, L.house.doorY);
      pg.noStroke();
    }
  }

  // roofs
  for (Lot L : w.lots) {
    House h = L.house;
    int base = p.roofs[h.roof];
    if (h.wing != null) drawRoof(pg, h.wing, h.hipWing, base, lk, null, L.number * 13L);
    drawRoof(pg, h.main, h.hipMain, base, lk, h, L.number * 17L);
    if (L.shed != null) drawRoof(pg, L.shed, false, p.shedRoof, lk, null, L.number * 19L);
  }

  // canopies last: they overhang everything
  for (Lot L : w.lots) for (Tree t : L.trees) drawTree(pg, t, p, simp);
  for (Tree t : w.farTrees) drawTree(pg, t, p, simp);
  for (Tree t : w.streetTrees) drawTree(pg, t, p, simp);

  pg.popMatrix();
  pg.endDraw();
}

// ---------------------------------------------------------- shadows
void shadowRect(PGraphics g, R r, float len) {
  float ox = SDX*len, oy = SDY*len;       // both positive: hull is a hexagon
  g.beginShape();
  g.vertex(r.x, r.y);
  g.vertex(r.x + r.w, r.y);
  g.vertex(r.x + r.w + ox, r.y + oy);
  g.vertex(r.x + r.w + ox, r.y + r.h + oy);
  g.vertex(r.x + ox, r.y + r.h + oy);
  g.vertex(r.x, r.y + r.h);
  g.endShape(CLOSE);
}

void shadowCircle(PGraphics g, float x, float y, float r, float len) {
  float ox = SDX*len, oy = SDY*len;
  g.ellipse(x, y, r*2, r*2);
  g.ellipse(x + ox, y + oy, r*2, r*2);
  float px = -SDY*r, py = SDX*r;
  g.quad(x + px, y + py, x + ox + px, y + oy + py, x + ox - px, y + oy - py, x - px, y - py);
}

// ------------------------------------------------------------- roofs
float[] rn(float nx, float ny, boolean horiz) {   // local normal -> world
  return horiz ? new float[]{nx, ny} : new float[]{-ny, nx};
}

int shadePlane(int c, float nx, float ny, Palette p) {
  float d = nx*TLX + ny*TLY;               // -1 .. 1, facing the sun
  float f = 1 + 0.3*d;
  int out = color(constrain(red(c)*f, 0, 255), constrain(green(c)*f, 0, 255), constrain(blue(c)*f, 0, 255));
  if (d > 0) return lerpColor(out, p.lightTint, d*0.2);
  return lerpColor(out, p.shadeTint, -d*0.25);
}

void drawRoof(PGraphics pg, R r, boolean hip, int base, Look lk, House h, long rs) {
  Palette p = lk.pal;
  boolean simp = lk.simplify;
  boolean horiz = r.w >= r.h;
  float w = horiz ? r.w : r.h, hh = horiz ? r.h : r.w;
  float x = -w/2, y = -hh/2;
  float i = min(hh/2, w/2);

  float[] nU = rn(0, -1, horiz), nD = rn(0, 1, horiz), nL = rn(-1, 0, horiz), nR = rn(1, 0, horiz);
  int cU = shadePlane(base, nU[0], nU[1], p), cD = shadePlane(base, nD[0], nD[1], p);
  int cL = shadePlane(base, nL[0], nL[1], p), cR = shadePlane(base, nR[0], nR[1], p);

  pg.pushMatrix();
  pg.translate(r.cx(), r.cy());
  if (!horiz) pg.rotate(HALF_PI);
  pg.noStroke();
  if (hip) {
    pg.fill(cU); pg.quad(x, y, x + w, y, x + w - i, 0, x + i, 0);
    pg.fill(cD); pg.quad(x, y + hh, x + w, y + hh, x + w - i, 0, x + i, 0);
    pg.fill(cL); pg.triangle(x, y, x + i, 0, x, y + hh);
    pg.fill(cR); pg.triangle(x + w, y, x + w - i, 0, x + w, y + hh);
  } else {
    pg.fill(cU); pg.rect(x, y, w, hh/2);
    pg.fill(cD); pg.rect(x, 0, w, hh/2);
  }

  if (!simp) {
    // shingle courses, parallel to each eave
    pg.strokeWeight(1);
    for (float t = 4; t < hh/2 - 1; t += 5) {
      float inset = hip ? t * (i / (hh/2)) : 0;
      pg.stroke(darker(cU, 0.8), 55);
      pg.line(x + inset, y + t, x + w - inset, y + t);
      pg.stroke(darker(cD, 0.8), 55);
      pg.line(x + inset, y + hh - t, x + w - inset, y + hh - t);
    }
    if (hip) {
      for (float t = 4; t < i - 1; t += 5) {
        float k = t * ((hh/2) / i);
        pg.stroke(darker(cL, 0.8), 55);
        pg.line(x + t, y + k, x + t, y + hh - k);
        pg.stroke(darker(cR, 0.8), 55);
        pg.line(x + w - t, y + k, x + w - t, y + hh - k);
      }
    }
  }
  // ridge and hips catch the light
  pg.stroke(lighter(base, 1.28), simp ? 120 : 170);
  pg.strokeWeight(2);
  if (hip) {
    pg.line(x + i, 0, x + w - i, 0);
    pg.line(x, y, x + i, 0);
    pg.line(x, y + hh, x + i, 0);
    pg.line(x + w, y, x + w - i, 0);
    pg.line(x + w, y + hh, x + w - i, 0);
  } else {
    pg.line(x, 0, x + w, 0);
  }
  // eave line
  pg.noFill();
  pg.stroke(darker(base, 0.6), 150);
  pg.strokeWeight(1.6);
  pg.rect(x, y, w, hh);
  pg.noStroke();

  if (h != null && !simp) {
    Random dr = new Random(rs);
    // pick the plane that faces the sun
    boolean upLit = (nU[0]*TLX + nU[1]*TLY) > 0;
    float py0 = upLit ? y + 7 : 7, py1 = upLit ? -7 : y + hh - 7;
    float px0 = x + i*0.7 + 8, px1 = x + w - i*0.7 - 8;
    if (!hip) { px0 = x + 10; px1 = x + w - 10; }
    // local shadow direction (inverse of the frame rotation)
    float lsx = horiz ? SDX : SDY, lsy = horiz ? SDY : -SDX;

    if (h.solar && px1 - px0 > 50) {
      int cols = (int)((px1 - px0) / 17);
      cols = min(cols, 6);
      float sx = (px0 + px1)/2 - cols*17/2.0;
      float ph = (py1 - py0);
      int rows = abs(ph) > 40 ? 2 : 1;
      for (int a = 0; a < cols; a++) for (int b = 0; b < rows; b++) {
        float yy = min(py0, py1) + 2 + b*21;
        pg.fill(p.solar);
        pg.rect(sx + a*17, yy, 15, 19);
        pg.stroke(lighter(p.solar, 2.2), 120);
        pg.strokeWeight(0.8);
        pg.line(sx + a*17 + 7.5, yy, sx + a*17 + 7.5, yy + 19);
        pg.noStroke();
      }
    }
    if (h.skylights && px1 - px0 > 40) {
      float yy = min(py0, py1) + 3;
      for (int a = 0; a < 2; a++) {
        float xx = lerp(px0, px1, 0.3 + a*0.3) - 7;
        pg.fill(p.skylight);
        pg.rect(xx, yy, 13, 19);
        pg.fill(lighter(p.skylight, 2.4), 160);
        pg.rect(xx + 2, yy + 2, 3, 15);
      }
    }
    if (h.vents) {
      for (int a = 0; a < 2; a++) {
        float vx = lerp(x + w*0.2, x + w*0.8, dr.nextFloat());
        float vy = (dr.nextFloat() < 0.5 ? -1 : 1) * hh * (0.12 + dr.nextFloat()*0.25);
        pg.fill(darker(base, 0.5), 160);
        pg.ellipse(vx + lsx*3, vy + lsy*3, 7, 7);
        pg.fill(lighter(base, 1.4));
        pg.ellipse(vx, vy, 6, 6);
      }
    }
    if (h.chimney) {
      float cx = x + w*h.chimU, cy = y + hh*h.chimV;
      float s = 13;
      pg.fill(0, 90);                       // chimney shadow across the roof
      pg.beginShape();
      pg.vertex(cx - s/2, cy - s/2); pg.vertex(cx + s/2, cy - s/2);
      pg.vertex(cx + s/2 + lsx*18, cy - s/2 + lsy*18); pg.vertex(cx + s/2 + lsx*18, cy + s/2 + lsy*18);
      pg.vertex(cx - s/2 + lsx*18, cy + s/2 + lsy*18); pg.vertex(cx - s/2, cy + s/2);
      pg.endShape(CLOSE);
      pg.fill(p.chimney);
      pg.rect(cx - s/2, cy - s/2, s, s);
      pg.fill(lighter(p.chimney, 1.25));
      pg.rect(cx - s/2, cy - s/2, s, 3);
      pg.fill(0xFF141414);
      pg.rect(cx - 2.5, cy - 2.5, 5, 5);
    }
  }
  pg.popMatrix();
}

// ------------------------------------------------------------- pools
void drawPool(PGraphics pg, R r, boolean kidney, Palette p, boolean simp) {
  pg.noStroke();
  if (kidney && !simp) {
    float ax = r.x + r.w*0.32, ay = r.y + r.h*0.52, aw = r.w*0.64, ah = r.h*1.0;
    float bx = r.x + r.w*0.72, by = r.y + r.h*0.46, bw = r.w*0.56, bh = r.h*0.82;
    pg.fill(p.coping);
    pg.ellipse(ax, ay, aw + 10, ah + 10); pg.ellipse(bx, by, bw + 10, bh + 10);
    pg.fill(p.poolDeep);
    pg.ellipse(ax, ay, aw, ah); pg.ellipse(bx, by, bw, bh);
    pg.fill(p.pool);
    pg.ellipse(ax + 2.4, ay + 3.2, aw*0.9, ah*0.88); pg.ellipse(bx + 2.4, by + 3.2, bw*0.88, bh*0.86);
  } else {
    pg.fill(p.coping);
    pg.rect(r.x - 5, r.y - 5, r.w + 10, r.h + 10, simp ? 0 : 6);
    pg.fill(p.poolDeep);
    pg.rect(r.x, r.y, r.w, r.h, simp ? 0 : 4);
    pg.fill(p.pool);
    pg.rect(r.x + 4, r.y + 5, r.w - 6, r.h - 7, simp ? 0 : 3);
  }
  if (!simp) {
    Random pr = new Random((long)(r.x*31 + r.y));
    pg.noFill();
    pg.stroke(lighter(p.pool, 1.35), 110);
    pg.strokeWeight(1.3);
    for (int k = 0; k < 6; k++) {
      float cx = r.x + 10 + pr.nextFloat()*(r.w - 20), cy = r.y + 8 + pr.nextFloat()*(r.h - 16);
      pg.bezier(cx - 9, cy, cx - 3, cy - 4, cx + 3, cy + 4, cx + 9, cy);
    }
    pg.noStroke();
  }
}

// ------------------------------------------------------------- trees
int tone3(int[] f, float t) {
  t = constrain(t, 0, 1);
  return t < 0.5 ? lerpColor(f[0], f[1], t*2) : lerpColor(f[1], f[2], (t - 0.5)*2);
}

void drawTree(PGraphics pg, Tree t, Palette p, boolean simp) {
  pg.noStroke();
  if (simp) {                               // a disc and its lit crescent
    pg.fill(p.foliage[0]);
    pg.ellipse(t.x, t.y, t.r*2, t.r*2);
    pg.fill(p.foliage[1]);
    pg.ellipse(t.x + TLX*t.r*0.16, t.y + TLY*t.r*0.16, t.r*1.62, t.r*1.62);
    pg.fill(p.foliage[2]);
    pg.ellipse(t.x + TLX*t.r*0.4, t.y + TLY*t.r*0.4, t.r*0.8, t.r*0.8);
    return;
  }
  Random tr = new Random(t.s);
  pg.fill(p.foliage[0]);
  pg.ellipse(t.x, t.y, t.r*1.9, t.r*1.9);
  int n = (int)(t.r*1.5);
  float[] bx = new float[n], by = new float[n], bs = new float[n], bt = new float[n];
  for (int k = 0; k < n; k++) {
    float a = tr.nextFloat()*TWO_PI, d = sqrt(tr.nextFloat())*t.r*0.74;
    bx[k] = t.x + cos(a)*d;
    by[k] = t.y + sin(a)*d;
    bs[k] = t.r*(0.26 + tr.nextFloat()*0.28);
    float lit = (cos(a)*TLX + sin(a)*TLY) * (d/(t.r*0.74));
    bt[k] = 0.42 + lit*0.5 + (tr.nextFloat() - 0.5)*0.3;
  }
  for (int band = 0; band < 6; band++) {    // dark first, light on top
    float lo = band/6.0 - (band == 0 ? 1 : 0), hi = (band + 1)/6.0 + (band == 5 ? 1 : 0);
    for (int k = 0; k < n; k++) {
      if (bt[k] < lo || bt[k] >= hi) continue;
      pg.fill(tone3(p.foliage, bt[k]), 235);
      pg.ellipse(bx[k], by[k], bs[k]*2, bs[k]*2*(0.85 + 0.3*((k*7) % 5)/5.0));
    }
  }
}

void drawHedge(PGraphics pg, R r, Palette p, boolean simp, int s) {
  if (r.w < 6) return;
  pg.noStroke();
  pg.fill(p.foliage[0]);
  rectR(pg, r);
  if (simp) return;
  Random hr = new Random(s*313L + seed);
  for (float x = r.x + 4; x < r.x + r.w - 2; x += 5) {
    pg.fill(tone3(p.foliage, 0.3 + hr.nextFloat()*0.6));
    pg.ellipse(x, r.cy() + TLY*2, 8, 8);
  }
}

// ------------------------------------------------------------- night
void glow(PGraphics pg, float x, float y, float r, int c, float a) {
  int steps = 26;
  pg.noStroke();
  for (int k = 0; k < steps; k++) {
    float t = 1 - k/(float)steps;
    pg.fill(c, a/steps);
    pg.ellipse(x, y, 2*r*t, 2*r*t);
  }
}

void drawNightLight(PGraphics pg, Palette p) {
  World w = world;
  pg.blendMode(ADD);
  for (float[] lp : w.lamps) {
    glow(pg, lp[0], lp[1], 175, p.lampGlow, 150);
    glow(pg, lp[0], lp[1], 40, p.lampGlow, 120);
  }
  for (Lot L : w.lots) {
    if (L.pool != null) glow(pg, L.pool.cx(), L.pool.cy(), max(L.pool.w, L.pool.h)*0.85, p.poolGlow, 105);
    House h = L.house;
    if (!h.lit) continue;                   // most windows stay dark
    R m = h.main;
    for (int k = 0; k < 3; k++) {
      float t = 0.25 + k*0.25;
      float gx, gy;
      if (h.litSide == 0)      { gx = m.x + m.w*t; gy = m.y - 4; }
      else if (h.litSide == 1) { gx = m.x + m.w*t; gy = m.y + m.h + 4; }
      else if (h.litSide == 2) { gx = m.x - 4; gy = m.y + m.h*t; }
      else                     { gx = m.x + m.w + 4; gy = m.y + m.h*t; }
      glow(pg, gx, gy, 38, p.windowGlow, 110);
    }
  }
  pg.blendMode(BLEND);
  for (float[] lp : w.lamps) {
    pg.fill(0xFFFFE6B8);
    pg.ellipse(lp[0], lp[1], 7, 7);
  }
}

// -------------------------------------------------------------- type
// The street's only text: curb numbers and a road legend. Painted, then
// repainted, so the letters are made of the same strokes as the houses.
void drawStreetType(PGraphics pg, Look lk) {
  Palette p = lk.pal;
  World w = world;
  // road legend: elongated in the direction of travel, read by a driver
  // who never comes. Westbound in the top lane, eastbound in the bottom.
  pg.fill(p.paint, 235);
  pg.textFont(fontRoad);
  pg.textAlign(CENTER, CENTER);
  pg.textSize(46);
  float laneTop = (w.streetTop + w.cy)/2, laneBot = (w.cy + w.streetBot)/2;
  pg.pushMatrix();
  pg.translate(w.slowBotX, laneBot);
  pg.rotate(HALF_PI);
  pg.scale(1, 3.0);
  pg.text("SLOW", 0, 0);
  pg.popMatrix();
  pg.pushMatrix();
  pg.translate(w.slowTopX, laneTop);
  pg.rotate(-HALF_PI);
  pg.scale(1, 3.0);
  pg.text("SLOW", 0, 0);
  pg.popMatrix();
  // stop-line-like bars ahead of each legend
  pg.noStroke();
  pg.fill(p.paint, 220);
  pg.rect(w.slowBotX + 120, w.cy + 8, 14, w.roadHalf - 18);
  pg.rect(w.slowTopX - 134, w.streetTop + 10, 14, w.roadHalf - 18);

  // curb numbers, facing the road — so the far row reads upside down
  pg.textFont(fontNum);
  pg.textSize(17);
  for (Lot L : w.lots) {
    if (L.numX < 20 || L.numX > VW - 20) continue;
    pg.pushMatrix();
    pg.translate(L.numX, L.numY + (L.dir > 0 ? -4 : 4));
    if (L.dir < 0) pg.rotate(PI);
    pg.noStroke();
    pg.fill(p.paint);
    pg.rect(-21, -11, 42, 22);
    pg.fill(p.ink);
    pg.textAlign(CENTER, CENTER);
    pg.text(str(L.number), 0, -2);
    pg.popMatrix();
  }
}

// ===================================================================
//  PAINT  — reference -> oil
// ===================================================================
float[] lumBuf;

float Lm(int x, int y) {
  x = constrain(x, 0, W - 1);
  y = constrain(y, 0, H - 1);
  return lumBuf[y*W + x];
}

float cdist(int a, int b) {
  return (abs(((a>>16)&255) - ((b>>16)&255)) + abs(((a>>8)&255) - ((b>>8)&255)) + abs((a&255) - (b&255))) / 3.0;
}

int[] shuffled(int n) {
  int[] o = new int[n];
  for (int i = 0; i < n; i++) o[i] = i;
  for (int i = n - 1; i > 0; i--) {
    int j = (int)random(i + 1);
    int t = o[i]; o[i] = o[j]; o[j] = t;
  }
  return o;
}

void paint(PGraphics src, Look lk) {
  src.loadPixels();
  int[] sp = src.pixels;
  lumBuf = new float[W*H];
  for (int i = 0; i < sp.length; i++) {
    int c = sp[i];
    lumBuf[i] = 0.299*((c>>16)&255) + 0.587*((c>>8)&255) + 0.114*(c&255);
  }
  randomSeed(seed*101 + 13);
  noiseSeed(seed);

  cv.beginDraw();
  cv.background(lk.pal.ground);
  cv.strokeCap(ROUND);
  hgt.beginDraw();
  hgt.background(128);
  hgt.strokeCap(ROUND);

  for (int pass = 0; pass < lk.radii.length; pass++) {
    float r = lk.radii[pass];
    int step = max(2, round(r*0.85));
    int gw = W/step + 1, gh = H/step + 1;
    int[] order = shuffled(gw*gh);
    int[] cp = null;
    if (pass > 0) { cv.loadPixels(); cp = cv.pixels; }
    for (int k : order) {
      int x = min(W - 1, (k % gw)*step + (int)random(step));
      int y = min(H - 1, (k / gw)*step + (int)random(step));
      int sc = sp[y*W + x];
      if (pass > 0 && cdist(cp[y*W + x], sc) < lk.thresh) continue;
      placeStroke(x, y, r, sc, sp, lk);
    }
  }
  if (lk.knife) knife(sp, lk);
  hgt.endDraw();
  finish(lk);
  cv.endDraw();
}

void placeStroke(int x, int y, float r, int sc, int[] sp, Look lk) {
  int s = max(1, round(r*0.6));
  float gx = Lm(x + s, y) - Lm(x - s, y);
  float gy = Lm(x, y + s) - Lm(x, y - s);
  float ang;
  if (gx*gx + gy*gy > 16) ang = atan2(gy, gx) + HALF_PI;   // run along edges
  else ang = (noise(x*0.0025, y*0.0025) - 0.5)*1.5;        // drift, mostly level
  ang += random(-0.12, 0.12);
  float ca = cos(ang), sa = sin(ang);
  float maxHalf = r*lk.strokeLen*random(0.6, 1.25);
  float a = max(walk(x, y, ca, sa, maxHalf, r, sc, sp), r*0.35);
  float b = max(walk(x, y, -ca, -sa, maxHalf, r, sc, sp), r*0.35);
  brush(x - ca*b, y - sa*b, x + ca*a, y + sa*a, r, sc, lk);
}

// extend a stroke until the reference colour changes
float walk(int x, int y, float ca, float sa, float maxHalf, float r, int sc, int[] sp) {
  float len = 0, st = max(1, r*0.5);
  while (len + st <= maxHalf) {
    int px = round(x + ca*(len + st)), py = round(y + sa*(len + st));
    if (px < 0 || py < 0 || px >= W || py >= H) break;
    if (cdist(sp[py*W + px], sc) > 30) break;
    len += st;
  }
  return len;
}

// one loaded brush: a bundle of bristles, each a slightly different colour,
// ragged at both ends, bowed, lighter on the side that faces the sun
void brush(float x1, float y1, float x2, float y2, float r, int c, Look lk) {
  float dx = x2 - x1, dy = y2 - y1, len = sqrt(dx*dx + dy*dy);
  if (len < 0.01) { dx = 0.01; dy = 0; len = 0.01; }
  float ux = dx/len, uy = dy/len, px = -uy, py = ux;
  float lit = px*TLX + py*TLY;
  int nb = constrain(round(r*0.75), 3, 14);
  float bw = (2*r/nb)*1.35;
  float bow = r*random(-0.35, 0.35);
  float j = lk.jitter;
  float sr = ((c>>16)&255) + random(-j, j);
  float sg = ((c>>8)&255) + random(-j, j);
  float sb = (c&255) + random(-j, j);
  cv.strokeWeight(bw);
  hgt.strokeWeight(bw);
  for (int b = 0; b < nb; b++) {
    float side = map(b, 0, nb - 1, -1, 1);
    float o = side*r*0.9 + random(-bw*0.3, bw*0.3);
    float lift = side*lit*lk.tone + random(-j*0.4, j*0.4);
    float t0 = random(0, 0.16), t1 = random(0.84, 1.0);
    float ax = x1 + dx*t0 + px*o, ay = y1 + dy*t0 + py*o;
    float bx = x1 + dx*t1 + px*o, by = y1 + dy*t1 + py*o;
    float mx = (ax + bx)/2 + px*bow, my = (ay + by)/2 + py*bow;
    cv.stroke(constrain(sr + lift, 0, 255), constrain(sg + lift, 0, 255), constrain(sb + lift, 0, 255), random(185, 240));
    cv.line(ax, ay, mx, my);
    cv.line(mx, my, bx, by);
    hgt.stroke(random(140, 255), 70);
    hgt.line(ax, ay, mx, my);
    hgt.line(mx, my, bx, by);
  }
}

// palette knife: flat, wide drags across quiet passages only
void knife(int[] sp, Look lk) {
  cv.loadPixels();
  int[] cp = cv.pixels;
  for (int i = 0; i < 420; i++) {
    int x = (int)random(W), y = (int)random(H);
    int c = sp[y*W + x];
    float ang = (noise(x*0.002, y*0.002) - 0.5)*0.9 + random(-0.1, 0.1);
    float len = random(36, 110), wid = random(7, 16);
    float ca = cos(ang), sa = sin(ang);
    boolean ok = true;
    for (int t = -2; t <= 2 && ok; t++) {
      for (int q = -1; q <= 1 && ok; q++) {
        int px = round(x + ca*len*0.25*t - sa*wid*0.5*q);
        int py = round(y + sa*len*0.25*t + ca*wid*0.5*q);
        if (px < 0 || py < 0 || px >= W || py >= H || cdist(sp[py*W + px], c) > 20) ok = false;
      }
    }
    if (!ok) continue;
    // the blade picks up the wet paint where it lands and drags it,
    // thinning as it goes; each row of the blade carries its own colour
    float ax = x - ca*len/2, ay = y - sa*len/2;
    cv.strokeWeight(1.6);
    hgt.strokeWeight(1.6);
    for (float q = -wid/2; q <= wid/2; q += 1.2) {
      float sx = ax - sa*q, sy = ay + ca*q;
      int pick = cp[constrain(round(sy), 0, H - 1)*W + constrain(round(sx), 0, W - 1)];
      float l = len*random(0.82, 1.0);
      int segs = 6;
      for (int s = 0; s < segs; s++) {
        float u0 = l*s/segs, u1 = l*(s + 1)/segs;
        float fade = 1 - s/(float)segs;
        cv.stroke(pick, 70 + 150*fade);
        cv.line(sx + ca*u0, sy + sa*u0, sx + ca*u1, sy + sa*u1);
      }
      hgt.stroke(abs(q) > wid/2 - 1.5 ? 175 : 120 + random(-6, 6), 150);
      hgt.line(sx, sy, sx + ca*l, sy + sa*l);
    }
  }
}

// emboss the paint, lay in canvas weave, a thin warm glaze and a vignette
void finish(Look lk) {
  cv.loadPixels();
  hgt.loadPixels();
  int[] cp = cv.pixels, hp = hgt.pixels;
  int gl = lk.pal.glaze;
  float ga = lk.pal.glazeAlpha;
  float glr = (gl>>16)&255, glg = (gl>>8)&255, glb = gl&255;
  float k = 0.42*lk.impasto;
  long rs = seed*7919 + 1;
  for (int y = 0; y < H; y++) {
    for (int x = 0; x < W; x++) {
      int i = y*W + x;
      int c = cp[i];
      float r = (c>>16)&255, g = (c>>8)&255, b = c&255;
      float e = 0;
      if (x > 0 && y > 0 && x < W - 1 && y < H - 1) e = ((hp[i + W + 1]&255) - (hp[i - W - 1]&255))*k;
      float wv = (float)(Math.sin(x*1.35)*Math.sin(y*1.35))*2.6;
      rs = rs*6364136223846793005L + 1442695040888963407L;
      float gn = ((rs >>> 40) & 255)/255.0*6 - 3;
      float vx = (x - W*0.5)/(W*0.5), vy = (y - H*0.5)/(H*0.5);
      float v = 1 - 0.15*(vx*vx*0.8 + vy*vy);
      float diag = constrain((x/(float)W + y/(float)H)*0.5, 0, 1);   // 0 = toward the sun
      float add = e + wv + gn;
      r = (r + (glr - r)*ga + add + (0.5 - diag)*10)*v;
      g = (g + (glg - g)*ga + add)*v;
      b = (b + (glb - b)*ga + add - (0.5 - diag)*10)*v;
      cp[i] = 0xFF000000 | (clampi(r) << 16) | (clampi(g) << 8) | clampi(b);
    }
  }
  cv.updatePixels();
}

int clampi(float v) {
  return v < 0 ? 0 : (v > 255 ? 255 : (int)v);
}

// ===================================================================
//  CONTACT SHEET  — the series as one object
// ===================================================================
void contactSheet(PImage[] thumbs) {
  int SW = 2400, SH = 1760;
  int cols = 4, mx = 90, gut = 44;
  float tw = (SW - 2*mx - (cols - 1)*gut) / (float)cols;
  float th = tw * H / (float)W;
  float top = 230;
  PGraphics s = createGraphics(SW, SH);
  s.beginDraw();
  s.background(0xFFECE7DE);
  s.fill(0xFF1D1C1A);
  s.textFont(fontTitle);
  s.textAlign(LEFT, BASELINE);
  s.textSize(64);
  trackedText(s, "EXOSKELETONS", mx, 150, 0.28);
  s.textFont(fontBody);
  s.textSize(19);
  s.fill(0xFF5C5852);
  s.textAlign(RIGHT, BASELINE);
  s.text("seven paintings of one block   ·   seed " + seed, SW - mx, 150);
  s.stroke(0xFF1D1C1A);
  s.strokeWeight(1.5);
  s.line(mx, 178, SW - mx, 178);
  s.noStroke();

  for (int i = 0; i < 8; i++) {
    int cx = i % cols, cy = i / cols;
    float x = mx + cx*(tw + gut), y = top + cy*(th + 110);
    if (i < thumbs.length) {
      s.fill(0, 30);
      s.rect(x + 5, y + 7, tw, th);
      s.image(thumbs[i], x, y, tw, th);
      s.fill(0xFF1D1C1A);
      s.textFont(fontMono);
      s.textSize(17);
      s.textAlign(LEFT, BASELINE);
      s.text(STAGES[i][0], x, y + th + 36);
      s.textFont(fontBody);
      s.textSize(21);
      s.text(STAGES[i][1].toUpperCase(), x + 44, y + th + 36);
      s.fill(0xFF6A665F);
      s.textSize(17);
      s.text(STAGES[i][2], x + 44, y + th + 62);
    } else {
      // the eighth cell carries the statement, set as a column of text
      s.fill(0xFF1D1C1A);
      s.textFont(fontBody);
      s.textSize(21);
      s.textAlign(LEFT, TOP);
      String st =
        "The people who live on this street are never seen. " +
        "Their houses stand in for them — shells side by side, " +
        "facing a road no one walks.\n\n" +
        "Seen from directly above and at a distance, a roof stops " +
        "being architecture and starts to read as a body: small, " +
        "exposed, a little alone.\n\n" +
        "Panel 00 is the aerial prompt. From 02 on, each painting " +
        "changes one element only — colour, shape, texture, mood, " +
        "type — while the block stays exactly where it is.";
      s.text(st, x, y + 4, tw, th);
    }
  }
  s.endDraw();
  String f = savePath("output/exoskeletons_" + seed + "_contact_sheet.png");
  s.save(f);
  println("saved " + f);
}

void trackedText(PGraphics s, String t, float x, float y, float track) {
  float sz = s.textSize;
  for (int i = 0; i < t.length(); i++) {
    String ch = str(t.charAt(i));
    s.text(ch, x, y);
    x += s.textWidth(ch) + sz*track;
  }
}

// ===================================================================
//  UTILITIES
// ===================================================================
void rectR(PGraphics pg, R r) {
  pg.rect(r.x, r.y, r.w, r.h);
}

int darker(int c, float f) {
  return color(red(c)*f, green(c)*f, blue(c)*f);
}

int lighter(int c, float f) {
  return color(min(255, red(c)*f + 6), min(255, green(c)*f + 6), min(255, blue(c)*f + 6));
}

PFont pickFont(String[] names, int size) {
  String[] avail = PFont.list();
  for (String n : names) {
    for (String a : avail) {
      if (a.equalsIgnoreCase(n)) return createFont(a, size, true);
    }
  }
  return createFont("SansSerif", size, true);
}

void loadFonts() {
  fontRoad = pickFont(new String[]{
    "DIN Condensed Bold", "DINCondensed-Bold", "Roboto Condensed Bold", "RobotoCondensed-Bold",
    "Arial Narrow Bold", "ArialNarrow-Bold", "Helvetica Neue Condensed Bold",
    "Inter Display ExtraBold", "Inter ExtraBold", "Inter Bold", "Arial Bold", "Arial-BoldMT",
    "DejaVu Sans Condensed Bold", "SansSerif.bold"}, 64);
  fontNum = pickFont(new String[]{
    "Helvetica Neue Bold", "HelveticaNeue-Bold", "Inter Display Bold", "Inter Bold",
    "Arial Bold", "Arial-BoldMT", "DejaVu Sans Bold", "SansSerif.bold"}, 32);
  fontTitle = pickFont(new String[]{
    "Helvetica Neue Light", "HelveticaNeue-Light", "Inter Display Light", "Inter Light",
    "Arial", "DejaVu Sans ExtraLight", "SansSerif"}, 72);
  fontBody = pickFont(new String[]{
    "Helvetica Neue", "Inter Display", "Inter", "Arial", "DejaVu Sans", "SansSerif"}, 24);
  fontMono = pickFont(new String[]{
    "JetBrains Mono", "IBM Plex Mono", "SF Mono", "Menlo", "DejaVu Sans Mono", "Courier New", "Monospaced"}, 20);
}
