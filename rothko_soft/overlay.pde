// Overlay image: load, turn into generative marks, then soft-composite onto the print.
// All controls live at the top of rothko_soft.pde.

PImage overlaySrc;

// Draws the overlay into its own transparent layer, unrotated, at its final
// print size. Rotation, feathering, opacity and blending happen in compositeOverlay().
PGraphics buildOverlay() {
  overlaySrc = loadOverlaySource();
  overlaySrc.loadPixels();

  // keep aspect ratio: the longest side becomes overlaySize of the canvas
  float aspect = (float) overlaySrc.width / overlaySrc.height;
  float longSide = max(1, overlaySize * S);
  int lw = max(1, round(aspect >= 1 ? longSide : longSide * aspect));
  int lh = max(1, round(aspect >= 1 ? longSide / aspect : longSide));
  println("overlay: " + overlaySrc.width + " x " + overlaySrc.height + " source -> "
    + lw + " x " + lh + " px on print, mode " + overlayMode);

  PGraphics lay = createGraphics(lw, lh);
  lay.beginDraw();
  lay.clear();

  if (overlayMode.equals("FLOW")) drawFlow(lay);
  else if (overlayMode.equals("DOTS")) drawDots(lay);
  else if (overlayMode.equals("BANDS")) drawBands(lay);
  else drawRaw(lay);

  lay.endDraw();
  lay.loadPixels();
  softenLayer(lay.pixels, lw, lh, round(overlaySoftness * S));
  return lay;
}

PImage loadOverlaySource() {
  if (new File(dataPath(overlayFile)).exists()) {
    PImage img = loadImage(overlayFile);
    if (img != null && img.width > 0) return img;
  }
  println("overlay: data/" + overlayFile + " not found, using placeholder");
  PGraphics ph = createGraphics(1200, 1500);
  ph.beginDraw();
  ph.clear();
  ph.noStroke();
  ph.fill(205, 130, 100);
  ph.ellipse(560, 820, 980, 980);
  ph.fill(45, 22, 18);
  ph.textFont(createFont("Serif", 1300, true));
  ph.textAlign(CENTER, CENTER);
  ph.text("&", 600, 640);
  ph.endDraw();
  return ph.get();
}

// ---------- modes ----------

void drawRaw(PGraphics lay) {
  lay.pushMatrix();
  if (overlayFlipX) {
    lay.translate(lay.width, 0);
    lay.scale(-1, 1);
  }
  lay.image(overlaySrc, 0, 0, lay.width, lay.height);
  lay.popMatrix();
}

void drawFlow(PGraphics lay) {
  float step = max(1, markSize * S * 0.6);
  int steps = max(3, round(markLength * S / step));
  lay.noFill();
  lay.strokeCap(ROUND);
  lay.strokeJoin(ROUND);
  for (int n = 0; n < markCount; n++) {
    float x = random(lay.width), y = random(lay.height);
    int c = sampleSource(x / lay.width, y / lay.height);
    float a = alpha(c) / 255.0, lum = luma(c);
    if (a < 0.1 || lum > lumaCutoff) continue;

    lay.stroke(markColour(c, lum), 255 * markAlpha * a * random(0.5, 1));
    lay.strokeWeight(markSize * S * random(0.5, 1.4));
    lay.beginShape();
    for (int i = 0; i < steps; i++) {
      lay.vertex(x, y);
      float u = x / lay.width, v = y / lay.height;
      float here = luma(sampleSource(u, v));
      float ang = (noise(u * flowScale, v * flowScale, 41) - 0.5) * TWO_PI * flowTurbulence
        + here * TWO_PI * toneSteer;
      x += cos(ang) * step;
      y += sin(ang) * step;
      if (x < 0 || y < 0 || x >= lay.width || y >= lay.height) break;
    }
    lay.endShape();
  }
}

void drawDots(PGraphics lay) {
  float cell = sqrt((float) lay.width * lay.height / max(1, markCount));
  lay.noStroke();
  for (float gy = cell * 0.5; gy < lay.height; gy += cell) {
    for (float gx = cell * 0.5; gx < lay.width; gx += cell) {
      float x = gx + random(-0.4, 0.4) * cell, y = gy + random(-0.4, 0.4) * cell;
      int c = sampleSource(x / lay.width, y / lay.height);
      float a = alpha(c) / 255.0, lum = luma(c);
      if (a < 0.1 || lum > lumaCutoff) continue;
      float r = markSize * S * ((1 - sizeByTone) + sizeByTone * (1 - lum)) * random(0.8, 1.25);
      int col = markColour(c, lum);
      // stacked translucent discs: dense centre, soft rim
      for (int k = 0; k < 4; k++) {
        lay.fill(col, 255 * markAlpha * a * 0.35);
        float d = 2 * r * (1 - k * 0.2);
        lay.ellipse(x, y, d, d);
      }
    }
  }
}

