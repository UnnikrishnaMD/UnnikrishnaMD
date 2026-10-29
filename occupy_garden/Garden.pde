// ---------------- The garden ----------------
// The plant/vine growth system, species, editions and consumer-culture layer from the original sketch.
// Changes for NODE are marked "NODE:" - mainly: the canvas is the logical W x H of the chosen surface
// (instead of width/height), images are loaded per piece by loadDrawing(), the body texture is built at
// the output resolution, and vines also root on the type grid's letters.

PImage srcImg;   // subject drawing (1920px analysis copy) — drives the main plant grid + colors
PImage bgImg;    // background scene — its edges seed a second layer of creeping vines. NODE: the same artwork as srcImg
// The drawing with its plain white canvas keyed to transparent (see buildBgImgKeyed) - drawn instead of
// bgImg wherever the sky/earth background needs to actually show through. The figure and colorful swirl
// decoration stay opaque and visible (that's the intended painted look), but the plain white canvas
// around them becomes a window onto the sky/earth gradient instead of a flat white field.
// NODE: built from the FULL-resolution drawing, so a large source stays sharp on the wall.
PImage bgImgKeyed;
PGraphics bodyTextureLayer; // soft painterly mottling over the visible body silhouette - see buildBodyTextureLayer

ArrayList<Plant> plants = new ArrayList<Plant>();             // main plants — rooted outside the human figure
ArrayList<Plant> contourPlants = new ArrayList<Plant>();      // sparse vines following the background's contours
ArrayList<Plant> bodyContourPlants = new ArrayList<Plant>();  // vines rooted on the human figure's own silhouette edge
ArrayList<Plant> fillerPlants = new ArrayList<Plant>();       // meadow filler across empty canvas, sized/hazed by depth
boolean[] bodyMask;  // true where a srcImg pixel belongs to the human figure — kept clear of plant roots

// ---------- Color control state ----------
ArrayList<int[]> palettes = new ArrayList<int[]>();
String[] paletteNames;
ArrayList<Integer> customPalette = new ArrayList<Integer>(); // grows as the user samples colors
int colorModeIndex = -1; // -1 = source-image color per plant, 0..palettes.size()-1 = named palette, palettes.size() = Custom
float hueShift = 0;      // degrees
float satMult = 1.0;
float briMult = 1.0;

// ---------- Sampling density (in each image's own pixel space — independent of canvas size) ----------
int stepX = 11, stepY = 20;         // spacing for the main portrait plant grid
float contourCell = 22;             // min spacing between contour-vine roots
float contourKeepProb = 0.5;        // fraction of edge points that actually sprout a vine
float edgeThreshold = 28;           // brightness-gradient threshold for "this is a contour"

// ---------- Human-figure silhouette (kept clear of roots so the body itself stays plant-free) ----------
float bodyContourCell = 10;         // tighter spacing than the background vines, for an accurate outline
float bodyContourKeepProb = 0.75;   // keep most sampled edge points so the silhouette reads clearly
// Approximate face bounding box in srcImg pixel space — vines rooted in here creep onto the figure far
// less often and stay much shorter than elsewhere. NODE: set per piece (Piece.faceZone).
float faceZoneX0 = 170, faceZoneY0 = 190, faceZoneX1 = 470, faceZoneY1 = 490;

// ---------- Image placement — both images fit proportionately in the canvas and move independently of it ----------
// NODE: initial values come from the surface (Surface.figureScale/figureOffsetX/figureOffsetY).
float bgScale = 1.0, bgOffsetX = 0, bgOffsetY = 0;
float srcScale = 1.0, srcOffsetX = 0, srcOffsetY = 0;
int activeTarget = 0; // 0 = background image, 1 = source image (which one arrow keys / scale keys affect)

// ---------- Reproducibility ----------
// Every plant's shape and the whole scene's layout comes from random()/noise() calls seeded here,
// once, before anything is built. Same seed -> identical output, every time -> this is what makes a
// specific piece re-renderable. NODE: set per piece (Piece.seed), or for all pieces with seed=N.
int sketchSeed = 42;

// ---------- Consumer-culture layer ----------
// A second, separable layer drawn on top of the botanical scene above. The plant/flower growth
// engine is untouched; each edition just reads the same flower tips, leaf positions, and vine
// anchors the ecosystem already computed and paints consumer-culture imagery onto them.
int editionIndex = 0; // 0 = original botanical scene, 1-5 = themed overlays
String[] editionNames = {
  "Botanical (original)",
  "Barcode Understory",
  "Logo Bloom",
  "Ad Canopy",
  "Currency Bloom",
  "Plastic Garden"
};
// Bumped every round of edits so a screenshot alone proves which code build produced it - a
// screenshot can't show a file path or a console line, but it CAN show this.
final String BUILD_TAG = "v22-occupy-node";
// Every sway, spin, and drift throughout the sketch is computed from this frozen constant instead of
// frameCount, so the scene holds still at one fixed instant. NODE: kept frozen in the video too - the
// motion is the growth and the eroding type; a swaying meadow at 8640px would cost bitrate the 500 MB
// limit can't spare, and would stop the grown plants from being cached through the hold.
final int stillFrame = 0;
ArrayList<PVector> adPanels = new ArrayList<PVector>();  // static billboard spots for Ad Canopy (x, y, noiseSeed)
ArrayList<PVector> coinDrops = new ArrayList<PVector>(); // drifting coins for Currency Bloom (x, y, noiseSeed)
// Draw-order counter for Currency Bloom's guaranteed-non-repeating symbol/colour assignment (see
// drawCurrencyBloom) - reset at the top of that function every call, so it's identical between the
// live preview and the high-res export pass as long as plants/coinDrops are built once and iterated
// in the same order both times, which buildAll()/buildConsumerLayer() already guarantee.
int currencyDrawCounter = 0;
PFont uiFont; // bold sans-serif for all consumer-layer typography (logical font, so currency glyphs fall back cleanly)

// ---------- Body-mask debug overlay ----------
// Since the mask hue band (isSkinPixel) has to be retuned per source image, this paints exactly
// what the mask currently sees, translucent red over the live scene, so tuning is done by eye
// against the actual artwork rather than by guessing hue numbers blind. Toggle with M.
boolean showBodyMaskDebug = false;
PGraphics bodyMaskDebugLayer;

// Builds a once-off translucent-red overlay of exactly what buildBodyMask() currently detects as
// "figure", positioned the same way srcImg itself would be (via computePlacement). Rebuilt only
// when R or M is pressed, not every frame — this is a tuning aid, not part of the artwork.
void buildBodyMaskDebugLayer() {
  bodyMaskDebugLayer = createGraphics(W, H);
  float[] place = computePlacement(srcImg, srcScale, srcOffsetX, srcOffsetY);
  bodyMaskDebugLayer.beginDraw();
  bodyMaskDebugLayer.clear();
  bodyMaskDebugLayer.noStroke();
  bodyMaskDebugLayer.fill(255, 0, 60, 130);
  float cell = max(1, place[4]); // one rect per source pixel, sized to land exactly on the canvas
  for (int y = 0; y < srcImg.height; y++) {
    for (int x = 0; x < srcImg.width; x++) {
      if (bodyMask[x + y * srcImg.width]) {
        bodyMaskDebugLayer.rect(place[0] + x * place[4], place[1] + y * place[4], cell, cell);
      }
    }
  }
  bodyMaskDebugLayer.endDraw();
}

// Combines every plant category into one list, sorted by root Y (top/far first, bottom/near last),
// so drawing them in this order gives correct front-to-back occlusion across the WHOLE scene - a
// near meadow plant properly overlaps a farther main-grid plant even though they come from different
// lists. Previously each category was drawn as a separate fixed block, so a "near" filler plant could
// still end up visually behind a "far" plant from a different list - this is the actual mechanism
// depth layering needs, beyond just scaling individual plant sizes.
ArrayList<Plant> depthSortedAllPlants() {
  ArrayList<Plant> all = new ArrayList<Plant>();
  all.addAll(fillerPlants);
  all.addAll(plants);
  all.addAll(bodyContourPlants);
  all.addAll(contourPlants);
  all.addAll(typePlants); // NODE: vines rooted on the type grid
  all.sort(new java.util.Comparator<Plant>() {
    public int compare(Plant a, Plant b) {
      return Float.compare(a.path.get(0).y, b.path.get(0).y);
    }
  });
  return all;
}

// ---------------- Image placement ----------------
// "Contain" fit: scales the image to fit inside the canvas without distortion or cropping,
// then applies the user's extra scale/offset on top. Canvas size and image size are never tied together.

float[] computePlacement(PImage im, float userScale, float offX, float offY) {
  float base = min((float) W / im.width, (float) H / im.height);
  float scl = base * userScale;
  float w = im.width * scl;
  float h = im.height * scl;
  float x = (W - w) / 2 + offX;
  float y = (H - h) / 2 + offY;
  return new float[]{x, y, w, h, scl};
}

// ---------------- Plant / vine construction ----------------

float[] srcPlace; // srcImg's canvas placement, cached once per build so onBody() doesn't recompute it per step

// Converts a CANVAS coordinate back into srcImg pixel space and checks the body mask there - this is
// what lets growth treat the figure as a wall (see Plant.canCrossBody) rather than relying only on
// probabilities to keep it mostly, but not reliably, off the body.
boolean onBody(float cx, float cy) {
  int sx = int((cx - srcPlace[0]) / srcPlace[4]);
  int sy = int((cy - srcPlace[1]) / srcPlace[4]);
  return isBody(sx, sy);
}

// Same idea, but against the placement the figure is actually DRAWN with (bgImg/bgPlace, since the
// visible figure on screen is bgImgKeyed) rather than srcImg's growth-avoidance placement. Those two
// placements are independently adjustable (separate scale/offset controls) and can differ - which is
// exactly what let ad panels, checked with the wrong one, land visibly on the body even though their
// seed-time check said they were clear. Ad-panel placement needs THIS one.
boolean onVisibleBody(float cx, float cy) {
  float[] bgPlace = computePlacement(bgImg, bgScale, bgOffsetX, bgOffsetY);
  int sx = int((cx - bgPlace[0]) / bgPlace[4]);
  int sy = int((cy - bgPlace[1]) / bgPlace[4]);
  return isBody(sx, sy);
}

// Rejects a point if it (or a ring of points around it, at the given margin) overlaps the visible
// body - a single center-point check isn't enough once the panel's own rendered width is considered;
// a panel seeded just outside the silhouette edge could still visually straddle onto it.
boolean tooCloseToBody(float cx, float cy, float margin) {
  return onVisibleBody(cx, cy) || onVisibleBody(cx - margin, cy) || onVisibleBody(cx + margin, cy)
      || onVisibleBody(cx, cy - margin) || onVisibleBody(cx, cy + margin);
}

// NODE: the keyed image is built once per drawing in loadDrawing(), and the body texture once per
// layer scale in buildLayers() - neither consumes random(), so the layout is unchanged. Plants start
// unborn; the growth schedule (Compositor.pde) grows them over the piece.
void buildAll() {
  bodyMaskDebugLayer = null; // stale after any rebuild — recomputed lazily next time M is toggled on
  buildBodyMask();
  computeJointIntensity();
  srcPlace = computePlacement(srcImg, srcScale, srcOffsetX, srcOffsetY);
  buildPlants();
  buildBodyContourPlants();
  buildContourPlants();
  buildFillerPlants();
  buildCentralGrowth();
  flowMeadow();
  buildConsumerLayer();
  buildTypeGrid();
  printSpeciesCounts();
}

// Prints exactly how many of each species got built, so "is the variety actually there" is a fact
// to check in the console rather than a guess from looking at a dense, busy canvas.
void printSpeciesCounts() {
  int[] counts = new int[SPECIES.length];
  for (Plant p : plants) counts[p.speciesIndex]++;
  for (Plant p : bodyContourPlants) counts[p.speciesIndex]++;
  for (Plant p : contourPlants) counts[p.speciesIndex]++;
  for (Plant p : fillerPlants) counts[p.speciesIndex]++;
  for (Plant p : typePlants) counts[p.speciesIndex]++;
  println("--- Species counts ---");
  for (int i = 0; i < SPECIES.length; i++) {
    println("  " + SPECIES[i].name + ": " + counts[i]);
  }
}

void forceFullyGrown(ArrayList<Plant> list) {
  for (Plant p : list) {
    int guard = 0;
    while (!isFullyGrown(p) && guard < 10000) { p.grow(); guard++; }
  }
}

boolean isFullyGrown(Plant p) {
  if (!p.grown) return false;
  for (Plant br : p.branches) if (!isFullyGrown(br)) return false;
  return true;
}

void buildPalettes() {
  palettes.add(new int[]{ color(255,183,197), color(255,223,186), color(186,255,201), color(186,225,255), color(221,186,255) }); // Pastel
  palettes.add(new int[]{ color(120,40,10), color(200,90,20), color(230,150,30), color(160,60,15), color(90,30,10) });           // Autumn
  palettes.add(new int[]{ color(255,0,120), color(0,255,200), color(255,230,0), color(120,0,255), color(0,150,255) });          // Neon
  palettes.add(new int[]{ color(20,40,70), color(50,80,120), color(90,120,160), color(140,160,190), color(10,20,40) });         // Ocean
  palettes.add(new int[]{ color(255,94,77), color(255,166,77), color(255,210,120), color(120,60,120), color(60,30,80) });       // Sunset
  paletteNames = new String[]{"Pastel", "Autumn", "Neon", "Ocean", "Sunset"};

  customPalette.add(color(90, 160, 90));
  customPalette.add(color(200, 60, 90));
}

// A pixel counts as "figure" only if it's opaque AND falls near the figure's own fill hue. srcImg is
// a full illustration — a transparent canvas with a colorful swirl/text pattern already drawn behind
// the man — so a plain brightness threshold can't tell his body apart from that decoration or from
// the transparent area (PNG tools can leave arbitrary RGB behind alpha-0 pixels). Instead, this
// SELF-CALIBRATES from the loaded image: the figure is one large solid-fill region, while the swirl
// decoration is thin scattered line strokes in many different hues - so even though swirls are
// numerous, no single swirl hue comes close to matching the figure's total pixel count.
// detectBodyHue() finds whichever hue actually dominates the opaque, saturated pixels, and that's
// almost always the figure regardless of what color it happens to be.
// NODE: a drawing whose figure ISN'T one flat fill can't be found this way - give its Piece a mask
// image instead (white = figure) and that is used directly.
// Press M in the running sketch to see exactly what this catches, painted translucent red.
float bodyHue = -1;             // set by detectBodyHue() in buildBodyMask(), before first use
float bodyHueTolerance = 0.05;  // how close a pixel's hue must be to bodyHue to count as figure

boolean isSkinPixel(color c) {
  if (alpha(c) < 120) return false;
  float[] hsb = Color.RGBtoHSB((int) red(c), (int) green(c), (int) blue(c), null);
  if (hsb[1] < 0.25 || hsb[2] < 0.2) return false; // skip near-white background / near-black outline
  float dh = abs(hsb[0] - bodyHue);
  dh = min(dh, 1 - dh); // hue wraps around (0.0 and 1.0 are the same hue)
  return dh < bodyHueTolerance;
}

boolean inMask(int i) {
  return brightness(maskImg.pixels[i]) > 128;
}

// Scans every opaque, saturated pixel into 60 hue buckets (6 degrees each) and returns the center of
// the most populous one. Run once per buildBodyMask() call, not per-pixel.
// NODE: with a mask, only pixels inside the mask vote - so the body wash still starts from the figure's own hue.
float detectBodyHue() {
  int buckets = 60;
  int[] counts = new int[buckets];
  for (int i = 0; i < srcImg.pixels.length; i++) {
    if (maskImg != null && !inMask(i)) continue;
    color c = srcImg.pixels[i];
    if (alpha(c) < 120) continue;
    float[] hsb = Color.RGBtoHSB((int) red(c), (int) green(c), (int) blue(c), null);
    if (hsb[1] < 0.25 || hsb[2] < 0.2) continue;
    counts[int(hsb[0] * buckets) % buckets]++;
  }
  int best = 0;
  for (int b = 1; b < buckets; b++) if (counts[b] > counts[best]) best = b;
  return (best + 0.5) / buckets;
}

// The body's own pixel bounding box, in srcImg space - used as a stand-in for "which part of the
// body is this" (e.g. torso/hip vs. extremities) without needing hand-guessed coordinates for a
// region I can't actually see the pixels of. bodyAlongT below turns this into a 0..1 position along
// the figure's longest axis.
int bodyMinX = 999999, bodyMaxX = -1, bodyMinY = 999999, bodyMaxY = -1;
color bodyLightTone, bodyDarkTone; // derived from bodyHue - used by buildBodyTextureLayer for a same-family grunge texture

void buildBodyMask() {
  srcImg.loadPixels();
  bodyHue = detectBodyHue();
  println("Detected figure hue: " + nf(bodyHue, 1, 3) + " (0=red, 0.33=green, 0.67=blue)"
          + (maskImg != null ? " - figure taken from the mask image." : " - press M to check it visually."));
  int rgbLight = Color.HSBtoRGB(bodyHue, 0.32, 0.92);
  int rgbDark = Color.HSBtoRGB(bodyHue, 0.8, 0.2);
  bodyLightTone = color((rgbLight >> 16) & 255, (rgbLight >> 8) & 255, rgbLight & 255);
  bodyDarkTone = color((rgbDark >> 16) & 255, (rgbDark >> 8) & 255, rgbDark & 255);
  boolean[] raw = new boolean[srcImg.width * srcImg.height];
  for (int i = 0; i < raw.length; i++) raw[i] = maskImg != null ? inMask(i) : isSkinPixel(srcImg.pixels[i]);

  bodyMask = new boolean[raw.length]; // 3x3 majority vote smooths antialiased edges into a clean silhouette
  bodyMinX = 999999; bodyMaxX = -1; bodyMinY = 999999; bodyMaxY = -1;
  for (int y = 0; y < srcImg.height; y++) {
    for (int x = 0; x < srcImg.width; x++) {
      int count = 0, total = 0;
      for (int dy = -1; dy <= 1; dy++) {
        for (int dx = -1; dx <= 1; dx++) {
          int nx = x + dx, ny = y + dy;
          if (nx < 0 || nx >= srcImg.width || ny < 0 || ny >= srcImg.height) continue;
          total++;
          if (raw[nx + ny * srcImg.width]) count++;
        }
      }
      boolean body = count * 2 >= total;
      bodyMask[x + y * srcImg.width] = body;
      if (body) {
        if (x < bodyMinX) bodyMinX = x;
        if (x > bodyMaxX) bodyMaxX = x;
        if (y < bodyMinY) bodyMinY = y;
        if (y > bodyMaxY) bodyMaxY = y;
      }
    }
  }
  collectSwirlAccents();
}

// 0 at one end of the body's bounding box, 1 at the other, along whichever axis (X or Y) the figure
// spans further - a reclining figure lying diagonally spans further in X, so this tracks roughly
// head-to-feet position without needing hand-identified coordinates for any specific body part.
float bodyAlongT(float x, float y) {
  boolean useX = (bodyMaxX - bodyMinX) >= (bodyMaxY - bodyMinY);
  if (useX) return constrain((x - bodyMinX) / max(1, bodyMaxX - bodyMinX), 0, 1);
  return constrain((y - bodyMinY) / max(1, bodyMaxY - bodyMinY), 0, 1);
}

// "Where are the joints" without any hand-identified coordinates: a limb is locally NARROW at an
// elbow/knee/wrist/ankle/neck compared to the thicker sections on either side of it (forearm,
// thigh, torso). distToEdge is a chamfer distance transform - how far each body pixel sits from the
// nearest non-body pixel, i.e. local half-thickness. jointIntensity then compares that to a coarse
// local average around each pixel: where the local thickness dips well below its surroundings, that
// IS a joint, geometrically, regardless of pose or which specific limb it is.
float[] distToEdge;
float[] jointIntensity;

void computeJointIntensity() {
  int w = srcImg.width, h = srcImg.height;
  float INF = 1e6;
  distToEdge = new float[w * h];
  for (int i = 0; i < w * h; i++) distToEdge[i] = bodyMask[i] ? INF : 0;

  float DIAG = 1.4142f;
  for (int y = 0; y < h; y++) { // forward pass
    for (int x = 0; x < w; x++) {
      int i = x + y * w;
      if (!bodyMask[i]) continue;
      float d = distToEdge[i];
      if (x > 0) d = min(d, distToEdge[i - 1] + 1);
      if (y > 0) d = min(d, distToEdge[i - w] + 1);
      if (x > 0 && y > 0) d = min(d, distToEdge[i - w - 1] + DIAG);
      if (x < w - 1 && y > 0) d = min(d, distToEdge[i - w + 1] + DIAG);
      distToEdge[i] = d;
    }
  }
  for (int y = h - 1; y >= 0; y--) { // backward pass
    for (int x = w - 1; x >= 0; x--) {
      int i = x + y * w;
      if (!bodyMask[i]) continue;
      float d = distToEdge[i];
      if (x < w - 1) d = min(d, distToEdge[i + 1] + 1);
      if (y < h - 1) d = min(d, distToEdge[i + w] + 1);
      if (x < w - 1 && y < h - 1) d = min(d, distToEdge[i + w + 1] + DIAG);
      if (x > 0 && y < h - 1) d = min(d, distToEdge[i + w - 1] + DIAG);
      distToEdge[i] = d;
    }
  }

  // Coarse grid average of distToEdge (limb-scale cells, not finger-scale), smoothed over a 3x3
  // neighborhood of cells - this is "how thick is the body around here in general."
  int cellSize = 24;
  int gw = (w + cellSize - 1) / cellSize, gh = (h + cellSize - 1) / cellSize;
  float[] cellSum = new float[gw * gh];
  int[] cellCount = new int[gw * gh];
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      int i = x + y * w;
      if (!bodyMask[i]) continue;
      int ci = (x / cellSize) + (y / cellSize) * gw;
      cellSum[ci] += distToEdge[i];
      cellCount[ci]++;
    }
  }
  float[] cellAvg = new float[gw * gh];
  for (int i = 0; i < cellAvg.length; i++) cellAvg[i] = cellCount[i] > 0 ? cellSum[i] / cellCount[i] : 0;

  jointIntensity = new float[w * h];
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      int i = x + y * w;
      if (!bodyMask[i]) continue;
      int cx = x / cellSize, cy = y / cellSize;
      float sum = 0;
      int cnt = 0;
      for (int dy = -1; dy <= 1; dy++) {
        for (int dx = -1; dx <= 1; dx++) {
          int nx = cx + dx, ny = cy + dy;
          if (nx < 0 || nx >= gw || ny < 0 || ny >= gh) continue;
          int ci = nx + ny * gw;
          if (cellCount[ci] == 0) continue;
          sum += cellAvg[ci];
          cnt++;
        }
      }
      float localAvg = cnt > 0 ? sum / cnt : distToEdge[i];
      float ratio = localAvg > 0.001 ? distToEdge[i] / localAvg : 1;
      jointIntensity[i] = constrain(1 - ratio, 0, 1); // locally thin relative to its surroundings = joint
    }
  }
}

boolean isBody(int x, int y) {
  if (x < 0 || x >= srcImg.width || y < 0 || y >= srcImg.height) return false;
  return bodyMask[x + y * srcImg.width];
}

