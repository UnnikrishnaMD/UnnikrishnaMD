// OCCUPY · Exhibition 2 (NODE, Palo Alto) — the plant-growth system adapted for NODE's three surfaces.
//
// One sketch, three outputs: the 8,640 x 2,160 projector wall and the two 1,600 x 1,600 LED pools.
// Each surface plays its own sequence of the six pieces (one per edition). Every piece grows from the
// bare figure to the full meadow while a grunge type grid behind the figure erodes into abstract forms,
// then crossfades into the next piece - and the last piece crossfades back into the first, so the file
// loops without a jump.
//
// The window is a reduced-scale preview of exactly what gets rendered. V renders the exact-resolution
// master MP4 for NODE's File Upload; encode_for_node.sh then fits it under the 500 MB upload limit.
// The garden itself (plants, species, editions, consumer layer) lives in Garden.pde; layers, the type
// grid, stills and the ffmpeg pipe live in Compositor.pde.
import java.awt.Color;    // used only for RGB<->HSB conversion in shiftColor()

// ---------- Which surface this run is for ----------
// Change this, or pass surface=wall / surface=pool1 / surface=pool2 as a command-line argument.
String surfaceName = "wall";

class Surface {
  String name;
  int outW, outH;          // the exact file size NODE's File Upload asks for
  int W, H;                // the logical canvas the garden is laid out in - every coordinate in Garden.pde
  float margin, gutter;    // type-grid safe area and gutters, in OUTPUT pixels (NODE gives no safe area - this one is ours)
  int cols, rows;
  int[] playlist;          // which PIECES this surface plays, in order
  float figureScale, figureOffsetX, figureOffsetY; // figure placement; offsets as a fraction of the logical canvas
  boolean rotateCells;     // pools are (probably) seen from above - letters face every direction, no single "up"
  float growSeconds, holdSeconds;

  Surface(String name, int outW, int outH, int W, int H, float margin, float gutter, int cols, int rows,
          int[] playlist, float figureScale, float figureOffsetX, float figureOffsetY, boolean rotateCells,
          float growSeconds, float holdSeconds) {
    this.name = name;
    this.outW = outW;
    this.outH = outH;
    this.W = W;
    this.H = H;
    this.margin = margin;
    this.gutter = gutter;
    this.cols = cols;
    this.rows = rows;
    this.playlist = playlist;
    this.figureScale = figureScale;
    this.figureOffsetX = figureOffsetX;
    this.figureOffsetY = figureOffsetY;
    this.rotateCells = rotateCells;
    this.growSeconds = growSeconds;
    this.holdSeconds = holdSeconds;
  }

  float outScale() { return outW / (float) W; } // output pixels per logical pixel
}

// The wall's logical canvas is 3840 x 960 (x2.25 = 8640 x 2160): the figure keeps roughly the on-canvas
// size it was tuned at in the original 1920 x 1080 sketch, relative to the plants, and the extra width
// becomes open meadow on either side. Type grid: 240px margin, 6 x 6 CTA cells (~1340 x 260px) with
// 24px gutters. Pools: 80px margin, 2 x 6 cells (~708 x 220px).
// Wall timing: 6 pieces x (18s grow + 6s hold) = 2:24, which keeps the master well inside 500 MB at 8640px.
// The pools play three pieces each, slower, since their files are small.
Surface[] SURFACES = {
  new Surface("wall",  8640, 2160, 3840, 960,  240, 24, 6, 6, new int[]{0, 1, 2, 3, 4, 5}, 0.92, 0,     0.02, false, 18, 6),
  new Surface("pool1", 1600, 1600, 1600, 1600, 80,  24, 2, 6, new int[]{0, 2, 4},          0.95, 0,     0,    true,  30, 10),
  new Surface("pool2", 1600, 1600, 1600, 1600, 80,  24, 2, 6, new int[]{1, 3, 5},          0.95, 0,     0,    true,  30, 10)
};

// ---------- The six pieces ----------
// Same system throughout; each piece is one edition. Change `drawing` per piece to give it its own base
// drawing (put the files in data/). A drawing whose figure is NOT one flat fill colour - e.g. a painted,
// multi-coloured figure - needs a `mask`: a black/white PNG the same size as the drawing, white where
// the figure is. Leave mask "" to detect the figure by its dominant fill hue, as before.
// faceZone is in the drawing's pixel space after it's scaled to 1920px wide (null = no face protection).
// The type grid's CTAs are drawn at random from the sketch's own CTA lists (see ctaVocabulary), a
// different spread per piece.
class Piece {
  String title;
  int edition;
  String drawing, mask;
  int seed;
  float[] faceZone;

  Piece(String title, int edition, String drawing, String mask, int seed, float[] faceZone) {
    this.title = title;
    this.edition = edition;
    this.drawing = drawing;
    this.mask = mask;
    this.seed = seed;
    this.faceZone = faceZone;
  }
}

