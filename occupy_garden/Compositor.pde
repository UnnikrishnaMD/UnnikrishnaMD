// ---------------- Layers, type grid, stills, ffmpeg ----------------
// Every frame is composited from cached layers at the current layerScale (preview or full output):
//   edition background -> eroding type grid -> figure + body texture -> plants -> consumer layer
// plus a crossfade out of the previous piece's last frame. The garden itself stays in logical
// coordinates (W x H) and is drawn through scale(layerScale), so preview and final render are the same
// layout - only the pixel density differs.

PGraphics frame;         // the composited frame, at layerScale
PGraphics baseLayer;     // edition background (sky/earth + duo wash + clouds + grain)
PGraphics figureLayer;   // keyed drawing + body texture, transparent elsewhere
PGraphics plantsCache;   // every plant, fully grown - reused through the hold instead of redrawing thousands of stems
boolean plantsCacheDirty = true;
PImage prevFrame;        // previous piece's last frame, for the crossfade
boolean allGrown = false;
float erosion = 0;       // 0 = type fully legible ... 1 = gone
float consumerReveal = 1; // fraction of ad panels / drifting coins shown (stills: everything)
FfmpegPipe ffmpeg;

// ---------- Growth schedule ----------
// The original live mode grew every plant one step per frame from frame 0, so short plants finished in
// a few seconds and only the trees kept going. Here each plant group starts at its own point in the
// growth phase - the figure's outline first, then vines on the letters, then the background contours,
// then the main grid, then the meadow - and within a group every plant is paced individually: it starts
// when a low-frequency noise field over its root position says so, and spreads its own steps over the
// rest of the window. The meadow fills in patch by patch and everything is fully grown exactly when the
// hold begins. The timing uses noise(), not random(), so the layout is the same as without it.
float[] growthDelay = { 0.0, 0.06, 0.12, 0.2, 0.3 }; // fraction of growSeconds before each group starts
float growthSpread = 0.55; // how late in its group's window a plant may start (0 = all together)

ArrayList<Plant> growthList(int i) {
  switch (i) {
    case 0: return bodyContourPlants;
    case 1: return typePlants;
    case 2: return contourPlants;
    case 3: return plants;
    default: return fillerPlants;
  }
}

void setupGrowth() {
  for (int i = 0; i < growthDelay.length; i++) {
    for (Plant p : growthList(i)) {
      PVector root = p.path.get(0);
      float n = constrain((noise(root.x * 0.004 + 4100, root.y * 0.004 + 4100) - 0.3) / 0.4, 0, 1);
      p.growStart = n * growthSpread;
      p.growCalls = 0;
    }
  }
  allGrown = false;
  plantsCacheDirty = true;
}

void growLists(float gp) {
  for (int i = 0; i < growthDelay.length; i++) {
    float lp = constrain((gp - growthDelay[i]) / (1 - growthDelay[i]), 0, 1);
    for (Plant p : growthList(i)) {
      float pp = constrain((lp - p.growStart) / (1 - p.growStart), 0, 1);
      // Branches spawned near a plant's tip need up to ~0.55x more steps after the stem itself stops.
      int target = int(pp * (p.maxSteps * 1.6 + 4));
      while (p.growCalls < target) {
        p.grow();
        p.growCalls++;
      }
    }
  }
}

void forceAllGrown() {
  for (int i = 0; i < growthDelay.length; i++) forceFullyGrown(growthList(i));
  allGrown = true;
  plantsCacheDirty = true;
}

// ---------- Type erosion schedule ----------
// Legible at the start of each piece, then eaten away from the edges inward while the plants take over,
// ending as scattered abstract fragments - only the figure stays whole.
float erosionStart = 0.1;  // fraction of growSeconds before erosion begins
float erosionEnd = 0.66;   // how far it gets by the end of the hold (1 = nothing left; ~0.66 leaves abstract letter fragments)

float erosionAt(float t) {
  float t0 = S.growSeconds * erosionStart;
  float t1 = pieceDuration();
  float u = constrain((t - t0) / max(0.001, t1 - t0), 0, 1);
  return erosionEnd * u * u * (3 - 2 * u); // smoothstep - slow to start, slow to settle
}

// ---------------- Layer building ----------------

