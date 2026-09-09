PGraphics cover;
PImage bg;
Snow[] snow;

void setup() {
  size(600, 800);
  smooth(4);

  bg = loadImage("background.jpg");

  cover = createGraphics(width, height);
  makeFreshSnowCover();

  snow = new Snow[680];
  for (int i = 0; i < snow.length; i++) {
    snow[i] = new Snow(true);
  }
}

void draw() {
  drawBackgroundImage();

  recoverCover();

  if (mouseIsMoving()) {
    brushSnowPath(pmouseX, pmouseY, mouseX, mouseY);
  }

  image(cover, 0, 0);
  drawFallingSnow();
}

void keyPressed() {
  if (key == 'r' || key == 'R') {
    restartSketch();
  }
}

void restartSketch() {
  makeFreshSnowCover();

  for (int i = 0; i < snow.length; i++) {
    snow[i].reset(true);
  }
}

void drawBackgroundImage() {
  background(232, 228, 214);

  if (bg == null) {
    return;
  }

  float scale = max(width / float(bg.width), height / float(bg.height));
  float w = bg.width * scale;
  float h = bg.height * scale;

  imageMode(CENTER);
  image(bg, width / 2, height / 2, w, h);
  imageMode(CORNER);
}

void recoverCover() {
  cover.beginDraw();
  cover.noStroke();
  cover.fill(248, 250, 250, 6);
  cover.rect(0, 0, width, height);

  for (int i = 0; i < 52; i++) {
    float r = random(0.8, 4.2);
    cover.fill(255, random(24, 56));
    cover.ellipse(random(width), random(height), r, r);
  }

  if (frameCount % 3 == 0) {
    for (int i = 0; i < 8; i++) {
      float r = random(6, 20);
      cover.fill(255, random(14, 34));
      cover.ellipse(random(width), random(height), r, r);
    }
  }
  cover.endDraw();
}

boolean mouseIsMoving() {
  return abs(mouseX - pmouseX) + abs(mouseY - pmouseY) > 0;
}

void makeFreshSnowCover() {
  cover.beginDraw();
  cover.noStroke();
  cover.fill(248, 250, 250, 252);
  cover.rect(0, 0, width, height);

  for (int i = 0; i < 1900; i++) {
    float r = random(0.5, 3.4);
    cover.fill(255, random(35, 110));
    cover.ellipse(random(width), random(height), r, r);
  }

  for (int i = 0; i < 130; i++) {
    float r = random(10, 42);
    cover.fill(225, 233, 236, random(14, 34));
    cover.ellipse(random(width), random(height), r * 1.5, r);
    cover.fill(255, random(36, 82));
    cover.ellipse(random(width), random(height), r, r * 0.72);
  }
  cover.endDraw();
}

void brushSnowPath(float x1, float y1, float x2, float y2) {
  float speed = dist(x1, y1, x2, y2);
  int steps = max(1, int(speed / 8));
  float angle = atan2(y2 - y1, x2 - x1);

  for (int i = 0; i <= steps; i++) {
    float t = i / float(steps);
    float x = lerp(x1, x2, t);
    float y = lerp(y1, y2, t);
    carveSnow(x, y, 68);
    pileSnowAroundBrush(x, y, angle);
  }
}

void carveSnow(float x, float y, float radius) {
  int left = max(0, int(x - radius));
  int right = min(width - 1, int(x + radius));
  int top = max(0, int(y - radius));
  int bottom = min(height - 1, int(y + radius));

  cover.loadPixels();
  for (int py = top; py <= bottom; py++) {
    for (int px = left; px <= right; px++) {
      float d = dist(px, py, x, y);
      if (d < radius) {
        int index = py * width + px;
        color c = cover.pixels[index];
        float softness = sq(1 - d / radius);
        float newAlpha = max(0, alpha(c) - softness * 135);
        cover.pixels[index] = color(248, 250, 250, newAlpha);
      }
    }
  }
  cover.updatePixels();
}

void pileSnowAroundBrush(float x, float y, float angle) {
  cover.beginDraw();
  cover.noStroke();

  for (int i = 0; i < 10; i++) {
    float side = random(1) < 0.5 ? -HALF_PI : HALF_PI;
    float a = angle + side + random(-0.55, 0.55);
    float d = random(50, 82);
    float px = x + cos(a) * d;
    float py = y + sin(a) * d;
    float w = random(10, 30);
    float h = random(4, 13);

    cover.pushMatrix();
    cover.translate(px, py);
    cover.rotate(a + random(-0.6, 0.6));
    cover.fill(202, 214, 220, random(16, 34));
    cover.ellipse(2, 3, w * 1.25, h * 1.35);
    cover.fill(255, random(105, 190));
    cover.ellipse(0, 0, w, h);
    cover.popMatrix();
  }

  for (int i = 0; i < 18; i++) {
    float a = random(TWO_PI);
    float d = random(46, 92);
    float r = random(1, 4.5);
    cover.fill(255, random(90, 180));
    cover.ellipse(x + cos(a) * d, y + sin(a) * d, r, r);
  }

  cover.endDraw();
}

void drawFallingSnow() {
  noStroke();
  for (int i = 0; i < snow.length; i++) {
    snow[i].fall();
    snow[i].show();
  }
}

class Snow {
  float x;
  float y;
  float r;
  float speed;
  float sway;
  float drift;
  float alpha;
  float glow;

  Snow(boolean scatter) {
    reset(scatter);
  }

  void reset(boolean scatter) {
    x = random(width);
    y = scatter ? random(height) : random(-80, -10);

    float kind = random(1);
    if (kind < 0.72) {
      r = random(0.8, 2.2);
      speed = random(0.55, 1.5);
      alpha = random(105, 210);
      glow = random(1.4, 2.2);
    } else if (kind < 0.94) {
      r = random(2.2, 6.5);
      speed = random(0.45, 1.15);
      alpha = random(70, 165);
      glow = random(2.0, 3.4);
    } else {
      r = random(8, 24);
      speed = random(0.25, 0.8);
      alpha = random(35, 92);
      glow = random(2.5, 4.2);
    }

    sway = random(0.006, 0.025);
    drift = random(-0.28, 0.28);
  }

  void fall() {
    x += sin(frameCount * sway + y * 0.018) * 0.55 + drift;
    y += speed;

    if (x < -30) {
      x = width + 30;
    }
    if (x > width + 30) {
      x = -30;
    }
    if (y > height + 10) {
      reset(false);
    }
  }

  void show() {
    fill(255, alpha * 0.16);
    ellipse(x, y, r * glow, r * glow);

    fill(255, alpha * 0.42);
    ellipse(x, y, r * 1.45, r * 1.45);

    fill(255, alpha);
    ellipse(x, y, r, r);
  }
}