float[] RECLINING_FACE = {170, 190, 470, 490}; // identified by inspecting recliningman.png in the original sketch

Piece[] PIECES = {
  new Piece("I · Botanical",          0, "recliningman.jpg", "", 42, RECLINING_FACE),
  new Piece("II · Barcode Understory", 1, "recliningman.jpg", "", 42, RECLINING_FACE),
  new Piece("III · Logo Bloom",        2, "recliningman.jpg", "", 42, RECLINING_FACE),
  new Piece("IV · Ad Canopy",          3, "recliningman.jpg", "", 42, RECLINING_FACE),
  new Piece("V · Currency Bloom",      4, "recliningman.jpg", "", 42, RECLINING_FACE),
  new Piece("VI · Plastic Garden",     5, "recliningman.jpg", "", 42, RECLINING_FACE)
};

// ---------- Timeline / render state ----------
Surface S;
int W, H;               // logical canvas - what width/height meant in the original sketch
float previewScale;     // window size as a fraction of the output size
float layerScale;       // pixels per logical pixel for the layers currently built (preview or full output)
int fps = 30;
float xfadeSeconds = 2;
int pieceSlot = 0;      // index into S.playlist
int pieceFrame = 0;
float tPiece = 0;       // seconds into the current piece
boolean paused = false;
boolean rendering = false;
boolean renderOnLaunch = false, stillsOnLaunch = false, exitWhenDone = false;
int seedOverride = -1;
int renderFrameIndex = 0, renderFrameTotal = 0;
long renderStartMillis = 0;

void settings() {
  parseArgs();
  S = surfaceByName(surfaceName);
  W = S.W;
  H = S.H;
  previewScale = min(1, min(1800.0 / S.outW, 900.0 / S.outH));
  size(max(200, round(S.outW * previewScale)), max(200, round(S.outH * previewScale)));
}

void setup() {
  frameRate(fps);
  uiFont = createFont("SansSerif.bold", 96, true);
  typeFont = createFont(typeFontName, 200, true);
  buildPalettes();
  buildCuratedAdPalette();
  buildCuratedPlasticPalette();
  buildCuratedBarcodePalette();

  bgScale = srcScale = S.figureScale;
  bgOffsetX = srcOffsetX = S.figureOffsetX * W;
  bgOffsetY = srcOffsetY = S.figureOffsetY * H;

  java.io.File outDir = new java.io.File(sketchPath("output"));
  if (!outDir.exists()) outDir.mkdir();
  println("BUILD: " + BUILD_TAG);
  println("Surface: " + S.name + " - output " + S.outW + "x" + S.outH + ", logical " + W + "x" + H
          + ", preview " + width + "x" + height + ", " + S.playlist.length + " pieces, "
          + nf(totalSeconds(), 0, 1) + "s loop");

  layerScale = previewLayerScale();
  startPiece(0);
  printControls();
  if (stillsOnLaunch) {
    exportAllStills();
    if (exitWhenDone && !renderOnLaunch) exit();
  }
  if (renderOnLaunch) startRender();
}

void draw() {
  boolean advancing = rendering || !paused;
  stepTimeline();
  composeFrame(frame);
  if (rendering) {
    ffmpeg.write(frame);
    renderFrameIndex++;
  }

  // While rendering, the window only refreshes every 10th frame - pushing an 8640px frame to the
  // window costs about as much as a tenth of drawing it.
  if (!rendering || renderFrameIndex % 10 == 1) {
    background(0);
    image(frame, 0, 0, width, height);
  }
  if (showBodyMaskDebug) {
    if (bodyMaskDebugLayer == null) buildBodyMaskDebugLayer();
    image(bodyMaskDebugLayer, 0, 0, width, height);
  }
  // Window-only diagnostic label - drawn straight to the window, never into `frame`, so it never
  // appears in a render or a still.
  noStroke();
  fill(0, 150);
  rect(0, 0, min(width, 900), 30);
  fill(255, 235);
  textFont(uiFont);
  textSize(15);
  textAlign(LEFT, TOP);
  text(statusLine(), 8, 7);

  if (advancing) advanceClock();
}

String statusLine() {
  Piece pc = PIECES[S.playlist[pieceSlot]];
  if (rendering) {
    float done = renderFrameIndex / (float) max(1, renderFrameTotal);
    float elapsed = (millis() - renderStartMillis) / 1000.0;
    float eta = done > 0 ? elapsed / done - elapsed : 0;
    return "RENDERING " + S.name + "  frame " + renderFrameIndex + "/" + renderFrameTotal
           + "  (" + nf(done * 100, 0, 1) + "%, ~" + nf(eta / 60, 0, 1) + " min left)  " + pc.title;
  }
  return S.name + "  " + pc.title + "  t " + nf(tPiece, 0, 1) + "/" + nf(pieceDuration(), 0, 1) + "s"
         + (paused ? "  PAUSED" : "") + "  |  build " + BUILD_TAG;
}