void buildLayers() {
  int fw = round(W * layerScale), fh = round(H * layerScale);
  if (frame == null || frame.width != fw || frame.height != fh) {
    frame = createGraphics(fw, fh);
    plantsCache = null;
  }
  buildBodyTextureLayer();
  buildBaseLayer();
  buildFigureLayer();
  buildTypeMap();
  plantsCacheDirty = true;
}

void buildBaseLayer() {
  baseLayer = createGraphics(frame.width, frame.height);
  baseLayer.beginDraw();
  baseLayer.scale(layerScale);
  drawEditionBackground(baseLayer);
  baseLayer.endDraw();
}

void buildFigureLayer() {
  figureLayer = createGraphics(frame.width, frame.height);
  figureLayer.beginDraw();
  figureLayer.clear();
  figureLayer.pushMatrix();
  figureLayer.scale(layerScale);
  float[] bgPlace = computePlacement(bgImg, bgScale, bgOffsetX, bgOffsetY);
  figureLayer.image(bgImgKeyed, bgPlace[0], bgPlace[1], bgPlace[2], bgPlace[3]);
  figureLayer.popMatrix();
  figureLayer.image(bodyTextureLayer, 0, 0);
  figureLayer.endDraw();
  bodyTextureLayer = null; // composited in - no need to keep a second full-size copy around
}

void renderPlantsCache() {
  if (plantsCache == null || plantsCache.width != frame.width || plantsCache.height != frame.height) {
    plantsCache = createGraphics(frame.width, frame.height);
  }
  plantsCache.beginDraw();
  plantsCache.clear();
  drawPlantsWithDepthOfField(plantsCache);
  plantsCache.endDraw();
  plantsCacheDirty = false;
}

// ---------- Depth of field ----------
// The meadow is drawn in three distance bands and the two far ones are optically blurred: the far band
// is drawn at half resolution and blurred strongly, the middle band at full resolution and blurred
// lightly, then both are laid under the sharp near band. The blur is a three-pass box blur (a close
// approximation of a Gaussian, the way a lens defocuses) on premultiplied colour, so edges soften evenly
// with no blocky stair-steps and no dark halos where plants meet the sky. The vines on the figure itself
// always stay sharp.
float farBand = 0.3, midBand = 0.5;   // depth (0 = horizon .. 1 = bottom edge) where each band ends
float farBlur = 6, midBlur = 2;       // blur radius in output pixels
PGraphics farLayer, midLayer;

float plantDepthU(Plant p) {
  return constrain((p.path.get(0).y / H - skyBand) / (1 - skyBand), 0, 1);
}

void drawPlantsWithDepthOfField(PGraphics f) {
  int fw = max(1, f.width / 2), fh = max(1, f.height / 2);
  if (farLayer == null || farLayer.width != fw || farLayer.height != fh) farLayer = createGraphics(fw, fh);
  if (midLayer == null || midLayer.width != f.width || midLayer.height != f.height) midLayer = createGraphics(f.width, f.height);
  ArrayList<Plant> all = depthSortedAllPlants();
  java.util.HashSet<Plant> sharp = new java.util.HashSet<Plant>(bodyContourPlants); // the figure's own vines are in focus
  float px = f.width / (float) S.outW; // blur radii are given at output size; scale them for previews

  farLayer.beginDraw();
  farLayer.clear();
  farLayer.scale(layerScale * 0.5);
  for (Plant p : all) if (!sharp.contains(p) && plantDepthU(p) < farBand) p.display(farLayer);
  farLayer.endDraw();
  gaussianBlur(farLayer, max(1, round(farBlur * px * 0.5)));

  midLayer.beginDraw();
  midLayer.clear();
  midLayer.scale(layerScale);
  for (Plant p : all) {
    float u = plantDepthU(p);
    if (!sharp.contains(p) && u >= farBand && u < midBand) p.display(midLayer);
  }
  midLayer.endDraw();
  gaussianBlur(midLayer, max(1, round(midBlur * px)));

  f.image(farLayer, 0, 0, f.width, f.height);
  f.image(midLayer, 0, 0);
  f.pushMatrix();
  f.scale(layerScale);
  for (Plant p : all) if (sharp.contains(p) || plantDepthU(p) >= midBand) p.display(f);
  f.popMatrix();
}

