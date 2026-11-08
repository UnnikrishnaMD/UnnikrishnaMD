// ─────────────────────────────────────────────────────────────
//  SERIES 07  —  "Face Wash": contour threads   (Processing 4 port)
//  The drawing from 06, unchanged. The new element: threads that find the
//  contour of every element (ink, ribbons, stencil word, painted arm, soap
//  box), wrap part of the way around it, then peel off into the open and
//  curl. Leaves, buds, flowers, spiral fern tips, butterflies, ladybirds
//  and snails grow along them.
//  The drawing loads no image: the contours are the outlines traced for 06,
//  written into the code as coordinates. The only files read are the five
//  process drawings in data/process/, shown at the start of the reel.
//
//  Blocks:  PALETTE · GROUND · TYPE · RIBBONS · PAINT · LABEL · INK · CANVAS
//           CONTOURS · THREADS · FLORA · FAUNA · GROWTH · REEL · PROCESS · EXPORT
//
//  Keys:  s  save the screen as PNG                    → print/
//         h  save a high-res print PNG (PRINT_SCALE ×)  → print/
//         p  save a vector PDF for print                → print/
//         v  record the reel straight to an MP4 (Reel / Short) → reel/:
//            the process drawings, then one full growth cycle. No image
//            frames are written; each frame is piped into the encoder as it
//            is drawn. Press v again to cancel.
//         r  restart the growth
// ─────────────────────────────────────────────────────────────

import processing.pdf.*;
import java.io.*;
import java.nio.*;

final int W = 1080, H = 1920;      // 9:16 portrait, as 06
final int SEED = 30;

// ── PALETTE ──────────────────────────────────────────────────
String INK_C = "#050505", STENCIL_C = "#3279c9", MAGENTA = "#f20587", CORAL = "#f24c3e",
       ORANGE = "#da8e04", NAVY = "#141b85", PURPLE = "#3e2f74", PAINT_C = "#b28eab",
       PAINT_LIGHT = "#d4b6cf", PAINT_DARK = "#8f6f95", CREAM = "#f1eee2", GOLD = "#c9a54a",
       ROSE = "#c2577a";

// ── GROUND ───────────────────────────────────────────────────
int   GROUND_CELL = 40;
float GROUND_SMOOTH = 1.0, GROUND_SATURATION = 1.0, GROUND_GRAIN = 10;
int   GROUND_SPECKLES = 5000;
float SPECKLE_ALPHA = 60;

// ── TYPE ─────────────────────────────────────────────────────
boolean STENCIL_ON = true;
String  STENCIL_COLOR = STENCIL_C;
float   STENCIL_ALPHA = 255, TYPE_OFFSET_X = 0, TYPE_OFFSET_Y = 0;

// ── RIBBONS ──────────────────────────────────────────────────
String[] RIBBON_ORDER = { "purple", "orange", "magenta", "navy", "coral" };
float RIBBON_ALPHA = 255, RIBBON_SEAM = 1.2;

// ── PAINT ────────────────────────────────────────────────────
int   PAINT_STREAKS = 2600;
float STREAK_LEN_MIN = 18, STREAK_LEN_MAX = 90, STREAK_W_MIN = 1, STREAK_W_MAX = 5;
float STREAK_A_MIN = 30, STREAK_A_MAX = 95, PAINT_ANGLE = -0.35, PAINT_JITTER = 0.5;

// ── LABEL ────────────────────────────────────────────────────
float LABEL_X = 835, LABEL_Y = 1478, LABEL_W = 128, LABEL_H = 205, LABEL_ANGLE = 0.24, LABEL_SHADOW = 70;
int   LABEL_ROWS = 5, LABEL_GLYPHS = 7;

// ── INK ──────────────────────────────────────────────────────
float INK_SEAM = 0.6;

// ── CANVAS ───────────────────────────────────────────────────
int   CANVAS_WEAVE = 6, CANVAS_THREADS = 2600;
float CANVAS_GRID = 0.12, CANVAS_ALPHA = 14;

// ── CONTOURS ─────────────────────────────────────────────────
// Which outlines the threads look for. Rings shorter than CONTOUR_MIN_LENGTH
// (the stencil's spray dots, tiny ink flecks) are ignored.
boolean CONTOUR_INK = true, CONTOUR_RIBBONS = true, CONTOUR_STENCIL = true, CONTOUR_PAINT = true, CONTOUR_LABEL = true;
float CONTOUR_MIN_LENGTH = 90;
float CONTOUR_SPACING = 3;         // px between resampled contour points

// ── THREADS ──────────────────────────────────────────────────
// Each thread starts on a contour, lifts off it to a small distance,
// follows it part of the way round, then peels away into a noise current
// and ends in a curl. Colour comes from the drawing itself: the sprayed
// ground just outside the outline, or the element's own colour.
int   THREAD_COUNT = 2320;
float OFFSET_MIN = 7, OFFSET_MAX = 30;   // distance kept from the outline (px)
float WOBBLE = 6;                        // how much that distance breathes
float LIFT = 24;                         // points over which a thread rises off the outline
float WRAP_MIN = 0.10, WRAP_MAX = 0.50;  // share of the outline it travels round
int   MAX_WRAP = 900;
int   PEEL_MIN = 40, PEEL_MAX = 240;     // steps after leaving the outline
float STEP_LEN = 2.2, FLOW_SCALE = 0.006, FLOW_TURN = 0.16, CURL = 0.22;
int   SMOOTH = 3;
float THREAD_W_MIN = 0.6, THREAD_W_MAX = 2.6;
float THREAD_A_MIN = 235, THREAD_A_MAX = 255;
float OWN_COLOUR = 0.4;                  // chance to take the element's own colour (not on ink)
float SATURATE = 1.8, SHIFT = 45;

// ── FLORA ────────────────────────────────────────────────────
float LEAF_CHANCE = 0.009, LEAF_MIN = 5, LEAF_MAX = 15;
float BUD_CHANCE = 0.0025, FLOWER_CHANCE = 0.0025, FLOWER_MIN = 4, FLOWER_MAX = 11;
float FERN_TIP_CHANCE = 0.3;
String[] LEAF_COLORS   = { "#5f8f4f", "#7fa65a", "#3f6f4a", "#a6b86a", "#2f5a5a", "#8a9a5b" };
String[] FLOWER_COLORS = { "#f20587", "#f24c3e", "#f1eee2", "#da8e04", "#d4b6cf", "#ffd35a", "#3279c9" };
int   GROW_FRAMES = 24;