// ---------------- Timeline ----------------

float pieceDuration() { return S.growSeconds + S.holdSeconds; }
int framesPerPiece() { return max(1, round(pieceDuration() * fps)); }
float totalSeconds() { return pieceDuration() * S.playlist.length; }
float previewLayerScale() { return S.outScale() * previewScale; }

// Advances growth, type erosion and the consumer-layer reveal to the current time.
void stepTimeline() {
  float gp = constrain(tPiece / S.growSeconds, 0, 1);
  if (!allGrown) {
    growLists(gp);
    if (gp >= 1) forceAllGrown();
  }
  erosion = erosionAt(tPiece);
  // Billboards and drifting coins arrive late in the growth and settle in during the hold, instead of
  // standing in an empty field from the first frame.
  consumerReveal = constrain(map(tPiece, S.growSeconds * 0.55, S.growSeconds + S.holdSeconds * 0.5, 0, 1), 0, 1);
}

void advanceClock() {
  pieceFrame++;
  tPiece = pieceFrame / (float) fps;
  if (pieceFrame >= framesPerPiece()) {
    prevFrame = frame.get(); // the next piece crossfades out of this exact frame
    int next = pieceSlot + 1;
    if (next >= S.playlist.length) {
      next = 0;
      if (rendering) {
        finishRender();
        return;
      }
    }
    startPiece(next);
  }
}

void startPiece(int slot) {
  pieceSlot = slot;
  applyPiece(PIECES[S.playlist[slot]]);
  randomSeed(sketchSeed);
  noiseSeed(sketchSeed);
  buildAll();
  setupGrowth();
  buildLayers();
  pieceFrame = 0;
  tPiece = 0;
}

void applyPiece(Piece pc) {
  editionIndex = pc.edition;
  sketchSeed = seedOverride >= 0 ? seedOverride : pc.seed;
  loadDrawing(pc.drawing, pc.mask);
  if (pc.faceZone != null) {
    faceZoneX0 = pc.faceZone[0];
    faceZoneY0 = pc.faceZone[1];
    faceZoneX1 = pc.faceZone[2];
    faceZoneY1 = pc.faceZone[3];
  } else {
    faceZoneX0 = 1; faceZoneY0 = 1; faceZoneX1 = 0; faceZoneY1 = 0; // empty box - nothing is ever inside it
  }
  typeInk = typeInkFor(editionIndex);
  bodyMaskDebugLayer = null;
}

// ---------------- Rendering ----------------

void startRender() {
  String ff = findFfmpeg();
  if (ff == null) {
    println("Can't render: ffmpeg not found. Install it (macOS: brew install ffmpeg) or set ffmpegPath in Compositor.pde.");
    return;
  }
  layerScale = S.outScale();
  // Seamless loop: the video opens by crossfading out of the exact frame it ends on, so build that
  // closing frame first - the last piece, fully grown, at its final erosion state.
  println("Preparing the loop's closing frame...");
  startPiece(S.playlist.length - 1);
  pieceFrame = framesPerPiece() - 1;
  tPiece = pieceFrame / (float) fps;
  stepTimeline();
  composeFrame(frame);
  prevFrame = frame.get();

  startPiece(0);
  String file = "output/occupy_" + S.name + "_master.mp4";
  try {
    ffmpeg = new FfmpegPipe(ff, sketchPath(file), frame.width, frame.height, fps, sketchPath("output/ffmpeg_" + S.name + ".log"));
  } catch (Exception e) {
    println("Couldn't start ffmpeg: " + e.getMessage());
    layerScale = previewLayerScale();
    startPiece(0);
    return;
  }
  renderFrameIndex = 0;
  renderFrameTotal = framesPerPiece() * S.playlist.length;
  renderStartMillis = millis();
  rendering = true;
  println("Rendering " + renderFrameTotal + " frames at " + frame.width + "x" + frame.height + " to " + file);
}

void finishRender() {
  ffmpeg.close();
  rendering = false;
  float mins = (millis() - renderStartMillis) / 60000.0;
  println("Render finished in " + nf(mins, 0, 1) + " min: output/occupy_" + S.name + "_master.mp4");
  println("Next: ./encode_for_node.sh output/occupy_" + S.name + "_master.mp4  (fits it under NODE's 500 MB limit)");
  if (exitWhenDone) {
    exit();
    return;
  }
  layerScale = previewLayerScale();
  prevFrame = null;
  startPiece(0);
}