// Three box-blur passes of radius r in each direction ~ a Gaussian. Works on premultiplied ARGB so
// transparent pixels contribute no colour (no dark fringes), then converts back.
void gaussianBlur(PGraphics g, int r) {
  g.loadPixels();
  int w = g.width, h = g.height, n = w * h;
  int[] px = g.pixels;
  int[] a = new int[n], rr = new int[n], gg = new int[n], bb = new int[n];
  for (int i = 0; i < n; i++) {
    int c = px[i], al = c >>> 24;
    a[i] = al;
    rr[i] = ((c >> 16) & 255) * al / 255;
    gg[i] = ((c >> 8) & 255) * al / 255;
    bb[i] = (c & 255) * al / 255;
  }
  int[] tmp = new int[n];
  int[][] ch = { a, rr, gg, bb };
  for (int[] c : ch) {
    for (int pass = 0; pass < 3; pass++) {
      boxBlurH(c, tmp, w, h, r);
      boxBlurV(tmp, c, w, h, r);
    }
  }
  for (int i = 0; i < n; i++) {
    int al = constrain(a[i], 0, 255);
    if (al == 0) { px[i] = 0; continue; }
    int r2 = constrain(rr[i] * 255 / al, 0, 255), g2 = constrain(gg[i] * 255 / al, 0, 255), b2 = constrain(bb[i] * 255 / al, 0, 255);
    px[i] = (al << 24) | (r2 << 16) | (g2 << 8) | b2;
  }
  g.updatePixels();
}

void boxBlurH(int[] src, int[] dst, int w, int h, int r) {
  float inv = 1f / (r + r + 1);
  for (int y = 0; y < h; y++) {
    int row = y * w;
    int first = src[row], last = src[row + w - 1];
    int sum = (r + 1) * first;
    for (int x = 0; x < r; x++) sum += src[row + min(x, w - 1)];
    for (int x = 0; x < w; x++) {
      sum += src[row + min(x + r, w - 1)] - (x - r - 1 >= 0 ? src[row + x - r - 1] : first);
      dst[row + x] = round(sum * inv);
    }
  }
}

void boxBlurV(int[] src, int[] dst, int w, int h, int r) {
  float inv = 1f / (r + r + 1);
  for (int x = 0; x < w; x++) {
    int first = src[x];
    int sum = (r + 1) * first;
    for (int y = 0; y < r; y++) sum += src[min(y, h - 1) * w + x];
    for (int y = 0; y < h; y++) {
      sum += src[min(y + r, h - 1) * w + x] - (y - r - 1 >= 0 ? src[(y - r - 1) * w + x] : first);
      dst[y * w + x] = round(sum * inv);
    }
  }
}

void composeFrame(PGraphics f) {
  f.beginDraw();
  f.image(baseLayer, 0, 0);
  updateTypeImage();
  f.image(typeImg, 0, 0);
  f.image(figureLayer, 0, 0);
  if (allGrown) {
    if (plantsCacheDirty || plantsCache == null) renderPlantsCache();
    f.image(plantsCache, 0, 0);
  } else {
    drawPlantsWithDepthOfField(f);
  }
  f.pushMatrix();
  f.scale(layerScale);
  drawConsumerLayer(f); // painted last so it always reads as the top layer, unobstructed
  f.popMatrix();
  if (prevFrame != null && tPiece < xfadeSeconds) {
    float u = constrain((tPiece + 1.0 / fps) / xfadeSeconds, 0, 1); // +1 frame: the loop's first frame isn't a copy of its last
    f.tint(255, 255 * (1 - u * u * (3 - 2 * u)));
    f.image(prevFrame, 0, 0, f.width, f.height);
    f.noTint();
  }
  f.endDraw();
}

// ---------------- Grunge type grid ----------------
// The whole canvas inside the safe margin filled with type: one letter per near-square cell, every
// cell filled, running as one continuous stream of the sketch's advertising calls to action with the
// spaces taken out (SHOPNOWLASTCHANCEGET20%OFF...), row after row, behind the figure. It doesn't need to
// be read - it's a field of advertising language. The plants grow over it, vines root on the letter
// outlines (typePlants), and over the piece the letters erode - edges first, through noise - until only
// abstract letter fragments remain. Erosion is a fixed per-pixel threshold map compared against one
// number per frame, so it costs almost nothing to animate and the grain stays still (moving grain would
// be both noisy and expensive to encode).

