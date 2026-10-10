import java.util.Collections;

PImage img;
int cols, rows;
PVector[][] flowField;

ArrayList<ThreadLine> threads = new ArrayList<ThreadLine>();
int totalThreads = 1000;

// ---- Colour option ----
// 0 = RED      : original red variations
// 1 = BIRTH    : each thread takes the image colour where it starts, keeps it
// 2 = LIVE     : thread picks up the image colour of every area it passes through
// Change here, or press 1 / 2 / 3 while the sketch runs.
int paletteMode = 2;
float colourJitter = 1.0;   // 0 = exact image colour, 1 = slight hue/sat/bri variation

void setup() {
  size(1080, 1350);
  colorMode(HSB, 360, 100, 100);
  background(255);
  
  img = loadImage("veramolnar.JPG");
  
  // Scale proportionally
  float imgAspect = float(img.width) / img.height;
  float canvasAspect = float(width) / height;
  int newW, newH;
  if (imgAspect > canvasAspect) {
    newW = width;
    newH = int(width / imgAspect);
  } else {
    newH = height;
    newW = int(height * imgAspect);
  }
  img.resize(newW, newH);
  img.loadPixels();
  
  // Create flow field from brightness gradient
  cols = img.width;
  rows = img.height;
  flowField = new PVector[cols][rows];
  
  for (int y = 1; y < rows - 1; y++) {
    for (int x = 1; x < cols - 1; x++) {
      int index = x + y * img.width;
      float bL = brightness(img.pixels[index - 1]);
      float bR = brightness(img.pixels[index + 1]);
      float bU = brightness(img.pixels[index - img.width]);
      float bD = brightness(img.pixels[index + img.width]);
      
      float gx = bR - bL;
      float gy = bD - bU;
      
      // Direction perpendicular to gradient for contour flow
      float angle = atan2(gy, gx) + HALF_PI;
      flowField[x][y] = new PVector(cos(angle), sin(angle));
    }
  }
  
  // Create threads
  for (int i = 0; i < totalThreads; i++) {
    float startX = (width - img.width) / 2 + random(img.width);
    float startY = (height - img.height) / 2 + random(img.height);
    threads.add(new ThreadLine(startX, startY));
  }
}

void draw() {
  for (ThreadLine t : threads) {
    t.update();
    t.display();
  }
  
  saveFrame("output/frame-####.png");
}

void keyPressed() {
  if (key == '1') paletteMode = 0;
  if (key == '2') paletteMode = 1;
  if (key == '3') paletteMode = 2;
}

// Canvas position -> colour of that area in the image
color pickColour(PVector p) {
  float imgX = map(p.x, (width - img.width) / 2, (width + img.width) / 2, 0, img.width);
  float imgY = map(p.y, (height - img.height) / 2, (height + img.height) / 2, 0, img.height);
  int ix = constrain(int(imgX), 0, img.width - 1);
  int iy = constrain(int(imgY), 0, img.height - 1);
  color c = img.pixels[ix + iy * img.width];
  
  if (colourJitter <= 0) return c;
  // Small variation around the sampled colour, same spirit as the red variations
  float h = (hue(c) + random(-5, 5) * colourJitter + 360) % 360;
  float s = constrain(saturation(c) + random(-8, 8) * colourJitter, 0, 100);
  float b = constrain(brightness(c) + random(-8, 8) * colourJitter, 0, 100);
  return color(h, s, b);
}

class ThreadLine {
  ArrayList<PVector> path;
  ArrayList<Integer> colours;   // picked image colour at each point
  float xoff, yoff;
  color threadColor;
  
  ThreadLine(float x, float y) {
    path = new ArrayList<PVector>();
    colours = new ArrayList<Integer>();
    PVector start = new PVector(x, y);
    path.add(start);
    colours.add(pickColour(start));
    xoff = random(1000);
    yoff = random(1000);
    // Variations of red
    float hueVal = random(-5, 5);
    threadColor = color((0 + hueVal + 360) % 360, 80 + random(-15, 15), 80 + random(-20, 20));
  }
  
  void update() {
    PVector last = path.get(path.size() - 1);
    
    // Convert canvas coords to image coords
    float imgX = map(last.x, (width - img.width) / 2, (width + img.width) / 2, 0, img.width);
    float imgY = map(last.y, (height - img.height) / 2, (height + img.height) / 2, 0, img.height);
    
    imgX = constrain(imgX, 1, img.width - 2);
    imgY = constrain(imgY, 1, img.height - 2);
    
    PVector dir = flowField[int(imgX)][int(imgY)].copy();
    
    // Add organic wiggle
    float noiseAngle = map(noise(xoff, yoff), 0, 1, -PI / 6, PI / 6);
    dir.rotate(noiseAngle);
    dir.mult(3);
    
    PVector next = PVector.add(last, dir);
    
    // Constrain to canvas
    next.x = constrain(next.x, (width - img.width) / 2, (width + img.width) / 2);
    next.y = constrain(next.y, (height - img.height) / 2, (height + img.height) / 2);
    
    path.add(next);
    colours.add(pickColour(next));
    
    xoff += 0.02;
    yoff += 0.02;
  }
  
  void display() {
    noFill();
    strokeWeight(random(0.4, 1.5)); // Slight thickness variation
    
    if (paletteMode == 2) {
      // LIVE: each segment drawn in the colour of the area it crosses.
      // curve() between p1 and p2 keeps the same smooth Catmull-Rom line as curveVertex.
      int n = path.size();
      for (int i = 1; i < n; i++) {
        PVector p0 = path.get(max(i - 2, 0));
        PVector p1 = path.get(i - 1);
        PVector p2 = path.get(i);
        PVector p3 = path.get(min(i + 1, n - 1));
        stroke(colours.get(i), 180);
        curve(p0.x, p0.y, p1.x, p1.y, p2.x, p2.y, p3.x, p3.y);
      }
      return;
    }
    
    // RED or BIRTH: one colour for the whole thread, drawn as before
    color c = (paletteMode == 1) ? colours.get(0) : threadColor;
    stroke(c, 180);
    beginShape();
    for (PVector p : path) {
      curveVertex(p.x, p.y);
    }
    endShape();
  }
}