// Colors lifted directly from the swirl/text decoration around the figure - opaque, vivid, and
// distinctly NOT the figure's own hue or the pale background. Used by flowerColor() to give some
// blooms an accent color pulled from the artwork itself, rather than everything defaulting to green
// or pink. Requires bodyMask/bodyHue to already be set (called at the end of buildBodyMask()).
ArrayList<Integer> swirlAccents = new ArrayList<Integer>();

void collectSwirlAccents() {
  swirlAccents.clear();
  int tries = 0;
  while (swirlAccents.size() < 24 && tries < 30000) {
    tries++;
    int x = int(random(srcImg.width));
    int y = int(random(srcImg.height));
    color c = srcImg.pixels[x + y * srcImg.width];
    if (alpha(c) < 200 || isBody(x, y)) continue;
    float[] hsb = Color.RGBtoHSB((int) red(c), (int) green(c), (int) blue(c), null);
    if (hsb[1] < 0.45 || hsb[2] < 0.35) continue; // want vivid decoration, not the pale background
    float dh = abs(hsb[0] - bodyHue);
    dh = min(dh, 1 - dh);
    if (dh < bodyHueTolerance * 1.5) continue; // skip anything too close to the figure's own hue
    swirlAccents.add(c);
  }
}

// Keys the drawing's plain white canvas to transparent, leaving only the figure and its colorful swirl
// decoration opaque. Drawing this instead of the raw image is what lets the sky/earth background
// actually be seen - otherwise the white background paints over the entire figure area and nothing
// behind it, however carefully built, is ever visible.
// NODE: takes the full-resolution drawing and returns its keyed copy (called once per drawing).
PImage buildBgImgKeyed(PImage src) {
  src.loadPixels();
  PImage keyed = createImage(src.width, src.height, ARGB);
  keyed.loadPixels();
  float[] hsb = new float[3];
  for (int i = 0; i < src.pixels.length; i++) {
    color c = src.pixels[i];
    Color.RGBtoHSB((c >> 16) & 255, (c >> 8) & 255, c & 255, hsb);
    boolean nearWhite = hsb[2] > 0.9 && hsb[1] < 0.15; // pale, low-saturation canvas background
    keyed.pixels[i] = nearWhite ? color(255, 255, 255, 0) : c;
  }
  keyed.updatePixels();
  return keyed;
}

// A soft, noise-mottled shading pass over exactly the visible body silhouette - coarse and fine
// noise layered together for an organic, painterly variation instead of one flat fill color. Drawn
// after the keyed drawing but before any plant growth, so vines that do cross onto the body (a
// deliberate few - see canCrossBody) render on top of this texture rather than under it.
// Grunge-style mottling in light/dark tones derived from bodyWashColor()'s own per-edition target
// hue (not the original bodyHue) so the shading stays hue-consistent with the wash instead of
// fighting it. Two noise octaves set the coarse patchwork, a high-frequency third layer roughens the
// patch edges (smooth edges read as clouds, not grunge), and jointIntensity (see
// computeJointIntensity) darkens and intensifies the grain specifically at elbows/knees/wrists/
// ankles/neck - anywhere the body is locally narrow relative to its surroundings.
// NODE: built at the current layer scale (preview or full output), not at canvas size and upscaled.
void buildBodyTextureLayer() {
  bodyTextureLayer = createGraphics(frame.width, frame.height);
  bodyTextureLayer.beginDraw();
  bodyTextureLayer.clear();
  bodyTextureLayer.scale(layerScale);
  bodyTextureLayer.noStroke();
  // A genuine full-body wash so the figure's dominant color actually shifts per edition - bold and
  // unmistakable now, not a subtle cast. Edition 0 stays the pure original blue untouched; every
  // other edition gets a genuinely different color FAMILY (bodyWashColor - a decisive target hue,
  // not a partial editionTint pull from blue, which is why the body kept reading as "blue with a
  // tint" everywhere before).
  color washColor = bodyWashColor();
  // lightTone/darkTone (the grunge shading) are derived from the SAME wash hue, which keeps the
  // whole body texture system hue-consistent instead of producing a muddy gray/purple result.
  float[] washHsb = Color.RGBtoHSB((int) red(washColor), (int) green(washColor), (int) blue(washColor), null);
  int lightRgb = Color.HSBtoRGB(washHsb[0], 0.3, 0.94);
  int darkRgb = Color.HSBtoRGB(washHsb[0], 0.75, 0.24);
  color lightTone = color((lightRgb >> 16) & 255, (lightRgb >> 8) & 255, lightRgb & 255);
  color darkTone = color((darkRgb >> 16) & 255, (darkRgb >> 8) & 255, darkRgb & 255);
  // Joint accent tones - dark cerulean and Prussian blue. Deliberately NOT run through the full
  // editionTint() (that has hue-PULL logic per edition, e.g. Barcode drags non-green hues toward
  // sepia/orange, Currency toward warm gold - it would turn this "blue at the joints" into brown on
  // several editions instead of keeping it readable as blue everywhere). jointAccentColor gives each
  // edition its own light drift in hue/sat/bri instead - unique per edition, painterly, still blue.
  color jointCerulean = jointAccentColor(true);
  color jointPrussian = jointAccentColor(false);
  float cell = max(2, srcPlace[4] * 2.2);
  for (int y = 0; y < srcImg.height; y += 2) {
    for (int x = 0; x < srcImg.width; x += 2) {
      int i = x + y * srcImg.width;
      if (!bodyMask[i]) continue;
      float joint = jointIntensity[i]; // 0..1, high at elbows/knees/wrists/ankles/neck
      float coarse = noise(x * 0.02, y * 0.02) - 0.5;
      float mid = noise(x * 0.06 + 900, y * 0.06 + 900) - 0.5;
      float grit = noise(x * 0.32 + 300, y * 0.32 + 300) - 0.5; // high-frequency grain breaks up smooth blob edges
      float shade = coarse * 0.55 + mid * 0.28 + grit * (0.5 + joint * 0.7);
      shade -= joint * 0.4; // biases darker specifically at joints
      color base = shade > 0 ? lightTone : darkTone;
      int alp = int(constrain(abs(shade) * (1.7 + joint * 1.4), 0, 1) * (100 + joint * 65));
      float px = srcPlace[0] + x * srcPlace[4], py = srcPlace[1] + y * srcPlace[4];
      color cellWash = washColor;
      // Logo Bloom's body wash mixes in patches of orange-red on top of the magenta base - both
      // colors reading on the figure, not a single flat hue. Coarse spatial noise (patchy, not
      // per-pixel) picks where the orange-red patches land, same "patch gate" idea as
      // localizedBreak elsewhere in the sketch.
      if (editionIndex == 2) {
        float mixN = noise(x * 0.012 + 5000, y * 0.012 + 5000);
        if (mixN > 0.45) {
          float mixAmt = map(mixN, 0.45, 1, 0.3, 0.85);
          float h2 = lerpHue(washHsb[0], 0.02, mixAmt); // pull from magenta toward orange-red
          int rgb2 = Color.HSBtoRGB(h2, min(1, washHsb[1] * 1.05), min(1, washHsb[2] * 1.1 + 0.06));
          cellWash = color((rgb2 >> 16) & 255, (rgb2 >> 8) & 255, rgb2 & 255);
        }
      }
      // Wash alpha at 205 - at 150 the original blue pixels underneath still showed through enough to
      // muddy the target hue into gray/purple instead of clean terracotta/gold/lavender. This is
      // edition 0-exempt in effect since bodyWashColor() returns bodyHue itself there, so the original
      // figure is unaffected either way.
      bodyTextureLayer.fill(red(cellWash), green(cellWash), blue(cellWash), 205);
      bodyTextureLayer.rect(px, py, cell, cell);
      bodyTextureLayer.fill(red(base), green(base), blue(base), alp);
      bodyTextureLayer.rect(px, py, cell, cell);
      // Dark joint accent restricted to (a) true anatomical joints - neck/knee/wrist/ankle, where the
      // body is locally thin relative to its surroundings (jointIntensity) - PLUS (b) hip/thigh
      // explicitly: a hip is anatomically THICK, not thin, so jointIntensity alone can never flag it.
      // bodyAlongT (head=0..feet=1 along the figure's own measured extent, no hardcoded coordinates)
      // fills that specific gap.
      boolean inFaceZone = x >= faceZoneX0 && x <= faceZoneX1 && y >= faceZoneY0 && y <= faceZoneY1;
      // The figure's decorative hand-drawn curls/linework within the silhouette are inked much
      // darker/less saturated than the flat body-color fill - detecting that directly (self-
      // calibrating, not a guessed region) is what keeps the joint accent off them wherever they
      // appear on the body, not just near the face, without needing hardcoded coordinates for them.
      color srcPixel = srcImg.pixels[i];
      float[] srcHsb = Color.RGBtoHSB((int) red(srcPixel), (int) green(srcPixel), (int) blue(srcPixel), null);
      boolean isLinework = srcHsb[2] < 0.3 || srcHsb[1] < 0.18;
      // Logo Bloom specifically: the figure's own dark hand-drawn linework recolored into bright
      // fluorescent fuchsia, for pop-candy contrast against the violet body wash - reuses the exact
      // same linework detection used above to protect it from the joint accent elsewhere.
      if (editionIndex == 2 && isLinework) {
        color neon = color(255, 20, 190);
        bodyTextureLayer.fill(red(neon), green(neon), blue(neon), 215);
        bodyTextureLayer.rect(px, py, cell, cell);
      }
      float alongT = bodyAlongT(x, y);
      boolean hipThigh = alongT > 0.48 && alongT < 0.78;
      float jointLike = 0;
      if (!inFaceZone && !isLinework) {
        if (joint > 0.55) jointLike = map(joint, 0.55, 1, 0, 1);
        else if (hipThigh) jointLike = 0.3; // a light dusting across hip/thigh, not a solid patch - it's a broad region, not a tight joint spike
      }
      if (jointLike > 0) {
        float jn = noise(x * 0.09 + 1700, y * 0.09 + 1700);
        color jointBase = jn > 0.5 ? jointCerulean : jointPrussian;
        int jAlp = int(jointLike * (70 + abs(grit) * 70));
        bodyTextureLayer.fill(red(jointBase), green(jointBase), blue(jointBase), jAlp);
        bodyTextureLayer.rect(px, py, cell, cell);
      }
    }
  }
  bodyTextureLayer.endDraw();
}

// Scans a window straight up from a root position (in srcImg pixel space) to see whose airspace a
// plant grown there would invade: 0 = open sky, 1 = the figure's body, 2 = the face. Plants grow
// upward, so it's the roots BELOW the figure — not just inside it — that end up covering it.
// Side effect: lastAboveDist holds the pixel distance to the first body hit (999 if none), so
// callers can grow a plant up to just below the figure without ever reaching it.
int lastAboveDist = 999;
float skyBand = 0.28; // NODE: set from the surface - top fraction of the canvas kept as open sky

int regionAbove(int x, int y) {
  lastAboveDist = 999;
  for (int dy = 6; dy <= 150; dy += 8) {
    int yy = y - dy;
    if (yy < 0) break;
    for (int dx = -18; dx <= 18; dx += 9) {
      int xx = x + dx;
      if (isBody(xx, yy)) {
        lastAboveDist = dy;
        if (xx >= faceZoneX0 && xx <= faceZoneX1 && yy >= faceZoneY0 && yy <= faceZoneY1) return 2;
        return 1;
      }
    }
  }
  return 0;
}

void buildPlants() {
  plants.clear();
  float[] place = computePlacement(srcImg, srcScale, srcOffsetX, srcOffsetY);
  for (int y = 0; y < srcImg.height; y += stepY) {
    for (int x = 0; x < srcImg.width; x += stepX) {
      color c = srcImg.pixels[x + y * srcImg.width];
      if (alpha(c) < 120) continue; // only grow where the illustration has content — not on empty transparent canvas
      if (isBody(x, y)) continue;   // keep the human figure itself clear — roots only go in the surrounding space
      // Thin out and shorten plants whose upward growth would blanket the figure, so it stays
      // visible with only scattered patches of overgrowth — and the face clearest of all.
      int above = regionAbove(x, y);
      boolean inFaceRect = x >= faceZoneX0 && x <= faceZoneX1 && y >= faceZoneY0 && y <= faceZoneY1;
      if (inFaceRect && random(1) < 0.85) continue;
      if (above == 2 && random(1) < 0.9) continue;
      if (above == 1 && random(1) < 0.65) continue;
      float cx = place[0] + x * place[4];
      float cy = place[1] + y * place[4];
      // Clumped rather than a uniform grid fill - without this, every valid cell sprouts something
      // and the sheer regularity reads as one repetitive texture instead of a varied meadow, no
      // matter how many species are in the mix. Same depth-of-field cue as the filler meadow: less
      // clumped, and hazed/scaled by distance, so the whole scene reads as one continuous landscape.
      float clump = noise(cx * 0.006, cy * 0.006);
      if (random(1) > lerp(0.22, 0.8, clump)) continue;
      float t = constrain(cy / (float) H, 0, 1); // 0 = far (top), 1 = near (bottom)
      // The upper canvas is sky, not distant meadow - thin it hard so it actually reads as open air
      // rather than the same growth just scaled small.
      if (t < skyBand && random(1) < 0.88) continue; // NODE: skyBand per surface (was 0.28) - lower on the pools so growth reaches higher
      color hazed = lerpColor(c, color(255), max(0, 1 - t) * 0.4);
      // The sparse top/sky band gets a deliberate lift in purple-species odds - with so few plants
      // surviving the sky-thinning above, purple's normal ~10% share of the pool rarely showed up
      // there at all just by chance.
      boolean topPurple = t < 0.3 && random(1) < 0.35;
      Plant p = topPurple ? new Plant(cx, cy, hazed, false, PURPLE_SPECIES[int(random(PURPLE_SPECIES.length))])
                           : new Plant(cx, cy, hazed, false);
      p.sizeScale *= lerp(0.22, 1.3, t); // strong far/near ratio, but capped on the near end so nothing balloons into an oversized blob
      if (above == 2 || inFaceRect) p.maxSteps = int(random(8, 18));
      else if (above == 1) p.maxSteps = int(random(12, 30));
      plants.add(p);
    }
  }
  println("Plants: " + plants.size());
}

// Traces the human figure's own silhouette by walking the body mask's boundary directly — this is the
// "accurate contour recognition" for the body, driven by the actual skin segmentation rather than
// generic image edges (which would also catch the swirl decoration around the man). Only a modest
// fraction of vines creep inward onto the figure — far fewer, and much shorter, over the face zone —
// the rest wander outward as usual, so overall body coverage stays light.
void buildBodyContourPlants() {
  bodyContourPlants.clear();
  ArrayList<PVector> edges = findBodySilhouetteEdges();
  ArrayList<PVector> chosen = organicSubsample(edges, bodyContourCell, bodyContourKeepProb);
  float[] place = computePlacement(srcImg, srcScale, srcOffsetX, srcOffsetY);
  for (PVector v : chosen) {
    // Extreme joints (finger-scale) pack many silhouette edge points into a tiny area - each one
    // sprouting its own flower/tag/badge there used to stack them on top of each other until they
    // fused into one solid blob (the "right hand" complaint). Thin density steeply wherever the
    // body is locally very thin relative to its surroundings, so flowers stay distinct instead.
    int vi = constrain(int(v.x), 0, srcImg.width - 1) + constrain(int(v.y), 0, srcImg.height - 1) * srcImg.width;
    float joint = jointIntensity[vi];
    if (joint > 0.65 && random(1) < map(joint, 0.65, 1, 0.3, 0.88)) continue;
    // Root a short distance OUTSIDE the body, in the ground the edge point sits on, rather than
    // exactly on the boundary pixel itself - rooting right on the silhouette line is what read as
    // "starting from the black edge" instead of growing up from the ground toward the figure.
    float outward = v.z + PI;
    float offsetDist = random(4, 15);
    float rx = v.x + cos(outward) * offsetDist;
    float ry = v.y + sin(outward) * offsetDist;
    if (isBody(int(rx), int(ry))) { rx = v.x; ry = v.y; } // concave-area fallback: offset landed back on the body, just use the edge point

    color c = srcImg.get((int) v.x, (int) v.y);
    float cx = place[0] + rx * place[4];
    float cy = place[1] + ry * place[4];
    boolean inFace = v.x >= faceZoneX0 && v.x <= faceZoneX1 && v.y >= faceZoneY0 && v.y <= faceZoneY1;
    // Thinned much less than before (was dropping half of everything in the face rectangle) - the
    // core eyes/nose/mouth legibility protection is a separate, stronger rule in buildPlants(); this
    // rectangle's edges were also catching the neck/chin/hair-drape fringe, which is exactly what was
    // reported as under-covered, so it no longer needs to sacrifice nearly as much there.
    if (inFace && random(1) < 0.2) continue;
    Plant p = new Plant(cx, cy, c, true);
    p.sizeScale = random(0.55, 0.95);       // sturdier than a background creeper, so it reads on the figure
    p.inwardAngle = v.z; // NODE: kept so flowMeadow() can send more of these onto the body in patches
    p.maxSteps = inFace ? int(random(12, 30)) : int(random(45, 110));
    // Only a small, deliberate fraction of boundary vines are actually permitted to creep onto the
    // body at all (canCrossBody - grow() enforces this as a hard wall for everyone else). This is
    // what keeps on-body coverage feeling like "here and there, randomly" rather than "most vines
    // near the edge eventually reach across it." bodyAlongT approximates head(0)-to-feet(1) position
    // from the body's own measured extent (no hand-guessed coordinates needed): the middle band gets
    // extra coverage (torso/hip), and the band near the far end gets extra too (leg/foot area).
    float alongT = bodyAlongT(v.x, v.y);
    // One smooth, organic curve instead of hard-edged bands - elevated coverage across nearly the
    // whole body, easing down gradually (not a hard step) only right at the very crown, with an
    // extra peak specifically over the loin/crotch transition, plus a joint-intensity-driven bonus -
    // the SAME geometric signal already used for the finger-blob fix (`joint`, computed just above
    // for this exact edge point) - which organically lifts density right at the wrist/ankle/neck/knee
    // articulation points, covering palms and feet by extension without a separate hand-guessed
    // "palm zone."
    float crownEase = constrain(alongT / 0.09, 0, 1);
    float regionBoost = lerp(1.8, 2.8, crownEase * crownEase);
    float loinPeak = constrain(1 - abs(alongT - 0.68) / 0.16, 0, 1);
    regionBoost *= 1 + 0.35 * loinPeak;
    regionBoost += joint * 1.1;
    float inwardChance = (inFace ? 0.05 : 0.2) * regionBoost;
    boolean inward = random(1) < inwardChance;
    if (inward) p.heading = v.z + random(-0.3, 0.3); // aim back toward the body from its new ground position
    p.canCrossBody = inward;
    bodyContourPlants.add(p);
  }
  println("Body contour vines: " + bodyContourPlants.size());
}

// Finds the boundary pixels of the body mask and, for each, the direction pointing back into the
// figure (the reverse of the direction toward its missing/non-body neighbors).
ArrayList<PVector> findBodySilhouetteEdges() {
  ArrayList<PVector> pts = new ArrayList<PVector>();
  for (int y = 1; y < srcImg.height - 1; y++) {
    for (int x = 1; x < srcImg.width - 1; x++) {
      if (!isBody(x, y)) continue;
      boolean edge = !isBody(x + 1, y) || !isBody(x - 1, y) || !isBody(x, y + 1) || !isBody(x, y - 1);
      if (!edge) continue;
      float outDx = 0, outDy = 0;
      if (!isBody(x + 1, y)) outDx += 1;
      if (!isBody(x - 1, y)) outDx -= 1;
      if (!isBody(x, y + 1)) outDy += 1;
      if (!isBody(x, y - 1)) outDy -= 1;
      float inward = (outDx == 0 && outDy == 0) ? random(TWO_PI) : atan2(-outDy, -outDx);
      pts.add(new PVector(x, y, inward));
    }
  }
  return pts;
}

// Detects edges in an image (simple brightness-gradient magnitude), then sparsely and randomly
// seeds small creeping vines along them — so growth traces the scene's shapes without tracing the
// whole outline or blanketing the image.
ArrayList<PVector> findEdgePoints(PImage im, float threshold) {
  im.loadPixels();
  ArrayList<PVector> pts = new ArrayList<PVector>();
  for (int y = 1; y < im.height - 1; y++) {
    for (int x = 1; x < im.width - 1; x++) {
      float gx = brightness(im.pixels[y * im.width + (x + 1)]) - brightness(im.pixels[y * im.width + (x - 1)]);
      float gy = brightness(im.pixels[(y + 1) * im.width + x]) - brightness(im.pixels[(y - 1) * im.width + x]);
      if (sqrt(gx * gx + gy * gy) > threshold) pts.add(new PVector(x, y));
    }
  }
  return pts;
}

// Detects edges in the background image (simple brightness-gradient magnitude), then sparsely and
// randomly seeds small creeping vines along them — so growth traces the scene's shapes without
// tracing the whole outline or blanketing the image.
void buildContourPlants() {
  contourPlants.clear();
  ArrayList<PVector> edges = findEdgePoints(bgImg, edgeThreshold);
  ArrayList<PVector> chosen = organicSubsample(edges, contourCell, contourKeepProb);
  float[] place = computePlacement(bgImg, bgScale, bgOffsetX, bgOffsetY);
  for (PVector v : chosen) {
    color c = bgImg.get((int) v.x, (int) v.y);
    float cx = place[0] + v.x * place[4];
    float cy = place[1] + v.y * place[4];
    contourPlants.add(new Plant(cx, cy, c, true));
  }
  println("Contour vines: " + contourPlants.size());
}

// Fills the otherwise-empty canvas with a meadow of plants, in canvas space, with a simple
// depth-of-field: the higher up the canvas a plant roots, the "farther away" it is — smaller,
// shorter, and hazed toward white — while plants near the bottom edge grow large and saturated
// in front of everything. The figure's airspace keeps the same protection as the main grid.
int fillStepX = 26, fillStepY = 30;

