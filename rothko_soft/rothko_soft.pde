// Soft colour fields — print render
// unnikrishna m d
//
// Renders once at print size and saves a 300 ppi PNG to output/.
// Every edge (outer and between blocks) is feathered, and the inside of
// each block is built from thin, uneven washes instead of flat fill.
//
// If you get OutOfMemoryError: Processing > Settings >
// "Increase maximum available memory" and set it to 2048 MB or more.

import javax.imageio.*;
import javax.imageio.metadata.*;
import javax.imageio.stream.*;
import java.awt.image.BufferedImage;
import java.io.File;

// ---------- print settings ----------
int PRINT_PX = 6000;        // 6000 px = 20 in at 300 ppi. 7200 = 24 in.
int PRINT_DPI = 300;
int FIELD_STEP = 4;         // soft fields are computed on a 1/4 grid, then smoothly upsampled
int SEED = 7;

String creditLine = "unnikrishna m d";
String savePath = "output/";

// ---------- composition ----------
color ground = color(240, 233, 214); // warm beige
color[] colors = {
  color(150, 40, 40),   // deep red
  color(220, 80, 60),   // coral
  color(250, 180, 100)  // saturated orange
};
float[] ratios = { 0.4, 0.3, 0.3 };

float marginSide   = 0.075;  // all proportions are of canvas size
float marginTop    = 0.065;
float marginBottom = 0.095;  // room for the credit line
float gap          = 0.045;  // gap between blocks (the feathering eats into it)
float cornerRadius = 0.035;
float yOffset      = 0.0;    // shifts all blocks up/down, proportion of canvas

// ---------- softness ----------
float feather    = 0.022;  // width of the soft edge
float edgeWobble = 0.016;  // how far the edge drifts in and out
float edgeGlow   = 0.10;   // slight lift of light where a block dissolves into ground
float washDepth  = 0.22;   // how much ground breathes through inside a block (0 = solid)
float toneShift  = 0.14;   // light/dark variation inside a block
float streaks    = 0.07;   // horizontal brush strata inside a block
float grain      = 5.0;    // print grain, in 0–255 levels

// soft pigment motes (the old particles, now feathered glazes)
int numParticles = 9000;

PGraphics pg;
int S, G;
float[][] blockMask, blockTone;
float[] groundTone;
float[][] rects; // x0, y0, x1, y1 per block

void setup() {
  size(800, 800);
  noLoop();
  randomSeed(SEED);
  noiseSeed(SEED);
  noiseDetail(5, 0.5);

  S = PRINT_PX;
  G = S / FIELD_STEP + 2;

  layoutBlocks();
  println("building soft fields...");
  buildFields();
  println("painting " + S + " x " + S + " px...");
  pg = createGraphics(S, S);
  pg.beginDraw();
  pg.loadPixels();
  paintFields();
  paintMotes();
  pg.updatePixels();
  drawCredit();
  pg.endDraw();

  String file = savePath + "rothko_soft_" + S + "px_" + PRINT_DPI + "ppi.png";
  println("saving " + file + " ...");
  pg.loadPixels();
  try {
    savePrintPNG(pg, sketchPath(file), PRINT_DPI);
    println("done: " + sketchPath(file));
  } catch (Exception e) {
    e.printStackTrace();
  }
}

void draw() {
  background(ground);
  image(pg, 0, 0, width, height); // scaled preview only
}

// ---------- layout ----------
void layoutBlocks() {
  float avail = S * (1 - marginTop - marginBottom - gap * (colors.length - 1));
  rects = new float[colors.length][4];
  float y = S * (marginTop + yOffset);
  for (int i = 0; i < colors.length; i++) {
    float h = avail * ratios[i];
    rects[i][0] = S * marginSide;
    rects[i][1] = y;
    rects[i][2] = S * (1 - marginSide);
    rects[i][3] = y + h;
    y += h + S * gap;
  }
}