// A modern sans-serif that ships with the operating system - the first of these found is used, so the
// same sketch works on a Mac, Windows or Linux machine. Reorder or add names (e.g. a .ttf in data/) to
// change it; the console prints which one was picked.
String[] typeFontNames = {
  "Helvetica Neue Bold", "HelveticaNeue-Bold",   // macOS
  "Avenir Next Bold", "AvenirNext-Bold",         // macOS
  "Segoe UI Bold", "SegoeUI-Bold",               // Windows
  "Inter Bold", "Roboto Bold", "DejaVu Sans Bold" // common on Linux
};

String pickTypeFont() {
  java.util.HashSet<String> installed = new java.util.HashSet<String>(java.util.Arrays.asList(PFont.list()));
  for (String name : typeFontNames) {
    if (installed.contains(name)) {
      println("Type field font: " + name);
      return name;
    }
  }
  println("Type field font: none of typeFontNames installed - using the generic bold sans-serif");
  return "SansSerif.bold";
}
final float CAP_HEIGHT = 0.72;          // cap height as a fraction of font size (Helvetica/Arial bold) - for vertical centring
float typeCellFill = 1.0;               // fraction of letter cells filled (1 = the whole canvas)
float typeLetterScale = 0.62;           // letter size as a fraction of what would fill its cell - the rest is breathing space
float typeAlphaMin = 0.25, typeAlphaMax = 1.0; // each letter gets its own random opacity in this range
float typeVineCell = 44;                // min spacing between vines rooted on letter outlines (logical px)
float typeVineKeepProb = 0.3;
color typeInk;

class TypeCell {
  float cx, cy;
  String ch; // one letter
  int rot;   // quarter turns
  float alpha; // 0..1 opacity of this letter
  TypeCell(float cx, float cy, String ch, int rot, float alpha) {
    this.cx = cx;
    this.cy = cy;
    this.ch = ch;
    this.rot = rot;
    this.alpha = alpha;
  }
}

// The stream's vocabulary: every entry in the sketch's own CTA lists (the same ones Ad Canopy draws
// from), uppercased, spaces removed and de-duplicated - so the type never says anything the ad layer
// couldn't.
ArrayList<String> ctaVocabulary() {
  String[][] pools = { ctaShop, ctaUrgency, ctaLearn, ctaDiscount, ctaBrand, ctaDigitalScreen, ctaCountdown };
  ArrayList<String> words = new ArrayList<String>();
  for (String[] pool : pools) {
    for (String s : pool) {
      String u = s.toUpperCase().replace(" ", "");
      if (!words.contains(u)) words.add(u);
    }
  }
  return words;
}

ArrayList<TypeCell> typeCells = new ArrayList<TypeCell>();
ArrayList<Plant> typePlants = new ArrayList<Plant>(); // vines rooted on the letters' outlines
PFont typeFont;
float typeSize = 100, typeCellW, typeCellH, typeMargin, typeGut;
int typeCols = 1;
float[] typeCellAlpha = new float[0]; // per grid cell (row * typeCols + col), for the threshold map
PImage typeImg;
int[] typeIdx = new int[0];   // pixel index of every inked letter pixel
byte[] typeThr = new byte[0]; // its erosion threshold: visible while threshold > erosion
byte[] typeA = new byte[0];   // its alpha (the letter's own opacity times the ink's)
int lastErosionKey = -1;

// Ink per edition - sits under the figure, so it's a strong colour rather than a pale one.
color typeInkFor(int ed) {
  switch (ed) {
    case 1: return color(48, 40, 34, 225);   // receipt ink
    case 2: return color(235, 30, 150, 225); // hot pink
    case 3: return color(18, 70, 78, 225);   // dusk teal
    case 4: return color(150, 104, 28, 225); // old gold
    case 5: return color(28, 118, 205, 225); // plastic blue
    default: return color(232, 22, 68, 230); // the drawing's own red lettering
  }
}