// ---------------- Arguments ----------------
// surface=wall|pool1|pool2   render (render the video, then keep previewing)   stills (save every
// piece's final frame)   exit (quit when done)   seed=N   grow=SECONDS   hold=SECONDS
// e.g. processing-java --sketch=occupy_garden --run surface=wall render exit
float growOverride = -1, holdOverride = -1;

void parseArgs() {
  if (args == null) return;
  for (String a : args) {
    if (a.startsWith("surface=")) surfaceName = a.substring(8);
    else if (a.equals("render")) renderOnLaunch = true;
    else if (a.equals("stills")) stillsOnLaunch = true;
    else if (a.equals("exit")) exitWhenDone = true;
    else if (a.startsWith("seed=")) seedOverride = parseInt(a.substring(5));
    else if (a.startsWith("grow=")) growOverride = parseFloat(a.substring(5));
    else if (a.startsWith("hold=")) holdOverride = parseFloat(a.substring(5));
    else println("Ignoring unknown argument: " + a);
  }
}

Surface surfaceByName(String name) {
  for (Surface s : SURFACES) {
    if (s.name.equals(name)) {
      if (growOverride > 0) s.growSeconds = growOverride;
      if (holdOverride >= 0) s.holdSeconds = holdOverride;
      return s;
    }
  }
  println("Unknown surface '" + name + "' - using wall.");
  return surfaceByName("wall");
}

// ---------------- Input ----------------

void keyPressed() {
  if (rendering) return; // nothing interactive while a render is running - it would change the output
  if (key == ' ') {
    paused = !paused;
  } else if (key == 'n' || key == 'N') {
    prevFrame = frame.get();
    startPiece((pieceSlot + 1) % S.playlist.length);
  } else if (key == 'b' || key == 'B') {
    prevFrame = frame.get();
    startPiece((pieceSlot - 1 + S.playlist.length) % S.playlist.length);
  } else if (key == 'r' || key == 'R') {
    prevFrame = null;
    startPiece(pieceSlot); // rebuild with the current placement/colour settings, from seed
  } else if (key == 's' || key == 'S') {
    saveStill(editionSlug(editionIndex) + "_t" + nf(tPiece, 0, 1));
  } else if (key == 'f' || key == 'F') {
    exportAllStills();
  } else if (key == 'v' || key == 'V') {
    startRender();
  } else if (key == 'm' || key == 'M') {
    showBodyMaskDebug = !showBodyMaskDebug;
    println(showBodyMaskDebug ? "Body mask debug overlay ON (translucent red = detected as figure)."
                              : "Body mask debug overlay OFF.");
  } else if (key == 'h' || key == 'H') {
    printControls();
  } else if (key == 'c' || key == 'C') {
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
  }
  // Colour keys change how plants are painted - re-render the cached grown-plant layer next frame.
  plantsCacheDirty = true;
}

void adjustOffset(float dx, float dy) {
  if (activeTarget == 0) { bgOffsetX += dx; bgOffsetY += dy; }
  else { srcOffsetX += dx; srcOffsetY += dy; }
  printPlacement();
}

void adjustScale(float ds) {
  if (activeTarget == 0) bgScale = constrain(bgScale + ds, 0.1, 5);
  else srcScale = constrain(srcScale + ds, 0.1, 5);
  printPlacement();
}

// Placement changes only take effect on R (rebuild). Prints the values in the form SURFACES expects,
// so a placement found by eye can be pasted back in and kept.
void printPlacement() {
  println("Placement (press R to rebuild) - figureScale " + nf(bgScale, 0, 2)
          + ", figureOffsetX " + nf(bgOffsetX / W, 0, 3) + ", figureOffsetY " + nf(bgOffsetY / H, 0, 3)
          + (activeTarget == 1 ? "   [source image: " + nf(srcScale, 0, 2) + ", " + nf(srcOffsetX / W, 0, 3) + ", " + nf(srcOffsetY / H, 0, 3) + "]" : ""));
}

void mousePressed() {
  color sampled = get(mouseX, mouseY); // grabs whatever is rendered at that window pixel
  customPalette.add(sampled);
  colorModeIndex = palettes.size();
  plantsCacheDirty = true;
  println("Sampled a color from the canvas. Custom palette size: " + customPalette.size());
}

void printControls() {
  println("--- Controls ---");
  println("SPACE: pause/play   N/B: next/previous piece   R: rebuild this piece from seed");
  println("S: save this frame as a full-resolution PNG   F: save every piece's final frame as full-resolution PNGs");
  println("V: render this surface's full looping MP4 at NODE's exact resolution (then run encode_for_node.sh)");
  println("M: toggle body-mask debug overlay (translucent red = detected as figure)   H: print this list again");
  println("C: cycle color palette   X: add a new random palette   Click canvas: sample a color into Custom");
  println("Q/E: hue   A/D: brightness   [ / ]: saturation");
  println("1: select Background, 2: select Source image, then Arrows: move it, -/=: scale it, R to apply");
}