// ---------- soft fields (low-res, smooth) ----------
void buildFields() {
  int n = colors.length;
  blockMask = new float[n][G * G];
  blockTone = new float[n][G * G];
  groundTone = new float[G * G];

  float fw = feather * S, wob = edgeWobble * S, rad = cornerRadius * S;

  for (int gy = 0; gy < G; gy++) {
    for (int gx = 0; gx < G; gx++) {
      float px = gx * FIELD_STEP, py = gy * FIELD_STEP;
      float u = px / S, v = py / S;
      int k = gy * G + gx;

      // ground: faint mottling + gentle darkening toward the corners
      float vig = dist(u, v, 0.5, 0.5) / 0.7071;
      groundTone[k] = 1 + (noise(u * 3, v * 3, 99) - 0.5) * 0.06 - vig * vig * 0.05;

      for (int i = 0; i < n; i++) {
        float[] r = rects[i];
        float inside = -roundRectSDF(px, py, r[0], r[1], r[2], r[3], rad);
        float z = i * 17.3;

        // edge drifts in and out, and its softness varies along its length
        float drift = (noise(u * 9, v * 9, z) - 0.5) * 2 * wob;
        float fwLocal = fw * (0.55 + 0.9 * noise(u * 4, v * 4, z + 3));
        float m = smoothstep(-fwLocal, fwLocal, inside + drift);

        // inside: thin washes and horizontal brush strata, never flat
        float wash = 1 - washDepth * noise(u * 3.5, v * 3.5, z + 6);
        float strata = (noise(u * 1.6, v * 26, z + 9) - 0.5) * 2 * streaks;
        blockMask[i][k] = constrain(m * (wash + strata), 0, 1);

        float tone = 1 + (noise(u * 5, v * 5, z + 12) - 0.5) * 2 * toneShift;
        // light gathers where the colour dissolves
        tone += edgeGlow * 4 * m * (1 - m);
        blockTone[i][k] = tone;
      }
    }
  }
}

// ---------- full-res paint ----------
void paintFields() {
  int n = colors.length;
  float gr = red(ground), gg = green(ground), gb = blue(ground);
  float[] cr = new float[n], cg = new float[n], cb = new float[n];
  for (int i = 0; i < n; i++) {
    cr[i] = red(colors[i]); cg[i] = green(colors[i]); cb[i] = blue(colors[i]);
  }

  for (int y = 0; y < S; y++) {
    float fy = (float) y / FIELD_STEP;
    int y0 = (int) fy;
    float ty = fy - y0;
    for (int x = 0; x < S; x++) {
      float fx = (float) x / FIELD_STEP;
      int x0 = (int) fx;
      float tx = fx - x0;
      int k = y0 * G + x0;

      float t = sample(groundTone, k, tx, ty);
      float r = gr * t, g = gg * t, b = gb * t;

      for (int i = 0; i < n; i++) {
        float m = sample(blockMask[i], k, tx, ty);
        if (m <= 0.0005) continue;
        float tone = sample(blockTone[i], k, tx, ty);
        r += (cr[i] * tone - r) * m;
        g += (cg[i] * tone - g) * m;
        b += (cb[i] * tone - b) * m;
      }

      float gn = (random(1) - 0.5) * grain;
      pg.pixels[y * S + x] = 0xFF000000
        | (clamp255(r + gn) << 16) | (clamp255(g + gn) << 8) | clamp255(b + gn);
    }
    if (y % 1000 == 0) println("  row " + y);
  }
}