// Logical layout of the grid + the vines rooted on it. Called from buildAll(), after everything else,
// so the rest of the garden's random layout is the same as it was before the type layer existed.
void buildTypeGrid() {
  typeCells.clear();
  typePlants.clear();
  float os = S.outScale();
  float m = S.margin / os, gut = S.gutter / os;
  // Rows are set per surface; columns follow from them so the letter cells come out close to square.
  typeCellH = (H - 2 * m - (S.rows - 1) * gut) / S.rows;
  int cols = max(1, round((W - 2 * m + gut) / (typeCellH + gut)));
  typeCellW = (W - 2 * m - (cols - 1) * gut) / cols;
  typeCols = cols;
  typeMargin = m;
  typeGut = gut;
  typeCellAlpha = new float[S.rows * cols];

  // Its own generator, seeded by piece seed AND edition, so each piece gets a different stream of CTAs
  // even though all six share one seed - and the garden's random() stream is left untouched.
  java.util.Random rng = new java.util.Random(sketchSeed * 7919L + editionIndex * 104729L);
  ArrayList<String> vocab = ctaVocabulary();
  StringBuilder stream = new StringBuilder();
  String last = "";
  while (stream.length() < S.rows * cols) {
    String pick = vocab.get(rng.nextInt(vocab.size()));
    if (pick.equals(last)) continue; // never the same CTA twice in a row
    stream.append(pick);
    last = pick;
  }

  int k = 0;
  for (int r = 0; r < S.rows; r++) {
    for (int c = 0; c < cols; c++) {
      String letter = str(stream.charAt(k++));
      if (rng.nextFloat() > typeCellFill) continue;
      // Pools are seen from above by people on every side: letters face every direction there.
      int rot = S.rotateCells ? rng.nextInt(4) : 0;
      float cx = m + c * (typeCellW + gut) + typeCellW * 0.5;
      float cy = m + r * (typeCellH + gut) + typeCellH * 0.5;
      float alpha = typeAlphaMin + rng.nextFloat() * (typeAlphaMax - typeAlphaMin);
      typeCellAlpha[r * cols + c] = alpha;
      typeCells.add(new TypeCell(cx, cy, letter, rot, alpha));
    }
  }
  if (typeCells.isEmpty()) return;

  // One size for every letter, fitted so the widest letter actually used fills its cell, so the field
  // reads as one typeface at one size instead of every letter scaled to fill its own cell.
  textFont(typeFont);
  textSize(100);
  float widest = 0;
  for (TypeCell tc : typeCells) widest = max(widest, textWidth(tc.ch) / 100);
  float boxW = S.rotateCells ? min(typeCellW, typeCellH) : typeCellW;
  float boxH = S.rotateCells ? min(typeCellW, typeCellH) : typeCellH;
  typeSize = min(boxH * 0.9 / CAP_HEIGHT, boxW * 0.92 / max(0.01, widest)) * typeLetterScale;

  // Vines rooted on the letter outlines - the same edge seeding the background contours use, run on the
  // type instead, so the meadow visibly grows out of the words before the words wear away.
  PGraphics lm = createGraphics(W, H);
  lm.beginDraw();
  lm.background(0);
  lm.noStroke();
  lm.fill(255);
  drawTypeCells(lm);
  lm.endDraw();
  ArrayList<PVector> edges = findEdgePoints(lm, 60);
  ArrayList<PVector> chosen = organicSubsample(edges, typeVineCell, typeVineKeepProb);
  for (PVector v : chosen) {
    if (onBody(v.x, v.y)) continue;
    if (v.y < H * skyBand) continue; // nothing roots in the sky - only letters below the horizon carry vines
    Plant p = new Plant(v.x, v.y, typeInk, true);
    p.maxSteps = int(random(25, 75));
    float d = depthScaleAt(v.y); // same foreshortening and haze as the rest of the meadow
    p.depth = d;
    p.stepLen *= d;
    p.sizeScale *= d;
    p.haze = 0.5 * pow(1 - constrain((v.y / H - skyBand) / (1 - skyBand), 0, 1), 1.6);
    typePlants.add(p);
  }
  println("Type cells: " + typeCells.size() + "  Type vines: " + typePlants.size());
}

void drawTypeCells(PGraphics pg) {
  pg.textFont(typeFont);
  pg.textSize(typeSize);
  pg.textAlign(CENTER, BASELINE);
  for (TypeCell tc : typeCells) {
    pg.pushMatrix();
    pg.translate(tc.cx, tc.cy);
    pg.rotate(tc.rot * HALF_PI);
    pg.text(tc.ch, 0, typeSize * CAP_HEIGHT * 0.5);
    pg.popMatrix();
  }
}