void drawBands(PGraphics lay) {
  int rows = max(1, round(sqrt(markCount * (float) lay.height / lay.width)));
  int cols = max(1, markCount / rows);
  float rowH = (float) lay.height / rows, segW = (float) lay.width / cols;
  lay.noStroke();
  lay.rectMode(CENTER);
  for (int ry = 0; ry < rows; ry++) {
    for (int cx = 0; cx < cols; cx++) {
      float x = (cx + 0.5) * segW + random(-0.5, 0.5) * segW;
      float y = (ry + 0.5) * rowH + random(-0.15, 0.15) * rowH;
      int c = sampleSource(x / lay.width, y / lay.height);
      float a = alpha(c) / 255.0, lum = luma(c);
      if (a < 0.1 || lum > lumaCutoff) continue;
      float w = segW + markLength * S * random(0.3, 1);
      float h = rowH * ((1 - sizeByTone) + sizeByTone * (1 - lum)) * 0.95;
      int col = markColour(c, lum);
      for (int k = 0; k < 4; k++) {
        float f = 1 - k * 0.18;
        lay.fill(col, 255 * markAlpha * a * 0.3);
        lay.rect(x, y, w * f, h * f, h * f * 0.5);
      }
    }
  }
}

// Three box blurs in a row approximate a gaussian. Done on premultiplied
// colour so transparent areas don't bleed dark into the marks.
void softenLayer(int[] px, int w, int h, int radius) {
  if (radius < 1) return;
  int n = w * h;
  float[][] ch = new float[4][n];
  for (int i = 0; i < n; i++) {
    int c = px[i];
    float a = ((c >>> 24) & 255) / 255.0;
    ch[0][i] = a;
    ch[1][i] = ((c >> 16) & 255) * a;
    ch[2][i] = ((c >> 8) & 255) * a;
    ch[3][i] = (c & 255) * a;
  }
  float[] tmp = new float[n];
  for (int k = 0; k < 4; k++) {
    for (int pass = 0; pass < 3; pass++) {
      boxBlur(ch[k], tmp, w, h, radius, true);
      boxBlur(tmp, ch[k], w, h, radius, false);
    }
  }
  for (int i = 0; i < n; i++) {
    float a = ch[0][i];
    if (a <= 0.0001) { px[i] = 0; continue; }
    px[i] = (clamp255(a * 255) << 24) | (clamp255(ch[1][i] / a) << 16)
      | (clamp255(ch[2][i] / a) << 8) | clamp255(ch[3][i] / a);
  }
}

// running-sum box blur along rows (horizontal) or columns, edges clamped
void boxBlur(float[] src, float[] dst, int w, int h, int r, boolean horizontal) {
  int len = horizontal ? w : h, lines = horizontal ? h : w;
  int stride = horizontal ? 1 : w;
  float norm = 1.0 / (2 * r + 1);
  for (int l = 0; l < lines; l++) {
    int base = horizontal ? l * w : l;
    float sum = 0;
    for (int i = -r; i <= r; i++) sum += src[base + constrain(i, 0, len - 1) * stride];
    for (int i = 0; i < len; i++) {
      dst[base + i * stride] = sum * norm;
      sum += src[base + min(i + r + 1, len - 1) * stride] - src[base + max(i - r, 0) * stride];
    }
  }
}

// ---------- composite ----------