// Each mote is a horizontally stretched gaussian glaze, faded by its
// block's own soft mask so it never leaves a hard mark.
void paintMotes() {
  for (int p = 0; p < numParticles; p++) {
    int i = p % colors.length;
    float[] rc = rects[i];
    float cx = random(rc[0], rc[2]);
    float cy = random(rc[1], rc[3]);
    float rad = random(0.004, 0.014) * S;
    float sx = rad * random(1.6, 3.0), sy = rad * random(0.5, 0.9);
    float alpha = random(0.03, 0.09);
    float shade = random(0.82, 1.14);
    float mr = red(colors[i]) * shade, mg = green(colors[i]) * shade, mb = blue(colors[i]) * shade;

    int xa = max(0, (int) (cx - sx * 2.5)), xb = min(S - 1, (int) (cx + sx * 2.5));
    int ya = max(0, (int) (cy - sy * 2.5)), yb = min(S - 1, (int) (cy + sy * 2.5));
    for (int y = ya; y <= yb; y++) {
      float dy = (y - cy) / sy;
      float fy = (float) y / FIELD_STEP;
      int y0 = (int) fy;
      float ty = fy - y0;
      for (int x = xa; x <= xb; x++) {
        float dx = (x - cx) / sx;
        float d2 = dx * dx + dy * dy;
        if (d2 > 6.25) continue;
        float fx = (float) x / FIELD_STEP;
        int x0 = (int) fx;
        float a = alpha * exp(-d2 * 0.5) * sample(blockMask[i], y0 * G + x0, fx - x0, ty);
        if (a < 0.002) continue;
        int idx = y * S + x;
        int c = pg.pixels[idx];
        float r = (c >> 16) & 255, g = (c >> 8) & 255, b = c & 255;
        r += (mr - r) * a; g += (mg - g) * a; b += (mb - b) * a;
        pg.pixels[idx] = 0xFF000000 | (clamp255(r) << 16) | (clamp255(g) << 8) | clamp255(b);
      }
    }
  }
}

void drawCredit() {
  float ts = S * 0.013;
  pg.textFont(createFont("SansSerif", ts, true));
  pg.fill(118, 100, 86);
  pg.noStroke();
  pg.textAlign(RIGHT, BASELINE);
  pg.text(creditLine, S * (1 - marginSide), S * (1 - marginBottom * 0.45));
}

// ---------- helpers ----------
float sample(float[] f, int k, float tx, float ty) {
  float a = f[k] + (f[k + 1] - f[k]) * tx;
  float b = f[k + G] + (f[k + G + 1] - f[k + G]) * tx;
  return a + (b - a) * ty;
}

float roundRectSDF(float px, float py, float x0, float y0, float x1, float y1, float r) {
  float cx = (x0 + x1) * 0.5, cy = (y0 + y1) * 0.5;
  float qx = abs(px - cx) - ((x1 - x0) * 0.5 - r);
  float qy = abs(py - cy) - ((y1 - y0) * 0.5 - r);
  float ox = max(qx, 0), oy = max(qy, 0);
  return sqrt(ox * ox + oy * oy) + min(max(qx, qy), 0) - r;
}

float smoothstep(float e0, float e1, float x) {
  float t = constrain((x - e0) / (e1 - e0), 0, 1);
  return t * t * (3 - 2 * t);
}

int clamp255(float v) {
  return v < 0 ? 0 : (v > 255 ? 255 : (int) v);
}

// PNG with real 300 ppi metadata, so print software sizes it correctly.
void savePrintPNG(PImage img, String path, int dpi) throws Exception {
  BufferedImage bi = new BufferedImage(img.width, img.height, BufferedImage.TYPE_INT_RGB);
  bi.setRGB(0, 0, img.width, img.height, img.pixels, 0, img.width);

  ImageWriter writer = ImageIO.getImageWritersByFormatName("png").next();
  ImageWriteParam param = writer.getDefaultWriteParam();
  IIOMetadata meta = writer.getDefaultImageMetadata(
    ImageTypeSpecifier.createFromBufferedImageType(BufferedImage.TYPE_INT_RGB), param);

  // pHYs chunk: pixels per metre (300 ppi = 11811 px/m)
  String ppm = Integer.toString(round(dpi / 0.0254));
  IIOMetadataNode phys = new IIOMetadataNode("pHYs");
  phys.setAttribute("pixelsPerUnitXAxis", ppm);
  phys.setAttribute("pixelsPerUnitYAxis", ppm);
  phys.setAttribute("unitSpecifier", "meter");
  IIOMetadataNode root = new IIOMetadataNode("javax_imageio_png_1.0");
  root.appendChild(phys);
  meta.mergeTree("javax_imageio_png_1.0", root);

  File f = new File(path);
  f.getParentFile().mkdirs();
  ImageOutputStream out = ImageIO.createImageOutputStream(f);
  writer.setOutput(out);
  writer.write(null, new IIOImage(bi, null, meta), param);
  out.close();
  writer.dispose();
}