// The erosion threshold map at the current layerScale. Each letter pixel's threshold mixes distance from
// the letter's edge (edges go first) with two octaves of noise (so it breaks up organically, not as a
// clean inset), and a fine grain field punches permanent holes for the printed-grunge texture. Noise is
// sampled in LOGICAL coordinates, so preview and full render erode identically.
void buildTypeMap() {
  int w = frame.width, h = frame.height;
  typeImg = createImage(w, h, ARGB);
  typeIdx = new int[0];
  typeThr = new byte[0];
  typeA = new byte[0];
  lastErosionKey = -1;
  if (typeCells.isEmpty()) return;

  PGraphics m = createGraphics(w, h);
  m.beginDraw();
  m.background(0);
  m.noStroke();
  m.fill(255);
  m.scale(layerScale);
  drawTypeCells(m);
  m.endDraw();
  m.loadPixels();

  int x0 = w, y0 = h, x1 = -1, y1 = -1, count = 0;
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      if ((m.pixels[x + y * w] & 0xFF) > 127) {
        count++;
        if (x < x0) x0 = x;
        if (x > x1) x1 = x;
        if (y < y0) y0 = y;
        if (y > y1) y1 = y;
      }
    }
  }
  if (count == 0) return;

  // 3-4 chamfer distance to the nearest non-ink pixel, inside the ink's bounding box only.
  int bw = x1 - x0 + 1, bh = y1 - y0 + 1;
  int[] d = new int[bw * bh];
  int INF = 1 << 28;
  for (int y = 0; y < bh; y++) {
    for (int x = 0; x < bw; x++) {
      d[x + y * bw] = (m.pixels[(x0 + x) + (y0 + y) * w] & 0xFF) > 127 ? INF : 0;
    }
  }
  for (int y = 0; y < bh; y++) {
    for (int x = 0; x < bw; x++) {
      int i = x + y * bw;
      if (d[i] == 0) continue;
      int v = d[i];
      v = min(v, x > 0 ? d[i - 1] + 3 : 3);
      v = min(v, y > 0 ? d[i - bw] + 3 : 3);
      v = min(v, (x > 0 && y > 0) ? d[i - bw - 1] + 4 : 4);
      v = min(v, (x < bw - 1 && y > 0) ? d[i - bw + 1] + 4 : 4);
      d[i] = v;
    }
  }
  for (int y = bh - 1; y >= 0; y--) {
    for (int x = bw - 1; x >= 0; x--) {
      int i = x + y * bw;
      if (d[i] == 0) continue;
      int v = d[i];
      v = min(v, x < bw - 1 ? d[i + 1] + 3 : 3);
      v = min(v, y < bh - 1 ? d[i + bw] + 3 : 3);
      v = min(v, (x < bw - 1 && y < bh - 1) ? d[i + bw + 1] + 4 : 4);
      v = min(v, (x > 0 && y < bh - 1) ? d[i + bw - 1] + 4 : 4);
      d[i] = v;
    }
  }
  m = null;

  // Edge distance saturates at roughly a stroke's half-width, measured in chamfer units (3 per pixel).
  float dMax = typeSize * 0.09 * layerScale * 3;
  typeIdx = new int[count];
  typeThr = new byte[count];
  typeA = new byte[count];
  float inkAlpha = (typeInk >>> 24) / 255.0;
  int k = 0;
  for (int y = 0; y < bh; y++) {
    for (int x = 0; x < bw; x++) {
      int di = d[x + y * bw];
      if (di == 0) continue;
      float lx = (x0 + x) / layerScale, ly = (y0 + y) / layerScale;
      float grain = noise(lx * 0.4 + 300, ly * 0.4 + 300);
      float thr;
      if (grain < 0.3) {
        thr = 0; // permanent grunge hole
      } else {
        float n1 = constrain((noise(lx * 0.010 + 11, ly * 0.010 + 11) - 0.25) / 0.5, 0, 1);
        float n2 = constrain((noise(lx * 0.045 + 77, ly * 0.045 + 77) - 0.25) / 0.5, 0, 1);
        float dn = min(1, di / dMax);
        thr = 0.06 + 0.94 * (0.42 * n1 + 0.28 * n2 + 0.3 * dn);
      }
      // which grid cell this pixel's letter sits in - letters stay inside their cells, so the cell
      // under a pixel is its letter, and its opacity comes from there
      int cc = constrain(floor((lx - typeMargin) / (typeCellW + typeGut)), 0, typeCols - 1);
      int cr = constrain(floor((ly - typeMargin) / (typeCellH + typeGut)), 0, S.rows - 1);
      typeA[k] = (byte) constrain(round(typeCellAlpha[cr * typeCols + cc] * inkAlpha * 255), 0, 255);
      typeIdx[k] = (x0 + x) + (y0 + y) * w;
      typeThr[k] = (byte) constrain(round(thr * 255), 0, 255);
      k++;
    }
  }
}