void buildFillerPlants() {
  fillerPlants.clear();
  float[] place = computePlacement(srcImg, srcScale, srcOffsetX, srcOffsetY);
  // The meadow is laid out as drifting clumps, not rows: a low-frequency noise field modulates how
  // likely each cell is to sprout, so growth gathers into organic thickets with looser breathing
  // room between them. Near-foreground cells are denser overall (but still patchy), and the gaps
  // between clumps are what preserve the sense of depth.
  // The grid starts just outside the canvas on the left/right/bottom so foliage overlaps every
  // edge — no bare canvas border anywhere.
  for (float gy = -4; gy < H + 28; gy += fillStepY) {
    for (float gx = -16; gx < W + 16; gx += fillStepX) {
      float px = gx + random(-13, 13);
      float py = gy + random(-13, 13);
      int sx = int((px - place[0]) / place[4]);
      int sy = int((py - place[1]) / place[4]);
      if (isBody(sx, sy)) continue;
      // Under the figure the meadow still grows — filling what would otherwise be a white band —
      // capped (in makeFillerPlant) so it never climbs onto the body; the face keeps a thin apron.
      int above = regionAbove(sx, sy);
      float t = constrain(py / (float) H, 0, 1); // 0 = far (top), 1 = near (bottom)
      float clump = noise(px * 0.005, py * 0.005);    // drifting patches of thick and thin growth
      // The floor of each range is what fills the thin patches; the clump ceiling keeps the
      // thick-and-thin variation that carries the depth of field. The far meadow visibly thins out
      // and opens up bare ground between clumps, not just fades in color, so depth of field reads.
      float density = lerp(0.22, 0.8, clump);
      if (t > 0.78) density = lerp(0.55, 1.1, clump); // fuller up front, still clumped
      else if (t < skyBand + 0.07) density = lerp(0.03, 0.22, clump); // far meadow should visibly thin toward the horizon (NODE: was t < 0.35)
      // NODE: beyond the drawing's left/right edges there are no swirls for contour vines to root on,
      // so on the wide wall the meadow there read as thin grass beside a dense thicket. `open` ramps
      // from 0 at the drawing's edge to 1 a short way out (no hard seam), and thickens, lengthens and
      // enlarges the meadow there so the growth carries across the whole width.
      float open = constrain(max(place[0] - px, px - (place[0] + place[2])) / 220.0, 0, 1);
      density = lerp(density, density * 1.6 + 0.2, open);
      if (above == 0 && random(1) > density) continue;
      if (above == 2 && random(1) < 0.6) continue;
      Plant p = makeFillerPlant(px, py, t, above);
      p.sizeScale *= lerp(0.8, 1.2, clump); // thick patches also grow a touch larger
      p.sizeScale *= lerp(1, 1.2, open);
      p.maxSteps = int(p.maxSteps * lerp(1, 1.9, open));
      fillerPlants.add(p);
    }
  }
  // The top-right corner is deliberately sparse - bare canvas there is exactly what reads as open sky.
  for (float gy = 12; gy < H * 0.3; gy += 26) {
    for (float gx = W * 0.68; gx < W; gx += 22) {
      if (random(1) < lerp(0.65, 0.85, noise(gx * 0.006, gy * 0.006))) continue; // clumped, not uniform
      float px = gx + random(-8, 8);
      float py = gy + random(-9, 9);
      int sx = int((px - place[0]) / place[4]);
      int sy = int((py - place[1]) / place[4]);
      if (isBody(sx, sy)) continue;
      fillerPlants.add(makeFillerPlant(px, py, constrain(py / (float) H + 0.12, 0, 1), regionAbove(sx, sy)));
    }
  }
  println("Filler plants: " + fillerPlants.size());
}

Plant makeFillerPlant(float px, float py, float t, int above) {
  t = constrain(t, 0, 1.1);
  color base = lerpColor(color(70, 120, 60), color(120, 170, 90), random(1));
  if (random(1) < 0.18) base = lerpColor(base, color(205, 120, 145), random(0.6)); // occasional bloom tint
  color hazed = lerpColor(base, color(255), max(0, 1 - t) * 0.5); // atmospheric haze with distance
  // Same top-band purple lift as the main grid (see buildPlants) - the sparse top/sky band rarely
  // rolled a purple species by chance alone.
  boolean topPurple = t < 0.3 && random(1) < 0.35;
  Plant p = topPurple ? new Plant(px, py, hazed, false, PURPLE_SPECIES[int(random(PURPLE_SPECIES.length))])
                       : new Plant(px, py, hazed, false);
  p.sizeScale = random(0.5, 0.9) * lerp(0.15, 1.35, min(t, 1)); // strong far/near ratio, capped near so nothing balloons
  p.maxSteps = int(random(20, 55) * lerp(0.55, 1.6, min(t, 1)));
  // steps ≈ pixels / average step length (~1.25); stop ~12px short of the body edge
  if (above == 1) p.maxSteps = int(constrain((lastAboveDist - 12) / 1.25, 6, p.maxSteps));
  else if (above == 2) p.maxSteps = int(constrain((lastAboveDist - 18) / 1.25, 4, 18));
  p.flowerSize *= lerp(0.5, 1.15, min(t, 1));
  p.isFiller = true;
  // NODE: the meadow wears the same two foliage tones as the vines that cover the figure (the vine
  // species' cerulean and fresh green), and its blooms take their colours from the drawing's own swirl
  // decoration - so the foreground reads as the same growth as the figure's, not a separate ochre field.
  // Chosen by hash, not random(), so the layout itself is unchanged.
  p.toneOverride = hashUnit(p.varietySeed, 401) < 0.5 ? GREEN_CERULEAN : GREEN_FRESH;
  p.usesAccentColor = hashUnit(p.varietySeed, 409) < 0.5; // NODE: half the drawing's own swirl colours, half the full floral palette
  return p;
}

// NODE: the meadow grows wild. Four passes, all hash/noise-driven (no random()), so they never shift the
// rest of the layout:
//  1. The dense growth rooted inside the drawing used to stop at the drawing's rectangle, reading as a
//     square block of plants. Plants in the main grid and on the background contours now thin out
//     towards that rectangle's edges along an irregular, noise-shaped margin, so the thicket's outline
//     is organic instead of a box.
//  2. More of the vines on the figure's outline creep onto the body, in random patches along its
//     contours, so the figure is covered here and there rather than evenly or not at all.
//  3. Growth is wild and upward: every stem wanders about twice as much as its species alone would, and
//     each plant gets its own independent tilt either side of straight up - no shared direction, so the
//     meadow never leans one way across the canvas. More and larger blooms, and half the plants
//     are coloured - stems and leaves.
//  4. The meadow at the bottom of the canvas grows taller, so the growth rises from the ground and
//     washes up around the figure rather than sitting as a band of short grass.
void flowMeadow() {
  // From the ground: nothing roots in the sky. Every plant rooted above the horizon goes, and so do the
  // silhouette vines that sat on TOP of the figure (their way into the body points down) - the body is
  // reached by vines climbing up from its lower and side edges, the way growth covers something lying in
  // a meadow.
  float horizonY = H * skyBand;
  ArrayList[] lists = { plants, contourPlants, fillerPlants, bodyContourPlants };
  for (ArrayList list : lists) {
    for (int i = list.size() - 1; i >= 0; i--) {
      Plant p = (Plant) list.get(i);
      PVector r = p.path.get(0);
      boolean onTopOfBody = list == bodyContourPlants && sin(p.inwardAngle) > 0.45;
      if (r.y < horizonY || onTopOfBody) list.remove(i);
    }
  }

  float rx0 = srcPlace[0], ry0 = srcPlace[1], rx1 = srcPlace[0] + srcPlace[2], ry1 = srcPlace[1] + srcPlace[3];
  float fade = 0.24 * min(srcPlace[2], srcPlace[3]);
  for (int li = 0; li < 2; li++) {
    ArrayList<Plant> list = li == 0 ? plants : contourPlants;
    for (int i = list.size() - 1; i >= 0; i--) {
      Plant p = list.get(i);
      PVector r = p.path.get(0);
      float inside = min(min(r.x - rx0, rx1 - r.x), min(r.y - ry0, ry1 - r.y)); // distance in from the nearest edge
      float wobble = (noise(r.x * 0.004 + 6100, r.y * 0.004 + 6100) - 0.5) * fade * 1.4;
      float keep = constrain((inside + wobble) / fade, 0, 1);
      keep = keep * keep * (3 - 2 * keep);
      if (hashUnit(p.varietySeed, 601) > keep) list.remove(i);
    }
  }

  // Silhouette vines: more of them creep onto the body, in random patches (a coarse noise field over
  // the outline decides where), so the figure gets covered here and there along its own contours
  // while other stretches stay clear. The face keeps its lighter protection.
  for (Plant p : bodyContourPlants) {
    if (p.canCrossBody) continue;
    PVector r = p.path.get(0);
    int sx = int((r.x - srcPlace[0]) / srcPlace[4]), sy = int((r.y - srcPlace[1]) / srcPlace[4]);
    boolean inFace = sx >= faceZoneX0 && sx <= faceZoneX1 && sy >= faceZoneY0 && sy <= faceZoneY1;
    float patch = noise(r.x * 0.008 + 8300, r.y * 0.008 + 8300);
    if (!inFace && patch > 0.36 && hashUnit(p.varietySeed, 701) < 0.95) {
      p.canCrossBody = true;
      p.heading = p.inwardAngle + (hashUnit(p.varietySeed, 709) - 0.5) * 0.6;
      // they climb up from the body's lower and side edges, so they need the length to get over it
      p.maxSteps = int(p.maxSteps * 2.4);
    }
  }

  ArrayList<Plant> all = new ArrayList<Plant>();
  all.addAll(plants);
  all.addAll(contourPlants);
  all.addAll(bodyContourPlants);
  all.addAll(fillerPlants);
  float riseStart = skyBand + 0.27; // where the meadow starts growing taller towards the bottom
  for (Plant p : all) {
    // Wild: every stem wanders about twice as much as its species alone would.
    p.wildness = 1.7 + hashUnit(p.varietySeed, 517) * 0.8;
    // Colour: ~40% more and ~25% larger blooms, and half the plants coloured, stems and leaves.
    if (!p.hasFlower && hashUnit(p.varietySeed, 521) < 0.4) p.hasFlower = true;
    p.flowerSize *= 1.25; // bigger blooms, so the colour reads at wall scale, not only up close
    if (hashUnit(p.varietySeed, 523) < 0.5) p.foliageAccent = int(hashUnit(p.varietySeed, 527) * floralPalette.length) % floralPalette.length;
    if (p.canCrossBody) continue; // aimed onto the body on purpose - keep that heading
    PVector root = p.path.get(0);
    // Up, not all one way: each plant gets its own independent tilt either side of straight up.
    p.heading = -HALF_PI + (hashUnit(p.varietySeed, 509) - 0.5) * 1.1;
    float t = constrain(root.y / (float) H, 0, 1);
    float rise = constrain((t - riseStart) / (1 - riseStart), 0, 1);
    if (p.isFiller) p.maxSteps = int(p.maxSteps * (1 + 0.9 * rise * rise));
    else p.maxSteps = int(p.maxSteps * 1.25);
  }
  applyDepth(plants, true);
  applyDepth(fillerPlants, true);
  applyDepth(contourPlants, false);
  applyDepth(bodyContourPlants, false);

  // Tall risers through the centre: across the drawing's width, a share of the ground plants grow tall
  // enough to climb up through the curl decoration to just below the top edge - longer strides rather
  // than ever more steps, so they stay a reasonable number of segments. Heights vary, so the tops form a
  // ragged canopy rather than a line.
  float topY = H * 0.04;
  for (ArrayList<Plant> list : new ArrayList[]{ plants, contourPlants, fillerPlants }) {
    for (Plant p : list) {
      PVector r = p.path.get(0);
      if (r.x < srcPlace[0] || r.x > srcPlace[0] + srcPlace[2]) continue;
      if (hashUnit(p.varietySeed, 911) > 0.42) continue;
      p.stepLen *= 1.7;
      int needed = int((r.y - topY) / (p.stepLen * 0.62) * lerp(0.55, 1.0, hashUnit(p.varietySeed, 919)));
      p.maxSteps = max(p.maxSteps, min(needed, 650));
    }
  }
}

// NODE: more growth in the centre - underneath and around the body, across the drawing's width, where
// the original meadow was thinnest. Rooted on the ground (below the horizon), skipping the body itself,
// in clumps like the rest of the meadow.
void buildCentralGrowth() {
  float horizonY = H * skyBand;
  int added = 0;
  for (float gy = horizonY + 10; gy < H + 20; gy += 22) {
    for (float gx = srcPlace[0]; gx < srcPlace[0] + srcPlace[2]; gx += 20) {
      float px = gx + random(-10, 10), py = gy + random(-10, 10);
      int sx = int((px - srcPlace[0]) / srcPlace[4]), sy = int((py - srcPlace[1]) / srcPlace[4]);
      if (isBody(sx, sy)) continue;
      float clump = noise(px * 0.006 + 2400, py * 0.006 + 2400);
      if (random(1) > lerp(0.15, 0.75, clump)) continue;
      int above = regionAbove(sx, sy);
      float t = constrain(py / (float) H, 0, 1);
      fillerPlants.add(makeFillerPlant(px, py, t, above));
      added++;
    }
  }
  println("Central growth: " + added);
}

// NODE: foreshortening and aerial perspective. A plant's size on screen follows how far down the canvas
// it roots: about a third of full size just below the horizon, growing smoothly to ~1.65x at the bottom
// edge - its stem length per step (so its height), and for lists that weren't depth-scaled already its
// leaves, blooms and stroke too. Distant plants also fade towards the haze colour, so the meadow recedes
// into the distance instead of reading as one flat layer.
float depthScaleAt(float rootY) {
  float u = constrain((rootY / H - skyBand) / (1 - skyBand), 0, 1); // 0 at the horizon .. 1 at the bottom
  return lerp(0.3, 1.65, pow(u, 1.2));
}

void applyDepth(ArrayList<Plant> list, boolean sizeAlreadyDepthScaled) {
  for (Plant p : list) {
    float y = p.path.get(0).y;
    float d = depthScaleAt(y);
    float u = constrain((y / H - skyBand) / (1 - skyBand), 0, 1);
    p.depth = d;
    p.stepLen *= d;
    if (!sizeAlreadyDepthScaled) p.sizeScale *= d;
    p.haze = 0.62 * pow(1 - u, 1.4);
  }
}

// The near/far split for the meadow: filler plants rooted below this line are "foreground".
boolean isForegroundFiller(Plant p) {
  return p.path.get(0).y >= H * 0.82;
}

ArrayList<PVector> organicSubsample(ArrayList<PVector> pts, float cellSize, float keepProb) {
  HashMap<String, Boolean> seen = new HashMap<String, Boolean>();
  ArrayList<PVector> result = new ArrayList<PVector>();
  for (PVector v : pts) {
    if (random(1) > keepProb) continue;
    String key = int(v.x / cellSize) + "," + int(v.y / cellSize);
    if (seen.containsKey(key)) continue; // caps density per cell so vines scatter naturally, not densely trace the edge
    seen.put(key, true);
    result.add(v);
  }
  return result;
}

// ---------------- Plant species ----------------
// Each species biases the SAME growth algorithm below (heading/noise/branch loop, stem rendering)
// rather than replacing it — species differ in growth form (curl, branch chance, a canopy ramp for
// bushes/trees), leaf silhouette, and flower silhouette. Categories: flower (ground meadow bloom),
// vine (creeper — reuses the existing silhouette/contour vine roles), bush (dense multi-branch,
// no dominant stem), tree (tall trunk-like stem that branches into a canopy near the top).
final int CAT_FLOWER = 0, CAT_VINE = 1, CAT_BUSH = 2, CAT_TREE = 3;
final int LEAF_ROUND = 0, LEAF_BLADE = 1, LEAF_HEART = 2, LEAF_SERRATED = 3, LEAF_COMPOUND = 4,
          LEAF_TREFOIL = 5, LEAF_SPOON = 6;
// 14 distinct flower shapes, plus NONE. Flower shape is rolled independently per plant (see
// Plant.flowerShapeRoll) rather than fixed by species - with only 9 species but 14 shapes, tying
// shape to species would cap variety below what's actually available; this way any flowering plant
// can land on any of the 14, which is what "different shapes, not just different colors/sizes" needs.
final int FLOWER_DAISY = 0, FLOWER_BELL = 1, FLOWER_STAR = 2, FLOWER_UMBEL = 3, FLOWER_SPIKE = 4,
          FLOWER_TRUMPET = 5, FLOWER_POPPY = 6, FLOWER_POM = 7, FLOWER_CROSS = 8, FLOWER_FRINGED = 9,
          FLOWER_TUBECLUSTER = 10, FLOWER_PINWHEEL = 11, FLOWER_RUFFLE = 12, FLOWER_CUP = 13, FLOWER_NONE = 14;
final int FLOWER_SHAPE_COUNT = 14;

// Eight foliage tones - six natural greens plus two purple/violet tones (real foliage colors -
// blackberry bramble, purple basil, heuchera - not just an accent, an actual leaf-color family).
// Each species leans on one for its stem/leaf color, so the palette itself carries variety instead
// of relying on shape alone.
color[] naturalGreens = {
  color(30, 152, 168),  // GREEN_CERULEAN - more saturated/vivid than before
  color(18, 55, 30),    // GREEN_BOTTLE
  color(152, 196, 55),  // GREEN_PARROT
  color(98, 152, 88),   // GREEN_SAGE
  color(34, 84, 55),    // GREEN_FOREST
  color(120, 205, 92),  // GREEN_FRESH
  color(168, 132, 200), // PURPLE_LIGHT
  color(88, 48, 96)     // PURPLE_DARK
};
final int GREEN_CERULEAN = 0, GREEN_BOTTLE = 1, GREEN_PARROT = 2, GREEN_SAGE = 3, GREEN_FOREST = 4,
          GREEN_FRESH = 5, PURPLE_LIGHT = 6, PURPLE_DARK = 7;

class Species {
  String name;
  int category, leafShape, flowerShape, greenTone;
  float curlMul;     // heading wander per step, multiplies the base algorithm's noise delta
  float branchProb;  // chance to spawn a branch at each leaf interval
  float canopyBias;  // extra branch chance as the plant nears full height -> canopy effect on trees/bushes
  float sizeMul, maxStepsMul, flowerChance;

  Species(String name, int category, int leafShape, int flowerShape, int greenTone, float curlMul,
          float branchProb, float canopyBias, float sizeMul, float maxStepsMul, float flowerChance) {
    this.name = name;
    this.category = category;
    this.leafShape = leafShape;
    this.flowerShape = flowerShape;
    this.greenTone = greenTone;
    this.curlMul = curlMul;
    this.branchProb = branchProb;
    this.canopyBias = canopyBias;
    this.sizeMul = sizeMul;
    this.maxStepsMul = maxStepsMul;
    this.flowerChance = flowerChance;
  }
}

// 9 species across the 4 categories - enough variety that no two neighboring plants read as
// identical, without so many that any one species loses its identity in the crowd.
Species[] SPECIES = {
  // Balanced so no one tone dominates - an earlier mix leaned 4 of 9 species (including 2 of the 3
  // most common flower species) cerulean, which produced an overall cerulean cast instead of variety.
  new Species("Meadow Daisy",       CAT_FLOWER, LEAF_ROUND,    FLOWER_DAISY, GREEN_FRESH,    1.0,  0.22, 0.0,  1.0,  1.0,  0.6),
  new Species("Trumpet Bell",       CAT_FLOWER, LEAF_BLADE,    FLOWER_BELL,  PURPLE_LIGHT,   0.8,  0.16, 0.0,  1.05, 1.1,  0.55),
  new Species("Star Bloom",         CAT_FLOWER, LEAF_SERRATED, FLOWER_STAR,  GREEN_SAGE,     1.15, 0.20, 0.0,  0.9,  0.9,  0.6),
  // High curlMul for organic bending/curving stems, so the body-contour vines bend naturally over the figure.
  new Species("Heart-leaf Creeper", CAT_VINE,   LEAF_HEART,    FLOWER_NONE,  GREEN_FRESH,    1.65, 0.12, 0.0,  0.9,  1.0,  0.08),
  new Species("Morning Glory",      CAT_VINE,   LEAF_SPOON,    FLOWER_BELL,  GREEN_CERULEAN, 1.5,  0.14, 0.0,  1.0,  1.1,  0.35),
  new Species("Bramble",            CAT_BUSH,   LEAF_SERRATED, FLOWER_STAR,  PURPLE_DARK,    0.9,  0.28, 0.18, 0.9,  0.6,  0.25),
  new Species("Round Shrub",        CAT_BUSH,   LEAF_TREFOIL,  FLOWER_SPIKE, GREEN_PARROT,   0.85, 0.26, 0.16, 1.0,  0.65, 0.5),
  new Species("Sapling",            CAT_TREE,   LEAF_COMPOUND, FLOWER_UMBEL, GREEN_FOREST,   0.4,  0.14, 0.28, 1.9,  2.1,  0.3),
  new Species("Umbel Sapling",      CAT_TREE,   LEAF_COMPOUND, FLOWER_UMBEL, GREEN_CERULEAN, 0.35, 0.15, 0.3,  2.0,  2.2,  0.4)
};
int[] VINE_SPECIES = { 3, 4 };
int[] PURPLE_SPECIES = { 1, 5 }; // Trumpet Bell (PURPLE_LIGHT), Bramble (PURPLE_DARK)
// Weighted so the meadow reads mostly as flowers, with vines, bushes, and trees as real but smaller
// shares. Vines are kept to ~10% - each vine's long wandering stem covers far more canvas area than
// one compact flower plant, so a bigger share read as "mostly vines, few tiny flowers." Cerulean-toned
// entries (4, 8) appear 3x each, giving the foreground bright green a cool counterweight.
int[] GROUND_SPECIES = { 0, 1, 2, 0, 1, 2, 0, 1, 2, 0, 1, 2, 3, 4, 5, 6, 5, 6, 7, 8, 4, 4, 8, 8 };

int pickSpecies(boolean creeping) {
  if (creeping) return VINE_SPECIES[int(random(VINE_SPECIES.length))];
  return GROUND_SPECIES[int(random(GROUND_SPECIES.length))];
}

// ---------------- Plant class ----------------

class Leaf {
  int attachIndex;
  float angle, size;
  Leaf(int attachIndex, float angle, float size) {
    this.attachIndex = attachIndex;
    this.angle = angle;
    this.size = size;
  }
}

class Plant {
  ArrayList<PVector> path = new ArrayList<PVector>();
  ArrayList<Leaf> leaves = new ArrayList<Leaf>();
  ArrayList<Plant> branches = new ArrayList<Plant>(); // small offshoot stems for extra detail
  color imageColor;
  int paletteSlot;
  int varietySeed;
  int speciesIndex;
  boolean grown = false;
  boolean hasFlower;
  int flowerShapeRoll; // which of the flower shapes this plant's bloom uses - independent of species
  boolean usesAccentColor; // this flower's color is lifted from the artwork's swirl decoration, not the plain sample
  boolean isCreeper;   // true for background-contour vines: smaller and shorter
  boolean isFiller = false; // meadow filler carries motifs more sparsely than the main flora
  boolean canBranch = true; // false on spawned branches, so they don't spawn their own
  boolean canCrossBody = false; // almost always false - see grow(): the body is a wall unless this is set
  float heading, stepLen, sizeScale, noiseOff, swayPhase;
  int maxSteps, leafInterval;
  float flowerSize;
  int petalCount;
  float growStart; // NODE: when this plant starts within its group's growth window (see setupGrowth)
  int growCalls;   // NODE: grow() calls made so far by the growth schedule
  int toneOverride = -1; // NODE: foliage tone (naturalGreens index) used instead of the species' own; -1 = species tone
  float wildness = 1;     // NODE: multiplies the species' curl - how much this stem wanders as it grows
  int foliageAccent = -1; // NODE: floralPalette index this plant's leaves lean towards (-1 = plain green foliage)
  float inwardAngle = 0;  // NODE: for silhouette vines, the direction pointing into the body
  float depth = 1;        // NODE: perspective scale from where it roots - small near the horizon, large up front
  float haze = 0;         // NODE: aerial-perspective haze, 0 up front .. ~0.6 near the horizon
  float curlSign = 1;     // NODE: which way this stem's curl turns (+1/-1) - see grow()

  Plant(float x, float y, color imgCol, boolean creeping) {
    this(x, y, imgCol, creeping, pickSpecies(creeping));
  }

