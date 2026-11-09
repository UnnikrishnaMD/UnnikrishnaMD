import com.hamoid.*;      // Video Export library — install via Sketch > Import Library > Manage Libraries > "Video Export" (hamoid)
import java.awt.Color;    // used only for RGB<->HSB conversion in shiftColor()

PImage srcImg;   // subject photo — drives the main plant grid + colors
PImage bgImg;    // background scene — drawn behind; its edges seed a second layer of creeping vines
// bgImg with its plain white canvas keyed to transparent (see buildBgImgKeyed) - drawn instead of
// bgImg wherever the sky/earth background needs to actually show through. Right now background.png
// and recliningman.png are the same artwork: its figure and colorful swirl decoration stay opaque
// and visible (that's the intended painted look), but the plain white canvas around them becomes a
// window onto the sky/earth gradient instead of a flat white field.
PImage bgImgKeyed;
PGraphics bodyTextureLayer; // soft painterly mottling over the visible body silhouette - see buildBodyTextureLayer

ArrayList<Plant> plants = new ArrayList<Plant>();             // main plants — rooted outside the human figure
ArrayList<Plant> contourPlants = new ArrayList<Plant>();      // sparse vines following the background's contours
ArrayList<Plant> bodyContourPlants = new ArrayList<Plant>();  // vines rooted on the human figure's own silhouette edge
ArrayList<Plant> fillerPlants = new ArrayList<Plant>();       // meadow filler across empty canvas, sized/hazed by depth
boolean[] bodyMask;  // true where a srcImg pixel belongs to the human figure — kept clear of plant roots
// 0..1 per srcImg pixel, 0 off-body - high where the body is locally THIN relative to its own nearby
// surroundings (wrists/knees/ankles/neck), self-calibrating from a chamfer distance-to-edge transform
// compared against a local max (so it adapts to this figure's own proportions, no hand-guessed radius
// or coordinates). See computeJointIntensity().
float[] jointIntensity;
float bodyBoxMinX, bodyBoxMaxX, bodyBoxMinY, bodyBoxMaxY;
boolean bodyAlongIsX; // true if the figure's own measured bounding box is wider than it is tall

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
// Approximate face bounding box in srcImg pixel space (identified by inspecting recliningman.png) —
// vines rooted in here creep onto the figure far less often and stay much shorter than elsewhere.
float faceZoneX0 = 170, faceZoneY0 = 190, faceZoneX1 = 470, faceZoneY1 = 490;

// ---------- Image placement — both images fit proportionately in the canvas and move independently of it ----------
float bgScale = 1.0, bgOffsetX = 0, bgOffsetY = 0;
float srcScale = 1.0, srcOffsetX = 0, srcOffsetY = 0;
int activeTarget = 0; // 0 = background image, 1 = source image (which one arrow keys / scale keys affect)

boolean recording = false;
VideoExport videoExport;
int printScale = 3; // 1920x1080 * 3 = 5760x3240px, plenty for large-format print

// ---------- Reproducibility ----------
// Every plant's shape and the whole scene's layout comes from random()/noise() calls seeded here,
// once, before anything is built. Same seed -> identical output, every time -> this is what makes a
// specific piece re-renderable (for print, for headless batch exports, for proving a bug is fixed).
// Override at launch with a CLI arg (processing-java ... seed), e.g. for phase 8's batch sweeps;
// defaults to a fixed value so a plain Run in the IDE is reproducible too.
int sketchSeed = 42;

// The deliverable is static Giclee prints, not a live/animated view - every sway, spin, and drift
// throughout the sketch used to be keyed off Processing's frameCount (which only ever increases), so
// the live view never actually held still, and no two screenshots of "the same" render ever matched
// exactly. Replacing frameCount with this frozen constant everywhere those effects are computed holds
// the whole scene at one fixed instant - which is also exactly what a print export needs.
final int stillFrame = 0;
// Bumped every round and drawn as an on-screen label (see draw()) so a screenshot can prove which
// code actually produced it - never baked into any exported print/JPEG.
final String BUILD_TAG = "v1-rebuild-infra";

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
ArrayList<PVector> adPanels = new ArrayList<PVector>();  // static billboard spots for Ad Canopy (x, y, noiseSeed)
ArrayList<PVector> coinDrops = new ArrayList<PVector>(); // drifting coins for Currency Bloom (x, y, noiseSeed)
PFont uiFont; // bold sans-serif for all consumer-layer typography (logical font, so currency glyphs fall back cleanly)

// ---------- Render mode ----------
// false (default): the fully-grown botanical scene is rendered once into plantLayer and reused every
// frame, so palette tweaks and edition switching respond instantly — this is the final-artwork mode.
// true: plants grow live frame by frame (the original behavior), for recording growth MP4s later.
boolean animateGrowth = false;
PGraphics plantLayer;
boolean plantLayerDirty = true;

// ---------- Body-mask debug overlay ----------
// Since the mask hue band (isSkinPixel) has to be retuned per source image, this paints exactly
// what the mask currently sees, translucent red over the live scene, so tuning is done by eye
// against the actual artwork rather than by guessing hue numbers blind. Toggle with M.
boolean showBodyMaskDebug = false;
PGraphics bodyMaskDebugLayer;

void setup() {
  size(1920, 1080);
  srcImg = loadImage("recliningman.jpg");
  bgImg = loadImage("background.jpg");
  srcImg.loadPixels();

  if (args != null && args.length > 0) {
    try {
      sketchSeed = Integer.parseInt(args[0]);
    } catch (NumberFormatException e) {
      println("Ignoring non-numeric seed argument: " + args[0]);
    }
  }
  randomSeed(sketchSeed);
  noiseSeed(sketchSeed);
  println("Seed: " + sketchSeed);

  uiFont = createFont("SansSerif.bold", 96, true);
  buildPalettes();
  buildCuratedBarcodePalette();
  buildCuratedAdPalette();
  buildAll();

  java.io.File outDir = new java.io.File(sketchPath("output"));
  if (!outDir.exists()) outDir.mkdir();
  printControls();
}

void draw() {
  if (animateGrowth) {
    drawEditionBackground(g);
    float[] bgPlace = computePlacement(bgImg, bgScale, bgOffsetX, bgOffsetY);
    image(bgImgKeyed, bgPlace[0], bgPlace[1], bgPlace[2], bgPlace[3]);
    image(bodyTextureLayer, 0, 0);
    for (Plant p : fillerPlants) { p.grow(); if (!isForegroundFiller(p)) p.display(g); }
    for (Plant p : plants) { p.grow(); p.display(g); }
    for (Plant p : bodyContourPlants) { p.grow(); p.display(g); }
    for (Plant p : contourPlants) { p.grow(); p.display(g); }
    for (Plant p : fillerPlants) { if (isForegroundFiller(p)) p.display(g); }
  } else {
    if (plantLayerDirty) renderPlantLayer();
    image(plantLayer, 0, 0);
  }

  drawConsumerLayer(g); // painted last so it always reads as the top layer, unobstructed

  if (showBodyMaskDebug) {
    if (bodyMaskDebugLayer == null) buildBodyMaskDebugLayer();
    image(bodyMaskDebugLayer, 0, 0);
  }

  drawBuildLabel(); // live-canvas only, never baked into any export - see BUILD_TAG

  if (recording) videoExport.saveFrame();
}

// Builds a once-off translucent-red overlay of exactly what buildBodyMask() currently detects as
// "figure", positioned the same way srcImg itself would be (via computePlacement). Rebuilt only
// when R or M is pressed, not every frame — this is a tuning aid, not part of the artwork.
void buildBodyMaskDebugLayer() {
  bodyMaskDebugLayer = createGraphics(width, height);
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
  all.sort(new java.util.Comparator<Plant>() {
    public int compare(Plant a, Plant b) {
      return Float.compare(a.path.get(0).y, b.path.get(0).y);
    }
  });
  return all;
}

// Renders the background + every fully-grown plant once into an offscreen buffer. Drawing ~thousands
// of stems/leaves per frame is what made the sketch feel unresponsive; against the cache, edition
// and color changes show up on the very next frame.
void renderPlantLayer() {
  if (plantLayer == null) plantLayer = createGraphics(width, height);
  plantLayer.beginDraw();
  drawEditionBackground(plantLayer);
  float[] bgPlace = computePlacement(bgImg, bgScale, bgOffsetX, bgOffsetY);
  plantLayer.image(bgImgKeyed, bgPlace[0], bgPlace[1], bgPlace[2], bgPlace[3]);
  plantLayer.image(bodyTextureLayer, 0, 0);
  for (Plant p : depthSortedAllPlants()) p.display(plantLayer);
  plantLayer.endDraw();
  plantLayerDirty = false;
}

// ---------------- Image placement ----------------
// "Contain" fit: scales the image to fit inside the canvas without distortion or cropping,
// then applies the user's extra scale/offset on top. Canvas size and image size are never tied together.