void updateTypeImage() {
  int ek = constrain(round(erosion * 255), 0, 255);
  if (ek == lastErosionKey) return;
  lastErosionKey = ek;
  int[] px = typeImg.pixels;
  int rgb = typeInk & 0xFFFFFF;
  for (int k = 0; k < typeIdx.length; k++) {
    px[typeIdx[k]] = (typeThr[k] & 0xFF) > ek ? ((typeA[k] & 0xFF) << 24) | rgb : 0;
  }
  typeImg.updatePixels();
}

// ---------------- Drawings ----------------
// Each drawing is loaded once and cached: a 1920px-wide analysis copy (the body mask, plant grid and
// contour detection were all tuned at that size, so densities stay the same however large the source is)
// and a full-resolution keyed copy that is what actually gets drawn - so a 6000px drawing stays sharp
// on the 8640px wall without multiplying the number of plants.
final int ANALYSIS_W = 1920;
HashMap<String, PImage[]> drawingCache = new HashMap<String, PImage[]>();
PImage maskImg; // optional hand-made figure mask (white = figure), at the analysis size

void loadDrawing(String file, String maskFile) {
  PImage[] cached = drawingCache.get(file);
  if (cached == null) {
    PImage full = loadImage(file);
    if (full == null) throw new RuntimeException("Missing data/" + file + " - see data/README.md");
    PImage analysis = full.copy();
    analysis.resize(ANALYSIS_W, 0);
    cached = new PImage[]{ analysis, buildBgImgKeyed(full) };
    drawingCache.put(file, cached);
    println("Loaded " + file + " (" + full.width + "x" + full.height + ")");
  }
  srcImg = cached[0];
  bgImg = cached[0];
  bgImgKeyed = cached[1];
  srcImg.loadPixels();
  maskImg = null;
  if (maskFile != null && maskFile.length() > 0) {
    PImage mk = loadImage(maskFile);
    if (mk == null) throw new RuntimeException("Missing mask data/" + maskFile);
    mk.resize(srcImg.width, srcImg.height);
    mk.loadPixels();
    maskImg = mk;
  }
}

// ---------------- Stills ----------------
// NODE's File Upload also takes PNG at the exact surface size - these are that, and the source for
// documentation images of each piece.

void saveStill(String label) {
  float keep = layerScale;
  layerScale = S.outScale();
  buildLayers();
  composeFrame(frame);
  String filename = "output/occupy_" + S.name + "_" + label + "_seed" + sketchSeed + "_" + timestamp() + ".png";
  frame.save(sketchPath(filename));
  println("Saved " + filename + " (" + frame.width + "x" + frame.height + "px)");
  layerScale = keep;
  buildLayers();
}

// Every piece in this surface's playlist at its final frame (fully grown, fully eroded, everything revealed).
void exportAllStills() {
  int keepSlot = pieceSlot;
  PImage keepPrev = prevFrame;
  prevFrame = null;
  float keep = layerScale;
  layerScale = S.outScale();
  for (int s = 0; s < S.playlist.length; s++) {
    startPiece(s);
    pieceFrame = framesPerPiece() - 1;
    tPiece = pieceFrame / (float) fps;
    stepTimeline();
    composeFrame(frame);
    String filename = "output/occupy_" + S.name + "_" + nf(s + 1, 2) + "_" + editionSlug(editionIndex) + "_seed" + sketchSeed + ".png";
    frame.save(sketchPath(filename));
    println("Saved " + filename + " (" + frame.width + "x" + frame.height + "px)");
  }
  layerScale = keep;
  prevFrame = keepPrev;
  startPiece(keepSlot);
}