// ── FAUNA ────────────────────────────────────────────────────
int   BUTTERFLIES = 12, LADYBIRDS = 16, SNAILS = 6;
float BUTTERFLY_MIN = 9, BUTTERFLY_MAX = 18, LADYBIRD_MIN = 4, LADYBIRD_MAX = 7, SNAIL_MIN = 7, SNAIL_MAX = 12;
float FLUTTER = 0.22;
String[] BUTTERFLY_COLORS = { "#f20587", "#da8e04", "#3279c9", "#f24c3e", "#3e2f74", "#f1eee2" };

// ── GROWTH ───────────────────────────────────────────────────
int   GROWTH_FRAMES = 5500;     // frames for every thread to finish
float STAGGER = 0.65;          // threads start somewhere in the first 65%
int   HOLD = 600;              // frames to hold the finished piece
boolean LOOP = true;
int   FPS = 30;

// ── REEL ─────────────────────────────────────────────────────
// The screen cycle (5500 + 600 frames) runs 3 min 23 s. The reel is kept
// short, so while recording the growth clock is compressed: the process
// drawings play first, then the whole growth plays in REEL_GROWTH_SECONDS,
// then the finished piece holds for REEL_HOLD_SECONDS (the last flowers
// open during the hold).
// Butterflies keep beating at their normal speed.
// Output: 1080 × 1920, 30 fps, H.264 High, yuv420p (BT.709), AAC silent
// track, faststart — accepted by Instagram Reels and YouTube Shorts.
float   REEL_GROWTH_SECONDS = 20;
float   REEL_HOLD_SECONDS = 3;
int     REEL_CRF = 18;             // lower = better quality, bigger file
String  REEL_MAXRATE = "8M";       // YouTube's recommended rate for 1080p30; keeps the file a sensible size
boolean RECORD_ON_START = false;   // true: start recording as soon as the sketch opens
boolean EXIT_AFTER_RECORD = false; // true: close the sketch when the MP4 is done
String  FFMPEG_PATH = "";          // leave empty to find ffmpeg automatically

// ── PROCESS ──────────────────────────────────────────────────
// The hand-made stages before the code, shown in order at the start of the
// reel: pencil sketch, inked lines with ribbons, painted ground, stencil
// type and soap bottle, the assembled drawing. Each image fills the 9:16
// frame (centred, edges trimmed if its proportions differ), drifts in
// slightly, and crossfades into the next; the last one dissolves into the
// coded drawing, where the threads begin.
boolean PROCESS_INTRO = true;
String[] PROCESS_FILES = { "process/01.png", "process/02.png", "process/03.png", "process/04.png", "process/05.png" };
float   PROCESS_SECONDS = 1.2;     // time on screen per drawing, crossfade included
float   PROCESS_FADE = 0.4;        // crossfade length
float   PROCESS_DRIFT = 0.03;      // slow push-in over each drawing (3 %)

// ── EXPORT ───────────────────────────────────────────────────
String EXPORT_NAME = "series-07-contour-threads";
int    PRINT_SCALE = 4;        // 4 → 4320 × 7680 px (≈ 36.6 × 65 cm at 300 dpi)
int    PDF_GROUND_SCALE = 3;   // the sprayed ground is the one raster layer in the PDF

// ─────────────────────────────────────────────────────────────

class Element {
  String name, col; boolean on;
  ArrayList<ArrayList<float[][]>> shapes;
  Element(String name, String col, ArrayList<ArrayList<float[][]>> shapes, boolean on) { this.name = name; this.col = col; this.shapes = shapes; this.on = on; }
}

class Ring { float[][] pts, nrm; Element el; float weight; }

class Flora {
  int k, kind, petals;         // kind: 0 leaf, 1 bud, 2 flower, 3 fern
  float a, size; float[] col, col2; boolean baked;
}

class Strand {             // one contour thread
  float[][] pts; float[] ang, col; float w0, start, dur; int drawn;
  ArrayList<Flora> flora = new ArrayList<Flora>();
}

class Creature {
  int kind, k; Strand th; float size, a, phase; float[] col, col2;   // kind: 0 butterfly, 1 ladybird, 2 snail
}

ArrayList<Element> ELEMENTS = new ArrayList<Element>();
PImage groundImg;
PGraphics base, layer;
ArrayList<float[]> speckles = new ArrayList<float[]>(), streaks = new ArrayList<float[]>(), canvasMarks = new ArrayList<float[]>();
ArrayList<float[][]> labelRowPts = new ArrayList<float[][]>();
ArrayList<float[]> labelRowStyle = new ArrayList<float[]>();
String[] labelRowCol = { "#9d99a6", "#a9a5ae", ROSE, ROSE, "#8d8a90" };
ArrayList<Strand> threads = new ArrayList<Strand>();
ArrayList<Creature> creatures = new ArrayList<Creature>();
float t = 0;               // growth clock (frames of growth)
float flutterClock = 0;    // real frame count, drives the wing beat
boolean recording = false;
int recFrame = 0;
Process encoder;
OutputStream encoderIn;
ByteBuffer frameBytes;
String reelPath;
PImage[] processImgs = new PImage[0];

void settings() { size(W, H); }

void setup() {
  frameRate(FPS);
  parseElements();
  prepareBase();
  base = createGraphics(W, H);
  base.beginDraw(); renderBase(base, groundImg); base.endDraw();
  buildThreads();
  layer = createGraphics(W, H);
  loadProcess();
  restart();
  if (RECORD_ON_START) startRecording();
}

void restart() {
  t = 0;
  layer.beginDraw(); layer.clear(); layer.endDraw();
  for (Strand th : threads) { th.drawn = 0; for (Flora f : th.flora) f.baked = false; }
}

void draw() {
  if (recording && recFrame < introFrames()) {
    drawIntro(recFrame);
    writeFrame();
    recFrame++;
    if (recFrame >= reelFrames()) finishRecording();
    return;
  }
  if (recording) t = reelClock(recFrame - introFrames());

  image(base, 0, 0);
  layer.beginDraw(); growStep(layer); layer.endDraw();
  image(layer, 0, 0);
  drawLiveFlora(g);
  drawCreatures(g, t, true);
  flutterClock++;

  if (recording) {
    writeFrame();
    recFrame++;
    if (recFrame % FPS == 0) println("reel  " + nf(recFrame / (float) FPS, 2, 0) + " / " + nf(reelFrames() / (float) FPS, 2, 0) + " s");
    if (recFrame >= reelFrames()) finishRecording();
    return;
  }
  t++;
  int end = GROWTH_FRAMES + HOLD;
  if (LOOP && t >= end) restart();
}