void compositeOverlay(PGraphics lay) {
  int lw = lay.width, lh = lay.height;
  float cx = overlayX * S, cy = overlayY * S;
  float th = radians(overlayRotation), ct = cos(th), st = sin(th);
  float ex = abs(lw * 0.5 * ct) + abs(lh * 0.5 * st);
  float ey = abs(lw * 0.5 * st) + abs(lh * 0.5 * ct);
  int xa = max(0, floor(cx - ex)), xb = min(S - 1, ceil(cx + ex));
  int ya = max(0, floor(cy - ey)), yb = min(S - 1, ceil(cy + ey));
  float fw = max(1, overlayFeather * min(lw, lh));
  int mode = blendCode(overlayBlend);
  int[] lp = lay.pixels;
  float[] o = new float[4];

  for (int y = ya; y <= yb; y++) {
    float dy = y + 0.5 - cy;
    for (int x = xa; x <= xb; x++) {
      float dx = x + 0.5 - cx;
      // canvas pixel -> unrotated layer coordinates
      float lx = dx * ct + dy * st + lw * 0.5;
      float ly = -dx * st + dy * ct + lh * 0.5;
      if (lx < 0 || ly < 0 || lx >= lw - 1 || ly >= lh - 1) continue;

      // soft, slightly irregular edge, like the colour fields
      float edge = min(min(lx, lw - lx), min(ly, lh - ly));
      edge += (noise(lx / lw * 6, ly / lh * 6, 77) - 0.5) * fw * 0.6;
      float fade = smoothstep(0, fw, edge);
      if (fade <= 0) continue;

      bilinearARGB(lp, lw, lx, ly, o);
      float a = o[0] * overlayOpacity * fade;
      if (a < 0.002) continue;

      int idx = y * S + x;
      int c = pg.pixels[idx];
      float br = (c >> 16) & 255, bg = (c >> 8) & 255, bb = c & 255;
      float gn = (random(1) - 0.5) * grain * a;
      float r = br + (blendChannel(mode, br, o[1]) - br) * a + gn;
      float g = bg + (blendChannel(mode, bg, o[2]) - bg) * a + gn;
      float b = bb + (blendChannel(mode, bb, o[3]) - bb) * a + gn;
      pg.pixels[idx] = 0xFF000000 | (clamp255(r) << 16) | (clamp255(g) << 8) | clamp255(b);
    }
  }
}

int blendCode(String name) {
  if (name.equals("MULTIPLY")) return 1;
  if (name.equals("SCREEN")) return 2;
  if (name.equals("SOFT_LIGHT")) return 3;
  return 0;
}

float blendChannel(int mode, float b, float o) {
  switch (mode) {
    case 1: return b * o / 255;
    case 2: return 255 - (255 - b) * (255 - o) / 255;
    case 3: {
      float bn = b / 255, on = o / 255;
      return 255 * ((1 - 2 * on) * bn * bn + 2 * on * bn);
    }
    default: return o;
  }
}

// premultiplied bilinear sample so transparent pixels don't leave dark fringes.
// out = { alpha 0–1, r, g, b }
void bilinearARGB(int[] px, int w, float x, float y, float[] out) {
  int x0 = (int) x, y0 = (int) y;
  float tx = x - x0, ty = y - y0;
  float A = 0, R = 0, Gc = 0, B = 0;
  for (int j = 0; j < 2; j++) {
    for (int i = 0; i < 2; i++) {
      float wt = (i == 0 ? 1 - tx : tx) * (j == 0 ? 1 - ty : ty);
      int c = px[(y0 + j) * w + x0 + i];
      float a = ((c >>> 24) & 255) / 255.0 * wt;
      A += a;
      R += ((c >> 16) & 255) * a;
      Gc += ((c >> 8) & 255) * a;
      B += (c & 255) * a;
    }
  }
  out[0] = A;
  if (A > 0) {
    out[1] = R / A; out[2] = Gc / A; out[3] = B / A;
  }
}

// ---------- colour helpers ----------

int sampleSource(float u, float v) {
  if (overlayFlipX) u = 1 - u;
  int x = constrain((int) (u * overlaySrc.width), 0, overlaySrc.width - 1);
  int y = constrain((int) (v * overlaySrc.height), 0, overlaySrc.height - 1);
  return overlaySrc.pixels[y * overlaySrc.width + x];
}

float luma(int c) {
  return (0.299 * ((c >> 16) & 255) + 0.587 * ((c >> 8) & 255) + 0.114 * (c & 255)) / 255.0;
}

// image colour pulled toward the field palette: dark -> deep red, light -> orange
int markColour(int c, float lum) {
  float t = constrain(lum, 0, 1) * (colors.length - 1);
  int i = min((int) t, colors.length - 2);
  int pal = lerpColor(colors[i], colors[i + 1], t - i);
  return lerpColor(c | 0xFF000000, pal, paletteMix);
}