// ---------------- ffmpeg ----------------
// Frames are piped straight into ffmpeg as raw RGB - nothing is written to disk per frame (an 8640px PNG
// sequence would run to tens of gigabytes). The master is near-lossless (CRF 12); encode_for_node.sh then
// re-encodes it with a two-pass bitrate that lands just under NODE's 500 MB limit, so the size can be
// tuned without re-rendering.
String ffmpegPath = ""; // set this if ffmpeg isn't found automatically, e.g. "/opt/homebrew/bin/ffmpeg"

String findFfmpeg() {
  if (ffmpegPath.length() > 0) return ffmpegPath;
  String[] candidates = { "/opt/homebrew/bin/ffmpeg", "/usr/local/bin/ffmpeg", "/usr/bin/ffmpeg", "C:\\ffmpeg\\bin\\ffmpeg.exe" };
  for (String c : candidates) {
    java.io.File f = new java.io.File(c);
    if (f.exists() && f.canExecute()) return c;
  }
  try { // last resort: whatever "ffmpeg" resolves to on PATH
    Process p = new ProcessBuilder("ffmpeg", "-version").redirectErrorStream(true).start();
    p.getInputStream().readAllBytes();
    if (p.waitFor() == 0) return "ffmpeg";
  } catch (Exception e) {
  }
  return null;
}

// Frames are handed to a writer thread, so ffmpeg encodes one frame while the sketch draws the next -
// at 8640px, drawing and encoding taking turns wasted about a fifth of the render time.
class FfmpegPipe {
  Process proc;
  java.io.OutputStream out;
  java.util.concurrent.ArrayBlockingQueue<byte[]> free = new java.util.concurrent.ArrayBlockingQueue<byte[]>(3);
  java.util.concurrent.ArrayBlockingQueue<byte[]> full = new java.util.concurrent.ArrayBlockingQueue<byte[]>(3);
  final byte[] DONE = new byte[0];
  Thread writer;
  volatile Exception failure;

  FfmpegPipe(String ffmpeg, String outFile, int w, int h, int fps, String logFile) throws java.io.IOException {
    String[] cmd = {
      ffmpeg, "-y", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", w + "x" + h, "-r", str(fps), "-i", "-",
      "-an", "-c:v", "libx264", "-preset", "fast", "-crf", "12", "-pix_fmt", "yuv420p",
      "-profile:v", "high", "-movflags", "+faststart", outFile
    };
    ProcessBuilder pb = new ProcessBuilder(cmd);
    pb.redirectErrorStream(true);
    pb.redirectOutput(new java.io.File(logFile)); // ffmpeg's log goes to a file so its output buffer never fills and stalls the pipe
    proc = pb.start();
    out = new java.io.BufferedOutputStream(proc.getOutputStream(), 1 << 22);
    for (int i = 0; i < 3; i++) free.add(new byte[w * h * 3]);
    writer = new Thread(new Runnable() {
      public void run() {
        try {
          while (true) {
            byte[] b = full.take();
            if (b == DONE) break;
            out.write(b);
            free.put(b);
          }
        } catch (Exception e) {
          failure = e;
        }
      }
    });
    writer.start();
  }

  void write(PGraphics f) {
    if (failure != null) throw new RuntimeException("ffmpeg stopped accepting frames - see output/ffmpeg_*.log", failure);
    f.loadPixels();
    int[] px = f.pixels;
    try {
      byte[] buf = free.take();
      int j = 0;
      for (int i = 0; i < px.length; i++) {
        int c = px[i];
        buf[j++] = (byte) (c >> 16);
        buf[j++] = (byte) (c >> 8);
        buf[j++] = (byte) c;
      }
      full.put(buf);
    } catch (InterruptedException e) {
      throw new RuntimeException(e);
    }
  }

  void close() {
    try {
      full.put(DONE);
      writer.join();
      out.flush();
      out.close();
      int code = proc.waitFor();
      if (failure != null) println("ffmpeg pipe failed: " + failure.getMessage());
      if (code != 0) println("ffmpeg exited with code " + code + " - see output/ffmpeg_*.log");
    } catch (Exception e) {
      println("Error closing ffmpeg: " + e.getMessage());
    }
  }
}