// ── reel: frames go straight into the encoder, nothing is saved as images ──

int reelGrowthFrames() { return round(REEL_GROWTH_SECONDS * FPS); }
int reelFrames() { return introFrames() + reelGrowthFrames() + round(REEL_HOLD_SECONDS * FPS); }
int introFrames() { return processImgs.length * round(PROCESS_SECONDS * FPS); }

// ── process intro ──

// scale each drawing once so it covers the 9:16 frame at 1 + PROCESS_DRIFT
void loadProcess() {
  if (!PROCESS_INTRO) { processImgs = new PImage[0]; return; }
  ArrayList<PImage> list = new ArrayList<PImage>();
  for (String f : PROCESS_FILES) {
    PImage img = loadImage(f);
    if (img == null) { println("Process drawing not found: data/" + f + " (skipped)"); continue; }
    float sc = max(W / (float) img.width, H / (float) img.height) * (1 + PROCESS_DRIFT);
    img.resize(round(img.width * sc), round(img.height * sc));
    list.add(img);
  }
  processImgs = list.toArray(new PImage[0]);
}

void drawProcess(int i, float local, float alpha) {
  PImage img = processImgs[i];
  float z = (1 + PROCESS_DRIFT * local) / (1 + PROCESS_DRIFT);   // grows from 1/(1+d) to 1
  float w = img.width * z, h = img.height * z;
  tint(255, alpha);
  image(img, (W - w) / 2, (H - h) / 2, w, h);
  noTint();
}

void drawIntro(int f) {
  int seg = round(PROCESS_SECONDS * FPS), fade = round(PROCESS_FADE * FPS);
  int i = f / seg, k = f % seg;
  background(255);
  drawProcess(i, k / (float) seg, 255);
  if (k >= seg - fade) {
    float u = (k - (seg - fade) + 1) / (float) fade;
    u = u * u * (3 - 2 * u);
    if (i + 1 < processImgs.length) drawProcess(i + 1, 0, 255 * u);
    else { tint(255, 255 * u); image(base, 0, 0); noTint(); }   // into the coded drawing
  }
}

// growth clock for video frame f: compressed during growth, real time in the hold
float reelClock(int f) {
  int gf = reelGrowthFrames();
  if (f < gf) return f * GROWTH_FRAMES / (float) gf;
  return GROWTH_FRAMES + (f - gf);
}

String findFfmpeg() {
  if (FFMPEG_PATH != null && FFMPEG_PATH.length() > 0) return FFMPEG_PATH;
  // apps started from the Dock / Start menu often don't see the shell PATH
  String[] guesses = { "/opt/homebrew/bin/ffmpeg", "/usr/local/bin/ffmpeg", "/usr/bin/ffmpeg",
                       "C:\\ffmpeg\\bin\\ffmpeg.exe", "C:\\Program Files\\ffmpeg\\bin\\ffmpeg.exe" };
  for (String p : guesses) if (new File(p).exists()) return p;
  return "ffmpeg";
}

void startRecording() {
  new File(sketchPath("reel")).mkdirs();
  reelPath = sketchPath("reel/" + EXPORT_NAME + "-reel-" + W + "x" + H + ".mp4");
  String[] cmd = {
    findFfmpeg(), "-y", "-loglevel", "error",
    "-f", "rawvideo", "-pix_fmt", "argb", "-s", W + "x" + H, "-r", str(FPS), "-i", "-",
    "-f", "lavfi", "-i", "anullsrc=r=48000:cl=stereo",
    "-map", "0:v", "-map", "1:a", "-shortest",
    "-vf", "scale=out_color_matrix=bt709:out_range=tv,format=yuv420p",
    "-c:v", "libx264", "-preset", "slow", "-profile:v", "high", "-level", "4.2",
    "-crf", str(REEL_CRF), "-maxrate", REEL_MAXRATE, "-bufsize", "16M", "-g", str(FPS * 2),
    "-color_primaries", "bt709", "-color_trc", "bt709", "-colorspace", "bt709",
    "-c:a", "aac", "-b:a", "128k",
    "-movflags", "+faststart", reelPath
  };
  try {
    ProcessBuilder pb = new ProcessBuilder(cmd);
    pb.redirectOutput(ProcessBuilder.Redirect.DISCARD);
    pb.redirectError(new File(sketchPath("reel/ffmpeg-log.txt")));
    encoder = pb.start();
    encoderIn = new BufferedOutputStream(encoder.getOutputStream(), W * H * 4);
  } catch (IOException e) {
    println("Could not start ffmpeg (" + e.getMessage() + ").");
    println("Install it once (macOS: brew install ffmpeg · Windows: winget install ffmpeg) or set FFMPEG_PATH.");
    encoder = null;
    return;
  }
  frameBytes = ByteBuffer.allocate(W * H * 4).order(ByteOrder.BIG_ENDIAN);
  restart();
  flutterClock = 0;
  recFrame = 0;
  recording = true;
  frameRate(1000);         // render as fast as the machine allows; timing comes from the encoder
  println("Recording " + reelFrames() + " frames (" + nf(reelFrames() / (float) FPS, 0, 1) + " s) → " + reelPath);
}

void writeFrame() {
  loadPixels();
  frameBytes.clear();
  frameBytes.asIntBuffer().put(pixels, 0, W * H);
  try { encoderIn.write(frameBytes.array(), 0, W * H * 4); }
  catch (IOException e) { println("Encoder stopped: " + e.getMessage() + " — see reel/ffmpeg-log.txt"); stopEncoder(); recording = false; frameRate(FPS); }
}

void stopEncoder() {
  try { if (encoderIn != null) encoderIn.close(); } catch (IOException e) { }
  try { if (encoder != null) encoder.waitFor(); } catch (InterruptedException e) { }
  encoderIn = null; encoder = null;
}

void finishRecording() {
  recording = false;
  stopEncoder();
  frameRate(FPS);
  println("Saved " + reelPath);
  restart();
  if (EXIT_AFTER_RECORD) exit();
}

void cancelRecording() {
  recording = false;
  stopEncoder();
  frameRate(FPS);
  new File(reelPath).delete();
  println("Recording cancelled.");
  restart();
}

// ── parsing the traced data ──────────────────────────────────