  // Used when spawning a branch off an existing plant, so the branch shares its parent's species
  // instead of rolling an independent (and visually inconsistent) one.
  Plant(float x, float y, color imgCol, boolean creeping, int forcedSpeciesIndex) {
    path.add(new PVector(x, y));
    imageColor = imgCol;
    isCreeper = creeping;
    speciesIndex = forcedSpeciesIndex;
    Species sp = SPECIES[speciesIndex];
    paletteSlot = int(random(100000));
    varietySeed = int(random(100000)); // independent of paletteSlot, so motif-gated plants still vary in color/symbol
    heading = -HALF_PI + random(-0.35, 0.35); // start pointing roughly upward
    stepLen = random(0.9, 1.6);
    sizeScale = (creeping ? random(0.35, 0.55) : random(0.7, 1.3)) * sp.sizeMul;
    noiseOff = random(1000);
    swayPhase = random(TWO_PI);
    maxSteps = int((creeping ? random(18, 55) : random(45, 140)) * sp.maxStepsMul); // "tiny" plants: short, varied lengths
    leafInterval = int(random(5, 10));
    hasFlower = random(1) < (brightness(imgCol) > 150 ? sp.flowerChance : sp.flowerChance * 0.4); // bright areas bloom more often
    flowerShapeRoll = int(random(FLOWER_SHAPE_COUNT));
    usesAccentColor = random(1) < 0.4; // ~40% of flowers pull an accent hue from the swirl decoration instead
    flowerSize = random(8, 15) * (creeping ? 0.7 : 1.0); // small and numerous, not large and few - bright tiny bunches, not oversized graphic blooms
    petalCount = int(random(5, 8));
    // NODE: half the stems curl one way, half the other. noise() averages slightly below 0.5, so a
    // single shared curl direction made every stem drift the same way over its length and the whole
    // meadow lean left; with the sign split, the drift cancels across the meadow. A hash, not random(),
    // so the layout is unchanged.
    curlSign = hashUnit(varietySeed, 811) < 0.5 ? -1 : 1;
  }

  void grow() {
    Species sp = SPECIES[speciesIndex];
    if (!grown) {
      // NODE: the curl is the difference of two noise samples - zero on average, so no stem drifts to one
      // side over its length (a single noise() sample averages a little under 0.5, which tipped every
      // long stem over sideways). A gentle pull back towards vertical, like a plant growing towards the
      // light, keeps the growth going up while it wiggles and curls freely; vines crossing the body get a
      // much weaker pull so they can still travel across it.
      float n = noise(noiseOff) - noise(noiseOff + 517.3);
      // The wander is small per step (noise changes slowly, so a turn persists for many steps) and the
      // pull strong enough to win over it: a stem swings up to roughly 45 degrees off vertical and back,
      // rather than turning until it lies flat along the edge of its cone.
      heading += n * 0.12 * sp.curlMul * wildness * curlSign; // gentle curling, vine-like - species-scaled
      heading += (-HALF_PI - heading) * (canCrossBody ? 0.03 : 0.06);
      heading = constrain(heading, -PI * 0.95, -PI * 0.05); // keep it swaying within an upward cone
      noiseOff += 0.015;

      PVector last = path.get(path.size() - 1);
      float nx = last.x + cos(heading) * stepLen;
      float ny = last.y + sin(heading) * stepLen;

      // The figure is a wall: growth stops right at its edge instead of crossing onto it, UNLESS
      // this specific plant was deliberately granted permission to creep on (a small, controlled
      // fraction of body-contour vines - see buildBodyContourPlants). This is what keeps coverage on
      // the body sparse and intentional rather than "however many stems happened to reach that far."
      if (!canCrossBody && srcPlace != null && onBody(nx, ny)) {
        grown = true;
      } else {
        path.add(new PVector(nx, ny));

        if (path.size() % leafInterval == 0 && path.size() > 4) {
          int side = (leaves.size() % 2 == 0) ? 1 : -1;
          float leafAngle = heading + side * (HALF_PI * 0.7 + random(-0.2, 0.2));
          leaves.add(new Leaf(path.size() - 1, leafAngle, random(6, 11))); // small, intricate leaves - shape still reads at this scale, just not oversized

          // Branch chance ramps up as the plant nears full height (canopyBias) - on trees and bushes
          // this is what turns a straight-ish trunk into a branching canopy near the top, without any
          // change to the underlying grow loop itself.
          float growthT = path.size() / (float) maxSteps;
          float branchChance = sp.branchProb + sp.canopyBias * growthT;
          if (canBranch && random(1) < branchChance) {
            PVector base = path.get(path.size() - 1);
            Plant br = new Plant(base.x, base.y, imageColor, isCreeper, speciesIndex);
            br.canBranch = false;
            br.canCrossBody = canCrossBody; // inherit - a branch off a body-permitted vine may also touch it
            br.toneOverride = toneOverride; // NODE: a branch keeps its parent's foliage tone
            br.wildness = wildness;
            br.stepLen *= depth; // a branch is as far away as its plant
            br.depth = depth;
            br.haze = haze;
            br.foliageAccent = foliageAccent;
            if (isFiller) br.usesAccentColor = usesAccentColor; // NODE: and a meadow branch's bloom keeps its parent's colour source
            br.heading = leafAngle;
            br.sizeScale = sizeScale * random(0.45, 0.65);
            br.maxSteps = int(maxSteps * random(0.3, 0.55));
            branches.add(br);
          }
        }
        if (path.size() >= maxSteps) grown = true;
      }
    }
    for (Plant br : branches) br.grow();
  }

  void display(PGraphics pg) {
    displayStem(pg, this);
    for (Leaf lf : leaves) displayLeaf(pg, this, lf);
    if (hasFlower && grown) displayFlower(pg, this);
    for (Plant br : branches) br.display(pg);
  }
}

// ---------------- Drawing helpers ----------------
// Stems are drawn in weighted bands (rather than one line() per segment) so thousands of tiny
// plants stay fast to render while still tapering from a thicker base to a thin tip.

void displayStem(PGraphics pg, Plant p) {
  int n = p.path.size();
  if (n < 2) return;
  color sc = stemColor(p);
  // NODE: 8 tapering steps (was 5: 3.2 / 2.4 / 1.8 / 1.2 / 0.6) with round joins, so the taper reads
  // as one smooth organic stem rather than visible stepped bands on a curve.
  float[] weights = { 3.2, 2.75, 2.35, 1.95, 1.6, 1.25, 0.9, 0.55 };
  pg.strokeJoin(ROUND);
  pg.strokeCap(ROUND);
  int bands = weights.length;
  int bandSize = max(1, n / bands);
  int idx = 0;
  for (int b = 0; b < bands; b++) {
    int startIdx = idx;
    int endIdx = (b == bands - 1) ? n - 1 : min(n - 1, idx + bandSize);
    pg.noFill();
    pg.stroke(sc);
    pg.strokeWeight(weights[b] * p.sizeScale);
    pg.beginShape();
    for (int i = startIdx; i <= endIdx; i++) {
      PVector v = p.path.get(i);
      pg.vertex(v.x + swayOffset(p, i, n) + jitterOffset(p, i), v.y);
    }
    pg.endShape();
    idx = endIdx;
  }
}

void displayLeaf(PGraphics pg, Plant p, Leaf lf) {
  if (lf.attachIndex >= p.path.size()) return;
  PVector base = p.path.get(lf.attachIndex);
  float sway = swayOffset(p, lf.attachIndex, p.path.size());
  float w = lf.size * p.sizeScale;
  color lc = leafColor(p);
  int shape = SPECIES[p.speciesIndex].leafShape;
  pg.pushMatrix();
  pg.translate(base.x + sway, base.y);
  pg.rotate(lf.angle);
  if (shape == LEAF_COMPOUND) { // fern/frond-like: three small leaflets fanned from the same joint
    for (int k = -1; k <= 1; k++) {
      pg.pushMatrix();
      pg.rotate(k * 0.5);
      drawLeafBlade(pg, w * 0.62, leafAspectFor(LEAF_ROUND), lc);
      pg.popMatrix();
    }
  } else {
    drawLeafBlade(pg, w, leafAspectFor(shape), lc, shape);
  }
  pg.popMatrix();
}

// Every fixed leaf silhouette carries a per-edition multiplier, so BLADE/HEART/SERRATED/SPOON leaves
// reshape per edition too (slimmer for Barcode, plumper for Logo, narrower for Ad Canopy, stiffer for
// Plastic) - each edition's foliage reads as distinctly its own silhouette.
float edLeafAspectMul() {
  switch (editionIndex) {
    case 1: return 0.55;
    case 2: return 1.5;
    case 3: return 0.68;
    case 4: return 1.15;
    case 5: return 1.35;
    default: return 1.0;
  }
}

float leafAspectFor(int shape) {
  float mul = edLeafAspectMul();
  if (shape == LEAF_BLADE) return constrain(0.18 * mul, 0.08, 0.4);      // narrow grass-like blade
  if (shape == LEAF_HEART) return constrain(0.75 * mul, 0.4, 1.0);
  if (shape == LEAF_SERRATED) return constrain(0.55 * mul, 0.3, 0.85);
  if (shape == LEAF_SPOON) return constrain(0.85 * mul, 0.5, 1.0);       // wide, rounded paddle
  return edLeafAspect(); // LEAF_ROUND, LEAF_TREFOIL (drawn from its own geometry) and compound's individual leaflets
}

// Draws one leaf blade at the current transform's origin (the original smooth bezier blade).
void drawLeafBlade(PGraphics pg, float w, float aspect, color lc) {
  float h = w * aspect;
  pg.noStroke();
  pg.fill(lc);
  pg.beginShape();
  pg.vertex(0, 0);
  pg.bezierVertex(w * 0.25, -h * 0.55, w * 0.75, -h * 0.35, w, 0);
  pg.bezierVertex(w * 0.75, h * 0.35, w * 0.25, h * 0.55, 0, 0);
  pg.endShape(CLOSE);
  pg.stroke(lerpColor(lc, color(20, 40, 15), 0.45)); // center vein
  pg.strokeWeight(0.5);
  pg.line(0, 0, w * 0.9, 0);
}

// Overload used directly by LEAF_HEART / LEAF_SERRATED / LEAF_SPOON / LEAF_TREFOIL with their own
// outlines, keeping displayLeaf's dispatch above a single call either way.
void drawLeafBlade(PGraphics pg, float w, float aspect, color lc, int shape) {
  float h = w * aspect;
  if (shape == LEAF_HEART) {
    pg.noStroke();
    pg.fill(lc);
    pg.beginShape();
    pg.vertex(0, 0);
    pg.bezierVertex(-w * 0.12, -h * 0.7, -w * 0.02, -h * 1.05, w * 0.5, -h * 0.5);
    pg.bezierVertex(w * 1.02, -h * 1.05, w * 1.12, -h * 0.7, w, 0);
    pg.bezierVertex(w * 0.75, h * 0.35, w * 0.25, h * 0.55, 0, 0);
    pg.endShape(CLOSE);
    pg.stroke(lerpColor(lc, color(20, 40, 15), 0.45));
    pg.strokeWeight(0.5);
    pg.line(0, 0, w * 0.85, -h * 0.15);
  } else if (shape == LEAF_SERRATED) {
    pg.noStroke();
    pg.fill(lc);
    pg.beginShape();
    pg.vertex(0, 0);
    int teeth = 6;
    for (int i = 1; i <= teeth; i++) {
      float t = i / (float) teeth;
      float bx = w * t;
      float baseY = -h * sin(t * PI);
      float toothY = baseY - h * 0.16 * ((i % 2 == 0) ? 1 : 0.35);
      pg.vertex(bx, toothY);
    }
    pg.bezierVertex(w * 0.75, h * 0.35, w * 0.25, h * 0.55, 0, 0);
    pg.endShape(CLOSE);
    pg.stroke(lerpColor(lc, color(20, 40, 15), 0.45));
    pg.strokeWeight(0.5);
    pg.line(0, 0, w * 0.9, 0);
  } else if (shape == LEAF_SPOON) { // narrow at the base, widening to a rounded paddle tip
    pg.noStroke();
    pg.fill(lc);
    pg.beginShape();
    pg.vertex(0, 0);
    pg.bezierVertex(w * 0.15, -h * 0.15, w * 0.35, -h * 0.55, w * 0.72, -h * 0.5);
    pg.bezierVertex(w * 1.05, -h * 0.42, w * 1.05, h * 0.42, w * 0.72, h * 0.5);
    pg.bezierVertex(w * 0.35, h * 0.55, w * 0.15, h * 0.15, 0, 0);
    pg.endShape(CLOSE);
    pg.stroke(lerpColor(lc, color(20, 40, 15), 0.45));
    pg.strokeWeight(0.5);
    pg.line(0, 0, w * 0.85, 0);
  } else if (shape == LEAF_TREFOIL) { // three fused rounded lobes - clover-like, ONE leaf, not three separate leaflets
    pg.noStroke();
    pg.fill(lc);
    float r = w * 0.34;
    pg.ellipse(w * 0.3, 0, r * 1.8, r * 1.5);
    pg.ellipse(w * 0.62, -r * 0.75, r * 1.6, r * 1.3);
    pg.ellipse(w * 0.62, r * 0.75, r * 1.6, r * 1.3);
    pg.stroke(lerpColor(lc, color(20, 40, 15), 0.45));
    pg.strokeWeight(0.5);
    pg.line(0, 0, w * 0.55, 0);
  } else {
    drawLeafBlade(pg, w, aspect, lc);
  }
}

void displayFlower(PGraphics pg, Plant p) {
  if (SPECIES[p.speciesIndex].flowerShape == FLOWER_NONE) return; // this species is foliage-only, regardless of shape roll
  switch (p.flowerShapeRoll) {
    case FLOWER_BELL: drawBellFlower(pg, p); break;
    case FLOWER_STAR: drawStarFlower(pg, p); break;
    case FLOWER_UMBEL: drawUmbelFlower(pg, p); break;
    case FLOWER_SPIKE: drawSpikeFlower(pg, p); break;
    case FLOWER_TRUMPET: drawTrumpetFlower(pg, p); break;
    case FLOWER_POPPY: drawPoppyFlower(pg, p); break;
    case FLOWER_POM: drawPomFlower(pg, p); break;
    case FLOWER_CROSS: drawCrossFlower(pg, p); break;
    case FLOWER_FRINGED: drawFringedFlower(pg, p); break;
    case FLOWER_TUBECLUSTER: drawTubeClusterFlower(pg, p); break;
    case FLOWER_PINWHEEL: drawPinwheelFlower(pg, p); break;
    case FLOWER_RUFFLE: drawRuffleFlower(pg, p); break;
    case FLOWER_CUP: drawCupFlower(pg, p); break;
    default: drawDaisyFlower(pg, p); break; // FLOWER_DAISY
  }
}

void drawDaisyFlower(PGraphics pg, Plant p) {
  PVector tip = p.path.get(p.path.size() - 1);
  float sway = swayOffset(p, p.path.size() - 1, p.path.size());
  float sz = p.flowerSize * p.sizeScale * edFlowerSizeMul();
  int petals = constrain(p.petalCount + edPetalDelta(), 3, 12);
  float pw = edPetalWidth();
  color outer = flowerColor(p);
  color inner = lerpColor(outer, color(255, 250, 235), 0.4);
  pg.pushMatrix();
  pg.translate(tip.x + sway, tip.y);
  pg.noStroke();
  for (int k = 0; k < petals; k++) {
    pg.pushMatrix();
    pg.rotate(TWO_PI / petals * k + stillFrame * 0.01 + p.swayPhase);
    pg.fill(outer);
    drawPetal(pg, sz * 0.75, sz * 0.34 * pw);
    pg.popMatrix();
  }
  for (int k = 0; k < petals; k++) { // inner ring, smaller and offset, for depth
    pg.pushMatrix();
    pg.rotate(TWO_PI / petals * (k + 0.5) + stillFrame * 0.01 + p.swayPhase);
    pg.fill(inner);
    drawPetal(pg, sz * 0.42, sz * 0.2 * pw);
    pg.popMatrix();
  }
  pg.fill(90, 70, 20);
  for (int j = 0; j < 6; j++) {
    float a = TWO_PI / 6 * j;
    pg.ellipse(cos(a) * sz * 0.12, sin(a) * sz * 0.12, sz * 0.08, sz * 0.08); // stamens
  }
  pg.fill(120, 90, 25);
  pg.ellipse(0, 0, sz * 0.3, sz * 0.3);
  pg.popMatrix();
}

// Single drooping cup, e.g. a foxglove/campanula bell rather than a radial daisy.
void drawBellFlower(PGraphics pg, Plant p) {
  PVector tip = p.path.get(p.path.size() - 1);
  float sway = swayOffset(p, p.path.size() - 1, p.path.size());
  float sz = p.flowerSize * p.sizeScale * edFlowerSizeMul();
  color outer = flowerColor(p);
  color inner = lerpColor(outer, color(255, 250, 235), 0.35);
  pg.pushMatrix();
  pg.translate(tip.x + sway, tip.y);
  pg.rotate(sin(stillFrame * 0.02 + p.swayPhase) * 0.15 + 0.25); // droops to one side
  pg.noStroke();
  pg.fill(outer);
  pg.beginShape();
  pg.vertex(-sz * 0.35, 0);
  pg.bezierVertex(-sz * 0.55, sz * 0.5, -sz * 0.3, sz * 1.05, 0, sz * 1.15);
  pg.bezierVertex(sz * 0.3, sz * 1.05, sz * 0.55, sz * 0.5, sz * 0.35, 0);
  pg.bezierVertex(sz * 0.15, sz * 0.12, -sz * 0.15, sz * 0.12, -sz * 0.35, 0);
  pg.endShape(CLOSE);
  pg.fill(inner);
  pg.ellipse(0, sz * 0.75, sz * 0.35, sz * 0.35);
  pg.popMatrix();
}

// Few, sharp, pointed petals - a spikier bloom than the daisy.
void drawStarFlower(PGraphics pg, Plant p) {
  PVector tip = p.path.get(p.path.size() - 1);
  float sway = swayOffset(p, p.path.size() - 1, p.path.size());
  float sz = p.flowerSize * p.sizeScale * edFlowerSizeMul();
  int petals = constrain(p.petalCount - 2, 4, 6);
  color outer = flowerColor(p);
  pg.pushMatrix();
  pg.translate(tip.x + sway, tip.y);
  pg.rotate(stillFrame * 0.006 + p.swayPhase);
  pg.noStroke();
  pg.fill(outer);
  pg.beginShape();
  for (int k = 0; k < petals * 2; k++) {
    float r = (k % 2 == 0) ? sz * 0.7 : sz * 0.34; // softer points - less spiky/artificial
    float a = TWO_PI / (petals * 2) * k;
    pg.vertex(cos(a) * r, sin(a) * r);
  }
  pg.endShape(CLOSE);
  pg.fill(120, 90, 25);
  pg.ellipse(0, 0, sz * 0.22, sz * 0.22);
  pg.popMatrix();
}

// A small cluster of miniature daisies radiating from one point, like Queen Anne's lace.
void drawUmbelFlower(PGraphics pg, Plant p) {
  PVector tip = p.path.get(p.path.size() - 1);
  float sway = swayOffset(p, p.path.size() - 1, p.path.size());
  float sz = p.flowerSize * p.sizeScale * edFlowerSizeMul() * 0.5;
  int florets = constrain(p.petalCount - 1, 4, 7);
  color outer = flowerColor(p);
  pg.pushMatrix();
  pg.translate(tip.x + sway, tip.y);
  for (int f = 0; f < florets; f++) {
    float a = TWO_PI / florets * f + p.varietySeed * 0.01;
    float r = sz * 0.9;
    pg.pushMatrix();
    pg.translate(cos(a) * r, sin(a) * r * 0.6 - sz * 0.3);
    pg.noStroke();
    pg.fill(outer);
    for (int k = 0; k < 5; k++) {
      pg.pushMatrix();
      pg.rotate(TWO_PI / 5 * k);
      drawPetal(pg, sz * 0.55, sz * 0.24);
      pg.popMatrix();
    }
    pg.fill(120, 90, 25);
    pg.ellipse(0, 0, sz * 0.25, sz * 0.25);
    pg.popMatrix();
  }
  pg.popMatrix();
}

// A cluster of small buds strung down the last stretch of stem instead of one bloom at the tip -
// e.g. foxglove/lavender-style flower spikes.
void drawSpikeFlower(PGraphics pg, Plant p) {
  int n = p.path.size();
  int buds = constrain(p.petalCount - 2, 3, 6);
  color outer = flowerColor(p);
  float sz = p.flowerSize * p.sizeScale * edFlowerSizeMul() * 0.55;
  for (int b = 0; b < buds; b++) {
    int idx = max(0, n - 1 - b * 3);
    PVector pos = p.path.get(idx);
    float sway = swayOffset(p, idx, n);
    float budSz = sz * (1.0 - b * 0.12);
    pg.pushMatrix();
    pg.translate(pos.x + sway, pos.y);
    pg.noStroke();
    pg.fill(outer);
    pg.ellipse(budSz * 0.4, -budSz * 0.3, budSz * 0.7, budSz * 0.9);
    pg.popMatrix();
  }
}

// A single wide-mouthed funnel facing outward/upward (lily/trumpet-vine style) - distinct from the
// drooping BELL by opening in the direction of growth rather than hanging to one side.
void drawTrumpetFlower(PGraphics pg, Plant p) {
  PVector tip = p.path.get(p.path.size() - 1);
  float sway = swayOffset(p, p.path.size() - 1, p.path.size());
  float sz = p.flowerSize * p.sizeScale * edFlowerSizeMul();
  color outer = flowerColor(p);
  color inner = lerpColor(outer, color(255, 250, 235), 0.4);
  pg.pushMatrix();
  pg.translate(tip.x + sway, tip.y);
  pg.rotate(sin(stillFrame * 0.015 + p.swayPhase) * 0.1);
  pg.noStroke();
  pg.fill(outer);
  pg.beginShape();
  pg.vertex(0, 0);
  pg.bezierVertex(-sz * 0.5, -sz * 0.3, -sz * 0.8, -sz * 0.85, 0, -sz * 1.05);
  pg.bezierVertex(sz * 0.8, -sz * 0.85, sz * 0.5, -sz * 0.3, 0, 0);
  pg.endShape(CLOSE);
  pg.fill(inner);
  pg.ellipse(0, -sz * 0.18, sz * 0.32, sz * 0.32);
  pg.popMatrix();
}

// Four large soft overlapping rounded petals with a dark seed-pod center - poppy/anemone style.
void drawPoppyFlower(PGraphics pg, Plant p) {
  PVector tip = p.path.get(p.path.size() - 1);
  float sway = swayOffset(p, p.path.size() - 1, p.path.size());
  float sz = p.flowerSize * p.sizeScale * edFlowerSizeMul();
  color outer = flowerColor(p);
  pg.pushMatrix();
  pg.translate(tip.x + sway, tip.y);
  pg.noStroke();
  pg.fill(outer);
  // Petals sized and offset so they stay as 4 distinct overlapping ovals, not a single fused disc.
  for (int k = 0; k < 4; k++) {
    pg.pushMatrix();
    pg.rotate(HALF_PI * k + QUARTER_PI * 0.5 + p.swayPhase * 0.2);
    pg.ellipse(sz * 0.42, 0, sz * 0.5, sz * 0.32);
    pg.popMatrix();
  }
  pg.fill(35, 24, 14);
  pg.ellipse(0, 0, sz * 0.22, sz * 0.22);
  pg.fill(15, 10, 6);
  for (int j = 0; j < 8; j++) {
    float a = TWO_PI / 8 * j;
    pg.ellipse(cos(a) * sz * 0.13, sin(a) * sz * 0.13, sz * 0.05, sz * 0.05);
  }
  pg.popMatrix();
}