float[] computePlacement(PImage im, float userScale, float offX, float offY) {
  float base = min((float) width / im.width, (float) height / im.height);
  float scl = base * userScale;
  float w = im.width * scl;
  float h = im.height * scl;
  float x = (width - w) / 2 + offX;
  float y = (height - h) / 2 + offY;
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

// bgImg and srcImg have INDEPENDENTLY adjustable placement (their own scale/offset), and the figure
// is actually drawn to the canvas via bgImg's placement, not srcImg's - so a body-avoidance check
// using onBody() (srcImg-based) can be wrong whenever the two placements have drifted apart, letting
// overlay content visibly land on the figure despite "passing" the check. This checks against the
// placement the figure is actually drawn with.
boolean onVisibleBody(float cx, float cy) {
  float[] bgPlace = computePlacement(bgImg, bgScale, bgOffsetX, bgOffsetY);
  int sx = int((cx - bgPlace[0]) / bgPlace[4]);
  int sy = int((cy - bgPlace[1]) / bgPlace[4]);
  return isBody(sx, sy);
}
boolean tooCloseToBody(float cx, float cy, float margin) {
  return onVisibleBody(cx, cy) || onVisibleBody(cx - margin, cy) || onVisibleBody(cx + margin, cy)
      || onVisibleBody(cx, cy - margin) || onVisibleBody(cx, cy + margin);
}

void buildAll() {
  bodyMaskDebugLayer = null; // stale after any rebuild — recomputed lazily next time M is toggled on
  buildBodyMask();
  buildBgImgKeyed();
  srcPlace = computePlacement(srcImg, srcScale, srcOffsetX, srcOffsetY);
  buildBodyTextureLayer();
  buildPlants();
  buildBodyContourPlants();
  buildContourPlants();
  buildFillerPlants();
  buildConsumerLayer();
  // Right now the finished artwork is what's needed, not the growth animation — fast-forward every
  // plant to fully grown immediately. Toggle animateGrowth (G key) to watch it grow from seed
  // instead, e.g. when recording an MP4 of the growth later.
  if (!animateGrowth) {
    forceFullyGrown(plants);
    forceFullyGrown(bodyContourPlants);
    forceFullyGrown(contourPlants);
    forceFullyGrown(fillerPlants);
  }
  printSpeciesCounts();
  plantLayerDirty = true;
}

// Prints exactly how many of each species got built, so "is the variety actually there" is a fact
// to check in the console rather than a guess from looking at a dense, busy canvas.
void printSpeciesCounts() {
  int[] counts = new int[SPECIES.length];
  for (Plant p : plants) counts[p.speciesIndex]++;
  for (Plant p : bodyContourPlants) counts[p.speciesIndex]++;
  for (Plant p : contourPlants) counts[p.speciesIndex]++;
  for (Plant p : fillerPlants) counts[p.speciesIndex]++;
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
// the transparent area (PNG tools can leave arbitrary RGB behind alpha-0 pixels). A single hardcoded
// hue band only works for one specific source photo (gap 2 in CLAUDE.md — a real fix externalizes
// this into per-work config) - hand-guessing a number blind, without ever seeing the actual pixels,
// proved unreliable the first time. Instead, this SELF-CALIBRATES from the loaded image: the figure
// is one large solid-fill region, while the swirl decoration is thin scattered line strokes in many
// different hues - so even though swirls are numerous, no single swirl hue comes close to matching
// the figure's total pixel count. detectBodyHue() finds whichever hue actually dominates the opaque,
// saturated pixels, and that's almost always the figure regardless of what color it happens to be.
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

// Scans every opaque, saturated pixel into 60 hue buckets (6 degrees each) and returns the center of
// the most populous one. Run once per buildBodyMask() call, not per-pixel.
float detectBodyHue() {
  int buckets = 60;
  int[] counts = new int[buckets];
  for (int i = 0; i < srcImg.pixels.length; i++) {
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

void buildBodyMask() {
  srcImg.loadPixels();
  bodyHue = detectBodyHue();
  println("Detected figure hue: " + nf(bodyHue, 1, 3) + " (0=red, 0.33=green, 0.67=blue) - press M to check it visually.");
  boolean[] raw = new boolean[srcImg.width * srcImg.height];
  for (int i = 0; i < raw.length; i++) raw[i] = isSkinPixel(srcImg.pixels[i]);

  bodyMask = new boolean[raw.length]; // 3x3 majority vote smooths antialiased edges into a clean silhouette
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
      bodyMask[x + y * srcImg.width] = count * 2 >= total;
    }
  }
  collectSwirlAccents();
  computeJointIntensity();
  computeBodyExtent();
}

// Chamfer distance-to-edge transform (two-pass, 1/1.4142 weights - a cheap, good approximation of true
// Euclidean distance), then compared against a local max of that same distance (separable box-max
// filter) so a pixel reads as "thin" relative to the body's OWN nearby thickness rather than against
// some fixed pixel threshold that would misjudge a larger or smaller figure.
void computeJointIntensity() {
  int w = srcImg.width, h = srcImg.height;
  float INF = 1e6;
  float[] dist = new float[w * h];
  for (int i = 0; i < dist.length; i++) dist[i] = bodyMask[i] ? INF : 0;
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      int i = x + y * w;
      if (!bodyMask[i]) continue;
      float d = dist[i];
      if (x > 0) d = min(d, dist[i - 1] + 1);
      if (y > 0) d = min(d, dist[i - w] + 1);
      if (x > 0 && y > 0) d = min(d, dist[i - w - 1] + 1.4142f);
      if (x < w - 1 && y > 0) d = min(d, dist[i - w + 1] + 1.4142f);
      dist[i] = d;
    }
  }
  for (int y = h - 1; y >= 0; y--) {
    for (int x = w - 1; x >= 0; x--) {
      int i = x + y * w;
      if (!bodyMask[i]) continue;
      float d = dist[i];
      if (x < w - 1) d = min(d, dist[i + 1] + 1);
      if (y < h - 1) d = min(d, dist[i + w] + 1);
      if (x < w - 1 && y < h - 1) d = min(d, dist[i + w + 1] + 1.4142f);
      if (x > 0 && y < h - 1) d = min(d, dist[i + w - 1] + 1.4142f);
      dist[i] = d;
    }
  }
  int radius = 30, step = 3; // stepped scan - an approximate box-max is plenty for this purpose and far cheaper
  float[] rowMax = new float[w * h];
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      float m = 0;
      for (int dx = -radius; dx <= radius; dx += step) m = max(m, dist[constrain(x + dx, 0, w - 1) + y * w]);
      rowMax[x + y * w] = m;
    }
  }
  float[] localMax = new float[w * h];
  for (int x = 0; x < w; x++) {
    for (int y = 0; y < h; y++) {
      float m = 0;
      for (int dy = -radius; dy <= radius; dy += step) m = max(m, rowMax[x + constrain(y + dy, 0, h - 1) * w]);
      localMax[x + y * w] = m;
    }
  }
  jointIntensity = new float[w * h];
  for (int i = 0; i < jointIntensity.length; i++) {
    jointIntensity[i] = (!bodyMask[i] || localMax[i] < 1) ? 0 : constrain(1 - dist[i] / localMax[i], 0, 1);
  }
}

// The figure's own measured bounding box, used by bodyAlongT() below - no hand-guessed coordinates.
void computeBodyExtent() {
  bodyBoxMinX = Float.MAX_VALUE; bodyBoxMaxX = -Float.MAX_VALUE;
  bodyBoxMinY = Float.MAX_VALUE; bodyBoxMaxY = -Float.MAX_VALUE;
  for (int y = 0; y < srcImg.height; y++) {
    for (int x = 0; x < srcImg.width; x++) {
      if (!bodyMask[x + y * srcImg.width]) continue;
      bodyBoxMinX = min(bodyBoxMinX, x); bodyBoxMaxX = max(bodyBoxMaxX, x);
      bodyBoxMinY = min(bodyBoxMinY, y); bodyBoxMaxY = max(bodyBoxMaxY, y);
    }
  }
  bodyAlongIsX = (bodyBoxMaxX - bodyBoxMinX) >= (bodyBoxMaxY - bodyBoxMinY);
}