ArrayList<ArrayList<float[][]>> parseShapes(String str) {
  ArrayList<ArrayList<float[][]>> out = new ArrayList<ArrayList<float[][]>>();
  for (String shape : split(str, '|')) {
    ArrayList<float[][]> rings = new ArrayList<float[][]>();
    for (String r : split(shape, '#')) {
      String[] q = splitTokens(r, " ");
      float[][] pts = new float[q.length][2];
      for (int i = 0; i < q.length; i++) {
        int c = q[i].indexOf(',');
        pts[i][0] = float(q[i].substring(0, c)); pts[i][1] = float(q[i].substring(c + 1));
      }
      rings.add(pts);
    }
    out.add(rings);
  }
  return out;
}

void parseElements() {
  ELEMENTS.clear();
  ELEMENTS.add(new Element("stencil", STENCIL_COLOR, parseShapes(dataFor("stencil")), CONTOUR_STENCIL));
  for (String n : RIBBON_ORDER) ELEMENTS.add(new Element(n, colourFor(n), parseShapes(dataFor(n)), CONTOUR_RIBBONS));
  ELEMENTS.add(new Element("paint", PAINT_C, parseShapes(dataFor("paint")), CONTOUR_PAINT));
  ELEMENTS.add(new Element("ink", INK_C, parseShapes(INK_DATA), CONTOUR_INK));
  // the soap box has no traced outline: its card is a rectangle
  float c = cos(LABEL_ANGLE), s = sin(LABEL_ANGLE), hw = LABEL_W / 2 + 12, hh = LABEL_H / 2 + 12;
  float[][] corners = { {-hw, -hh}, {hw, -hh}, {hw, hh}, {-hw, hh} };
  float[][] box = new float[4][2];
  for (int i = 0; i < 4; i++) {
    box[i][0] = LABEL_X + corners[i][0] * c - corners[i][1] * s;
    box[i][1] = LABEL_Y + corners[i][0] * s + corners[i][1] * c;
  }
  ArrayList<float[][]> rings = new ArrayList<float[][]>(); rings.add(box);
  ArrayList<ArrayList<float[][]>> shapes = new ArrayList<ArrayList<float[][]>>(); shapes.add(rings);
  ELEMENTS.add(new Element("label", GOLD, shapes, CONTOUR_LABEL));
}

Element element(String name) { for (Element e : ELEMENTS) if (e.name.equals(name)) return e; return null; }

String colourFor(String n) {
  if (n.equals("purple")) return PURPLE;
  if (n.equals("orange")) return ORANGE;
  if (n.equals("magenta")) return MAGENTA;
  if (n.equals("navy")) return NAVY;
  return CORAL;
}

float[] rgba(String h, float a) { return new float[] { unhex(h.substring(1, 3)), unhex(h.substring(3, 5)), unhex(h.substring(5, 7)), a }; }
String pick(String[] arr) { return arr[floor(random(arr.length))]; }

// ── the drawing (06), prepared once so it can be redrawn at any size ──

void prepareBase() {
  groundImg = makeGround(1);

  // overspray dots take the colour of the ground beneath them
  randomSeed(SEED + 2);
  speckles.clear();
  for (int i = 0; i < GROUND_SPECKLES; i++) {
    float x = random(W), y = random(H), d = random(1, 3.2), tone = random(-40, 40);
    int c = groundImg.get(floor(x), floor(y));
    speckles.add(new float[] { x, y, d, red(c) + tone, green(c) + tone, blue(c) + tone });
  }

  // dry-brush streaks: kept only where they lie wholly on the paint
  PGraphics m = createGraphics(W, H);
  m.beginDraw(); m.background(0);
  drawShapes(m, element("paint").shapes, new float[] {255, 255, 255, 255}, 0);
  m.endDraw();
  m.loadPixels();
  randomSeed(SEED + 3);
  noiseSeed(SEED);
  streaks.clear();
  for (int s = 0; s < PAINT_STREAKS; s++) {
    float x = random(W), y = random(1150, H);
    float len = random(STREAK_LEN_MIN, STREAK_LEN_MAX);
    float a = PAINT_ANGLE + (noise(x * 0.004, y * 0.004) - 0.5) * 2 * PAINT_JITTER;
    float x2 = x + cos(a) * len, y2 = y + sin(a) * len;
    boolean light = random(1) < 0.6;
    float alpha = random(STREAK_A_MIN, STREAK_A_MAX), wt = random(STREAK_W_MIN, STREAK_W_MAX);
    if (!onMask(m, x, y) || !onMask(m, x2, y2) || !onMask(m, (x + x2) / 2, (y + y2) / 2)) continue;
    float[] c = rgba(light ? PAINT_LIGHT : PAINT_DARK, alpha);
    streaks.add(new float[] { x, y, x2, y2, wt, c[0], c[1], c[2], alpha });
  }

  // soap-box lettering: running scribbles of letter-like humps
  randomSeed(SEED + 4);
  float[][] rows = { {-0.17, 0.74, 9, 4.5}, {-0.07, 0.42, 3, 1.6}, {0.07, 0.44, 7, 5}, {0.17, 0.62, 6, 5}, {0.29, 0.50, 2, 2.2} };
  labelRowPts.clear(); labelRowStyle.clear();
  for (int r = 0; r < min(LABEL_ROWS, rows.length); r++) {
    float fy = rows[r][0], span = LABEL_W * rows[r][1], amp = rows[r][2];
    int n = LABEL_GLYPHS * 4;
    float[][] pts = new float[n + 1][2];
    for (int k = 0; k <= n; k++) {
      float u = k / (float) n;
      pts[k][0] = -span / 2 + u * span + random(-1.5, 1.5);
      pts[k][1] = LABEL_H * fy - abs(sin(u * LABEL_GLYPHS * PI)) * amp * random(0.6, 1.2) + amp / 2;
    }
    labelRowPts.add(pts);
    labelRowStyle.add(new float[] { rows[r][3], r });
  }

  // canvas weave marks
  randomSeed(SEED + 5);
  canvasMarks.clear();
  for (int i = 0; i < CANVAS_THREADS; i++) {
    float v = random(1) < 0.5 ? 255 : 0, a = CANVAS_ALPHA * random(0.4, 1);
    float x = random(W), y = random(H), l = random(20, 160);
    if (random(1) < 0.5) canvasMarks.add(new float[] { x, y, x + l, y + random(-1, 1), v, a });
    else canvasMarks.add(new float[] { x, y, x + random(-1, 1), y + l, v, a });
  }
}

boolean onMask(PGraphics m, float fx, float fy) {
  int x = floor(fx), y = floor(fy);
  return x >= 0 && y >= 0 && x < W && y < H && ((m.pixels[y * W + x] >> 16) & 0xff) > 128;
}