// A dense round pom-pom of many small petal-dots - dahlia/mum style, deliberately fuller and rounder
// than the open radial DAISY.
void drawPomFlower(PGraphics pg, Plant p) {
  PVector tip = p.path.get(p.path.size() - 1);
  float sway = swayOffset(p, p.path.size() - 1, p.path.size());
  float sz = p.flowerSize * p.sizeScale * edFlowerSizeMul();
  color outer = flowerColor(p);
  color inner = lerpColor(outer, color(255, 250, 235), 0.3);
  pg.pushMatrix();
  pg.translate(tip.x + sway, tip.y);
  pg.noStroke();
  int n = 22;
  for (int i = 0; i < n; i++) {
    float a = TWO_PI / n * i + p.swayPhase;
    float rJitter = 0.65 + 0.35 * noise(p.varietySeed * 0.011 + i * 0.3);
    float r = sz * 0.5 * rJitter;
    pg.pushMatrix();
    pg.rotate(a);
    pg.translate(r, 0);
    pg.fill(i % 2 == 0 ? outer : inner);
    pg.ellipse(0, 0, sz * 0.24, sz * 0.12);
    pg.popMatrix();
  }
  pg.fill(outer);
  pg.ellipse(0, 0, sz * 0.32, sz * 0.32);
  pg.popMatrix();
}

// A small, plain 4-petal wildflower - phlox/forget-me-not style. Deliberately the simplest,
// smallest shape in the set, for contrast against the fuller blooms.
void drawCrossFlower(PGraphics pg, Plant p) {
  PVector tip = p.path.get(p.path.size() - 1);
  float sway = swayOffset(p, p.path.size() - 1, p.path.size());
  float sz = p.flowerSize * p.sizeScale * edFlowerSizeMul() * 0.65;
  color outer = flowerColor(p);
  pg.pushMatrix();
  pg.translate(tip.x + sway, tip.y);
  pg.noStroke();
  pg.fill(outer);
  for (int k = 0; k < 4; k++) {
    pg.pushMatrix();
    pg.rotate(HALF_PI * k + stillFrame * 0.01 + p.swayPhase);
    drawPetal(pg, sz * 0.6, sz * 0.3);
    pg.popMatrix();
  }
  pg.fill(120, 90, 25);
  pg.ellipse(0, 0, sz * 0.16, sz * 0.16);
  pg.popMatrix();
}

// Many thin, spiky rays rather than a few broad petals - carnation/aster-fringe style, distinct from
// the sharper but fewer-pointed STAR.
void drawFringedFlower(PGraphics pg, Plant p) {
  PVector tip = p.path.get(p.path.size() - 1);
  float sway = swayOffset(p, p.path.size() - 1, p.path.size());
  float sz = p.flowerSize * p.sizeScale * edFlowerSizeMul();
  color outer = flowerColor(p);
  pg.pushMatrix();
  pg.translate(tip.x + sway, tip.y);
  pg.noStroke();
  int spikes = 11;
  for (int k = 0; k < spikes; k++) {
    pg.pushMatrix();
    pg.rotate(TWO_PI / spikes * k + stillFrame * 0.006 + p.swayPhase);
    pg.fill(outer);
    drawPetal(pg, sz * 0.62, sz * 0.16); // softer/shorter rays - less sharp and artificial
    pg.popMatrix();
  }
  pg.fill(90, 70, 20);
  pg.ellipse(0, 0, sz * 0.22, sz * 0.22);
  pg.popMatrix();
}

// A tight cluster of small tube-shaped florets - verbena/lantana style, distinct from UMBEL's mini
// daisies by using simple elongated capsules instead.
void drawTubeClusterFlower(PGraphics pg, Plant p) {
  PVector tip = p.path.get(p.path.size() - 1);
  float sway = swayOffset(p, p.path.size() - 1, p.path.size());
  float sz = p.flowerSize * p.sizeScale * edFlowerSizeMul() * 0.55;
  int florets = constrain(p.petalCount, 5, 9);
  color outer = flowerColor(p);
  pg.pushMatrix();
  pg.translate(tip.x + sway, tip.y);
  pg.noStroke();
  pg.fill(outer);
  for (int f = 0; f < florets; f++) {
    float a = TWO_PI / florets * f + p.varietySeed * 0.01;
    float r = sz * 0.55;
    pg.pushMatrix();
    pg.translate(cos(a) * r, sin(a) * r * 0.7);
    pg.rotate(a);
    pg.ellipse(0, 0, sz * 0.5, sz * 0.18);
    pg.popMatrix();
  }
  pg.popMatrix();
}

// Asymmetric curved petals that all twist the same direction - periwinkle/vinca-pinwheel style,
// distinct from the symmetric daisy/star petals used elsewhere.
void drawPinwheelFlower(PGraphics pg, Plant p) {
  PVector tip = p.path.get(p.path.size() - 1);
  float sway = swayOffset(p, p.path.size() - 1, p.path.size());
  float sz = p.flowerSize * p.sizeScale * edFlowerSizeMul();
  color outer = flowerColor(p);
  color inner = lerpColor(outer, color(255, 250, 235), 0.35);
  int petals = 5;
  pg.pushMatrix();
  pg.translate(tip.x + sway, tip.y);
  pg.noStroke();
  pg.fill(outer);
  for (int k = 0; k < petals; k++) {
    pg.pushMatrix();
    pg.rotate(TWO_PI / petals * k + stillFrame * 0.01 + p.swayPhase);
    pg.beginShape();
    pg.vertex(0, 0);
    pg.bezierVertex(sz * 0.55, -sz * 0.08, sz * 0.8, sz * 0.22, sz * 0.45, sz * 0.55);
    pg.bezierVertex(sz * 0.22, sz * 0.35, sz * 0.08, sz * 0.15, 0, 0);
    pg.endShape(CLOSE);
    pg.popMatrix();
  }
  pg.fill(inner);
  pg.ellipse(0, 0, sz * 0.22, sz * 0.22);
  pg.popMatrix();
}

// A round bloom with a wavy, ruffled outer edge - peony/ranunculus style, softer and fuller than
// the sharp-pointed STAR or the plain round POM.
void drawRuffleFlower(PGraphics pg, Plant p) {
  PVector tip = p.path.get(p.path.size() - 1);
  float sway = swayOffset(p, p.path.size() - 1, p.path.size());
  float sz = p.flowerSize * p.sizeScale * edFlowerSizeMul();
  color outer = flowerColor(p);
  color inner = lerpColor(outer, color(255, 250, 235), 0.35);
  pg.pushMatrix();
  pg.translate(tip.x + sway, tip.y);
  pg.noStroke();
  pg.fill(outer);
  int waves = 9;
  pg.beginShape();
  for (int i = 0; i <= waves * 3; i++) {
    float a = TWO_PI / (waves * 3) * i;
    float r = sz * 0.5 * (1 + 0.16 * sin(a * waves + p.varietySeed));
    pg.vertex(cos(a) * r, sin(a) * r);
  }
  pg.endShape(CLOSE);
  pg.fill(inner);
  pg.ellipse(0, 0, sz * 0.3, sz * 0.3);
  pg.popMatrix();
}

// A small, plain open cup/bowl - buttercup style. The simplest, most understated shape in the set,
// for contrast against the fuller/spikier blooms.
void drawCupFlower(PGraphics pg, Plant p) {
  PVector tip = p.path.get(p.path.size() - 1);
  float sway = swayOffset(p, p.path.size() - 1, p.path.size());
  float sz = p.flowerSize * p.sizeScale * edFlowerSizeMul() * 0.85;
  color outer = flowerColor(p);
  pg.pushMatrix();
  pg.translate(tip.x + sway, tip.y);
  pg.noStroke();
  pg.fill(outer);
  int petals = 5;
  for (int k = 0; k < petals; k++) {
    pg.pushMatrix();
    pg.rotate(TWO_PI / petals * k + p.swayPhase);
    pg.ellipse(sz * 0.22, 0, sz * 0.42, sz * 0.3);
    pg.popMatrix();
  }
  pg.fill(120, 90, 25);
  pg.ellipse(0, 0, sz * 0.18, sz * 0.18);
  pg.popMatrix();
}

void drawPetal(PGraphics pg, float len, float wid) {
  pg.beginShape();
  pg.vertex(0, 0);
  pg.bezierVertex(len * 0.25, -wid * 0.6, len * 0.75, -wid * 0.5, len, 0);
  pg.bezierVertex(len * 0.75, wid * 0.5, len * 0.25, wid * 0.6, 0, 0);
  pg.endShape(CLOSE);
}

float swayOffset(Plant p, int i, int n) {
  float t = (float) i / max(1, n - 1);
  float amt = pow(t, 1.5) * 3.0; // more movement near the tip, root stays anchored
  return sin(stillFrame * 0.03 + p.swayPhase + i * 0.08) * amt * edSwayMul();
}

float jitterOffset(Plant p, int i) {
  return (noise(p.noiseOff + i * 0.2) - 0.5) * 1.4 * p.sizeScale; // fine per-segment wobble for a hand-drawn feel
}

// ---------------- Color logic ----------------

color getBaseSourceColor(Plant p) {
  if (colorModeIndex == -1) return p.imageColor;
  if (colorModeIndex == palettes.size()) return customPalette.get(p.paletteSlot % customPalette.size());
  int[] pal = palettes.get(colorModeIndex);
  return pal[p.paletteSlot % pal.length];
}

color shiftColor(color c) {
  float[] hsb = Color.RGBtoHSB((int) red(c), (int) green(c), (int) blue(c), null);
  float h = hsb[0] + hueShift / 360.0;
  h = h - floor(h);
  float s = constrain(hsb[1] * satMult, 0, 1);
  float b = constrain(hsb[2] * briMult, 0, 1);
  int rgb = Color.HSBtoRGB(h, s, b);
  return color((rgb >> 16) & 255, (rgb >> 8) & 255, rgb & 255);
}

// Nudges a base tone's hue/saturation/brightness by a small, per-plant deterministic amount (seeded
// from the plant's own paletteSlot) so plants sharing a species green aren't perfectly flat/identical
// - real foliage varies in tonal value even within one species.
color jitterTone(color c, int seed) {
  float[] hsb = Color.RGBtoHSB((int) red(c), (int) green(c), (int) blue(c), null);
  // hashUnit instead of noise() - noise() clusters near the middle of its output range, which meant
  // this "per-plant variance" was landing on nearly the same small nudge for every plant instead of
  // genuinely spreading across its full jitter range.
  float jH = (hashUnit(seed, 2) - 0.5) * 0.05;
  // Biased to lift rather than dull - the depth haze elsewhere already pulls distant plants toward
  // pale/white, so this jitter doesn't need to be symmetric; skewing positive keeps greens reading
  // as fresh instead of compounding into a general grayish murk.
  float jS = map(hashUnit(seed, 3), 0, 1, -0.05, 0.2);
  float jB = map(hashUnit(seed, 4), 0, 1, -0.08, 0.18);
  int rgb = Color.HSBtoRGB(hsb[0] + jH, constrain(hsb[1] + jS, 0.3, 1), constrain(hsb[2] + jB, 0.25, 1));
  return color((rgb >> 16) & 255, (rgb >> 8) & 255, rgb & 255);
}

// Most of the canvas keeps each edition's base cast; a noise field carves out patches (spatially
// coherent, not per-pixel noise) that lean toward a deliberate contrasting/complementary hue instead,
// breaking up the uniformity of a flat wash.
color localizedBreak(color c, float px, float py) {
  if (editionIndex < 1 || editionIndex > 5) return c;
  float n = noise(px * 0.003 + editionIndex * 211, py * 0.003 + 500);
  // Lower threshold for Barcode/Ad Canopy - both read green/turquoise-dominant in the foreground, so
  // those two editions get more break-patch coverage than the others.
  float breakThreshold = (editionIndex == 1 || editionIndex == 3) ? 0.5 : 0.6;
  if (n < breakThreshold) return c;
  float[] hsb = Color.RGBtoHSB((int) red(c), (int) green(c), (int) blue(c), null);
  float amt = map(n, breakThreshold, 1, 0.22, 0.68);
  float targetHue;
  float briMul = 1.0;
  if (editionIndex == 1) {
    // Turquoise-blue AND light purple, alternating by a second spatial noise field, to counter the
    // unnaturally bright green foreground.
    boolean coolPick = noise(px * 0.006 + 930, py * 0.006) < 0.5;
    targetHue = coolPick ? 0.5 : 0.78; // turquoise-blue OR light purple
  } else if (editionIndex == 2) {
    targetHue = 0.08; // warm orange - complementary counterweight to the blue/cerulean dominance
  } else if (editionIndex == 3) {
    // Dark Prussian blue AND purple - still cool, but genuinely different sub-hues from the dominant
    // turquoise-green, rather than a jarring warm swap.
    boolean bluePick = noise(px * 0.006 + 940, py * 0.006) < 0.5;
    targetHue = bluePick ? 0.6 : 0.76; // dark Prussian blue OR purple
    briMul = bluePick ? 0.75 : 0.9; // Prussian blue reads darker/richer, not pastel
  } else if (editionIndex == 4) {
    boolean coolPick = noise(px * 0.006 + 900, py * 0.006) < 0.5;
    targetHue = coolPick ? 0.55 : 0.82; // dark cerulean OR magenta-purple - purple sits close to green's true complement
    briMul = 0.82; // darker than a plain hue shift - "dark cerulean blue and purple", not pastel
  } else {
    targetHue = 0.07; // warm orange - the actual complement to Plastic's bright blue cast
  }
  float h = lerpHue(hsb[0], targetHue, amt);
  float s = min(1, hsb[1] * 1.15 + 0.08);
  float b = constrain(hsb[2] * briMul, 0, 1);
  int rgb = Color.HSBtoRGB(h, s, b);
  return color((rgb >> 16) & 255, (rgb >> 8) & 255, rgb & 255);
}

// Blend weight toward the species green is high (0.8-0.9) so the species tone actually dominates the
// narrow, largely-fixed base colour most plants sample - which is what real green variants require.
int foliageTone(Plant p) {
  return p.toneOverride >= 0 ? p.toneOverride : SPECIES[p.speciesIndex].greenTone;
}
color stemColor(Plant p) {
  color baseGreen = jitterTone(naturalGreens[foliageTone(p)], p.paletteSlot);
  PVector root = p.path.get(0);
  color sc = localizedBreak(editionTint(shiftColor(lerpColor(getBaseSourceColor(p), baseGreen, 0.8))), root.x, root.y);
  // NODE: a colourful plant's stem takes its colour too (a little less strongly than its leaves, so stem
  // and leaf still read apart) - the whole plant is coloured, not just green stems with coloured leaves.
  if (p.foliageAccent >= 0) sc = lerpColor(sc, editionTint(floralPalette[p.foliageAccent]), 0.65);
  return p.haze > 0 ? lerpColor(sc, hazeColor, p.haze) : sc;
}
color leafColor(Plant p) {
  color baseGreen = jitterTone(naturalGreens[foliageTone(p)], p.paletteSlot + 777);
  PVector root = p.path.get(0);
  color lc = localizedBreak(editionTint(shiftColor(lerpColor(getBaseSourceColor(p), baseGreen, 0.9))), root.x, root.y);
  // NODE: half the plants carry coloured foliage - their leaves lean towards a vivid bloom
  // colour (pink, violet, coral, turquoise, gold...) instead of staying green; stems stay green.
  if (p.foliageAccent >= 0) lc = lerpColor(lc, editionTint(floralPalette[p.foliageAccent]), 0.78);
  return p.haze > 0 ? lerpColor(lc, hazeColor, p.haze) : lc;
}

// ---------------- Edition flora identity ----------------
// Each edition re-costumes the SAME ecosystem: geometry and growth stay identical, but color
// grading (editionTint) plus leaf/petal/sway character give every edition its own distinctive
// botanical mood — sepia-and-ink for Barcode, candy pop for Logo, teal dusk for Ad Canopy,
// gilded amber for Currency, bleached synthetic for Plastic.

float lerpHue(float h, float target, float amt) {
  float d = target - h;
  if (d > 0.5) d -= 1;
  if (d < -0.5) d += 1;
  return h + d * amt;
}

color editionTint(color c) {
  if (editionIndex == 0) return c;
  float[] hsb = Color.RGBtoHSB((int) red(c), (int) green(c), (int) blue(c), null);
  float h = hsb[0], s = hsb[1], b = hsb[2];
  switch (editionIndex) {
    case 1: // paper & ink: sepia-olive base, but green hues get pushed toward warm rust/terracotta
             // instead of just desaturated - a real contrasting complementary color, not a wash,
             // which is what actually breaks a green cast rather than just dimming it.
             boolean barcodeGreen = h > 0.18 && h < 0.46;
             if (barcodeGreen) { h = lerpHue(h, 0.06, 0.55); s = min(1, s * 1.2 + 0.08); }
             else { h = lerpHue(h, 0.11, 0.3); s = min(1, s * 0.85 + 0.05); }
             b = min(1, b * 1.06);
             break;
    case 2: // pop candy: loud, saturated, brand-bright - but greens AND cerulean/blue-green (the most
             // common foliage hues) get a much smaller boost than everything else, so one bright tone
             // doesn't dominate the edition just because it's the most common color underneath.
             boolean isGreenish = h > 0.18 && h < 0.53;
             s = min(1, s * (isGreenish ? 1.15 : 1.6) + (isGreenish ? 0.03 : 0.15));
             h = lerpHue(h, h + 0.06, 1);
             b = min(1, b * 1.15);
             break;
    case 3: h = lerpHue(h, 0.52, 0.22); s = min(1, s * 1.1); b *= 0.92; break;              // urban dusk: a teal lean, not a teal wash
    case 4: h = lerpHue(h, 0.12, 0.18); s = min(1, s * 1.2 + 0.04); b = min(1, b * 1.05); break; // warm cast only — flora keeps its varied colors
    case 5: s = min(1, s * 0.65 + 0.05); h = lerpHue(h, 0.55, 0.22); b = min(1, b * 1.1); break; // bleached synthetic, cool-leaning
  }
  h = h - floor(h);
  int rgb = Color.HSBtoRGB(h, constrain(s, 0, 1), constrain(b, 0, 1));
  return color((rgb >> 16) & 255, (rgb >> 8) & 255, rgb & 255);
}

// The body's joint-accent blue (dark cerulean / Prussian blue), varied per edition WITHOUT running
// through editionTint()'s hue-pull - that pull is tuned for flora and would turn this into brown or
// gold on several editions. A small per-edition hue/sat/bri drift instead: every edition still reads
// as genuinely its own mood on the figure (painterly, visually distinct), but the blue never
// disappears into the edition's flora palette.
color jointAccentColor(boolean cerulean) {
  float h = cerulean ? 0.56 : 0.60;
  float s = cerulean ? 0.72 : 0.66;
  float b = cerulean ? 0.36 : 0.24;
  switch (editionIndex) {
    case 1: s *= 0.85; b *= 1.15; break;                          // ink-toned, slightly muted - paper & ink mood
    case 2: h += 0.02; s = min(1, s * 1.25); b *= 1.1; break;      // pop-candy vividness
    case 3: h -= 0.03; b *= 0.85; break;                           // urban dusk lean, darker
    case 4: h += 0.05; s = min(1, s * 1.1); b *= 1.2; break;       // gilded warm edge, brighter
    case 5: s *= 0.55; b = min(1, b * 1.4); break;                 // bleached synthetic, pale
  }
  int rgb = Color.HSBtoRGB(h, constrain(s, 0, 1), constrain(b, 0, 1));
  return color((rgb >> 16) & 255, (rgb >> 8) & 255, rgb & 255);
}

// The main body wash color - a full, decisive target hue per edition, so each edition gets a
// genuinely different color family on the figure, not a shade of the same one. Edition 0 keeps the
// true original detected hue, untouched.
color bodyWashColor() {
  if (editionIndex == 0) {
    int rgb = Color.HSBtoRGB(bodyHue, 0.65, 0.6);
    return color((rgb >> 16) & 255, (rgb >> 8) & 255, rgb & 255);
  }
  float h, s, b;
  switch (editionIndex) {
    case 1: h = 0.06; s = 0.62; b = 0.58; break;         // burnt sienna / terracotta - paper & ink mood
    case 2: h = 0.90; s = 0.88; b = 0.76; break;         // brighter hot magenta / fuchsia - pop candy (see buildBodyTextureLayer for the orange-red patches mixed on top)
    case 3: h = 0.45; s = 0.68; b = 0.5;  break;         // deep teal-emerald - urban dusk
    case 4: h = 0.11; s = 0.72; b = 0.62; break;         // rich amber / gold - gilded currency
    default: h = 0.52; s = 0.38; b = 0.78; break;        // pale ice-blue/cyan - bleached synthetic plastic
  }
  int rgb = Color.HSBtoRGB(h, s, b);
  return color((rgb >> 16) & 255, (rgb >> 8) & 255, rgb & 255);
}

// ---------------- Edition background ----------------
// Each edition gets a two-color ground: the pair drifts into each other in soft organic patches
// via a low-frequency Perlin-noise field, then a sprinkle of particle grain adds paper-like tooth.
// Everything stays pale so the flora and motifs dominate, and the wash lightens toward the top of
// the canvas so the distance haze on far meadow plants still reads.
color[] editionBgColors() { // { primary, secondary } — deep enough that the pair actually registers
  switch (editionIndex) {
    case 1: return new color[]{ color(236, 222, 188), color(178, 205, 231) }; // aged receipt + light blue
    case 2: return new color[]{ color(255, 210, 158), color(240, 166, 208) }; // candy orange + magenta
    case 3: return new color[]{ color(184, 218, 218), color(232, 168, 118) }; // dusk teal + warm amber - a complementary counterweight
    case 4: return new color[]{ color(240, 222, 172), color(247, 192, 208) }; // champagne + light pink
    case 5: return new color[]{ color(200, 219, 235), color(186, 223, 190) }; // cool blue-grey + light green
    default: return new color[]{ color(212, 184, 143), color(183, 205, 148) }; // soft brown + green
  }
}

// A real sky -> hazy horizon -> earth vertical structure, underneath each edition's own duo wash
// (kept as a tint on top so editions keep their distinct mood). Plant size/haze already scales by
// depth; this gives the whole canvas a genuine "standing in a landscape" spatial structure to play against.
// NODE: a clearer, softer sky blue (was 94, 168, 214) and a paler horizon (was 226, 216, 190).
color skyTop = color(108, 182, 234);
color skyHorizon = color(232, 236, 230);
// NODE: what distance fades towards - a pale version of the horizon sky (aerial perspective).
color hazeColor = color(214, 230, 238);
// NODE: was a brown earth (90, 66, 44) - showing between the foreground stems it made the whole front
// of the meadow read ochre. A deep cerulean-green shade instead, the shadow of the growth itself.
color earthColor = color(28, 84, 80);

