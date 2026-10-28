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
float erosionEnd = 0.88;   // how far it gets by the end of the hold (1 = nothing left)

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
  plantsCache.scale(layerScale);
  for (Plant p : depthSortedAllPlants()) p.display(plantsCache);
  plantsCache.endDraw();
  plantsCacheDirty = false;
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
    f.pushMatrix();
    f.scale(layerScale);
    for (Plant p : depthSortedAllPlants()) p.display(f);
    f.popMatrix();
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
// A grid of advertising calls to action spread across the whole canvas inside the safe margin, behind
// the figure - a different random CTA in each cell, all set at one size, left-aligned to the cell. The
// plants grow over it, vines root on the letter outlines (typePlants), and over the piece the letters
// erode - edges first, through noise - until only abstract letter fragments remain. Erosion is a fixed
// per-pixel threshold map compared against one number per frame, so it costs almost nothing to animate
// and the grain stays still (moving grain would be both noisy and expensive to encode).

String typeFontName = "SansSerif.bold"; // any installed font name, or a .ttf/.otf placed in data/
final float CAP_HEIGHT = 0.72;          // cap height as a fraction of font size (Helvetica/Arial bold) - for vertical centring
float typeCellFill = 0.8;               // fraction of cells that get a CTA - the gaps let the grid breathe
int typeMaxChars = 11;                  // longest CTA used: keeps one shared type size from shrinking to fit a long phrase
float typeVineCell = 34;                // min spacing between vines rooted on letter outlines (logical px)
float typeVineKeepProb = 0.35;
color typeInk;

class TypeCell {
  float cx, cy;
  String words;
  int rot; // quarter turns
  TypeCell(float cx, float cy, String words, int rot) {
    this.cx = cx;
    this.cy = cy;
    this.words = words;
    this.rot = rot;
  }
}

// The grid's vocabulary: every short entry in the sketch's own CTA lists (the same ones Ad Canopy draws
// from), uppercased and de-duplicated - so the type never says anything the ad layer couldn't.
ArrayList<String> ctaVocabulary() {
  String[][] pools = { ctaShop, ctaUrgency, ctaLearn, ctaDiscount, ctaBrand, ctaDigitalScreen, ctaCountdown };
  ArrayList<String> words = new ArrayList<String>();
  for (String[] pool : pools) {
    for (String s : pool) {
      String u = s.toUpperCase();
      if (u.length() <= typeMaxChars && !words.contains(u)) words.add(u);
    }
  }
  return words;
}

ArrayList<TypeCell> typeCells = new ArrayList<TypeCell>();
ArrayList<Plant> typePlants = new ArrayList<Plant>(); // vines rooted on the letters' outlines
PFont typeFont;
float typeSize = 100, typeCellW, typeCellH;
PImage typeImg;
int[] typeIdx = new int[0];   // pixel index of every inked letter pixel
byte[] typeThr = new byte[0]; // its erosion threshold: visible while threshold > erosion
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
  typeCellW = (W - 2 * m - (S.cols - 1) * gut) / S.cols;
  typeCellH = (H - 2 * m - (S.rows - 1) * gut) / S.rows;
  ArrayList<String> vocab = ctaVocabulary();

  // Its own generator, seeded by piece seed AND edition, so each piece gets a different spread of CTAs
  // even though all six share one seed - and the garden's random() stream is left untouched.
  java.util.Random rng = new java.util.Random(sketchSeed * 7919L + editionIndex * 104729L);
  String[][] grid = new String[S.rows][S.cols];
  for (int r = 0; r < S.rows; r++) {
    for (int c = 0; c < S.cols; c++) {
      if (rng.nextFloat() > typeCellFill) continue;
      String pick;
      int tries = 0;
      do { // never the same CTA as the cell to the left or above
        pick = vocab.get(rng.nextInt(vocab.size()));
        tries++;
      } while (tries < 20 && ((c > 0 && pick.equals(grid[r][c - 1])) || (r > 0 && pick.equals(grid[r - 1][c]))));
      grid[r][c] = pick;
      // Pools are seen from above by people on every side: a cell reads either way up, never sideways,
      // since a rotated phrase wouldn't fit its wide cell.
      int rot = S.rotateCells && rng.nextFloat() < 0.5 ? 2 : 0;
      float cx = m + c * (typeCellW + gut) + typeCellW * 0.5;
      float cy = m + r * (typeCellH + gut) + typeCellH * 0.5;
      typeCells.add(new TypeCell(cx, cy, pick, rot));
    }
  }
  if (typeCells.isEmpty()) return;

  // One size for the whole grid, fitted so the longest CTA actually placed fills its cell, so the grid
  // reads as one typeface at one size instead of every phrase scaled to fill its own cell.
  textFont(typeFont);
  textSize(100);
  float widest = 0;
  for (TypeCell tc : typeCells) widest = max(widest, textWidth(tc.words) / 100);
  typeSize = min(typeCellH * 0.9 / CAP_HEIGHT, typeCellW * 0.97 / max(0.01, widest));

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
    Plant p = new Plant(v.x, v.y, typeInk, true);
    p.maxSteps = int(random(25, 75));
    typePlants.add(p);
  }
  println("Type cells: " + typeCells.size() + "  Type vines: " + typePlants.size());
}

void drawTypeCells(PGraphics pg) {
  pg.textFont(typeFont);
  pg.textSize(typeSize);
  pg.textAlign(LEFT, BASELINE);
  for (TypeCell tc : typeCells) {
    pg.pushMatrix();
    pg.translate(tc.cx, tc.cy); // rotate about the cell centre, then set from the cell's left edge
    pg.rotate(tc.rot * HALF_PI);
    pg.text(tc.words, -typeCellW * 0.5, typeSize * CAP_HEIGHT * 0.5);
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
  int ink = typeInk;
  for (int k = 0; k < typeIdx.length; k++) {
    px[typeIdx[k]] = (typeThr[k] & 0xFF) > ek ? ink : 0;
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