// the sprayed field, computed at any scale (s = 1 for screen, more for print)
PImage makeGround(int s) {
  int n = GRID.length() / 6;
  float[][] cols = new float[n][3];
  for (int i = 0; i < n; i++) {
    float r = unhex(GRID.substring(i * 6, i * 6 + 2)), gg = unhex(GRID.substring(i * 6 + 2, i * 6 + 4)), b = unhex(GRID.substring(i * 6 + 4, i * 6 + 6));
    float l = (r + gg + b) / 3;
    cols[i][0] = l + (r - l) * GROUND_SATURATION; cols[i][1] = l + (gg - l) * GROUND_SATURATION; cols[i][2] = l + (b - l) * GROUND_SATURATION;
  }
  randomSeed(SEED + 1);
  int w = W * s, h = H * s;
  float cell = GROUND_CELL * s;
  PImage img = createImage(w, h, RGB);
  img.loadPixels();
  for (int y = 0; y < h; y++) {
    float gy = min(y / cell, GRID_H - 1.001);
    int j = floor(gy); float v = gy - j;
    v = lerp(v, v * v * (3 - 2 * v), GROUND_SMOOTH);
    for (int x = 0; x < w; x++) {
      float gx = min(x / cell, GRID_W - 1.001);
      int i = floor(gx); float u = gx - i;
      u = lerp(u, u * u * (3 - 2 * u), GROUND_SMOOTH);
      float[] a = cols[j * GRID_W + i], b = cols[j * GRID_W + i + 1];
      float[] c = cols[(j + 1) * GRID_W + i], d = cols[(j + 1) * GRID_W + i + 1];
      float nz = (random(1) - 0.5) * GROUND_GRAIN;
      int[] o = new int[3];
      for (int ch = 0; ch < 3; ch++) {
        float top = a[ch] + (b[ch] - a[ch]) * u, bot = c[ch] + (d[ch] - c[ch]) * u;
        o[ch] = (int) constrain(top + (bot - top) * v + nz, 0, 255);
      }
      img.pixels[y * w + x] = 0xff000000 | (o[0] << 16) | (o[1] << 8) | o[2];
    }
  }
  img.updatePixels();
  return img;
}

// draws the whole of 06 into g; g may be any size, the drawing is scaled to fit
void renderBase(PGraphics g, PImage gimg) {
  g.pushMatrix();
  g.scale(g.width / (float) W);
  g.image(gimg, 0, 0, W, H);
  g.noStroke();
  for (float[] p : speckles) { g.fill(p[3], p[4], p[5], SPECKLE_ALPHA); g.ellipse(p[0], p[1], p[2], p[2]); }

  if (STENCIL_ON) {
    g.pushMatrix();
    g.translate(TYPE_OFFSET_X, TYPE_OFFSET_Y);
    drawShapes(g, element("stencil").shapes, rgba(STENCIL_COLOR, STENCIL_ALPHA), 0);
    g.popMatrix();
  }
  for (String n : RIBBON_ORDER) drawShapes(g, element(n).shapes, rgba(colourFor(n), RIBBON_ALPHA), RIBBON_SEAM);

  drawShapes(g, element("paint").shapes, rgba(PAINT_C, 255), 1);
  g.strokeCap(ROUND);
  for (float[] s : streaks) { g.stroke(s[5], s[6], s[7], s[8]); g.strokeWeight(s[4]); g.line(s[0], s[1], s[2], s[3]); }
  g.noStroke();

  drawLabel(g);
  drawShapes(g, element("ink").shapes, rgba(INK_C, 255), INK_SEAM);

  g.strokeWeight(1);
  for (float[] m : canvasMarks) { g.stroke(m[4], m[5]); g.line(m[0], m[1], m[2], m[3]); }
  g.noStroke();
  for (int y = 0; y < H; y += CANVAS_WEAVE) { g.fill(0, CANVAS_ALPHA * CANVAS_GRID); g.rect(0, y, W, 1); }
  for (int x = 0; x < W; x += CANVAS_WEAVE) { g.fill(255, CANVAS_ALPHA * CANVAS_GRID); g.rect(x, 0, 1, H); }
  g.popMatrix();
}

void drawShapes(PGraphics g, ArrayList<ArrayList<float[][]>> shapes, float[] c, float seam) {
  g.fill(c[0], c[1], c[2], c[3]);
  if (seam > 0) { g.stroke(c[0], c[1], c[2], c[3]); g.strokeWeight(seam); g.strokeJoin(ROUND); } else g.noStroke();
  for (ArrayList<float[][]> rings : shapes) {
    g.beginShape();
    for (float[] p : rings.get(0)) g.vertex(p[0], p[1]);
    for (int r = 1; r < rings.size(); r++) {
      g.beginContour();
      for (float[] p : rings.get(r)) g.vertex(p[0], p[1]);
      g.endContour();
    }
    g.endShape(CLOSE);
  }
  g.noStroke();
}

void drawLabel(PGraphics g) {
  float w = LABEL_W, h = LABEL_H;
  g.pushMatrix();
  g.translate(LABEL_X, LABEL_Y);
  g.rotate(LABEL_ANGLE);
  g.rectMode(CENTER);
  g.noStroke();
  g.fill(40, 30, 60, LABEL_SHADOW);
  g.rect(6, 8, w + 8, h + 8, 4);
  g.fill(205, 205, 222, 150);              // the translucent wrapper
  g.rect(-10, -16, w + 34, h + 30, 10);
  fillHex(g, "#c4c1cf", 255);              // the box's side
  g.rect(0, 0, w + 10, h + 10, 6);
  fillHex(g, CREAM, 255);
  g.rect(0, 0, w, h, 2);
  g.noFill();
  strokeHex(g, GOLD, 255); g.strokeWeight(5);
  g.rect(0, 0, w - 8, h - 8);
  strokeHex(g, "#e6d9a6", 255); g.strokeWeight(1.5);
  g.rect(0, 0, w - 20, h - 20);
  g.noStroke();
  fillHex(g, GOLD, 255);
  g.ellipse(0, -h * 0.36, 34, 24);
  fillHex(g, "#e8cf7a", 255);
  g.ellipse(-6, -h * 0.38, 12, 9);
  g.ellipse(7, -h * 0.37, 10, 8);
  g.noFill();
  g.strokeJoin(ROUND); g.strokeCap(ROUND);
  for (int r = 0; r < labelRowPts.size(); r++) {
    float wt = labelRowStyle.get(r)[0];
    for (int pass = 0; pass < 2; pass++) {
      strokeHex(g, labelRowCol[r], pass == 1 ? 230 : 60);
      g.strokeWeight(pass == 1 ? wt : wt * 2.6);
      g.beginShape();
      for (float[] p : labelRowPts.get(r)) g.vertex(p[0], p[1]);
      g.endShape();
    }
  }
  strokeHex(g, "#5f8f4f", 255); g.strokeWeight(2.5);
  g.line(-w * 0.42, h * 0.46, -w * 0.3, h * 0.2);
  g.rectMode(CORNER);
  g.popMatrix();
}