void drawEditionBackground(PGraphics pg) {
  color[] duo = editionBgColors();
  pg.noStroke();
  int cell = 8;
  float ns = 0.004; // low-frequency drift between the two colors
  for (int y = 0; y < H; y += cell) {
    float t = y / (float) H; // 0 = top (sky), 1 = bottom (earth)
    // NODE: the gradient's horizon sits where the meadow starts (skyBand + 0.12; it was fixed at 0.6),
    // so the sky ends where the ground begins.
    float hz = skyBand + 0.12;
    color vertical = (t < hz)
      ? lerpColor(skyTop, skyHorizon, constrain(t / hz, 0, 1))
      : lerpColor(skyHorizon, earthColor, constrain((t - hz) / (1 - hz), 0, 1));
    float lighten = map(y, 0, H, 0.1, 0.0);
    for (int x = 0; x < W; x += cell) {
      float n = noise(500 + x * ns, 500 + y * ns); // offset so the wash doesn't mirror the meadow clumps
      n = constrain(map(n, 0.35, 0.65, 0, 1), 0, 1); // Perlin clusters near 0.5 — widen that band so the two colors swing fully
      color editionWash = lerpColor(duo[0], duo[1], n);
      // sky/earth is the structure; the edition wash is a lighter tint on top of it - NODE: only lightly in
      // the sky (0.1, was 0.28 everywhere) so the blue stays clean, full strength on the ground
      color c = lerpColor(vertical, editionWash, t < hz ? lerp(0.1, 0.28, t / hz) : 0.28);
      pg.fill(lerpColor(c, color(255), lighten));
      pg.rect(x, y, cell, cell);
    }
  }
  // Soft clouds in the upper sky, fixed-seed so they hold still between the cached layer and the
  // high-res export just like the grain below.
  java.util.Random cloudRng = new java.util.Random(777);
  for (int i = 0; i < 7; i++) {
    float ccx = cloudRng.nextFloat() * W;
    float ccy = cloudRng.nextFloat() * H * 0.32;
    float baseW = 150 + cloudRng.nextFloat() * 230;
    for (int k = 0; k < 5; k++) {
      float ox = (cloudRng.nextFloat() - 0.5) * baseW * 0.8;
      float oy = (cloudRng.nextFloat() - 0.5) * baseW * 0.22;
      float w = baseW * (0.4 + cloudRng.nextFloat() * 0.5);
      pg.fill(255, 255, 255, 35 + cloudRng.nextInt(30));
      pg.ellipse(ccx + ox, ccy + oy, w, w * 0.5);
    }
  }
  // Particle grain: fixed-seed RNG so the speckle holds still frame to frame (and between the
  // cached layer and the high-res export) without disturbing the sketch's global random stream.
  // NODE: count scaled by canvas area, so the wall's grain is as dense as the original 1920x1080's.
  java.util.Random grain = new java.util.Random(4242);
  int grainCount = int(3000 * (W * (float) H) / (1920.0 * 1080.0));
  for (int i = 0; i < grainCount; i++) {
    float x = grain.nextFloat() * W;
    float y = grain.nextFloat() * H;
    float n = constrain(map(noise(500 + x * ns, 500 + y * ns), 0.35, 0.65, 0, 1), 0, 1);
    color c = lerpColor(duo[0], duo[1], n);
    boolean dark = grain.nextFloat() < 0.5;
    color fleck = lerpColor(c, dark ? color(70, 62, 50) : color(255), 0.28 + grain.nextFloat() * 0.25);
    pg.fill(fleck, 165);
    float d = 2 + grain.nextFloat() * 4.5;
    pg.ellipse(x, y, d, d);
  }
}

// Leaf silhouette per edition: slim blades for Barcode, plump rounds for Logo, narrow street
// foliage for Ad Canopy, classic for Currency, stiff geometric for Plastic.
float edLeafAspect() {
  switch (editionIndex) {
    case 1: return 0.38;
    case 2: return 0.75;
    case 3: return 0.45;
    case 5: return 0.62;
    default: return 0.55;
  }
}

// Petal count shift and width factor reshape the blooms per edition.
int edPetalDelta() {
  switch (editionIndex) {
    case 1: return -2;
    case 2: return 4;
    case 3: return -3;
    case 4: return 1;
    case 5: return -3;
    default: return 0;
  }
}

float edPetalWidth() {
  // A wide spread so each edition's bloom shape is immediately distinct even when colors are similar.
  switch (editionIndex) {
    case 1: return 0.6;
    case 2: return 1.6;
    case 3: return 0.5;
    case 4: return 1.25;
    case 5: return 0.7;
    default: return 1.0;
  }
}

float edFlowerSizeMul() {
  switch (editionIndex) {
    case 1: return 0.85;
    case 2: return 1.35;
    case 3: return 0.75;
    case 4: return 1.15;
    case 5: return 0.8;
    default: return 1.0;
  }
}

// Movement character: plastic vegetation barely sways; candy-pop bounces.
float edSwayMul() {
  switch (editionIndex) {
    case 2: return 1.4;
    case 5: return 0.3;
    default: return 1.0;
  }
}

// A dedicated floral palette (12 distinct hues, none of them green) - flowers no longer inherit the
// plant's own greenish base color, which was quietly making most blooms read as green or pink no
// matter what flower shape they used. ~40% still pull from swirlAccents (colors lifted straight from
// the artwork's swirl decoration); the rest pick from this set.
color[] floralPalette = {
  color(235, 90, 120),  // rose pink
  color(222, 58, 68),   // poppy red
  color(250, 160, 55),  // marigold orange
  color(250, 208, 68),  // buttercup yellow
  color(178, 108, 210), // lavender purple
  color(118, 78, 172),  // violet
  color(88, 138, 222),  // cornflower blue
  color(58, 168, 198),  // turquoise
  color(248, 238, 228), // creamy white
  color(230, 138, 180), // orchid pink
  color(208, 68, 140),  // magenta
  color(255, 138, 88)   // coral
};

// Flowers get a floor on saturation/brightness so they never render black or near-black,
// no matter how dark the sampled color or the hue/brightness sliders push things.
color flowerColor(Plant p) {
  color c;
  if (p.usesAccentColor && swirlAccents.size() > 0) {
    c = swirlAccents.get(p.varietySeed % swirlAccents.size());
  } else {
    c = floralPalette[p.varietySeed % floralPalette.length];
  }
  float[] hsb = Color.RGBtoHSB((int) red(c), (int) green(c), (int) blue(c), null);
  float s = max(hsb[1], 0.68); // NODE: floors raised (0.5 / 0.6) - more saturated, brighter blooms
  float b = max(hsb[2], 0.74);
  int rgb = Color.HSBtoRGB(hsb[0], s, b);
  color fc = editionTint(color((rgb >> 16) & 255, (rgb >> 8) & 255, rgb & 255));
  return p.haze > 0 ? lerpColor(fc, hazeColor, p.haze * 0.8) : fc; // NODE: distant blooms hazed a little less than foliage, so colour still carries
}

String colorModeName() {
  if (colorModeIndex == -1) return "Image";
  if (colorModeIndex == palettes.size()) return "Custom";
  return paletteNames[colorModeIndex];
}

// ---------------- Consumer-culture layer ----------------
// Five overlays, each keyed off the SAME anchors the botanical ecosystem already produced
// (flower tips via p.path, leaf attach points, vine roots) — no new geometry is generated,
// so the plant/flower layer underneath always stays intact regardless of edition. Every overlay
// element is drawn at least at a floor size (see visScale()) so it reads clearly at full-canvas
// scale instead of disappearing at the same tiny size as the flower it's pinned to.

// Rejects a candidate panel position too close to an already-placed one - independently-seeded roots
// and scatter points could otherwise land right on top of each other, reading as one overlapping
// mess instead of two distinct signs.
boolean tooCloseToPanels(float x, float y, float minDist) {
  for (PVector ad : adPanels) {
    if (dist(x, y, ad.x, ad.y) < minDist) return true;
  }
  return false;
}

void buildConsumerLayer() {
  adPanels.clear();
  coinDrops.clear();
  // Hard caps keep each edition a deliberate accent over the ecosystem — without them, thousands of
  // vine roots would carpet the whole canvas in billboards/coins and bury the plants and the figure.
  // Ad panels are landscape signage, not something that grows ON the figure - every source explicitly
  // rejects a position that overlaps the VISIBLE body (tooCloseToBody, checked against the figure's
  // actual on-screen placement) with a margin wide enough to cover a panel's own rendered width.
  // panelMargin keeps every panel's full rendered box (plus its vine curl and stand) inside the canvas.
  float panelMargin = 100;
  for (Plant p : contourPlants) { // Ad Canopy billboards sprout at sparse background vine roots
    if (adPanels.size() >= 30) break;
    if (random(1) < 0.025) {
      float px = constrain(p.path.get(0).x, panelMargin, W - panelMargin);
      float py = constrain(p.path.get(0).y, max(panelMargin, H * skyBand + 40), H - panelMargin); // NODE: boards stand on the ground, not in the sky
      if (!tooCloseToBody(px, py, 65) && !tooCloseToPanels(px, py, 100)) adPanels.add(new PVector(px, py, random(1000)));
    }
  }
  for (int i = 0; i < 28; i++) { // guaranteed baseline scatter, strictly off the figure, so the canopy always reads regardless of vine density
    float groundTop = max(panelMargin, H * skyBand + 40); // NODE: boards stand on the ground, not in the sky
    float px = random(panelMargin, W - panelMargin), py = random(groundTop, H - panelMargin);
    for (int tries = 0; tries < 20 && (tooCloseToBody(px, py, 65) || tooCloseToPanels(px, py, 100)); tries++) { px = random(panelMargin, W - panelMargin); py = random(groundTop, H - panelMargin); }
    if (!tooCloseToBody(px, py, 65)) adPanels.add(new PVector(px, py, random(1000))); // skip rather than ever falling back onto the body
  }
  // Capped hard at 12 total, matching mintFaces.length - Currency Bloom only has 12 distinct metal
  // tones by design (each currency keeps ITS tone always, for identity), so more than 12 coins on
  // screen makes a colour repeat mathematically unavoidable. "You don't necessarily need to fill the
  // space, but never repeat currency and colours" - density traded for a guarantee of zero repeats.
  for (Plant p : plants) { // Currency Bloom seeds a handful of drifting coins from portrait plants
    if (coinDrops.size() >= 12) break;
    if (random(1) < 0.01) coinDrops.add(new PVector(p.path.get(0).x, random(-H, 0), random(1000)));
  }
  for (int i = 0; i < 6 && coinDrops.size() < 12; i++) { // small guaranteed baseline, not a space-filling flood
    coinDrops.add(new PVector(random(W), random(-H, 0), random(1000)));
  }
}

void drawConsumerLayer(PGraphics pg) {
  switch (editionIndex) {
    case 1: drawBarcodeUnderstory(pg); break;
    case 2: drawLogoBloom(pg); break;
    case 3: drawAdCanopy(pg); break;
    case 4: drawCurrencyBloom(pg); break;
    case 5: drawPlasticGarden(pg); break;
  }
}

// Floors an overlay's driving size so tiny flowers still carry a legible, clearly visible motif.
float visScale(Plant p) {
  return max(p.flowerSize * p.sizeScale, 9);
}

// A FLAT floor quietly erases depth-of-field: p.flowerSize*p.sizeScale rarely exceeds ~17-20 even for
// near/large flowers, so almost every motif would land exactly on the flat floor regardless of depth.
// This scales the floor itself by the motif's own canvas-Y position (the same near=bottom/large,
// far=top/small convention the meadow already uses), so depth is preserved.
float depthVisScale(Plant p, float canvasY, float minFloor, float maxFloor) {
  float t = constrain(canvasY / (float) H, 0, 1);
  return max(visScale(p), lerp(minFloor, maxFloor, t));
}

// The main plant grid spans the whole area outside the figure (thousands of plants), so gating
// motifs to a fraction of flowers keeps each edition reading as a deliberate accent rather than
// turning every single bloom into an overlapping mess of tags/badges/coins.
boolean motifGate(Plant p) {
  return p.paletteSlot % (p.isFiller ? 22 : 8) == 0; // meadow filler is vast — keep its motifs sparse
}

// Edition 1 — Barcode Understory: every bloom doubles as a price tag, hung off the flower on a thread.
// Reset the curated-palette draw-order counter here so tag paper colours cycle through a non-repeating
// sequence across the whole edition (see curatedBarcodePalette).
void drawBarcodeUnderstory(PGraphics pg) {
  tagDrawCounter = 0;
  for (Plant p : plants) drawBarcodeTag(pg, p);
  for (Plant p : bodyContourPlants) drawBarcodeTag(pg, p);
  for (Plant p : contourPlants) drawBarcodeTag(pg, p);
  for (Plant p : fillerPlants) drawBarcodeTag(pg, p);
}

// Evenly-spaced hues (not golden-angle) so every ADJACENT entry in the array is already maximally far
// apart - assigned via a draw-order counter stepped by roughly half the palette length, so tags drawn
// one after another land on close-to-opposite hues instead of just "different but still similar."
color[] curatedBarcodePalette = new color[40];
void buildCuratedBarcodePalette() {
  for (int i = 0; i < curatedBarcodePalette.length; i++) {
    float h = i / (float) curatedBarcodePalette.length;
    int rgb = Color.HSBtoRGB(h, 0.6, 0.92);
    curatedBarcodePalette[i] = color((rgb >> 16) & 255, (rgb >> 8) & 255, rgb & 255);
  }
}
int tagDrawCounter = 0;

// Every tag's paper hue comes from the curated, evenly-spaced palette above, stepped 19 slots per tag
// - 19 and 40 are coprime and close to half the palette length, which maximizes the hue jump between
// tags drawn one after another.
color barcodePaperColor(Plant p) {
  color src = curatedBarcodePalette[(tagDrawCounter * 19 + sketchSeed) % curatedBarcodePalette.length];
  tagDrawCounter++;
  float[] hsb = Color.RGBtoHSB((int) red(src), (int) green(src), (int) blue(src), null);
  // A wide saturation/brightness spread via hashUnit (noise() clusters near the middle of its range,
  // which collapsed most tags toward the same mid-saturation value).
  float paperSat = 0.28 + hashUnit(p.varietySeed, 5) * 0.55;
  float paperBri = 0.62 + hashUnit(p.varietySeed, 7) * 0.32;
  int rgb = Color.HSBtoRGB(hsb[0], paperSat, paperBri);
  color paper = color((rgb >> 16) & 255, (rgb >> 8) & 255, rgb & 255);
  // A light sepia mood instead of the full editionTint() - its case-1 hue-PULL would compress these
  // deliberately wide-spread paper hues back toward each other.
  return lerpColor(paper, color(235, 218, 190), 0.14);
}

void drawBarcodeTag(PGraphics pg, Plant p) {
  if (!(p.hasFlower && p.grown && motifGate(p))) return;
  PVector tip = p.path.get(p.path.size() - 1);
  float sway = swayOffset(p, p.path.size() - 1, p.path.size());
  // A barcode needs real pixels to read as bars at all - the depth floor (24-56) and module count
  // (18) are set so every module resolves to several real pixels even at the small end.
  float sz = depthVisScale(p, tip.y, 24, 56);
  float tagW = sz * 2.0, tagH = sz * 1.05;
  color paper = barcodePaperColor(p);
  pg.pushMatrix();
  pg.translate(tip.x + sway, tip.y + sz * 1.2);
  pg.rotate(sin(stillFrame * 0.02 + p.swayPhase) * 0.12); // tag sways like it's hanging off a thread
  pg.stroke(50, 50, 50, 220);
  pg.strokeWeight(1.4);
  pg.line(0, -sz * 1.2, 0, -tagH * 0.5);
  pg.rectMode(CENTER);
  pg.noStroke(); // no outline - a real price tag's edge is just its paper, not a drawn border
  pg.fill(paper);
  pg.rect(0, 0, tagW, tagH, 3);

  // Real UPC-style structure: thin, full-height GUARD bars (bar-space-bar) bookend the code and mark
  // its center, exactly like a genuine barcode's quiet-zone markers - the rest of the modules are
  // irregular-width bars/spaces (driven by the plant's own varietySeed, not the shared paletteSlot,
  // so every tag's pattern is independent of every other tag using the same color slot).
  int modules = 18;
  int mid = modules / 2;
  float[] mw = new float[modules];
  boolean[] isBar = new boolean[modules];
  boolean[] isGuard = new boolean[modules];
  float totalUnits = 0;
  for (int i = 0; i < modules; i++) {
    boolean guard = i < 3 || i >= modules - 3 || (i >= mid - 1 && i <= mid + 1);
    isGuard[i] = guard;
    if (guard) {
      mw[i] = 1;
      int gi = i < 3 ? i : (i >= modules - 3 ? i - (modules - 3) : i - (mid - 1));
      isBar[i] = (gi % 2 == 0); // bar, space, bar
    } else {
      float n = noise(p.varietySeed * 0.02 + i * 0.73);
      mw[i] = n < 0.4 ? 1 : (n < 0.75 ? 2 : 3);
      isBar[i] = noise(p.varietySeed * 0.031 + i * 0.41 + 200) > 0.42; // irregular bar/space, not a fixed alternation
    }
    totalUnits += mw[i];
  }
  float codeW = tagW * 0.84;
  float unitW = codeW / totalUnits;
  float barTopData = -tagH * 0.32, barHData = tagH * 0.46;
  float barTopGuard = -tagH * 0.38, barHGuard = tagH * 0.58; // guard bars run taller than data bars
  float bx = -codeW * 0.5;
  pg.noStroke();
  pg.fill(20);
  for (int i = 0; i < modules; i++) {
    float w = mw[i] * unitW;
    if (isBar[i]) {
      if (isGuard[i]) pg.rect(bx, barTopGuard, max(1, w * 0.8), barHGuard);
      else pg.rect(bx, barTopData, w, barHData);
    }
    bx += w;
  }

  // The number is a caption under the code, grouped like a real UPC digit string, and scales WITH
  // the bars - no fixed-pixel floor, so it never reads as larger than the code at small tag scale.
  pg.fill(20);
  pg.textFont(uiFont);
  pg.textSize(constrain(tagH * 0.13, 3, tagH * 0.16));
  pg.textAlign(CENTER, CENTER);
  int code = p.varietySeed % 1000000;
  pg.text(nf(code / 1000, 3) + " " + nf(code % 1000, 3), 0, tagH * 0.36);
  // ~1 in 4 tags gets a thin tendril creeping partially across it - ties the sticker back into the
  // ecosystem instead of every tag sitting untouched on top, same idea as the vine crossing the top
  // edge of each Ad Canopy panel.
  if (hashUnit(p.varietySeed, 271) < 0.25) {
    color tendril = stemColor(p);
    pg.stroke(tendril, 200);
    pg.strokeWeight(max(0.8, tagH * 0.035));
    pg.noFill();
    float side = hashUnit(p.varietySeed, 277) < 0.5 ? -1 : 1;
    pg.bezier(side * tagW * 0.55, -tagH * 0.4, side * tagW * 0.1, -tagH * 0.05,
              -side * tagW * 0.15, tagH * 0.15, -side * tagW * 0.4, tagH * 0.5);
    pg.noStroke();
    pg.fill(tendril, 210);
    for (int li = 0; li < 2; li++) {
      float lt = 0.3 + li * 0.35;
      pg.pushMatrix();
      pg.translate(lerp(side * tagW * 0.55, -side * tagW * 0.4, lt), lerp(-tagH * 0.4, tagH * 0.5, lt));
      pg.rotate(hashUnit(p.varietySeed, 281 + li) * TWO_PI);
      pg.ellipse(0, 0, tagH * 0.16, tagH * 0.08);
      pg.popMatrix();
    }
  }
  pg.rectMode(CORNER);
  pg.popMatrix();
}

// Edition 2 — Logo Bloom: flowers get branded with a seal + mark; a few go on "SALE".
void drawLogoBloom(PGraphics pg) {
  for (Plant p : plants) drawLogoBadge(pg, p);
  for (Plant p : bodyContourPlants) drawLogoBadge(pg, p);
  for (Plant p : contourPlants) drawLogoBadge(pg, p);
  for (Plant p : fillerPlants) drawLogoBadge(pg, p);
}

// Five badge silhouettes instead of always a circle - real brand marks aren't all discs (square
// app-icon tiles, hexagon seals, shield/crest marks, ribbon/award banners are all common too).
final int BADGE_CIRCLE = 0, BADGE_SQUARE = 1, BADGE_HEX = 2, BADGE_SHIELD = 3, BADGE_RIBBON = 4;

void drawBadgeShape(PGraphics pg, int shape, float sz, color badge) {
  pg.fill(badge);
  if (shape == BADGE_CIRCLE) {
    pg.ellipse(0, 0, sz * 1.8, sz * 1.8);
    pg.noFill(); pg.stroke(255); pg.strokeWeight(sz * 0.09); pg.ellipse(0, 0, sz * 1.45, sz * 1.45);
    pg.stroke(lerpColor(badge, color(255), 0.45)); pg.strokeWeight(sz * 0.05); pg.ellipse(0, 0, sz * 1.95, sz * 1.95);
  } else if (shape == BADGE_SQUARE) {
    pg.rectMode(CENTER);
    pg.rect(0, 0, sz * 1.7, sz * 1.7, sz * 0.32);
    pg.noFill(); pg.stroke(255); pg.strokeWeight(sz * 0.09); pg.rect(0, 0, sz * 1.35, sz * 1.35, sz * 0.24);
    pg.rectMode(CORNER);
  } else if (shape == BADGE_HEX) {
    pg.beginShape();
    for (int k = 0; k < 6; k++) { float a = TWO_PI / 6 * k - HALF_PI; pg.vertex(cos(a) * sz * 0.95, sin(a) * sz * 0.95); }
    pg.endShape(CLOSE);
    pg.noFill(); pg.stroke(255); pg.strokeWeight(sz * 0.08);
    pg.beginShape();
    for (int k = 0; k < 6; k++) { float a = TWO_PI / 6 * k - HALF_PI; pg.vertex(cos(a) * sz * 0.72, sin(a) * sz * 0.72); }
    pg.endShape(CLOSE);
  } else if (shape == BADGE_SHIELD) {
    pg.beginShape();
    pg.vertex(-sz * 0.85, -sz * 0.55);
    pg.bezierVertex(-sz * 0.85, -sz * 0.95, sz * 0.85, -sz * 0.95, sz * 0.85, -sz * 0.55);
    pg.bezierVertex(sz * 0.85, sz * 0.15, sz * 0.55, sz * 0.75, 0, sz * 1.05);
    pg.bezierVertex(-sz * 0.55, sz * 0.75, -sz * 0.85, sz * 0.15, -sz * 0.85, -sz * 0.55);
    pg.endShape(CLOSE);
  } else { // BADGE_RIBBON
    pg.rectMode(CENTER);
    pg.rect(0, 0, sz * 1.9, sz * 1.15, sz * 0.1);
    pg.rectMode(CORNER);
    pg.triangle(-sz * 0.95, -sz * 0.58, -sz * 0.95, sz * 0.58, -sz * 1.28, 0);
    pg.triangle(sz * 0.95, -sz * 0.58, sz * 0.95, sz * 0.58, sz * 1.28, 0);
  }
}

// A light printed/embossed texture pass - a seed-varied rim glint (angle/length differ per badge,
// so it isn't a repeating stamp) plus a scatter of fine speckle, so badges aren't flat vector fills.
void drawBadgeTexture(PGraphics pg, float sz, int seed) {
  pg.noFill();
  pg.stroke(255, 255, 255, 60);
  pg.strokeWeight(max(1, sz * 0.03));
  float glintA = hashUnit(seed, 241) * TWO_PI;
  float glintSpan = 0.25 + hashUnit(seed, 251) * 0.35;
  pg.arc(0, 0, sz * 1.5, sz * 1.5, glintA, glintA + glintSpan * PI);
  pg.noStroke();
  for (int i = 0; i < 16; i++) {
    float a = noise(seed * 0.02 + i) * TWO_PI;
    float r = noise(seed * 0.02 + i + 50) * sz * 0.85;
    float d = noise(seed * 0.02 + i + 100) * 3.2 + 1;
    pg.fill(0, 0, 0, 55);
    pg.ellipse(cos(a) * r, sin(a) * r, d, d);
  }
}