// 0 at the head end, 1 at the feet end, along the figure's own longest measured axis - which end is
// "head" is decided by which end the detected face zone sits closer to, not a hardcoded orientation.
// Used to boost coverage over specific body regions (e.g. hips/thighs) without any hand-picked
// coordinates: just a position along the body's own measured extent.
float bodyAlongT(float x, float y) {
  float faceCenter = bodyAlongIsX ? (faceZoneX0 + faceZoneX1) * 0.5 : (faceZoneY0 + faceZoneY1) * 0.5;
  float lo = bodyAlongIsX ? bodyBoxMinX : bodyBoxMinY;
  float hi = bodyAlongIsX ? bodyBoxMaxX : bodyBoxMaxY;
  float v = bodyAlongIsX ? x : y;
  boolean faceNearLo = abs(faceCenter - lo) <= abs(faceCenter - hi);
  float t = faceNearLo ? (v - lo) / max(1, hi - lo) : (hi - v) / max(1, hi - lo);
  return constrain(t, 0, 1);
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

// Keys bgImg's plain white canvas to transparent, leaving only the figure and its colorful swirl
// decoration opaque. Drawing this instead of the raw bgImg is what lets the sky/earth background
// actually be seen - otherwise bgImg's white background paints over the entire canvas edge to edge
// (it's the same image as srcImg here, sized to match the canvas exactly) and nothing behind it,
// however carefully built, is ever visible.
void buildBgImgKeyed() {
  bgImg.loadPixels();
  bgImgKeyed = createImage(bgImg.width, bgImg.height, ARGB);
  bgImgKeyed.loadPixels();
  for (int i = 0; i < bgImg.pixels.length; i++) {
    color c = bgImg.pixels[i];
    float[] hsb = Color.RGBtoHSB((int) red(c), (int) green(c), (int) blue(c), null);
    boolean nearWhite = hsb[2] > 0.9 && hsb[1] < 0.15; // pale, low-saturation canvas background
    bgImgKeyed.pixels[i] = nearWhite ? color(255, 255, 255, 0) : c;
  }
  bgImgKeyed.updatePixels();
}

// Grunge-style mottling in light/dark tones derived from bodyWashColor()'s own per-edition target hue
// (not the original bodyHue) so the shading stays hue-consistent with the wash instead of fighting
// it. Two noise octaves set the coarse patchwork, a high-frequency third layer roughens the patch
// edges (smooth edges read as clouds, not grunge), and jointIntensity darkens/intensifies the grain
// specifically at elbows/knees/wrists/ankles/neck. Drawn after bgImg(Keyed) but before any plant
// growth, so vines that do cross onto the body render on top of this texture rather than under it.
void buildBodyTextureLayer() {
  bodyTextureLayer = createGraphics(width, height);
  bodyTextureLayer.beginDraw();
  bodyTextureLayer.clear();
  bodyTextureLayer.noStroke();
  // A genuine full-body wash so the figure's dominant color actually shifts per edition - bold and
  // unmistakable, not a subtle cast. Edition 0 stays the pure original blue untouched.
  color washColor = bodyWashColor();
  float[] washHsb = Color.RGBtoHSB((int) red(washColor), (int) green(washColor), (int) blue(washColor), null);
  int lightRgb = Color.HSBtoRGB(washHsb[0], 0.3, 0.94);
  int darkRgb = Color.HSBtoRGB(washHsb[0], 0.75, 0.24);
  color lightTone = color((lightRgb >> 16) & 255, (lightRgb >> 8) & 255, lightRgb & 255);
  color darkTone = color((darkRgb >> 16) & 255, (darkRgb >> 8) & 255, darkRgb & 255);
  // Joint accent tones - dark cerulean and Prussian blue. Deliberately NOT run through editionTint()
  // (its hue-PULL logic would turn "blue at the joints" into brown/gold on several editions) -
  // jointAccentColor gives each edition its own light drift in hue/sat/bri instead, still blue everywhere.
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
      // Logo Bloom's body wash mixes in patches of orange-red on top of the magenta base, so both
      // colors read on the figure rather than one flat hue. Coarse spatial noise (patchy, not
      // per-pixel) picks where the orange-red patches land.
      if (editionIndex == 2) {
        float mixN = noise(x * 0.012 + 5000, y * 0.012 + 5000);
        if (mixN > 0.45) {
          float mixAmt = map(mixN, 0.45, 1, 0.3, 0.85);
          float h2 = lerpHue(washHsb[0], 0.02, mixAmt); // pull from magenta toward orange-red
          int rgb2 = Color.HSBtoRGB(h2, min(1, washHsb[1] * 1.05), min(1, washHsb[2] * 1.1 + 0.06));
          cellWash = color((rgb2 >> 16) & 255, (rgb2 >> 8) & 255, rgb2 & 255);
        }
      }
      // Wash alpha 205 (not a lighter partial blend) - at a lighter alpha the original blue pixels
      // underneath still showed through enough to muddy the target hue toward gray/purple.
      bodyTextureLayer.fill(red(cellWash), green(cellWash), blue(cellWash), 205);
      bodyTextureLayer.rect(px, py, cell, cell);
      bodyTextureLayer.fill(red(base), green(base), blue(base), alp);
      bodyTextureLayer.rect(px, py, cell, cell);
      // Dark joint accent restricted to (a) true anatomical joints - neck/knee/wrist/ankle, where the
      // body is locally thin relative to its surroundings (jointIntensity) - PLUS (b) hip/thigh
      // explicitly: a hip is anatomically THICK, not thin, so jointIntensity alone can never flag it.
      // bodyAlongT fills that specific gap. Excludes the face zone and the figure's own decorative
      // linework (inked much darker/less saturated than the flat body-color fill - detected directly,
      // not a guessed region) so the accent doesn't fight either of those.
      boolean inFaceZone = x >= faceZoneX0 && x <= faceZoneX1 && y >= faceZoneY0 && y <= faceZoneY1;
      color srcPx = srcImg.pixels[i];
      float[] srcHsb = Color.RGBtoHSB((int) red(srcPx), (int) green(srcPx), (int) blue(srcPx), null);
      boolean isLinework = srcHsb[2] < 0.3 || srcHsb[1] < 0.18;
      float alongT = bodyAlongT(x, y);
      float hipPeak = constrain(1 - abs(alongT - 0.68) / 0.12, 0, 1);
      boolean trueJoint = joint > 0.55;
      if (!inFaceZone && !isLinework && (trueJoint || hipPeak > 0)) {
        float accentStrength = max(trueJoint ? map(joint, 0.55, 1, 0.2, 0.75) : 0, hipPeak * 0.3);
        if (accentStrength > 0.02) {
          boolean useCerulean = noise(x * 0.02 + 700, y * 0.02 + 700) > 0.5;
          color accent = useCerulean ? jointCerulean : jointPrussian;
          bodyTextureLayer.fill(red(accent), green(accent), blue(accent), int(accentStrength * 150));
          bodyTextureLayer.rect(px, py, cell, cell);
        }
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
      float t = constrain(cy / (float) height, 0, 1); // 0 = far (top), 1 = near (bottom)
      // The upper canvas is sky, not distant meadow - thin it hard so it actually reads as open air
      // rather than the same growth just scaled small.
      if (t < 0.28 && random(1) < 0.88) continue;
      color hazed = lerpColor(c, color(255), max(0, 1 - t) * 0.55);
      Plant p = new Plant(cx, cy, hazed, false);
      p.sizeScale *= lerp(0.3, 1.75, t);
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
    // sprouting its own flower/motif there would stack them until they fuse into one solid blob.
    // Thin density steeply wherever the body is locally very thin relative to its surroundings.
    int vi = constrain(int(v.x), 0, srcImg.width - 1) + constrain(int(v.y), 0, srcImg.height - 1) * srcImg.width;
    float joint = jointIntensity[vi];
    if (joint > 0.65 && random(1) < map(joint, 0.65, 1, 0.3, 0.88)) continue;
    // Root a short distance OUTSIDE the body, in the ground the edge point sits on, rather than
    // exactly on the boundary pixel itself - rooting right on the silhouette line reads as "starting
    // from the black edge" instead of growing up from the ground toward the figure.
    float outward = v.z + PI;
    float offsetDist = random(4, 15);
    float rx = v.x + cos(outward) * offsetDist;
    float ry = v.y + sin(outward) * offsetDist;
    if (isBody(int(rx), int(ry))) { rx = v.x; ry = v.y; } // concave-area fallback

    color c = srcImg.get((int) v.x, (int) v.y);
    float cx = place[0] + rx * place[4];
    float cy = place[1] + ry * place[4];
    boolean inFace = v.x >= faceZoneX0 && v.x <= faceZoneX1 && v.y >= faceZoneY0 && v.y <= faceZoneY1;
    if (inFace && random(1) < 0.2) continue; // thin the outline vines around the face too
    Plant p = new Plant(cx, cy, c, true);
    p.sizeScale = random(0.55, 0.95);       // sturdier than a background creeper, so it reads on the figure
    p.maxSteps = inFace ? int(random(12, 30)) : int(random(45, 110));
    // Only a small, deliberate fraction of boundary vines are actually permitted to creep onto the
    // body at all (canCrossBody - grow() enforces this as a hard wall for everyone else). This is
    // what keeps on-body coverage feeling like "here and there, randomly" rather than "most vines
    // near the edge eventually reach across it." bodyAlongT approximates head(0)-to-feet(1) position
    // from the body's own measured extent: the middle band (hip/thigh) gets extra coverage, and the
    // crown eases up only right at the very top of the head.
    float alongT = bodyAlongT(v.x, v.y);
    float crownEase = constrain(alongT / 0.09, 0, 1);
    float regionBoost = lerp(1.8, 2.8, crownEase * crownEase);
    float loinPeak = constrain(1 - abs(alongT - 0.68) / 0.16, 0, 1);
    regionBoost *= 1 + 0.35 * loinPeak;
    regionBoost += joint * 1.1; // joint-driven bonus organically lifts density at wrist/ankle/neck/knee too
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
  for (float gy = -4; gy < height + 28; gy += fillStepY) {
    for (float gx = -16; gx < width + 16; gx += fillStepX) {
      float px = gx + random(-13, 13);
      float py = gy + random(-13, 13);
      int sx = int((px - place[0]) / place[4]);
      int sy = int((py - place[1]) / place[4]);
      if (isBody(sx, sy)) continue;
      // Under the figure the meadow still grows — filling what would otherwise be a white band —
      // capped (in makeFillerPlant) so it never climbs onto the body; the face keeps a thin apron.
      int above = regionAbove(sx, sy);
      float t = constrain(py / (float) height, 0, 1); // 0 = far (top), 1 = near (bottom)
      float clump = noise(px * 0.005, py * 0.005);    // drifting patches of thick and thin growth
      // The floor of each range is what fills the thin patches; the clump ceiling keeps the
      // thick-and-thin variation that carries the depth of field.
      // Wider near/far contrast than before - the far meadow should visibly thin out and open up
      // bare ground between clumps, not just fade in color, for the depth-of-field to actually read.
      float density = lerp(0.22, 0.8, clump);
      if (t > 0.78) density = lerp(0.55, 1.1, clump); // fuller up front, still clumped
      else if (t < 0.35) density = lerp(0.03, 0.22, clump); // far meadow should visibly thin toward the horizon
      if (above == 0 && random(1) > density) continue;
      if (above == 2 && random(1) < 0.6) continue;
      Plant p = makeFillerPlant(px, py, t, above);
      p.sizeScale *= lerp(0.8, 1.2, clump); // thick patches also grow a touch larger
      fillerPlants.add(p);
    }
  }
  // The top-right corner used to get its own thick patch of distant growth "so no bare canvas
  // survives there" - but bare canvas there is exactly what reads as open sky now, so this is
  // deliberately much sparser than it used to be.
  for (float gy = 12; gy < height * 0.3; gy += 26) {
    for (float gx = width * 0.68; gx < width; gx += 22) {
      if (random(1) < lerp(0.65, 0.85, noise(gx * 0.006, gy * 0.006))) continue; // clumped, not uniform
      float px = gx + random(-8, 8);
      float py = gy + random(-9, 9);
      int sx = int((px - place[0]) / place[4]);
      int sy = int((py - place[1]) / place[4]);
      if (isBody(sx, sy)) continue;
      fillerPlants.add(makeFillerPlant(px, py, constrain(py / (float) height + 0.12, 0, 1), regionAbove(sx, sy)));
    }
  }
  println("Filler plants: " + fillerPlants.size());
}

Plant makeFillerPlant(float px, float py, float t, int above) {
  t = constrain(t, 0, 1.1);
  color base = lerpColor(color(70, 120, 60), color(120, 170, 90), random(1));
  if (random(1) < 0.18) base = lerpColor(base, color(205, 120, 145), random(0.6)); // occasional bloom tint
  color hazed = lerpColor(base, color(255), max(0, 1 - t) * 0.72); // atmospheric haze with distance
  Plant p = new Plant(px, py, hazed, false);
  p.sizeScale = random(0.5, 0.9) * lerp(0.18, 2.0, min(t, 1));
  p.maxSteps = int(random(20, 55) * lerp(0.55, 1.6, min(t, 1)));
  // steps ≈ pixels / average step length (~1.25); stop ~12px short of the body edge
  if (above == 1) p.maxSteps = int(constrain((lastAboveDist - 12) / 1.25, 6, p.maxSteps));
  else if (above == 2) p.maxSteps = int(constrain((lastAboveDist - 18) / 1.25, 4, 18));
  p.flowerSize *= lerp(0.5, 1.15, min(t, 1));
  p.isFiller = true;
  return p;
}

// The near/far split for the meadow: filler plants rooted below this line are "foreground" and are
// drawn over everything else, completing the depth effect.
boolean isForegroundFiller(Plant p) {
  return p.path.get(0).y >= height * 0.82;
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
final int LEAF_ROUND = 0, LEAF_BLADE = 1, LEAF_HEART = 2, LEAF_SERRATED = 3, LEAF_COMPOUND = 4;
// 12 distinct flower shapes, plus NONE. Flower shape is rolled independently per plant (see
// Plant.flowerShapeRoll) rather than fixed by species - with only 9 species but 12 shapes, tying
// shape to species would cap variety below what's actually available; this way any flowering plant
// can land on any of the 12, which is what "different shapes, not just different colors/sizes" needs.
final int FLOWER_DAISY = 0, FLOWER_BELL = 1, FLOWER_STAR = 2, FLOWER_UMBEL = 3, FLOWER_SPIKE = 4,
          FLOWER_TRUMPET = 5, FLOWER_POPPY = 6, FLOWER_POM = 7, FLOWER_CROSS = 8, FLOWER_FRINGED = 9,
          FLOWER_TUBECLUSTER = 10, FLOWER_PINWHEEL = 11, FLOWER_NONE = 12;
final int FLOWER_SHAPE_COUNT = 12;

// Six distinct natural greens - each species leans on one for its stem/leaf color, so the palette
// itself carries variety instead of relying on shape alone. GREEN_CERULEAN blue-green, GREEN_BOTTLE
// dark bottle green, GREEN_PARROT yellow-green, GREEN_SAGE soft natural green, GREEN_FOREST deep
// forest green, GREEN_FRESH bright spring green (the most common species uses this one, per
// feedback that fresh green presence was too low).
color[] naturalGreens = {
  color(40, 120, 128),  // GREEN_CERULEAN
  color(18, 55, 30),    // GREEN_BOTTLE
  color(152, 196, 55),  // GREEN_PARROT
  color(98, 152, 88),   // GREEN_SAGE
  color(34, 84, 55),    // GREEN_FOREST
  color(120, 205, 92)   // GREEN_FRESH
};
final int GREEN_CERULEAN = 0, GREEN_BOTTLE = 1, GREEN_PARROT = 2, GREEN_SAGE = 3, GREEN_FOREST = 4, GREEN_FRESH = 5;

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
  // Leaning heavily on cerulean/parrot (the brighter, bluer/yellower greens) and light on
  // bottle/forest (the two darkest tones) per feedback that dark brownish-green areas dominated.
  new Species("Meadow Daisy",       CAT_FLOWER, LEAF_ROUND,    FLOWER_DAISY, GREEN_FRESH,    1.0,  0.22, 0.0,  1.0,  1.0,  0.6),
  new Species("Trumpet Bell",       CAT_FLOWER, LEAF_BLADE,    FLOWER_BELL,  GREEN_CERULEAN, 0.8,  0.16, 0.0,  1.05, 1.1,  0.55),
  new Species("Star Bloom",         CAT_FLOWER, LEAF_SERRATED, FLOWER_STAR,  GREEN_CERULEAN, 1.15, 0.20, 0.0,  0.9,  0.9,  0.6),
  new Species("Heart-leaf Creeper", CAT_VINE,   LEAF_HEART,    FLOWER_NONE,  GREEN_SAGE,     1.4,  0.12, 0.0,  0.9,  1.0,  0.08),
  new Species("Morning Glory",      CAT_VINE,   LEAF_ROUND,    FLOWER_BELL,  GREEN_CERULEAN, 1.25, 0.14, 0.0,  1.0,  1.1,  0.35),
  new Species("Bramble",            CAT_BUSH,   LEAF_SERRATED, FLOWER_STAR,  GREEN_BOTTLE,   0.9,  0.28, 0.18, 0.9,  0.6,  0.25),
  new Species("Round Shrub",        CAT_BUSH,   LEAF_ROUND,    FLOWER_SPIKE, GREEN_PARROT,   0.85, 0.26, 0.16, 1.0,  0.65, 0.5),
  new Species("Sapling",            CAT_TREE,   LEAF_COMPOUND, FLOWER_UMBEL, GREEN_BOTTLE,   0.4,  0.14, 0.28, 1.9,  2.1,  0.3),
  new Species("Umbel Sapling",      CAT_TREE,   LEAF_COMPOUND, FLOWER_UMBEL, GREEN_CERULEAN, 0.35, 0.15, 0.3,  2.0,  2.2,  0.4)
};
int[] VINE_SPECIES = { 3, 4 };
// Weighted so the meadow reads mostly as flowers, with vines, bushes, and trees as real but smaller
// shares - not a third of the ground cover each. Vine species are now included here too (they were
// previously ONLY reachable via the figure's own silhouette/contour vines, which is why vines never
// appeared out in the open meadow/foreground at all): ground-cover vines are common in a real
// landscape, not something confined to clinging on one figure.
int[] GROUND_SPECIES = { 0, 1, 2, 0, 1, 2, 0, 1, 2, 3, 4, 3, 4, 5, 6, 5, 6, 7, 8 }; // ~45% flower, ~20% vine, ~20% bush, ~10% tree

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
  int flowerShapeRoll; // which of the 12 flower shapes this plant's bloom uses - independent of species
  boolean usesAccentColor; // this flower's color is lifted from the artwork's swirl decoration, not the plain sample
  boolean isCreeper;   // true for background-contour vines: smaller and shorter
  boolean isFiller = false; // meadow filler carries motifs more sparsely than the main flora
  boolean canBranch = true; // false on spawned branches, so they don't spawn their own
  boolean canCrossBody = false; // almost always false - see grow(): the body is a wall unless this is set
  float heading, stepLen, sizeScale, noiseOff, swayPhase;
  int maxSteps, leafInterval;
  float flowerSize;
  int petalCount;

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
  }

  void grow() {
    Species sp = SPECIES[speciesIndex];
    if (!grown) {
      float n = noise(noiseOff);
      heading += map(n, 0, 1, -0.12, 0.12) * sp.curlMul;      // gentle curling, vine-like - species-scaled
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
          leaves.add(new Leaf(path.size() - 1, leafAngle, random(6, 11))); // small, intricate leaves - shape still reads at this scale (round/blade/heart/serrated/compound), just not oversized

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
  float[] weights = { 3.2, 2.4, 1.8, 1.2, 0.6 };
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

float leafAspectFor(int shape) {
  if (shape == LEAF_BLADE) return 0.18;      // narrow grass-like blade
  if (shape == LEAF_HEART) return 0.75;
  if (shape == LEAF_SERRATED) return 0.55;
  return edLeafAspect(); // LEAF_ROUND (and compound's individual leaflets) keep the edition-driven aspect
}

// Draws one leaf blade at the current transform's origin, shape driven by `shape` (LEAF_HEART and
// LEAF_SERRATED get distinct outlines; everything else reuses the original smooth bezier blade).
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

// Overload used directly by LEAF_HEART / LEAF_SERRATED with their own outlines, keeping the same
// signature shape so displayLeaf's dispatch above stays a single call either way.
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
    float r = (k % 2 == 0) ? sz * 0.7 : sz * 0.34; // softer points than before - less spiky/artificial
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
  // Petals sized and offset so they stay as 4 distinct overlapping ovals, not a single fused disc
  // (an earlier version had the ellipses far larger than their offset, which merged into one solid
  // blob at any real size - this is what caused the oversized "balloon" shape).
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
    drawPetal(pg, sz * 0.62, sz * 0.16); // softer/shorter rays than before - less sharp and artificial
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

// Integer hash, NOT noise() - noise()'s output isn't uniform across 0..1, it clusters tightly around
// 0.4-0.6, which quietly collapsed a lot of "per-seed variety" (jitter, badge/coin/panel/bag colors,
// brand-name syllables) toward nearly the same value every time. A hash spreads evenly across the
// full range, so these genuinely cover their whole range from seed to seed.
int hash32(int x) {
  x = ((x >>> 16) ^ x) * 0x45d9f3b;
  x = ((x >>> 16) ^ x) * 0x45d9f3b;
  x = (x >>> 16) ^ x;
  return x;
}
float hashUnit(int seed, int salt) {
  return (hash32(seed * 92821 + salt) & 0x7fffffff) / (float) 0x7fffffff;
}

// Draws the current edition name + BUILD_TAG as a small top-left label on the LIVE canvas only - never
// part of any exported print (saveHighResPrint/exportAllEditions build their own PGraphics and never
// call this). A screenshot of the live view can then prove exactly which code produced it, which is
// the only reliable way to tell a genuinely-unfixed bug from feedback on a stale build.
void drawBuildLabel() {
  noStroke();
  fill(0, 0, 0, 150);
  rect(0, 0, width, 26);
  fill(255);
  textFont(uiFont);
  textSize(15);
  textAlign(LEFT, CENTER);
  text("Edition " + editionIndex + ": " + editionNames[editionIndex] + "   |   build " + BUILD_TAG, 10, 13);
}

// Blend target is now the plant's SPECIES green (one of 5 distinct natural tones - see naturalGreens)
// rather than one fixed dark/light green, and blended in more heavily so that tone actually reads
// against the (often pale, depth-hazed) base color instead of being washed out by it.
// Nudges a base tone's hue/saturation/brightness by a small, per-plant deterministic amount (seeded
// from the plant's own paletteSlot) so plants sharing a species green aren't perfectly flat/identical
// - real foliage varies in tonal value even within one species.
color jitterTone(color c, int seed) {
  float[] hsb = Color.RGBtoHSB((int) red(c), (int) green(c), (int) blue(c), null);
  float jH = (hashUnit(seed, 2) - 0.5) * 0.05;
  // Biased to lift rather than dull - the depth haze elsewhere already pulls distant plants toward
  // pale/white, so this jitter doesn't need to be symmetric; skewing positive keeps greens reading
  // as fresh instead of compounding into a general grayish murk.
  float jS = map(hashUnit(seed, 3), 0, 1, -0.05, 0.2);
  float jB = map(hashUnit(seed, 4), 0, 1, -0.08, 0.18);
  int rgb = Color.HSBtoRGB(hsb[0] + jH, constrain(hsb[1] + jS, 0.3, 1), constrain(hsb[2] + jB, 0.25, 1));
  return color((rgb >> 16) & 255, (rgb >> 8) & 255, rgb & 255);
}

// Blend weight toward the species green raised (0.55/0.7 -> 0.8/0.9) - a lighter blend let
// getBaseSourceColor()'s narrow base dilute the species-green palette back toward sameness; at
// 0.8-0.9 the species tone actually dominates, which is what real per-species green variety needs.
color stemColor(Plant p) {
  color baseGreen = jitterTone(naturalGreens[SPECIES[p.speciesIndex].greenTone], p.paletteSlot);
  PVector root = p.path.get(0);
  return localizedBreak(editionTint(shiftColor(lerpColor(getBaseSourceColor(p), baseGreen, 0.8))), root.x, root.y);
}
color leafColor(Plant p) {
  color baseGreen = jitterTone(naturalGreens[SPECIES[p.speciesIndex].greenTone], p.paletteSlot + 777);
  PVector root = p.path.get(0);
  return localizedBreak(editionTint(shiftColor(lerpColor(getBaseSourceColor(p), baseGreen, 0.9))), root.x, root.y);
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
// as genuinely its own mood on the figure, but the blue never disappears into the edition's flora palette.
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

// The main body wash color. A full, decisive target hue per edition (not a partial lerp from blue) -
// each edition gets a genuinely different color family, not a shade of the same one. Edition 0 keeps
// the true original detected hue, untouched.
color bodyWashColor() {
  if (editionIndex == 0) {
    int rgb = Color.HSBtoRGB(bodyHue, 0.65, 0.6);
    return color((rgb >> 16) & 255, (rgb >> 8) & 255, rgb & 255);
  }
  float h, s, b;
  switch (editionIndex) {
    case 1: h = 0.06; s = 0.62; b = 0.58; break;         // burnt sienna / terracotta - paper & ink mood
    case 2: h = 0.90; s = 0.88; b = 0.76; break;         // brighter hot magenta / fuchsia - pop candy
    case 3: h = 0.45; s = 0.68; b = 0.5;  break;         // deep teal-emerald - urban dusk
    case 4: h = 0.11; s = 0.72; b = 0.62; break;         // rich amber / gold - gilded currency
    default: h = 0.52; s = 0.38; b = 0.78; break;        // pale ice-blue/cyan - bleached synthetic plastic
  }
  int rgb = Color.HSBtoRGB(h, s, b);
  return color((rgb >> 16) & 255, (rgb >> 8) & 255, rgb & 255);
}

// Most of the canvas keeps each edition's base cast (editionTint above); a spatially-coherent noise
// field carves out patches (not per-pixel noise - real patches, so it reads as organic variation
// rather than static) that lean toward a genuinely DIFFERENT, contrasting color, breaking the
// uniformity a flat edition-wide tint alone would otherwise produce.
color localizedBreak(color c, float px, float py) {
  if (editionIndex < 1 || editionIndex > 5) return c;
  float n = noise(px * 0.003 + editionIndex * 211, py * 0.003 + 500);
  float breakThreshold = (editionIndex == 1 || editionIndex == 3) ? 0.5 : 0.6;
  if (n < breakThreshold) return c;
  float[] hsb = Color.RGBtoHSB((int) red(c), (int) green(c), (int) blue(c), null);
  float amt = map(n, breakThreshold, 1, 0.22, 0.68);
  float targetHue;
  float briMul = 1.0;
  if (editionIndex == 1) {
    // Turquoise-blue AND light purple, alternating by a second spatial noise field - counters a
    // green-dominant foreground without pulling everything toward one single hue.
    boolean coolPick = noise(px * 0.006 + 930, py * 0.006) < 0.5;
    targetHue = coolPick ? 0.5 : 0.78;
  } else if (editionIndex == 2) {
    targetHue = 0.08; // warm orange - complementary counterweight to the blue/cerulean dominance
  } else if (editionIndex == 3) {
    // Dark Prussian blue AND purple, alternating - genuinely different sub-hues from the dominant
    // turquoise-green, rather than a jarring warm swap.
    boolean bluePick = noise(px * 0.006 + 940, py * 0.006) < 0.5;
    targetHue = bluePick ? 0.6 : 0.76;
    briMul = bluePick ? 0.75 : 0.9;
  } else if (editionIndex == 4) {
    boolean coolPick = noise(px * 0.006 + 900, py * 0.006) < 0.5;
    targetHue = coolPick ? 0.55 : 0.82; // dark cerulean OR magenta-purple
    briMul = 0.82;
  } else {
    targetHue = 0.07; // warm orange - complement to Plastic's cool cast
  }
  float h = lerpHue(hsb[0], targetHue, amt);
  float s = min(1, hsb[1] * 1.15 + 0.08);
  float b = constrain(hsb[2] * briMul, 0, 1);
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
    case 3: return new color[]{ color(184, 218, 218), color(160, 202, 240) }; // dusk teal + sky blue
    case 4: return new color[]{ color(240, 222, 172), color(247, 192, 208) }; // champagne + light pink
    case 5: return new color[]{ color(200, 219, 235), color(186, 223, 190) }; // cool blue-grey + light green
    default: return new color[]{ color(212, 184, 143), color(183, 205, 148) }; // soft brown + green
  }
}

// A real sky -> hazy horizon -> earth vertical structure, underneath each edition's own duo wash
// (kept as a tint on top so editions keep their distinct mood). Plant size/haze already scales by
// depth, but without an actual sky-to-ground background behind it, that scaling had nothing to play
// against - this gives the whole canvas a genuine "standing in a landscape" spatial structure.
color skyTop = color(94, 168, 214);
color skyHorizon = color(226, 216, 190);
color earthColor = color(90, 66, 44);

void drawEditionBackground(PGraphics pg) {
  color[] duo = editionBgColors();
  pg.noStroke();
  int cell = 8;
  float ns = 0.004; // low-frequency drift between the two colors
  for (int y = 0; y < height; y += cell) {
    float t = y / (float) height; // 0 = top (sky), 1 = bottom (earth)
    color vertical = (t < 0.6)
      ? lerpColor(skyTop, skyHorizon, constrain(t / 0.6, 0, 1))
      : lerpColor(skyHorizon, earthColor, constrain((t - 0.6) / 0.4, 0, 1));
    float lighten = map(y, 0, height, 0.1, 0.0);
    for (int x = 0; x < width; x += cell) {
      float n = noise(500 + x * ns, 500 + y * ns); // offset so the wash doesn't mirror the meadow clumps
      n = constrain(map(n, 0.35, 0.65, 0, 1), 0, 1); // Perlin clusters near 0.5 — widen that band so the two colors swing fully
      color editionWash = lerpColor(duo[0], duo[1], n);
      color c = lerpColor(vertical, editionWash, 0.28); // sky/earth is the structure; the edition wash is a lighter tint on top of it
      pg.fill(lerpColor(c, color(255), lighten));
      pg.rect(x, y, cell, cell);
    }
  }
  // Soft clouds in the upper sky, fixed-seed so they hold still between the cached layer and the
  // high-res export just like the grain below.
  java.util.Random cloudRng = new java.util.Random(777);
  for (int i = 0; i < 7; i++) {
    float ccx = cloudRng.nextFloat() * width;
    float ccy = cloudRng.nextFloat() * height * 0.32;
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
  java.util.Random grain = new java.util.Random(4242);
  for (int i = 0; i < 3000; i++) {
    float x = grain.nextFloat() * width;
    float y = grain.nextFloat() * height;
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
    case 1: return -1;
    case 2: return 3;
    case 3: return -2;
    case 5: return -2;
    default: return 0;
  }
}

float edPetalWidth() {
  switch (editionIndex) {
    case 1: return 0.75;
    case 2: return 1.35;
    case 3: return 0.65;
    case 4: return 1.1;
    case 5: return 0.8;
    default: return 1.0;
  }
}

float edFlowerSizeMul() {
  switch (editionIndex) {
    case 2: return 1.2;
    case 3: return 0.85;
    case 5: return 0.9;
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
  float s = max(hsb[1], 0.5);
  float b = max(hsb[2], 0.6);
  int rgb = Color.HSBtoRGB(hsb[0], s, b);
  return editionTint(color((rgb >> 16) & 255, (rgb >> 8) & 255, rgb & 255));
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

// Checks a candidate ad-panel position against every panel already placed this build - the actual
// mechanism behind "panels don't overlap/crowd each other."
boolean tooCloseToPanels(float x, float y, float margin) {
  for (PVector q : adPanels) if (dist(x, y, q.x, q.y) < margin) return true;
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
  // Keeps every panel's full rendered box fully inside the canvas - positions used to run all the way
  // to width/height with no allowance for the panel's own half-size, which clipped panels at the edge.
  float panelMargin = 100;
  for (Plant p : contourPlants) { // Ad Canopy billboards sprout at sparse background vine roots
    if (adPanels.size() >= 30) break;
    if (random(1) < 0.025) {
      float px = constrain(p.path.get(0).x, panelMargin, width - panelMargin);
      float py = constrain(p.path.get(0).y, panelMargin, height - panelMargin);
      if (!tooCloseToBody(px, py, 65) && !tooCloseToPanels(px, py, 100)) adPanels.add(new PVector(px, py, random(1000)));
    }
  }
  for (int i = 0; i < 28; i++) { // guaranteed baseline scatter, strictly off the figure, so the canopy always reads regardless of vine density
    float px = random(panelMargin, width - panelMargin), py = random(panelMargin, height - panelMargin);
    for (int tries = 0; tries < 20 && (tooCloseToBody(px, py, 65) || tooCloseToPanels(px, py, 100)); tries++) { px = random(panelMargin, width - panelMargin); py = random(panelMargin, height - panelMargin); }
    if (!tooCloseToBody(px, py, 65)) adPanels.add(new PVector(px, py, random(1000))); // skip rather than ever falling back onto the body
  }
  // Capped hard at 12 total, matching mintFaces.length - Currency Bloom only has 12 distinct metal
  // tones by design (each currency keeps ITS tone always, for identity), so more than 12 coins on
  // screen makes a colour repeat mathematically unavoidable.
  for (Plant p : plants) { // Currency Bloom seeds a handful of drifting coins from portrait plants
    if (coinDrops.size() >= 12) break;
    if (random(1) < 0.01) coinDrops.add(new PVector(p.path.get(0).x, random(-height, 0), random(1000)));
  }
  for (int i = 0; i < 6 && coinDrops.size() < 12; i++) { // small guaranteed baseline, not a space-filling flood
    coinDrops.add(new PVector(random(width), random(-height, 0), random(1000)));
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
// Lowered from 18 - at 18 this floor dominated almost every motif regardless of the flower's actual
// scale, flattening out size variety; 9 only kicks in for genuinely tiny flowers.
float visScale(Plant p) {
  return max(p.flowerSize * p.sizeScale, 9);
}

// A flat floor (like visScale() alone) quietly erases depth-of-field: p.flowerSize*p.sizeScale rarely
// exceeds ~17-20px even for near/large flowers, so almost every motif landed on the same flat floor
// regardless of depth - forefront and background motifs ending up the same size. This scales the floor
// itself by the motif's own canvas-Y position (same near=bottom/large, far=top/small convention the
// meadow already uses), so depth is preserved even where visScale() alone would be floored out.
float depthVisScale(Plant p, float canvasY, float minFloor, float maxFloor) {
  float t = constrain(canvasY / (float) height, 0, 1);
  return max(visScale(p), lerp(minFloor, maxFloor, t));
}

// The main plant grid now spans the whole area outside the figure (thousands of plants), so gating
// motifs to a fraction of flowers keeps each edition reading as a deliberate accent rather than
// turning every single bloom into an overlapping mess of tags/badges/coins.
boolean motifGate(Plant p) {
  return p.paletteSlot % (p.isFiller ? 22 : 8) == 0; // meadow filler is vast — keep its motifs sparse
}

// Edition 1 — Barcode Understory: every bloom doubles as a price tag, hung off the flower on a thread.
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
// one after another (which, following the plant lists' scan order, tend to be near each other on
// screen too) land on close-to-opposite hues instead of just "different but still similar."
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
// - 19 and 40 are coprime and close to half the palette length, maximizing the hue jump between tags
// drawn one after another. A light sepia blend keeps the mood without compressing the hue spread back
// toward sameness (a full editionTint hue-pull would otherwise quietly undo this).
color barcodePaperColor(Plant p) {
  color src = curatedBarcodePalette[(tagDrawCounter * 19 + sketchSeed) % curatedBarcodePalette.length];
  tagDrawCounter++;
  float[] hsb = Color.RGBtoHSB((int) red(src), (int) green(src), (int) blue(src), null);
  float paperSat = 0.28 + hashUnit(p.varietySeed, 5) * 0.55;
  float paperBri = 0.62 + hashUnit(p.varietySeed, 7) * 0.32;
  int rgb = Color.HSBtoRGB(hsb[0], paperSat, paperBri);
  color paper = color((rgb >> 16) & 255, (rgb >> 8) & 255, rgb & 255);
  return lerpColor(paper, color(235, 218, 190), 0.14);
}

void drawBarcodeTag(PGraphics pg, Plant p) {
  if (!(p.hasFlower && p.grown && motifGate(p))) return;
  PVector tip = p.path.get(p.path.size() - 1);
  float sway = swayOffset(p, p.path.size() - 1, p.path.size());
  // A UPC-style code needs real pixels to read as bars at all - a flat/small floor squeezes the code
  // down to sub-pixel-wide bars that merge into a solid black patch instead of reading as bars.
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
  // irregular-width bars/spaces driven by the plant's own varietySeed. 18 modules (not 36) - enough
  // for a dozen tags to need twice that many pixels before they'd merge into an unreadable smear.
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

  // The number is a caption under the code, grouped like a real UPC digit string, and scales WITH the
  // bars rather than a fixed-pixel floor.
  pg.fill(20);
  pg.textFont(uiFont);
  pg.textSize(constrain(tagH * 0.13, 3, tagH * 0.16));
  pg.textAlign(CENTER, CENTER);
  int code = p.varietySeed % 1000000;
  pg.text(nf(code / 1000, 3) + " " + nf(code % 1000, 3), 0, tagH * 0.36);
  // ~1 in 4 tags gets a thin tendril creeping partially across it - ties the sticker back into the
  // ecosystem instead of every tag sitting untouched on top.
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

// Edition 2 — Logo Bloom: flowers get branded with a spinning seal + monogram; a few go on "SALE".
void drawLogoBloom(PGraphics pg) {
  for (Plant p : plants) drawLogoBadge(pg, p);
  for (Plant p : bodyContourPlants) drawLogoBadge(pg, p);
  for (Plant p : contourPlants) drawLogoBadge(pg, p);
  for (Plant p : fillerPlants) drawLogoBadge(pg, p);
}

// Dedicated vivid brand hue, hash-based across the full wheel (not a short fixed array) - every badge
// reads as a bright trademark disc, and the wide sat/bri range keeps near-neighbors from landing on
// near-identical tones.
color logoBadgeColor(int seed) {
  float h = hashUnit(seed, 31);
  float s = 0.62 + hashUnit(seed, 37) * 0.36;
  float b = 0.68 + hashUnit(seed, 41) * 0.3;
  int rgb = Color.HSBtoRGB(h, s, b);
  return color((rgb >> 16) & 255, (rgb >> 8) & 255, rgb & 255);
}

// 5 bold, fully-filled abstract brand marks instead of a literal alphabet letter (which read as
// "the badges are just labeled A-Z", not actual trademark iconography) - a swoosh/crescent, a
// chevron, a ringed seal, a diamond, and ascending bars, hash-selected per badge.
void drawLogoMark(PGraphics pg, float sz, int seed) {
  int kind = int(hashUnit(seed, 53) * 5) % 5;
  pg.fill(255);
  if (kind == 0) { // swoosh / crescent
    pg.beginShape();
    pg.vertex(-sz * 0.55, sz * 0.25);
    pg.bezierVertex(-sz * 0.1, -sz * 0.5, sz * 0.4, -sz * 0.55, sz * 0.6, -sz * 0.3);
    pg.bezierVertex(sz * 0.3, -sz * 0.35, -sz * 0.05, -sz * 0.15, -sz * 0.3, sz * 0.35);
    pg.endShape(CLOSE);
  } else if (kind == 1) { // chevron
    pg.beginShape();
    pg.vertex(-sz * 0.5, sz * 0.4); pg.vertex(0, -sz * 0.45); pg.vertex(sz * 0.5, sz * 0.4);
    pg.vertex(sz * 0.28, sz * 0.4); pg.vertex(0, -sz * 0.05); pg.vertex(-sz * 0.28, sz * 0.4);
    pg.endShape(CLOSE);
  } else if (kind == 2) { // ringed seal
    pg.ellipse(0, 0, sz * 0.9, sz * 0.9);
    pg.fill(logoBadgeColor(seed));
    pg.ellipse(0, 0, sz * 0.5, sz * 0.5);
  } else if (kind == 3) { // diamond
    pg.beginShape();
    pg.vertex(0, -sz * 0.55); pg.vertex(sz * 0.42, 0); pg.vertex(0, sz * 0.55); pg.vertex(-sz * 0.42, 0);
    pg.endShape(CLOSE);
  } else { // ascending bars
    for (int i = 0; i < 3; i++) {
      float bh = sz * (0.35 + i * 0.25);
      pg.rect(-sz * 0.45 + i * sz * 0.42, sz * 0.4 - bh, sz * 0.26, bh);
    }
  }
}

void drawLogoBadge(PGraphics pg, Plant p) {
  // Extra 1-in-3 density gate on top of motifGate - badges are a deliberate accent, not every bloom.
  if (!(p.hasFlower && p.grown && motifGate(p) && p.varietySeed % 3 == 0)) return;
  PVector tip = p.path.get(p.path.size() - 1);
  float sway = swayOffset(p, p.path.size() - 1, p.path.size());
  float sz = visScale(p);
  color badge = logoBadgeColor(p.varietySeed);
  // Fixed per-badge hash-based tilt (stillFrame-driven, i.e. static since the scene is frozen) instead
  // of a shared spin, so badges don't all sit at the same angle.
  float tilt = hashUnit(p.varietySeed, 59) * TWO_PI;
  pg.pushMatrix();
  pg.translate(tip.x + sway, tip.y);
  pg.rotate(tilt + stillFrame * 0.004);
  pg.noStroke();
  pg.fill(badge);
  pg.ellipse(0, 0, sz * 1.8, sz * 1.8);
  pg.noFill();
  pg.stroke(255);
  pg.strokeWeight(sz * 0.09);
  pg.ellipse(0, 0, sz * 1.45, sz * 1.45);
  // Seed-varied rim glint - a short bright arc at a per-badge angle, instead of a flat uniform ring,
  // so the metallic-looking rim reads as catching light from a slightly different direction each time.
  pg.stroke(lerpColor(badge, color(255), 0.7));
  pg.strokeWeight(sz * 0.07);
  float glintA = hashUnit(p.varietySeed, 61) * TWO_PI;
  pg.arc(0, 0, sz * 1.45, sz * 1.45, glintA, glintA + PI * 0.35);
  pg.stroke(lerpColor(badge, color(255), 0.45));
  pg.strokeWeight(sz * 0.05);
  pg.ellipse(0, 0, sz * 1.95, sz * 1.95);
  pg.noStroke();
  drawLogoMark(pg, sz * 0.95, p.varietySeed);
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

// Real digital-ad CTA vocabulary, grouped by intent - each panel `kind` pulls from whichever category
// actually fits its content, rather than one flat word bank that could hand a discount poster a
// signup phrase.
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

// Picks the CTA vocabulary pool for a given panel `kind`.
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

// The ONLY source of panel text in this edition - no invented percentages, no hardcoded literals.
// Prefers pool entries that fit within maxChars so text stays a legible size instead of shrinking a
// long phrase to fit a small panel; falls back to the pool's own shortest entry if nothing qualifies.
String pickCta(String[] pool, int seed, int maxChars) {
  String shortest = pool[0];
  for (String s : pool) if (s.length() < shortest.length()) shortest = s;
  ArrayList<String> fits = new ArrayList<String>();
  for (String s : pool) if (s.length() <= maxChars) fits.add(s);
  if (fits.isEmpty()) return shortest;
  return fits.get(int(hashUnit(seed, 293) * fits.size()) % fits.size());
}

// Hard floor under every CTA text size in this edition so nothing ever goes illegibly small.
void adTextSize(PGraphics pg, float sz) { pg.textSize(max(9, sz)); }

// A curated, designed palette instead of raw per-panel HSB math - hues spaced by the golden angle
// (0.618034 turns), the standard technique for generating N colors maximally spread around the wheel
// regardless of how many you pick, so consecutively-added colors are always maximally distinct from
// each other (the whole reason to index this directly by panelIdx below, not through any extra
// permutation that would undo that property). Bold/vivid-only sat/bri combos.
color[] curatedAdPalette = new color[60];
void buildCuratedAdPalette() {
  float[][] svCombos = { {0.82, 0.88}, {0.68, 0.95}, {0.9, 0.7}, {0.55, 0.98} };
  for (int i = 0; i < curatedAdPalette.length; i++) {
    float h = (i * 0.618034) % 1.0;
    float[] sv = svCombos[i % svCombos.length];
    int rgb = Color.HSBtoRGB(h, sv[0], sv[1]);
    curatedAdPalette[i] = color((rgb >> 16) & 255, (rgb >> 8) & 255, rgb & 255);
  }
}

// Edition 3 — Ad Canopy: digital-style ad units (banner cards, CTA screens, discount posters) planted
// among the vines on slim modern stands, with vines creeping over their top edges. Panel size follows
// the same depth-of-field rule as the meadow: smaller and farther up the canvas, larger near the bottom.
void drawAdCanopy(PGraphics pg) {
  for (int panelIdx = 0; panelIdx < adPanels.size(); panelIdx++) {
    PVector ad = adPanels.get(panelIdx);
    float t = constrain(ad.y / (float) height, 0, 1); // depth: lower on canvas = closer = bigger
    int adSeed = int(ad.z * 997);
    float panelW = lerp(52, 118, t) * (0.85 + hashUnit(adSeed, 111) * 0.3);
    float panelH = panelW * 0.72; // landscape hoarding proportions
    int maxChars = panelW > 95 ? 26 : (panelW > 70 ? 18 : 12);
    pg.pushMatrix();
    pg.translate(ad.x, ad.y);
    pg.rotate((hashUnit(adSeed, 113) - 0.5) * 0.16); // slight hand-planted lean

    // Indexed DIRECTLY by panelIdx (not through any extra permutation) so consecutive panels keep the
    // palette's own maximal adjacent-hue separation; still guarantees no two panels share a color up
    // to 60 panels.
    color accent = curatedAdPalette[panelIdx % curatedAdPalette.length];

    pg.stroke(200, 205, 212);
    pg.strokeWeight(max(1.5, panelW * 0.025));
    pg.line(0, panelH * 0.42, 0, panelH * 0.95);
    pg.rectMode(CENTER);
    boolean smallPanel = panelW < 68; // distant/small boards get one bold word instead of a full layout
    int kind = int(ad.z * 3) % 8; // 8 genuinely distinct designs
    String cta = pickCta(poolForKind(kind), adSeed, maxChars);
    boolean digital = (kind == 3 || kind == 4);
    color frameCol = lerpColor(accent, color(0), 0.55);
    color faceCol = digital ? lerpColor(accent, color(20, 20, 28), 0.5) : lerpColor(accent, color(255, 250, 240), 0.35);
    pg.noStroke();
    pg.fill(frameCol);
    pg.rect(0, 0, panelW * 1.08, panelH * 1.14, 3);
    pg.fill(faceCol);
    pg.rect(0, 0, panelW, panelH, 2);
    // "Ad" disclosure tag, top corner
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
      pg.fill(adTextColor(faceCol));
      adTextSize(pg, min(panelH * 0.36, panelW * 0.88 / max(3, cta.length())));
      pg.text(cta.toUpperCase(), 0, 0);
    } else if (kind == 0) { // hero-image style digital ad card
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
      String button = pickCta(ctaShop, adSeed + 1, maxChars);
      adTextSize(pg, min(panelH * 0.08, panelW * 0.38 / max(4, button.length())));
      pg.text(button.toUpperCase(), 0, panelH * 0.36);
    } else if (kind == 1) { // discount poster
      pg.fill(accent);
      pg.rect(0, -panelH * 0.2, panelW * 0.88, panelH * 0.32);
      pg.fill(adTextColor(accent));
      adTextSize(pg, min(panelH * 0.24, panelW * 0.85 / max(4, cta.length())));
      pg.text(cta.toUpperCase(), 0, -panelH * 0.21);
      pg.fill(adTextColor(faceCol));
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
      pg.text(">>>", 0, panelH * 0.12);
      pg.fill(lerpColor(accent, faceCol, 0.5));
      pg.rect(0, panelH * 0.32, panelW * 0.6, panelH * 0.05, 2);
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
      pg.text("★★★★★", 0, -panelH * 0.16);
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

// Always-readable text/tag color for a given background - picks black or white by the background's
// actual brightness rather than assuming a fixed color per design kind.
color adTextColor(color bg) {
  return brightness(bg) > 150 ? color(28, 22, 16) : color(255);
}

// Edition 4 — Currency Bloom: flower centers become embossed coins; loose coins drift down the scene.
void drawCurrencyBloom(PGraphics pg) {
  for (Plant p : plants) drawCoinCenter(pg, p);
  for (Plant p : bodyContourPlants) drawCoinCenter(pg, p);
  for (Plant p : contourPlants) drawCoinCenter(pg, p);
  for (Plant p : fillerPlants) drawCoinCenter(pg, p);
  for (PVector c : coinDrops) drawFallingCoin(pg, c);
}

// World-currency mint: symbols from many currencies, struck in gold or silver. Index selection is
// deterministic per coin so each one keeps its identity between frames.
String[] currencySymbols = { "$", "€", "£", "¥", "₹", "₩", "₽", "¢" }; // $ € £ ¥ ₹ ₩ ₽ ¢

void drawCoinCenter(PGraphics pg, Plant p) {
  if (!(p.hasFlower && p.grown && motifGate(p))) return;
  PVector tip = p.path.get(p.path.size() - 1);
  float sway = swayOffset(p, p.path.size() - 1, p.path.size());
  float sz = visScale(p);
  boolean gold = (p.varietySeed / 11) % 2 == 0;
  color face = gold ? color(230, 190, 90) : color(212, 216, 224);
  color rim = gold ? color(150, 110, 30) : color(120, 126, 138);
  color ink = gold ? color(110, 80, 20) : color(70, 76, 88);
  String sym = currencySymbols[p.varietySeed % currencySymbols.length];
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
  pg.noStroke();
  pg.fill(ink);
  pg.textFont(uiFont);
  pg.textSize(sz * 0.52);
  pg.textAlign(CENTER, CENTER);
  pg.text(sym, 0, sz * 0.02);
  pg.popMatrix();
}

void drawFallingCoin(PGraphics pg, PVector c) {
  float speed = 0.6 + noise(c.z) * 1.2;
  float y = (c.y + stillFrame * speed) % (height + 60) - 30;
  float wobble = sin(stillFrame * 0.03 + c.z) * 10;
  float sz = 18 + noise(c.z + 5) * 18;
  boolean gold = int(c.z * 31) % 2 == 0;
  color face = gold ? color(230, 190, 90) : color(212, 216, 224);
  color rim = gold ? color(150, 110, 30) : color(120, 126, 138);
  color ink = gold ? color(110, 80, 20) : color(70, 76, 88);
  String sym = currencySymbols[int(c.z * 17) % currencySymbols.length];
  pg.pushMatrix();
  pg.translate(c.x + wobble, y);
  pg.rotate(stillFrame * 0.05 + c.z);
  pg.fill(face);
  pg.stroke(rim);
  pg.strokeWeight(1.5);
  pg.ellipse(0, 0, sz, sz * 0.85); // slight squash so the spin reads as a tumbling coin
  pg.noStroke();
  pg.fill(ink);
  pg.textFont(uiFont);
  pg.textSize(sz * 0.5);
  pg.textAlign(CENTER, CENTER);
  pg.text(sym, 0, 0);
  pg.popMatrix();
}

// Edition 5 — Plastic Garden: half the leaves get a plastic-bag skin; flower centers become bottle caps.
void drawPlasticGarden(PGraphics pg) {
  for (Plant p : plants) drawPlasticOverlay(pg, p);
  for (Plant p : bodyContourPlants) drawPlasticOverlay(pg, p);
  for (Plant p : contourPlants) drawPlasticOverlay(pg, p);
  for (Plant p : fillerPlants) drawPlasticOverlay(pg, p);
}

void drawPlasticOverlay(PGraphics pg, Plant p) {
  // Two-level gate: only ~1 in 4 plants catches any plastic at all, and only at some leaf joints —
  // otherwise the sheer number of leaves in the scene turns the overlay into a solid blanket.
  if (p.paletteSlot % 4 == 0) {
    // Grocery-bag palette: translucent white, pink, blue, yellow, green, orange.
    color[] bagCols = {
      color(245, 248, 252), color(255, 165, 190), color(140, 195, 255),
      color(255, 220, 110), color(150, 225, 165), color(245, 155, 90)
    };
    for (Leaf lf : p.leaves) {
      if (lf.attachIndex >= p.path.size()) continue;
      if ((lf.attachIndex + p.paletteSlot) % 6 != 0) continue;
      PVector base = p.path.get(lf.attachIndex);
      float sway = swayOffset(p, lf.attachIndex, p.path.size());
      float s = max(lf.size * p.sizeScale, 10) * 1.7; // bag height
      color bc = bagCols[(lf.attachIndex + p.varietySeed) % bagCols.length];
      pg.pushMatrix();
      pg.translate(base.x + sway, base.y);
      // an actual carrier bag snagged on the stem, dangling and swinging below its handles
      pg.rotate(sin(stillFrame * 0.03 + lf.angle * 3) * 0.18 + (lf.angle > 0 ? 0.12 : -0.12));
      pg.noFill();
      pg.stroke(bc, 230);
      pg.strokeWeight(max(1, s * 0.07));
      pg.arc(-s * 0.13, 0, s * 0.2, s * 0.3, PI, TWO_PI); // two handle loops
      pg.arc(s * 0.13, 0, s * 0.2, s * 0.3, PI, TWO_PI);
      pg.noStroke();
      pg.fill(bc, 185);
      pg.beginShape(); // body: slightly flaring, crumpled at the bottom
      pg.vertex(-s * 0.26, 0);
      pg.vertex(s * 0.26, 0);
      pg.bezierVertex(s * 0.36, s * 0.35, s * 0.4, s * 0.7, s * 0.3, s * 0.92);
      pg.bezierVertex(s * 0.1, s * 1.02, -s * 0.14, s * 0.96, -s * 0.32, s * 0.88);
      pg.bezierVertex(-s * 0.4, s * 0.62, -s * 0.34, s * 0.3, -s * 0.26, 0);
      pg.endShape(CLOSE);
      pg.stroke(255, 190); // crinkle highlights
      pg.strokeWeight(0.8);
      pg.line(-s * 0.08, s * 0.15, s * 0.04, s * 0.65);
      pg.line(s * 0.14, s * 0.2, s * 0.08, s * 0.55);
      pg.popMatrix();
    }
  }
  if (p.hasFlower && p.grown && motifGate(p)) {
    // plastic screw-caps in mixed colors instead of blooms
    color[] capCols = {
      color(225, 60, 50), color(45, 120, 220), color(250, 200, 45),
      color(60, 180, 95), color(245, 245, 245), color(250, 140, 40), color(150, 90, 210)
    };
    color cc = capCols[p.varietySeed % capCols.length];
    PVector tip = p.path.get(p.path.size() - 1);
    float sway = swayOffset(p, p.path.size() - 1, p.path.size());
    float sz = visScale(p);
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
    pg.popMatrix();
  }
}

// ---------------- Input ----------------

void keyPressed() {
  if (key == 'c' || key == 'C') {
    colorModeIndex++;
    if (colorModeIndex > palettes.size()) colorModeIndex = -1;
    println("Color mode: " + colorModeName());
  } else if (key == 'x' || key == 'X') {
    int[] fresh = new int[5];
    for (int i = 0; i < 5; i++) fresh[i] = color(random(255), random(255), random(255));
    palettes.add(fresh);
    paletteNames = append(paletteNames, "Random" + palettes.size());
    colorModeIndex = palettes.size() - 1;
    println("Added a new random palette and switched to it.");
  } else if (key == 'r' || key == 'R') {
    randomSeed(sketchSeed); // without this, rebuilding just continues the drifting random stream -
    noiseSeed(sketchSeed);  // reseeding here means R always returns to the exact same canonical layout
    buildAll();
  } else if (key == 'h' || key == 'H') {
    printControls();
  } else if (key == 'm' || key == 'M') {
    showBodyMaskDebug = !showBodyMaskDebug;
    println(showBodyMaskDebug ? "Body mask debug overlay ON (translucent red = detected as figure)."
                              : "Body mask debug overlay OFF.");
  } else if (key == 's' || key == 'S') {
    saveHighResJPEG();
  } else if (key == 'v' || key == 'V') {
    toggleRecording();
  } else if (key == 'q' || key == 'Q') {
    hueShift -= 8;
  } else if (key == 'e' || key == 'E') {
    hueShift += 8;
  } else if (key == 'a' || key == 'A') {
    briMult = constrain(briMult - 0.05, 0.3, 1.8);
  } else if (key == 'd' || key == 'D') {
    briMult = constrain(briMult + 0.05, 0.3, 1.8);
  } else if (key == '[') {
    satMult = constrain(satMult - 0.08, 0, 2);
  } else if (key == ']') {
    satMult = constrain(satMult + 0.08, 0, 2);
  } else if (key == '1') {
    activeTarget = 0;
    println("Now adjusting: Background image");
  } else if (key == '2') {
    activeTarget = 1;
    println("Now adjusting: Source image");
  } else if (key == '-' || key == '_') {
    adjustScale(-0.05);
  } else if (key == '=' || key == '+') {
    adjustScale(0.05);
  } else if (keyCode == UP) {
    adjustOffset(0, -8);
  } else if (keyCode == DOWN) {
    adjustOffset(0, 8);
  } else if (keyCode == LEFT) {
    adjustOffset(-8, 0);
  } else if (keyCode == RIGHT) {
    adjustOffset(8, 0);
  } else if (key == 'n' || key == 'N') {
    editionIndex = (editionIndex + 1) % editionNames.length;
    println("Edition: " + editionNames[editionIndex]);
  } else if (key == 'b' || key == 'B') {
    editionIndex = (editionIndex - 1 + editionNames.length) % editionNames.length;
    println("Edition: " + editionNames[editionIndex]);
  } else if (key == 'f' || key == 'F') {
    exportAllEditions();
  } else if (key == 'g' || key == 'G') {
    animateGrowth = !animateGrowth;
    println(animateGrowth ? "Growth animation ON — rebuilding from seed (use with V to record an MP4)."
                          : "Growth animation OFF — snapping to the finished artwork.");
    buildAll();
  }

  // Color, palette, hue/sat/brightness, and placement keys all change how the cached botanical layer
  // should look — flag it for re-render on the next frame. (Cheap to do for every key.)
  plantLayerDirty = true;
}

void adjustOffset(float dx, float dy) {
  if (activeTarget == 0) { bgOffsetX += dx; bgOffsetY += dy; }
  else { srcOffsetX += dx; srcOffsetY += dy; }
}

void adjustScale(float ds) {
  if (activeTarget == 0) bgScale = constrain(bgScale + ds, 0.1, 5);
  else srcScale = constrain(srcScale + ds, 0.1, 5);
}

void mousePressed() {
  color sampled = get(mouseX, mouseY); // grabs whatever is rendered at that canvas pixel
  customPalette.add(sampled);
  colorModeIndex = palettes.size();
  plantLayerDirty = true;
  println("Sampled a color from the canvas. Custom palette size: " + customPalette.size());
}

// ---------------- Save / export ----------------

void saveHighResJPEG() {
  saveHighResJPEG(editionSlug(editionIndex));
}

void saveHighResJPEG(String label) {
  PGraphics pg = createGraphics(width * printScale, height * printScale);
  pg.beginDraw();
  pg.scale(printScale);
  drawEditionBackground(pg); // after scale(), so the gradient spans the canvas in sketch coordinates
  float[] bgPlace = computePlacement(bgImg, bgScale, bgOffsetX, bgOffsetY);
  pg.image(bgImgKeyed, bgPlace[0], bgPlace[1], bgPlace[2], bgPlace[3]);
  pg.image(bodyTextureLayer, 0, 0);
  for (Plant p : depthSortedAllPlants()) p.display(pg);
  drawConsumerLayer(pg); // painted last so it always reads as the top layer, unobstructed
  pg.endDraw();
  String filename = "output/plant_print_" + label + "_seed" + sketchSeed + "_" + timestamp() + ".jpg";
  pg.save(filename);
  println("Saved high-res JPEG: " + filename + " (" + pg.width + "x" + pg.height + "px) [seed " + sketchSeed + "]");
}

String editionSlug(int idx) {
  return idx + "_" + editionNames[idx].replaceAll("[^A-Za-z0-9]+", "");
}

// Exports all 5 finished editions (plus the original) as separate high-res JPEGs in one go, using
// the current fully-grown scene — no need to wait through, or capture, the growth animation for this.
void exportAllEditions() {
  int savedEdition = editionIndex;
  for (int i = 0; i < editionNames.length; i++) {
    editionIndex = i;
    saveHighResJPEG(editionSlug(i));
  }
  editionIndex = savedEdition;
  println("Exported all " + editionNames.length + " editions to output/.");
}

void toggleRecording() {
  recording = !recording;
  if (recording) {
    videoExport = new VideoExport(this, "output/PlantGrowth_seed" + sketchSeed + "_" + timestamp() + ".mp4");
    videoExport.setFrameRate(30);
    videoExport.startMovie();
    println("Recording started...");
  } else {
    videoExport.endMovie();
    println("Recording saved to the output/ folder.");
  }
}

String timestamp() {
  return year() + nf(month(), 2) + nf(day(), 2) + "_" + nf(hour(), 2) + nf(minute(), 2) + nf(second(), 2);
}

void printControls() {
  println("--- Controls ---");
  println("C: cycle color palette   X: add a new random palette   Click canvas: sample a color into Custom");
  println("Q/E: hue   A/D: brightness   [ / ]: saturation");
  println("1: select Background, 2: select Source image, then Arrows: move it, -/=: scale it");
  println("R: rebuild all plants (do this after moving/scaling images)");
  println("M: toggle body-mask debug overlay (translucent red = detected as figure)");
  println("S: save high-res JPEG   V: start/stop MP4 recording   H: print this list again");
  println("N/B: next/previous consumer-culture edition — " + join(editionNames, " | "));
  println("F: export all 5 editions as final high-res JPEGs in one go");
  println("G: toggle growth animation (off = finished artwork instantly; on = watch it grow, for MP4s)");
}