void fillHex(PGraphics g, String h, float a) { float[] c = rgba(h, a); g.fill(c[0], c[1], c[2], c[3]); }
void strokeHex(PGraphics g, String h, float a) { float[] c = rgba(h, a); g.stroke(c[0], c[1], c[2], c[3]); }

// ── contour threads ──────────────────────────────────────────

// even points round a closed ring, each with the normal that points away
// from the element (holes are wound the other way, so this works for them too)
Ring resample(float[][] ring) {
  ArrayList<float[]> out = new ArrayList<float[]>();
  float area = 0;
  for (int i = 0; i < ring.length; i++) {
    float[] a = ring[i], b = ring[(i + 1) % ring.length];
    area += a[0] * b[1] - b[0] * a[1];
  }
  float carry = 0;
  for (int i = 0; i < ring.length; i++) {
    float[] a = ring[i], b = ring[(i + 1) % ring.length];
    float len = dist(a[0], a[1], b[0], b[1]);
    float d = carry;
    while (d < len) {
      float u = d / len;
      out.add(new float[] { a[0] + (b[0] - a[0]) * u, a[1] + (b[1] - a[1]) * u });
      d += CONTOUR_SPACING;
    }
    carry = d - len;
  }
  Ring r = new Ring();
  int n = out.size();
  r.pts = out.toArray(new float[n][]);
  r.nrm = new float[n][2];
  float sgn = area > 0 ? 1 : -1;
  for (int k = 0; k < n; k++) {
    float[] p = r.pts[(k - 2 + n) % n], q = r.pts[(k + 2) % n];
    float dx = q[0] - p[0], dy = q[1] - p[1];
    float l = sqrt(dx * dx + dy * dy); if (l == 0) l = 1;
    r.nrm[k][0] = dy / l * sgn; r.nrm[k][1] = -dx / l * sgn;
  }
  return r;
}

void buildThreads() {
  randomSeed(SEED + 6);
  noiseSeed(SEED + 6);
  groundImg.loadPixels();
  ArrayList<Ring> rings = new ArrayList<Ring>();
  float total = 0;
  for (Element e : ELEMENTS) {
    if (!e.on) continue;
    for (ArrayList<float[][]> shape : e.shapes) for (float[][] ring : shape) {
      Ring r = resample(ring);
      if (r.pts.length * CONTOUR_SPACING < CONTOUR_MIN_LENGTH) continue;
      r.el = e;
      r.weight = pow(r.pts.length, 0.8);
      total += r.weight;
      rings.add(r);
    }
  }
  threads.clear();
  for (int i = 0; i < THREAD_COUNT; i++) {
    float pk = random(total);
    Ring ring = rings.get(0);
    for (Ring r : rings) { pk -= r.weight; if (pk < 0) { ring = r; break; } }
    threads.add(makeThread(ring));
  }

  randomSeed(SEED + 7);
  creatures.clear();
  place(0, BUTTERFLIES, BUTTERFLY_MIN, BUTTERFLY_MAX);
  place(1, LADYBIRDS, LADYBIRD_MIN, LADYBIRD_MAX);
  place(2, SNAILS, SNAIL_MIN, SNAIL_MAX);
}

void place(int kind, int n, float smin, float smax) {
  for (int i = 0; i < n; i++) {
    Creature c = new Creature();
    c.kind = kind;
    c.th = threads.get(floor(random(threads.size())));
    c.k = floor(random(c.th.pts.length * 0.3, c.th.pts.length));
    c.size = random(smin, smax);
    c.a = c.th.ang[c.k] + random(-0.6, 0.6);
    c.col = rgba(pick(BUTTERFLY_COLORS), 235);
    c.col2 = rgba(pick(BUTTERFLY_COLORS), 235);
    c.phase = random(TWO_PI);
    creatures.add(c);
  }
}