// Hash-driven, not a fixed swatch list - spreads across the full hue wheel AND from deep/moody
// through pastel/muted to vivid, so the SET of badges feels genuinely varied, not just
// differently-hued copies of the same brightness.
color logoBadgeColor(int seed) {
  float h = hashUnit(seed, 151);
  float s = 0.3 + hashUnit(seed, 157) * 0.65;
  float b = 0.4 + hashUnit(seed, 163) * 0.55;
  int rgb = Color.HSBtoRGB(h, s, b);
  return color((rgb >> 16) & 255, (rgb >> 8) & 255, rgb & 255);
}

// Abstract geometric logo marks instead of a literal alphabet letter - a random "A"-"Z" reads as
// text, not a brand mark. Five simple, BOLD, fully-filled vector glyphs (no thin stroked lines that
// read as "an unclear tiny shape" at badge scale) - the kind of reductive icon real logos use.
void drawLogoMark(PGraphics pg, float sz, int seed) {
  int kind = int(hashUnit(seed, 191) * 5) % 5;
  float r = sz * 0.48;
  pg.fill(255);
  pg.noStroke();
  if (kind == 0) { // filled crescent/comma "swoosh" mark - bold, not a thin stroked line
    pg.beginShape();
    pg.vertex(-r * 0.75, r * 0.55);
    pg.bezierVertex(-r * 0.15, r * 0.85, r * 0.75, r * 0.35, r * 0.75, -r * 0.55);
    pg.bezierVertex(r * 0.15, -r * 0.15, -r * 0.4, r * 0.05, -r * 0.75, r * 0.55);
    pg.endShape(CLOSE);
  } else if (kind == 1) { // chevron / arrow mark
    pg.beginShape();
    pg.vertex(-r * 0.72, r * 0.62); pg.vertex(0, -r * 0.62); pg.vertex(r * 0.72, r * 0.62); pg.vertex(0, r * 0.08);
    pg.endShape(CLOSE);
  } else if (kind == 2) { // ringed seal - solid dot with a bold ring
    pg.ellipse(0, 0, r * 0.85, r * 0.85);
    pg.noFill();
    pg.stroke(255);
    pg.strokeWeight(sz * 0.11);
    pg.ellipse(0, 0, r * 1.7, r * 1.7);
    pg.noStroke();
  } else if (kind == 3) { // diamond
    pg.beginShape();
    pg.vertex(0, -r); pg.vertex(r * 0.62, 0); pg.vertex(0, r); pg.vertex(-r * 0.62, 0);
    pg.endShape(CLOSE);
  } else { // ascending bars - a growth-chart brand mark
    float baseline = r * 0.75, bw = r * 0.36;
    pg.rect(-r * 0.7, baseline - r * 0.55, bw, r * 0.55);
    pg.rect(-r * 0.7 + bw * 1.35, baseline - r * 1.1, bw, r * 1.1);
    pg.rect(-r * 0.7 + bw * 2.7, baseline - r * 1.55, bw, r * 1.55);
  }
}

void drawLogoBadge(PGraphics pg, Plant p) {
  // Extra 1-in-3 gate on top of motifGate - fewer, more spaced-out badges each read as distinct
  // instead of wallpapering the scene.
  if (!(p.hasFlower && p.grown && motifGate(p) && p.varietySeed % 3 == 0)) return;
  PVector tip = p.path.get(p.path.size() - 1);
  float sway = swayOffset(p, p.path.size() - 1, p.path.size());
  // Badge texture and the ribbon/shield outlines need more than visScale()'s general 9px floor to
  // actually read - depth-scaled so forefront badges stay visibly bigger than background ones.
  float sz = depthVisScale(p, tip.y, 10, 30);
  // Continuous hash-driven brand color instead of a short fixed list — with hundreds of badges on
  // screen, a short list guarantees visible repeats sitting right next to each other.
  color badge = logoBadgeColor(p.varietySeed);
  int shape = p.varietySeed % 5;
  pg.pushMatrix();
  pg.translate(tip.x + sway, tip.y);
  // Fixed per-badge tilt instead of a continuous spin - a spinning badge could get caught mid-turn in
  // any given frame, reading as "an unclear shape."
  pg.rotate((hashUnit(p.varietySeed, 223) - 0.5) * 0.4);
  pg.noStroke();
  drawBadgeShape(pg, shape, sz, badge);
  drawBadgeTexture(pg, sz, p.paletteSlot);
  pg.noStroke();
  drawLogoMark(pg, sz, p.varietySeed);
  pg.popMatrix();

  if (p.varietySeed % 12 == 0) { // roughly 1 in 12 blooms gets a sale burst
    pg.pushMatrix();
    pg.translate(tip.x + sway + sz * 1.1, tip.y - sz * 0.9);
    pg.noStroke();
    pg.fill(220, 30, 30);
    float burstR = sz * 0.6;
    int pts = 10;
    pg.beginShape();
    for (int i = 0; i < pts * 2; i++) {
      float r = (i % 2 == 0) ? burstR : burstR * 0.6;
      float a = TWO_PI / (pts * 2) * i;
      pg.vertex(cos(a) * r, sin(a) * r);
    }
    pg.endShape(CLOSE);
    pg.fill(255);
    pg.textFont(uiFont);
    pg.textSize(burstR * 0.42);
    pg.textAlign(CENTER, CENTER);
    pg.text("SALE", 0, 0);
    pg.popMatrix();
  }
}

// Always-readable text/tag color for a given background - picks black or white by the background's
// actual brightness rather than assuming a fixed color per design kind, so text never goes invisible
// against a panel accent that happens to land pale or dark.
color adTextColor(color bg) {
  return brightness(bg) > 150 ? color(28, 22, 16) : color(255);
}

// Real digital-ad CTA vocabulary, grouped by intent (search/social/email/e-commerce/SaaS campaigns
// use different phrasing for different jobs, even when the words look similar) - each panel `kind`
// below pulls from whichever category actually fits its content, rather than one flat word bank
// that could hand a discount poster a signup phrase.
String[] ctaShop = { "Shop Now", "Buy Now", "Get Yours", "Add to Cart", "Order Today", "Get It Now",
                     "Claim Yours", "Grab Yours", "Buy 1 Get 1", "Shop the Sale", "Complete Purchase",
                     "Check Out Now" };
String[] ctaUrgency = { "Limited Time Only", "While Supplies Last", "Don't Miss Out", "Last Chance",
                        "Ends Tonight", "Only 3 Left", "Only 5 Left", "Act Now", "Hurry, Ends Soon",
                        "Almost Gone", "Sale Ends in 24 Hours" };
String[] ctaLearn = { "Learn More", "Read More", "Discover How", "See How It Works", "Explore Now",
                      "Find Out More", "See the Difference", "Get the Details", "Watch the Demo",
                      "See for Yourself" };
String[] ctaDiscount = { "Get 20% Off", "Save Big Today", "Unlock Your Discount", "Claim Your Free Gift",
                         "Redeem Now", "Get the Deal", "Upgrade Now" };
String[] ctaBrand = { "Join the Movement", "Be the First to Know", "Because You Deserve It",
                      "Treat Yourself", "Live Better Today", "Own Your Story" };
// Combined pool for the digital-screen panel kind, whose content spans signup and consideration intent.
String[] ctaDigitalScreen = { "Sign Up Free", "Get Started", "Start Free Trial", "Join Now",
                              "Try It Free", "Join the Waitlist", "Get Early Access", "See Options",
                              "Take the Quiz", "Book a Call", "Request a Demo", "No Credit Card Required" };
String[] ctaCountdown = { "Ends Tonight", "Only 3 Left", "Only 5 Left", "Act Now", "Hurry, Ends Soon",
                          "Sale Ends in 24 Hours", "Last Chance", "Don't Miss Out" };

// Picks the CTA vocabulary pool for a given panel `kind` - a discount poster gets urgency language,
// a signup-flavored digital screen gets signup/consideration language, and so on.
String[] poolForKind(int kind) {
  switch (kind) {
    case 0: return ctaLearn;            // hero-image card - discovery framing
    case 1: return ctaUrgency;          // discount poster headline
    case 2: return ctaBrand;            // brand monogram
    case 3: return ctaDigitalScreen;    // glowing app-like CTA screen
    case 4: return ctaShop;             // web banner
    case 5: return ctaUrgency;          // starburst poster headline
    case 6: return ctaBrand;            // star-rating strip
    default: return ctaCountdown;       // countdown/urgency strip
  }
}

// The ONLY source of panel text in this whole edition. Prefers pool entries that fit within maxChars
// so text stays a legible size instead of shrinking a long phrase to fit a small panel; falls back to
// the pool's own shortest entry if nothing qualifies, so even the smallest panel still gets REAL
// vocabulary from the given list rather than a truncated or invented substitute.
String pickCta(String[] pool, int seed, int maxChars) {
  String shortest = pool[0];
  for (String s : pool) if (s.length() < shortest.length()) shortest = s;
  ArrayList<String> fits = new ArrayList<String>();
  for (String s : pool) if (s.length() <= maxChars) fits.add(s);
  if (fits.isEmpty()) return shortest;
  return fits.get(int(hashUnit(seed, 293) * fits.size()) % fits.size());
}

// Hard floor under every CTA text size in this edition - "readable, no tiny size" is an explicit
// requirement, so no computed size is ever allowed to shrink past this regardless of panel size or
// phrase length.
void adTextSize(PGraphics pg, float sz) { pg.textSize(max(9, sz)); }

// A curated, designed palette instead of raw per-panel HSB math - assigned by each panel's own
// position in adPanels, which GUARANTEES no two panels share a color as long as there are fewer
// panels than palette entries. Hues are spaced by the golden angle (0.618034 turns) - the standard
// technique for generating N colors that are maximally spread around the wheel no matter how many
// you pick - phase-shifted 180 degrees and at uniformly bold/vivid saturation and brightness.
color[] curatedAdPalette = new color[60];
void buildCuratedAdPalette() {
  float[][] svCombos = { {0.82, 0.88}, {0.68, 0.95}, {0.9, 0.7}, {0.55, 0.98} };
  for (int i = 0; i < curatedAdPalette.length; i++) {
    float h = (i * 0.618034 + 0.5) % 1.0;
    float[] sv = svCombos[i % svCombos.length];
    int rgb = Color.HSBtoRGB(h, sv[0], sv[1]);
    curatedAdPalette[i] = color((rgb >> 16) & 255, (rgb >> 8) & 255, rgb & 255);
  }
}

// Same guaranteed-non-repeat technique as curatedAdPalette, for Plastic Garden's bags and caps -
// assigning from this fixed, golden-angle-spread set via a running draw-order counter (see
// bagDrawCounter/capDrawCounter below) guarantees real separation between consecutively-drawn
// bags/caps instead of leaving it to chance.
color[] curatedPlasticPalette = new color[48];
void buildCuratedPlasticPalette() {
  float[][] svCombos = { {0.55, 0.92}, {0.4, 0.78}, {0.7, 0.62}, {0.3, 0.95} }; // bright, muted, deeper, pastel plastic tones
  for (int i = 0; i < curatedPlasticPalette.length; i++) {
    float h = (i * 0.618034) % 1.0;
    float[] sv = svCombos[i % svCombos.length];
    int rgb = Color.HSBtoRGB(h, sv[0], sv[1]);
    curatedPlasticPalette[i] = color((rgb >> 16) & 255, (rgb >> 8) & 255, rgb & 255);
  }
}
// Discrete, deliberately-spread size multipliers for bags/caps (replacing a continuous hash range)
// so "never repeat dimensions" is an actual guarantee within one cycle, not just a wide random range
// that can still land close together by chance.
float[] curatedSizeMul = { 0.82, 1.28, 0.95, 1.14, 0.88, 1.35, 1.02, 0.9, 1.2, 1.08, 0.96, 1.3 };
int bagDrawCounter = 0;
int capDrawCounter = 0;
// Positions of every bag/cap already drawn this edition, so a new one can check it isn't landing on
// top of or right next to an existing one. Bags and caps share this one list so a cap checks against
// nearby BAGS too, not just other caps.
ArrayList<PVector> plasticPlaced = new ArrayList<PVector>();
boolean tooCloseToPlastic(float x, float y, float margin) {
  for (PVector q : plasticPlaced) if (dist(x, y, q.x, q.y) < margin) return true;
  return false;
}

// Edition 3 — Ad Canopy: digital-style ad units (banner cards, CTA screens, discount posters) planted
// among the vines on slim modern stands, with vines creeping over their top edges. Panel size follows
// the same depth-of-field rule as the meadow: smaller and farther up the canvas, larger near the bottom.
// Every string this function draws comes from pickCta()/poolForKind(), which only ever reach into the
// categorized CTA arrays; every text size is floored via adTextSize() so nothing goes illegibly small.
// NODE: panels arrive one by one late in the growth (consumerReveal), not all on the first frame.
void drawAdCanopy(PGraphics pg) {
  int shown = ceil(consumerReveal * adPanels.size());
  for (int panelIdx = 0; panelIdx < shown; panelIdx++) {
    PVector ad = adPanels.get(panelIdx);
    float t = constrain(ad.y / (float) H, 0, 1); // depth: lower on canvas = closer = bigger
    // hashUnit instead of noise() for size/lean - noise() clusters near the middle of its range,
    // which made most panels land on nearly the same size multiplier and lean angle.
    int adSeed = int(ad.z * 997);
    float panelW = lerp(52, 118, t) * (0.85 + hashUnit(adSeed, 111) * 0.3);
    float panelH = panelW * 0.72; // landscape hoarding proportions
    // Caps how long a picked phrase is allowed to be for THIS panel's size, so pickCta() favors
    // shorter real vocabulary on small panels instead of a long phrase getting crushed down to fit.
    int maxChars = panelW > 95 ? 26 : (panelW > 70 ? 18 : 12);
    pg.pushMatrix();
    pg.translate(ad.x, ad.y);
    pg.rotate((hashUnit(adSeed, 113) - 0.5) * 0.16); // slight hand-planted lean

    // The palette's own index order is already a golden-angle sequence, so consecutive indices are the
    // most-separated possible hues - indexing panelIdx directly gives a large adjacent-panel hue jump
    // while still guaranteeing no repeat up to 60 panels.
    color accent = curatedAdPalette[panelIdx % curatedAdPalette.length];

    // Thin modern stand instead of a rustic wood post - reads closer to a kiosk/sign mount than a
    // roadside billboard, matching the "digital ad, not paper flyer" direction.
    pg.stroke(200, 205, 212);
    pg.strokeWeight(max(1.5, panelW * 0.025));
    pg.line(0, panelH * 0.42, 0, panelH * 0.95);
    pg.rectMode(CENTER);
    boolean smallPanel = panelW < 68; // distant/small boards get one bold word instead of a full layout
    int kind = int(ad.z * 3) % 8; // 8 genuinely distinct designs
    String cta = pickCta(poolForKind(kind), adSeed, maxChars);
    boolean digital = (kind == 3 || kind == 4);
    // Frame and face colors are always derived from this panel's own accent - never plain black or
    // near-black, so every board is a colored object rather than a dark box with graphics on it.
    // Frame darkened toward BLACK (hue-neutral), so panel borders don't converge toward one muddy tone.
    color frameCol = lerpColor(accent, color(0), 0.55);
    color faceCol = digital ? lerpColor(accent, color(20, 20, 28), 0.5) : lerpColor(accent, color(255, 250, 240), 0.35);
    pg.noStroke();
    pg.fill(frameCol);
    pg.rect(0, 0, panelW * 1.08, panelH * 1.14, 3);
    pg.fill(faceCol);
    pg.rect(0, 0, panelW, panelH, 2);
    // "Ad" disclosure tag, top corner - the small transparency label real digital ads carry, and a
    // quick visual cue this is an ad unit rather than a plain sign.
    color tagText = adTextColor(faceCol);
    pg.fill(lerpColor(faceCol, tagText, 0.12));
    pg.noStroke();
    pg.rect(panelW * 0.5 - panelW * 0.15, -panelH * 0.5 + panelH * 0.1, panelW * 0.22, panelH * 0.14, 2);
    pg.fill(tagText, 200);
    pg.textFont(uiFont);
    adTextSize(pg, panelH * 0.09);
    pg.textAlign(CENTER, CENTER);
    pg.text("Ad", panelW * 0.5 - panelW * 0.04, -panelH * 0.5 + panelH * 0.17);
    pg.textAlign(CENTER, CENTER);
    if (smallPanel) {
      // At this scale none of the fine layout below survives as legible detail. One bold CTA phrase,
      // already length-budgeted for this panel's size by pickCta(), reads as an actual digital ad.
      pg.fill(adTextColor(faceCol));
      adTextSize(pg, min(panelH * 0.36, panelW * 0.88 / max(3, cta.length())));
      pg.text(cta.toUpperCase(), 0, 0);
    } else if (kind == 0) { // hero-image style digital ad card - a bold color "image" block with a
      // simple placeholder glyph, headline, and CTA pill reads clearly as an actual ad at any size.
      color heroCol = lerpColor(accent, color(255), 0.15);
      pg.fill(heroCol);
      pg.rect(0, -panelH * 0.16, panelW * 0.86, panelH * 0.48, 3);
      color heroMark = adTextColor(heroCol);
      pg.fill(heroMark, 165);
      pg.ellipse(-panelW * 0.16, -panelH * 0.28, panelH * 0.12, panelH * 0.12);
      pg.triangle(-panelW * 0.32, -panelH * 0.06, panelW * 0.06, -panelH * 0.06, -panelW * 0.1, -panelH * 0.3);
      pg.fill(adTextColor(faceCol));
      adTextSize(pg, min(panelH * 0.15, panelW * 0.85 / max(4, cta.length())));
      pg.text(cta.toUpperCase(), 0, panelH * 0.18);
      pg.fill(accent);
      pg.rect(0, panelH * 0.36, panelW * 0.42, panelH * 0.14, panelH * 0.07);
      pg.fill(adTextColor(accent));
      // Distinct second line from a shopping-flavored pool - the discovery headline above pairs with
      // an action button below, both real vocabulary, never the same phrase twice on one card.
      String button = pickCta(ctaShop, adSeed + 1, maxChars);
      adTextSize(pg, min(panelH * 0.08, panelW * 0.38 / max(4, button.length())));
      pg.text(button.toUpperCase(), 0, panelH * 0.36);
    } else if (kind == 1) { // discount poster
      pg.fill(accent);
      pg.rect(0, -panelH * 0.2, panelW * 0.88, panelH * 0.32);
      pg.fill(adTextColor(accent)); // dynamic, not fixed white - a pale accent would swallow white text whole
      adTextSize(pg, min(panelH * 0.24, panelW * 0.85 / max(4, cta.length())));
      pg.text(cta.toUpperCase(), 0, -panelH * 0.21);
      pg.fill(adTextColor(faceCol));
      // A real discount-category phrase, distinct from the urgency headline above via its own hash salt.
      String sub = pickCta(ctaDiscount, adSeed + 2, maxChars);
      adTextSize(pg, min(panelH * 0.13, panelW * 0.8 / max(4, sub.length())));
      pg.text(sub.toUpperCase(), 0, panelH * 0.18);
    } else if (kind == 2) { // brand monogram
      pg.fill(adTextColor(faceCol));
      adTextSize(pg, min(panelH * 0.27, panelW * 0.85 / max(4, cta.length())));
      pg.text(cta.toUpperCase(), 0, -panelH * 0.05);
      pg.fill(accent);
      pg.rect(0, panelH * 0.28, panelW * 0.45, panelH * 0.06);
    } else if (kind == 3) { // digital screen: glowing call-to-action on a dark display
      color glow = lerpColor(accent, color(255), 0.35);
      pg.noFill();
      pg.stroke(glow);
      pg.strokeWeight(max(1, panelH * 0.02));
      pg.rect(0, 0, panelW * 0.92, panelH * 0.88, 2);
      pg.noStroke();
      pg.fill(glow);
      adTextSize(pg, min(panelH * 0.24, panelW * 0.88 / max(4, cta.length())));
      pg.text(cta.toUpperCase(), 0, -panelH * 0.12);
      pg.fill(lerpColor(glow, color(255), 0.5));
      adTextSize(pg, panelH * 0.13);
      pg.text(">>>", 0, panelH * 0.12); // decorative affordance arrow, not a text claim
      pg.fill(lerpColor(accent, faceCol, 0.5));
      pg.rect(0, panelH * 0.32, panelW * 0.6, panelH * 0.05, 2); // url bar, tinted by the accent instead of flat grey
    } else if (kind == 4) { // web banner ad: bright gradient with a white CTA pill button
      pg.fill(accent);
      pg.rect(0, -panelH * 0.12, panelW * 0.92, panelH * 0.58, 2);
      pg.fill(lerpColor(accent, color(255), 0.35));
      pg.rect(0, -panelH * 0.28, panelW * 0.92, panelH * 0.22, 2);
      pg.fill(255);
      pg.rect(0, panelH * 0.24, panelW * 0.55, panelH * 0.2, panelH * 0.1); // pill button
      pg.fill(40);
      adTextSize(pg, min(panelH * 0.15, panelW * 0.5 / max(4, cta.length())));
      pg.text(cta.toUpperCase(), 0, panelH * 0.23);
    } else if (kind == 5) { // starburst poster
      pg.fill(accent);
      float burstR = panelH * 0.34;
      pg.beginShape();
      for (int i = 0; i < 20; i++) {
        float r = (i % 2 == 0) ? burstR : burstR * 0.62;
        float a = TWO_PI / 20 * i;
        pg.vertex(cos(a) * r, sin(a) * r - panelH * 0.08);
      }
      pg.endShape(CLOSE);
      pg.fill(255);
      // The burst carries real urgency vocabulary, budgeted extra-short so it fits inside the starburst.
      String burstWord = pickCta(ctaUrgency, adSeed + 3, max(6, maxChars / 2));
      adTextSize(pg, min(panelH * 0.15, burstR * 1.5 / max(4, burstWord.length())));
      pg.text(burstWord.toUpperCase(), 0, -panelH * 0.09);
      pg.fill(60);
      String subBrand = pickCta(ctaBrand, adSeed + 4, maxChars);
      adTextSize(pg, min(panelH * 0.11, panelW * 0.85 / max(4, subBrand.length())));
      pg.text(subBrand.toUpperCase(), 0, panelH * 0.3);
    } else if (kind == 6) { // star-rating / testimonial strip
      pg.fill(255, 205, 60);
      adTextSize(pg, panelH * 0.16);
      pg.text("★★★★★", 0, -panelH * 0.16); // rating icon, not a text claim
      pg.fill(lerpColor(faceCol, color(255), 0.7));
      adTextSize(pg, min(panelH * 0.13, panelW * 0.88 / max(4, cta.length())));
      pg.text(cta.toUpperCase(), 0, panelH * 0.14);
    } else { // kind == 7: countdown / urgency strip
      pg.fill(accent);
      pg.rect(0, -panelH * 0.02, panelW * 0.92, panelH * 0.46, 2);
      pg.fill(255);
      adTextSize(pg, min(panelH * 0.24, panelW * 0.88 / max(4, cta.length())));
      pg.text(cta.toUpperCase(), 0, -panelH * 0.02);
      pg.fill(60);
      String sub2 = pickCta(ctaCountdown, adSeed + 5, maxChars);
      adTextSize(pg, min(panelH * 0.11, panelW * 0.85 / max(4, sub2.length())));
      pg.text(sub2.toUpperCase(), 0, panelH * 0.3);
    }
    // a vine creeps along the top edge, tying the ad back into the ecosystem
    pg.stroke(58, 98, 52);
    pg.strokeWeight(max(1, panelW * 0.02));
    pg.noFill();
    pg.bezier(-panelW * 0.55, -panelH * 0.42, -panelW * 0.2, -panelH * 0.75,
              panelW * 0.15, -panelH * 0.38, panelW * 0.52, -panelH * 0.66);
    pg.noStroke();
    pg.fill(72, 122, 62);
    for (int i = 0; i < 4; i++) {
      float lx = lerp(-panelW * 0.45, panelW * 0.42, i / 3.0);
      float ly = -panelH * (0.48 + 0.16 * noise(ad.z + i * 2));
      pg.pushMatrix();
      pg.translate(lx, ly);
      pg.rotate(noise(ad.z + i * 3) * TWO_PI);
      pg.ellipse(0, 0, panelW * 0.11, panelW * 0.055);
      pg.popMatrix();
    }
    pg.rectMode(CORNER);
    pg.popMatrix();
  }
}

// Edition 4 — Currency Bloom: flower centers become embossed coins; loose coins drift down the scene.
// Reset the shared draw-order counter here (not per-list) so coin centers AND falling coins pull from
// ONE continuous non-repeating sequence (see nextCurrencyIndex) - the guarantee covers the whole
// edition, not just one plant list.
// NODE: the drifting coins arrive late in the growth (consumerReveal), like the ad panels.
void drawCurrencyBloom(PGraphics pg) {
  currencyDrawCounter = 0;
  for (Plant p : plants) drawCoinCenter(pg, p);
  for (Plant p : bodyContourPlants) drawCoinCenter(pg, p);
  for (Plant p : contourPlants) drawCoinCenter(pg, p);
  for (Plant p : fillerPlants) drawCoinCenter(pg, p);
  int shown = ceil(consumerReveal * coinDrops.size());
  for (int i = 0; i < shown; i++) drawFallingCoin(pg, coinDrops.get(i));
}

// Assigns the NEXT currency in a fixed non-repeating permutation of currencySymbols, instead of
// hashing each coin's own seed independently (which, with dozens of coins pulling from the same pool,
// produced real collisions by pigeonhole). Step 11 is coprime with both currencySymbols.length (36)
// and mintFaces.length (12), so as long as the total coin count stays at or under 12 (enforced in
// buildConsumerLayer), BOTH the currency symbol and its metal tone are guaranteed distinct for every coin.
int nextCurrencyIndex() {
  int idx = (currencyDrawCounter * 11 + sketchSeed) % currencySymbols.length;
  if (idx < 0) idx += currencySymbols.length;
  currencyDrawCounter++;
  return idx;
}

// World-currency mint: symbols from many currencies, struck in gold or silver. Index selection is
// deterministic per coin so each one keeps its identity between frames. A genuinely global set -
// Americas, Europe, Africa, Middle East, South/Southeast Asia, East Asia - all real symbols/codes.
String[] currencySymbols = {
  "$", "€", "£", "¥", "₹", "₩", "₽", "¢", "₺", "₦", "₴", "₪", "฿", "₫", "₱", "R", "₲", "₡", "₵", "₮",
  "₭", "₸", "₼", "₾", "Kč", "zł", "Ft", "lei", "Fr", "kr", "R$", "₨", "K", "₧", "Rp", "din"
};
// Mint tones indexed with currencySymbols - each currency keeps the SAME tone every time it appears,
// so it reads as its own coin identity, not a random gold/silver coin flip.
color[] mintFaces = {
  color(230, 190, 90),  // gold
  color(212, 216, 224), // silver
  color(205, 145, 95),  // rose gold / copper
  color(180, 150, 90),  // antique brass
  color(150, 155, 160), // gunmetal
  color(225, 210, 180), // platinum-cream
  color(170, 120, 70),  // bronze
  color(140, 170, 175), // patina teal-copper
  color(205, 175, 210), // pale amethyst mint
  color(90, 100, 115),  // dark oxidized steel
  color(235, 225, 150), // pale gold
  color(160, 130, 180)  // dusty violet mint
};

color mintFaceFor(int symIndex) { return mintFaces[symIndex % mintFaces.length]; }
color mintRimFor(int symIndex) { return lerpColor(mintFaceFor(symIndex), color(20, 15, 10), 0.42); }
color mintInkFor(int symIndex) { return lerpColor(mintFaceFor(symIndex), color(15, 10, 5), 0.62); }

// Struck-metal texture, given real shine: concentric fading rings fake a radial sheen (light doesn't
// hit a coin evenly), a tight bright specular highlight sits offset like a single light source, then
// scratches (both bright and dark, varied length) plus fine speckle keep the face from reading as a
// flat, evenly-lit fill.
void drawCoinTexture(PGraphics pg, float sz, int seed) {
  int rings = 5;
  pg.noStroke();
  for (int i = 0; i < rings; i++) {
    float t = i / (float) (rings - 1);
    float r = sz * lerp(0.02, 0.5, t);
    int alp = int(lerp(60, 0, t));
    pg.fill(255, 255, 255, alp);
    pg.ellipse(-sz * 0.08, -sz * 0.1, r * 2, r * 2);
  }
  pg.fill(255, 255, 255, 130);
  pg.ellipse(-sz * 0.18, -sz * 0.22, sz * 0.32, sz * 0.14);
  pg.fill(255, 255, 255, 60);
  pg.ellipse(-sz * 0.14, -sz * 0.16, sz * 0.55, sz * 0.24);
  pg.noFill();
  pg.stroke(255, 255, 255, 55);
  pg.strokeWeight(max(1, sz * 0.02));
  for (int i = 0; i < 5; i++) {
    float a0 = noise(seed * 0.03 + i) * TWO_PI;
    float r = sz * (0.15 + 0.25 * noise(seed * 0.03 + i + 10));
    pg.arc(0, 0, r * 2, r * 2, a0, a0 + PI * (0.25 + 0.25 * noise(seed * 0.03 + i + 60)));
  }
  pg.stroke(0, 0, 0, 30);
  pg.strokeWeight(max(1, sz * 0.012));
  for (int i = 0; i < 3; i++) {
    float a0 = noise(seed * 0.04 + i + 70) * TWO_PI;
    float r = sz * (0.2 + 0.22 * noise(seed * 0.04 + i + 80));
    pg.arc(0, 0, r * 2, r * 2, a0, a0 + PI * 0.3);
  }
  pg.noStroke();
  for (int i = 0; i < 12; i++) {
    float a = noise(seed * 0.05 + i + 20) * TWO_PI;
    float r = noise(seed * 0.05 + i + 30) * sz * 0.48;
    pg.fill(0, 0, 0, 25);
    pg.ellipse(cos(a) * r, sin(a) * r, 1.6, 1.6);
  }
}

// Struck-metal engraving effect for coin lettering: a dark offset "recessed shadow" pass and a light
// offset "catch-light" pass, then the main ink on top - reads as debossed/embossed engraving instead
// of a flat printed glyph, which is what makes coin text look authentic rather than typed-on.
void drawEmbossedGlyph(PGraphics pg, String s, float sz, float yOff, color ink) {
  pg.fill(lerpColor(ink, color(0), 0.45));
  pg.text(s, sz * 0.025, yOff + sz * 0.03);
  pg.fill(lerpColor(ink, color(255), 0.55));
  pg.text(s, -sz * 0.02, yOff - sz * 0.02);
  pg.fill(ink);
  pg.text(s, 0, yOff);
}

void drawCoinCenter(PGraphics pg, Plant p) {
  // A low 1-in-6 gate - "you don't necessarily need to fill the space, but never repeat currency and
  // colours" - keeps the coin count low enough that the 12-coin no-repeat budget isn't blown by coin
  // centers alone, leaving room for the falling coins too.
  if (!(p.hasFlower && p.grown && motifGate(p) && p.varietySeed % 6 == 0)) return;
  if (currencyDrawCounter >= currencySymbols.length) return; // sequence exhausted, don't wrap into a repeat
  PVector tip = p.path.get(p.path.size() - 1);
  float sway = swayOffset(p, p.path.size() - 1, p.path.size());
  // Depth is the sole, dominant size driver - a dramatic "large up close, small far away" gradient.
  float depthT = constrain(tip.y / (float) H, 0, 1);
  float sz = lerp(18, 64, depthT);
  // nextCurrencyIndex() hands out a fixed non-repeating permutation across the whole edition.
  int symIndex = nextCurrencyIndex();
  // jitterTone on top of the symbol's base metal tone - even distinct currencies get their own subtle
  // shade variation, so no two coins ever read as visually identical.
  color face = jitterTone(mintFaceFor(symIndex), p.paletteSlot);
  color rim = mintRimFor(symIndex);
  color ink = mintInkFor(symIndex);
  String sym = currencySymbols[symIndex];
  pg.pushMatrix();
  pg.translate(tip.x + sway, tip.y);
  pg.fill(face);
  pg.stroke(rim);
  pg.strokeWeight(sz * 0.06);
  pg.ellipse(0, 0, sz * 1.1, sz * 1.1);
  pg.noFill();
  pg.strokeWeight(sz * 0.045);
  int ticks = 18;
  for (int i = 0; i < ticks; i++) {
    float a = TWO_PI / ticks * i;
    float r1 = sz * 0.4, r2 = sz * 0.5;
    pg.line(cos(a) * r1, sin(a) * r1, cos(a) * r2, sin(a) * r2);
  }
  drawCoinTexture(pg, sz, p.paletteSlot);
  pg.noStroke();
  pg.textFont(uiFont);
  pg.textSize(sz * 0.52);
  pg.textAlign(CENTER, CENTER);
  drawEmbossedGlyph(pg, sym, sz, sz * 0.02, ink);
  pg.popMatrix();
}

void drawFallingCoin(PGraphics pg, PVector c) {
  // hashUnit instead of noise() - same clustering issue as everywhere else.
  int coinSeed = int(c.z * 997);
  float speed = 0.6 + hashUnit(coinSeed, 131) * 1.2;
  float y = (c.y + stillFrame * speed) % (H + 60) - 30;
  float wobble = sin(stillFrame * 0.03 + c.z) * 10;
  // Depth-scaled now that the scene is frozen at one instant - lower on canvas reads as closer. The
  // small +-10 jitter is secondary variety and can't flip the near/far size order.
  float depthT = constrain(y / (float) H, 0, 1);
  float sz = lerp(18, 64, depthT) + hashUnit(coinSeed, 139) * 10;
  // Pulls the next slot in the same non-repeating sequence the coin centers use, so falling coins
  // never duplicate a currency/colour already used anywhere else in this render.
  if (currencyDrawCounter >= currencySymbols.length) return; // sequence exhausted, don't wrap into a repeat
  int symIndex = nextCurrencyIndex();
  color face = mintFaceFor(symIndex);
  color rim = mintRimFor(symIndex);
  color ink = mintInkFor(symIndex);
  String sym = currencySymbols[symIndex];
  pg.pushMatrix();
  pg.translate(c.x + wobble, y);
  pg.rotate(stillFrame * 0.05 + c.z);
  pg.fill(face);
  pg.stroke(rim);
  pg.strokeWeight(1.5);
  pg.ellipse(0, 0, sz, sz * 0.85); // slight squash so the spin reads as a tumbling coin
  drawCoinTexture(pg, sz, int(c.z * 999));
  pg.noStroke();
  pg.textFont(uiFont);
  pg.textSize(sz * 0.5);
  pg.textAlign(CENTER, CENTER);
  drawEmbossedGlyph(pg, sym, sz, 0, ink);
  pg.popMatrix();
}

// Edition 5 — Plastic Garden: half the leaves get a plastic-bag skin; flower centers become bottle caps.
// Reset the curated-palette draw-order counters here so bag colours and cap colours each cycle
// through their own non-repeating sequence across the whole edition (see curatedPlasticPalette).
void drawPlasticGarden(PGraphics pg) {
  bagDrawCounter = 0;
  capDrawCounter = 0;
  plasticPlaced.clear();
  for (Plant p : plants) drawPlasticOverlay(pg, p);
  for (Plant p : bodyContourPlants) drawPlasticOverlay(pg, p);
  for (Plant p : contourPlants) drawPlasticOverlay(pg, p);
  for (Plant p : fillerPlants) drawPlasticOverlay(pg, p);
}

// Integer hash, NOT noise() - noise()'s output isn't uniform across 0..1, it clusters tightly
// around 0.4-0.6, so hash-driven values spread evenly across their full range instead of clustering.
int hash32(int x) {
  x = ((x >>> 16) ^ x) * 0x45d9f3b;
  x = ((x >>> 16) ^ x) * 0x45d9f3b;
  x = (x >>> 16) ^ x;
  return x;
}
float hashUnit(int seed, int salt) {
  return (hash32(seed * 92821 + salt) & 0x7fffffff) / (float) 0x7fffffff;
}

// Pseudo-brand-name generator (2-3 syllables, deterministic per seed) - packaging text reads as an
// actual (if fictional) product name instead of a single repeating monogram letter. hashUnit spreads
// across the FULL syllable set (noise() only ever reached a handful of middle indices).
String[] pbSyl1 = {"Zo","Ka","Ne","Vi","Tro","Bri","Lu","Sa","Mo","Fi","Cor","Da","Ru","Ny","Ax","Pe","Qu","Or"};
String[] pbSyl2 = {"lo","ra","tex","nix","va","mo","ce","dis","fy","ka","zo","lin","tra","xen","bo","sil","dor","ny"};
String pseudoBrandName(int seed) {
  int n1 = int(hashUnit(seed, 71) * pbSyl1.length) % pbSyl1.length;
  int n2 = int(hashUnit(seed, 83) * pbSyl2.length) % pbSyl2.length;
  String s = pbSyl1[n1] + pbSyl2[n2];
  if (hashUnit(seed, 97) > 0.5) s += pbSyl2[int(hashUnit(seed, 101) * pbSyl2.length) % pbSyl2.length];
  return s.toUpperCase();
}

void drawPlasticOverlay(PGraphics pg, Plant p) {
  // Two-level gate (8/12) - "you don't necessarily need to fill the space, but never repeat colours
  // and dimensions." Fewer bags on screen both eases the curated palette's repeat-free budget and
  // gives each one real visual space of its own.
  if (p.paletteSlot % 8 == 0) {
    for (Leaf lf : p.leaves) {
      if (lf.attachIndex >= p.path.size()) continue;
      if ((lf.attachIndex + p.paletteSlot) % 12 != 0) continue;
      PVector base = p.path.get(lf.attachIndex);
      float sway = swayOffset(p, lf.attachIndex, p.path.size());
      // Skip if a bag or cap already landed nearby - bags/caps were bunching up right next to or on
      // top of each other.
      if (tooCloseToPlastic(base.x + sway, base.y, 55)) continue;
      int bagSeed = lf.attachIndex + p.varietySeed;
      // Pulls the next entry from a fixed, deliberately-spread set via the same draw-order-counter
      // technique as the currency coins, so consecutive bags never repeat a dimension until the
      // 12-entry set cycles.
      float sizeVar = curatedSizeMul[(bagDrawCounter * 5 + sketchSeed) % curatedSizeMul.length];
      // Independent WIDTH proportion on top of that - without this, two bags of the same silhouette
      // family were just uniformly-scaled clones of each other. Applied as a transform scale below so
      // it doesn't require rewriting every hand-authored bezier point per shape.
      float widthVar = 0.72 + hashUnit(bagSeed, 227) * 0.66;
      // Depth is the DOMINANT size driver, with sizeVar layered on top only as a mild secondary
      // variety (not something that can flip the near/far size order).
      float depthT = constrain(base.y / (float) H, 0, 1);
      float s = lerp(9, 52, depthT) * 1.7 * sizeVar; // bag height, depth-driven
      // The curated, golden-angle-spread palette assigned in draw order guarantees real separation
      // between consecutively-drawn bags instead of leaving it to chance.
      color bc = jitterTone(curatedPlasticPalette[(bagDrawCounter * 17 + sketchSeed) % curatedPlasticPalette.length], bagSeed);
      bagDrawCounter++;
      int bagShape = bagSeed % 3; // three silhouettes - boxy, slouchy, narrow - not one crumple every time
      pg.pushMatrix();
      pg.translate(base.x + sway, base.y);
      // an actual carrier bag snagged on the stem, dangling and swinging below its handles
      pg.rotate(sin(stillFrame * 0.03 + lf.angle * 3) * 0.18 + (lf.angle > 0 ? 0.12 : -0.12));
      pg.scale(widthVar, 1); // independent width variance, after rotation so it doesn't skew the lean
      pg.noFill();
      pg.stroke(bc, 230);
      pg.strokeWeight(max(1, s * 0.07));
      pg.arc(-s * 0.13, 0, s * 0.2, s * 0.3, PI, TWO_PI); // two handle loops
      pg.arc(s * 0.13, 0, s * 0.2, s * 0.3, PI, TWO_PI);
      pg.noStroke();
      pg.fill(bc, 185);
      pg.beginShape(); // body: shape varies per bag so they don't all read as the same crumpled sack
      if (bagShape == 0) { // boxy - flatter sides, squared bottom
        pg.vertex(-s * 0.28, 0); pg.vertex(s * 0.28, 0);
        pg.bezierVertex(s * 0.3, s * 0.4, s * 0.3, s * 0.75, s * 0.24, s * 0.92);
        pg.vertex(-s * 0.24, s * 0.92);
        pg.bezierVertex(-s * 0.3, s * 0.75, -s * 0.3, s * 0.4, -s * 0.28, 0);
      } else if (bagShape == 1) { // slouchy - wider flare, sagging bottom
        pg.vertex(-s * 0.24, 0); pg.vertex(s * 0.24, 0);
        pg.bezierVertex(s * 0.4, s * 0.4, s * 0.46, s * 0.75, s * 0.32, s * 1.0);
        pg.bezierVertex(s * 0.05, s * 1.12, -s * 0.18, s * 1.02, -s * 0.36, s * 0.9);
        pg.bezierVertex(-s * 0.46, s * 0.6, -s * 0.36, s * 0.3, -s * 0.24, 0);
      } else { // narrow - a slim boutique-style bag
        pg.vertex(-s * 0.18, 0); pg.vertex(s * 0.18, 0);
        pg.bezierVertex(s * 0.24, s * 0.4, s * 0.22, s * 0.75, s * 0.16, s * 0.88);
        pg.vertex(-s * 0.16, s * 0.88);
        pg.bezierVertex(-s * 0.22, s * 0.75, -s * 0.24, s * 0.4, -s * 0.18, 0);
      }
      pg.endShape(CLOSE);
      pg.stroke(255, 190); // crinkle highlights
      pg.strokeWeight(0.8);
      pg.line(-s * 0.08, s * 0.15, s * 0.04, s * 0.65);
      pg.line(s * 0.14, s * 0.2, s * 0.08, s * 0.55);
      // a small printed label patch carrying an actual (fictional) product name, like a store's own
      // mark - what makes each bag read as "a different product or service" rather than an
      // unbranded plastic sack with a single repeating letter on it.
      String brand = pseudoBrandName(bagSeed);
      float labelW = s * max(0.34, brand.length() * 0.075);
      pg.noStroke();
      pg.fill(255, 235);
      pg.rect(-labelW * 0.5, s * 0.35, labelW, s * 0.2, 2);
      pg.fill(lerpColor(bc, color(30, 25, 20), 0.55));
      pg.textFont(uiFont);
      pg.textSize(min(s * 0.13, labelW * 0.85 / max(3, brand.length())));
      pg.textAlign(CENTER, CENTER);
      pg.text(brand, 0, s * 0.45);
      pg.popMatrix();
      plasticPlaced.add(new PVector(base.x + sway, base.y));
    }
  }
  if (p.hasFlower && p.grown && motifGate(p)) {
    PVector tip = p.path.get(p.path.size() - 1);
    float sway = swayOffset(p, p.path.size() - 1, p.path.size());
    // Skip if a bag or another cap already landed nearby - checked against the SAME shared position
    // list the bags add to, so a cap can't land on a bag either.
    if (tooCloseToPlastic(tip.x + sway, tip.y, 50)) return;
    // The same curated, draw-order-assigned palette as the bags, offset by ~a third of the palette
    // (~120 degrees of hue) so caps start in a genuinely different part of the wheel than bags at the
    // same counter value.
    color cc = jitterTone(curatedPlasticPalette[(capDrawCounter * 17 + sketchSeed + 16) % curatedPlasticPalette.length], p.paletteSlot);
    // Same as the bags: depth is the dominant size driver, and the size multiplier comes from the
    // same fixed, non-repeating curated set (offset from the bags' sequence).
    float capSizeVar = curatedSizeMul[(capDrawCounter * 5 + sketchSeed + 3) % curatedSizeMul.length];
    float depthT = constrain(tip.y / (float) H, 0, 1);
    float sz = lerp(9, 40, depthT) * capSizeVar;
    capDrawCounter++;
    pg.pushMatrix();
    pg.translate(tip.x + sway, tip.y);
    pg.noStroke();
    pg.fill(lerpColor(cc, color(0), 0.25)); // ridged outer rim
    int teeth = 14;
    pg.beginShape();
    for (int i = 0; i < teeth * 2; i++) {
      float r = (i % 2 == 0) ? sz * 0.55 : sz * 0.46;
      float a = TWO_PI / (teeth * 2) * i;
      pg.vertex(cos(a) * r, sin(a) * r);
    }
    pg.endShape(CLOSE);
    pg.fill(cc); // cap top
    pg.ellipse(0, 0, sz * 0.86, sz * 0.86);
    pg.noFill(); // molded ring detail on the top face
    pg.stroke(lerpColor(cc, color(255), 0.35));
    pg.strokeWeight(sz * 0.045);
    pg.ellipse(0, 0, sz * 0.52, sz * 0.52);
    pg.stroke(lerpColor(cc, color(0), 0.15));
    pg.strokeWeight(sz * 0.03);
    pg.ellipse(0, 0, sz * 0.68, sz * 0.68);
    pg.noStroke();
    // Same pseudo-brand-name pool as the bags, trimmed to a 2-letter cap monogram - a plausible
    // abbreviated bottling mark instead of a single repeating letter.
    String capMark = pseudoBrandName(p.varietySeed);
    capMark = capMark.substring(0, min(2, capMark.length()));
    pg.fill(lerpColor(cc, color(255), 0.5)); // small embossed brand mark on the top face
    pg.textFont(uiFont);
    pg.textSize(sz * 0.22);
    pg.textAlign(CENTER, CENTER);
    pg.text(capMark, 0, sz * 0.02);
    pg.popMatrix();
    plasticPlaced.add(new PVector(tip.x + sway, tip.y));
  }
}

String editionSlug(int idx) {
  return idx + "_" + editionNames[idx].replaceAll("[^A-Za-z0-9]+", "");
}

String timestamp() {
  return year() + nf(month(), 2) + nf(day(), 2) + "_" + nf(hour(), 2) + nf(minute(), 2) + nf(second(), 2);
}