Strand makeThread(Ring ring) {
  int n = ring.pts.length;
  int start = floor(random(n));
  int dir = random(1) < 0.5 ? 1 : -1;
  int steps = min(MAX_WRAP, floor(n * random(WRAP_MIN, WRAP_MAX)));
  float off = random(OFFSET_MIN, OFFSET_MAX);
  float nz = random(1000);
  ArrayList<float[]> pts = new ArrayList<float[]>();

  // follow the outline at a breathing distance, rising off it at the start
  for (int k = 0; k < steps; k++) {
    int idx = ((start + dir * k) % n + n) % n;
    float lift = min(1, k / LIFT);
    float o = max(1, (off + (noise(k * 0.02, nz) - 0.5) * 2 * WOBBLE) * lift);
    pts.add(new float[] { ring.pts[idx][0] + ring.nrm[idx][0] * o, ring.pts[idx][1] + ring.nrm[idx][1] * o });
  }
  if (pts.size() < 2) { pts.clear(); pts.add(ring.pts[start].clone()); pts.add(ring.pts[(start + 1) % n].clone()); }

  // peel away into the current and end in a tightening curl
  float[] last = pts.get(pts.size() - 1), prev = pts.get(pts.size() - 2);
  float x = last[0], y = last[1], a = atan2(last[1] - prev[1], last[0] - prev[0]);
  int peel = floor(random(PEEL_MIN, PEEL_MAX));
  float curlDir = random(1) < 0.5 ? -1 : 1;
  int curlFrom = floor(peel * random(0.55, 0.8));
  for (int j = 0; j < peel; j++) {
    a += (noise(x * FLOW_SCALE, y * FLOW_SCALE, nz) - 0.5) * 2 * FLOW_TURN;
    if (j > curlFrom) { float u = (j - curlFrom) / (float) (peel - curlFrom); a += curlDir * u * u * CURL; }
    x += cos(a) * STEP_LEN;
    y += sin(a) * STEP_LEN;
    pts.add(new float[] { x, y });
  }

  // soften corners from the outline
  Strand th = new Strand();
  int m = pts.size();
  th.pts = new float[m][2];
  for (int k = 0; k < m; k++) {
    float sx = 0, sy = 0; int c = 0;
    for (int q = max(0, k - SMOOTH); q <= min(m - 1, k + SMOOTH); q++) { sx += pts.get(q)[0]; sy += pts.get(q)[1]; c++; }
    th.pts[k][0] = sx / c; th.pts[k][1] = sy / c;
  }
  th.ang = new float[m];
  for (int k = 0; k < m; k++) {
    float[] q = th.pts[min(m - 1, k + 1)], r = th.pts[max(0, k - 1)];
    th.ang[k] = atan2(q[1] - r[1], q[0] - r[0]);
  }

  // colour: the element's own, or the sprayed ground just outside the outline
  if (random(1) < OWN_COLOUR && !ring.el.name.equals("ink")) th.col = rgba(ring.el.col, random(THREAD_A_MIN, THREAD_A_MAX));
  else {
    float o = off + 10;
    int sx = (int) constrain(floor(ring.pts[start][0] + ring.nrm[start][0] * o), 0, W - 1);
    int sy = (int) constrain(floor(ring.pts[start][1] + ring.nrm[start][1] * o), 0, H - 1);
    int c = groundImg.pixels[sy * W + sx];
    float r = red(c), gg = green(c), b = blue(c);
    float l = (r + gg + b) / 3, sh = random(-SHIFT, SHIFT);
    th.col = new float[] { constrain(l + (r - l) * SATURATE + sh, 0, 255), constrain(l + (gg - l) * SATURATE + sh, 0, 255),
                           constrain(l + (b - l) * SATURATE + sh, 0, 255), random(THREAD_A_MIN, THREAD_A_MAX) };
  }
  th.w0 = random(THREAD_W_MIN, THREAD_W_MAX);
  th.start = random(GROWTH_FRAMES * STAGGER);
  th.dur = max(30, GROWTH_FRAMES - th.start);

  // plant forms along the way
  for (int k = 6; k < m - 2; k++) {
    float side = random(1) < 0.5 ? -1 : 1;
    if (random(1) < LEAF_CHANCE) {
      Flora f = new Flora(); f.k = k; f.kind = 0; f.a = th.ang[k] + side * random(0.5, 1.1);
      f.size = random(LEAF_MIN, LEAF_MAX); f.col = rgba(pick(LEAF_COLORS), 225); th.flora.add(f);
    } else if (random(1) < BUD_CHANCE) {
      Flora f = new Flora(); f.k = k; f.kind = 1; f.a = th.ang[k] + side * random(0.6, 1.2);
      f.size = random(4, 8); f.col = rgba(pick(FLOWER_COLORS), 235); f.col2 = rgba(pick(LEAF_COLORS), 235); th.flora.add(f);
    } else if (random(1) < FLOWER_CHANCE) {
      Flora f = new Flora(); f.k = k; f.kind = 2; f.a = random(TWO_PI); f.size = random(FLOWER_MIN, FLOWER_MAX);
      f.col = rgba(pick(FLOWER_COLORS), 240); f.col2 = rgba(pick(FLOWER_COLORS), 255); f.petals = floor(random(5, 8)); th.flora.add(f);
    }
  }
  if (random(1) < FERN_TIP_CHANCE) {
    Flora f = new Flora(); f.k = m - 1; f.kind = 3; f.a = th.ang[m - 1]; f.size = random(5, 12); f.col = th.col.clone(); th.flora.add(f);
  }
  return th;
}

float widthAt(Strand th, int k) {
  float u = k / (float) (th.pts.length - 1);
  return th.w0 * (0.2 + 0.8 * pow(max(0, sin(PI * min(1, u * 1.08))), 0.6));
}

int revealAt(Strand th, float frame) {
  float u = constrain((frame - th.start) / th.dur, 0, 1);
  return floor(u * (th.pts.length - 1));
}

// frame on which point k of a thread is reached
float reachedAt(Strand th, int k) { return th.start + (k / (float) (th.pts.length - 1)) * th.dur; }

// draw newly reached segments, and bake plant forms that have finished opening
void growStep(PGraphics g) {
  g.strokeCap(ROUND);
  for (Strand th : threads) {
    int target = revealAt(th, t);
    g.stroke(th.col[0], th.col[1], th.col[2], th.col[3]);
    for (int k = max(1, th.drawn + 1); k <= target; k++) {
      g.strokeWeight(widthAt(th, k));
      g.line(th.pts[k - 1][0], th.pts[k - 1][1], th.pts[k][0], th.pts[k][1]);
    }
    if (target > th.drawn) th.drawn = target;
    for (Flora f : th.flora) {
      if (f.baked || f.k > th.drawn) continue;
      if (t - reachedAt(th, f.k) >= GROW_FRAMES) { drawFlora(g, th, f, 1); f.baked = true; }
    }
  }
}

void drawLiveFlora(PGraphics g) {
  for (Strand th : threads)
    for (Flora f : th.flora)
      if (!f.baked && f.k <= th.drawn) drawFlora(g, th, f, constrain((t - reachedAt(th, f.k)) / GROW_FRAMES, 0.05, 1));
}

// everything at a given growth frame, for print
void drawThreadsAt(PGraphics g, float frame) {
  g.strokeCap(ROUND);
  for (Strand th : threads) {
    int target = revealAt(th, frame);
    g.stroke(th.col[0], th.col[1], th.col[2], th.col[3]);
    for (int k = 1; k <= target; k++) {
      g.strokeWeight(widthAt(th, k));
      g.line(th.pts[k - 1][0], th.pts[k - 1][1], th.pts[k][0], th.pts[k][1]);
    }
  }
  for (Strand th : threads) {
    int target = revealAt(th, frame);
    for (Flora f : th.flora)
      if (f.k <= target) drawFlora(g, th, f, constrain((frame - reachedAt(th, f.k)) / GROW_FRAMES, 0.05, 1));
  }
  drawCreatures(g, frame, true);
}

// ── flora ────────────────────────────────────────────────────

void drawFlora(PGraphics g, Strand th, Flora f, float grow) {
  float x = th.pts[f.k][0], y = th.pts[f.k][1], s = f.size * grow;
  g.pushMatrix();
  g.translate(x, y);
  g.rotate(f.a);
  if (f.kind == 0) {
    g.noStroke();
    g.fill(f.col[0], f.col[1], f.col[2], f.col[3]);
    g.beginShape();
    g.vertex(0, 0);
    g.bezierVertex(s * 0.3, -s * 0.42, s * 0.8, -s * 0.34, s, 0);
    g.bezierVertex(s * 0.8, s * 0.34, s * 0.3, s * 0.42, 0, 0);
    g.endShape(CLOSE);
    g.stroke(f.col[0] * 0.6, f.col[1] * 0.6, f.col[2] * 0.6, 150);
    g.strokeWeight(0.6);
    g.line(0, 0, s * 0.85, 0);
  } else if (f.kind == 1) {
    g.stroke(f.col2[0], f.col2[1], f.col2[2], f.col2[3]);
    g.strokeWeight(1);
    g.line(0, 0, s * 1.2, 0);
    g.noStroke();
    g.fill(f.col[0], f.col[1], f.col[2], f.col[3]);
    g.ellipse(s * 1.4, 0, s * 0.9, s * 0.65);
    g.fill(f.col2[0], f.col2[1], f.col2[2], f.col2[3]);
    g.ellipse(s * 1.1, 0, s * 0.45, s * 0.6);
  } else if (f.kind == 2) {
    g.noStroke();
    g.fill(f.col[0], f.col[1], f.col[2], f.col[3]);
    for (int i = 0; i < f.petals; i++) {
      float u = i * TWO_PI / f.petals;
      g.ellipse(cos(u) * s * 0.34, sin(u) * s * 0.34, s * 0.5, s * 0.5);
    }
    g.fill(f.col2[0], f.col2[1], f.col2[2], f.col2[3]);
    g.ellipse(0, 0, s * 0.32, s * 0.32);
  } else {
    // a small spiral, like the eyes, continuing the thread's direction
    g.noFill();
    g.stroke(f.col[0], f.col[1], f.col[2], f.col[3]);
    g.strokeWeight(max(0.5, widthAt(th, f.k) * 0.8 + 0.4));
    g.beginShape();
    float turns = 1.6 * grow;
    for (float u = 0; u <= turns * TWO_PI; u += 0.2) {
      float r = s * (1 - u / (TWO_PI * 2.2));
      g.vertex(sin(u) * r, -(1 - cos(u)) * r);
    }
    g.endShape();
  }
  g.popMatrix();
}

// ── fauna ────────────────────────────────────────────────────

void drawCreatures(PGraphics g, float frame, boolean live) {
  for (Creature c : creatures) {
    if (frame < reachedAt(c.th, c.k) + GROW_FRAMES) continue;
    float s = c.size;
    g.pushMatrix();
    g.translate(c.th.pts[c.k][0], c.th.pts[c.k][1]);
    g.rotate(c.a);
    if (c.kind == 0) {
      // the wing beat runs on real frames, so it stays natural when the growth is compressed
      float beat = live ? 0.35 + 0.65 * abs(sin(flutterClock * FLUTTER + c.phase)) : 1;
      g.noStroke();
      for (int side = -1; side <= 1; side += 2) {
        g.fill(c.col[0], c.col[1], c.col[2], c.col[3]);
        g.ellipse(-s * 0.15, side * s * 0.42 * beat, s * 0.75, s * 0.8 * beat);
        g.fill(c.col2[0], c.col2[1], c.col2[2], c.col2[3]);
        g.ellipse(s * 0.32, side * s * 0.3 * beat, s * 0.5, s * 0.55 * beat);
      }
      g.stroke(10); g.strokeWeight(max(0.8, s * 0.09));
      g.line(-s * 0.45, 0, s * 0.45, 0);
      g.strokeWeight(0.6);
      g.line(s * 0.45, 0, s * 0.75, -s * 0.22);
      g.line(s * 0.45, 0, s * 0.75, s * 0.22);
    } else if (c.kind == 1) {
      g.noStroke();
      g.fill(10);
      g.ellipse(s * 0.55, 0, s * 0.6, s * 0.6);
      g.fill(220, 30, 35);
      g.ellipse(0, 0, s * 1.3, s * 1.1);
      g.stroke(10); g.strokeWeight(max(0.4, s * 0.08));
      g.line(-s * 0.65, 0, s * 0.62, 0);
      g.noStroke(); g.fill(10);
      float[][] dots = { {-0.25, -0.28}, {-0.25, 0.28}, {0.18, -0.24}, {0.18, 0.24} };
      for (float[] d : dots) g.ellipse(d[0] * s, d[1] * s, s * 0.22, s * 0.22);
    } else {
      // snail: soft body with feelers, shell drawn as a spiral like the eyes
      g.noStroke();
      g.fill(196, 172, 150, 240);
      g.ellipse(s * 0.2, s * 0.35, s * 2.0, s * 0.45);
      g.stroke(120, 100, 90); g.strokeWeight(0.6);
      g.line(s * 1.1, s * 0.25, s * 1.35, -s * 0.15);
      g.line(s * 1.0, s * 0.25, s * 1.15, -s * 0.2);
      g.noStroke();
      g.fill(c.col[0], c.col[1], c.col[2], 255);
      g.ellipse(0, -s * 0.15, s * 1.2, s * 1.2);
      g.noFill();
      g.stroke(20); g.strokeWeight(max(0.6, s * 0.08));
      g.beginShape();
      for (float u = 0; u < TWO_PI * 2.2; u += 0.25) {
        float r = s * 0.55 * (1 - u / (TWO_PI * 2.4));
        g.vertex(cos(u) * r, -s * 0.15 + sin(u) * r);
      }
      g.endShape();
    }
    g.popMatrix();
  }
}

// ── saving ───────────────────────────────────────────────────

void keyPressed() {
  if (key == 's') save(sketchPath("print/" + EXPORT_NAME + "-screen-" + nf((int) t, 4) + ".png"));
  if (key == 'h') savePrint();
  if (key == 'p') savePDF();
  if (key == 'v') { if (recording) cancelRecording(); else startRecording(); }
  if (key == 'r' && !recording) restart();
}

// redraws everything at PRINT_SCALE × size, at the current growth frame
void savePrint() {
  int s = PRINT_SCALE;
  PGraphics pg = createGraphics(W * s, H * s);
  pg.beginDraw();
  renderBase(pg, makeGround(s));
  pg.pushMatrix();
  pg.scale(s);
  drawThreadsAt(pg, t);
  pg.popMatrix();
  pg.endDraw();
  String path = sketchPath("print/" + EXPORT_NAME + "-print-" + (W * s) + "x" + (H * s) + ".png");
  pg.save(path);
  println("Saved " + path);
}

// vector PDF: every outline, thread and plant stays sharp at any size;
// only the sprayed ground is embedded as an image
void savePDF() {
  String path = sketchPath("print/" + EXPORT_NAME + ".pdf");
  PGraphics pdf = createGraphics(W, H, PDF, path);
  pdf.beginDraw();
  renderBase(pdf, makeGround(PDF_GROUND_SCALE));
  drawThreadsAt(pdf, t);
  pdf.dispose();
  pdf.endDraw();
  println("Saved " + path);
}
