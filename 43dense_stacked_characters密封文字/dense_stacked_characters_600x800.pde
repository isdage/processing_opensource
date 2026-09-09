ArrayList<Glyph> glyphs = new ArrayList<Glyph>();
ArrayList<Glyph>[] rowGlyphs;
boolean[] rowStarted;
PImage bgImage;
PGraphics staticTextLayer;
PFont glyphFont;
PFont chineseFont;
boolean staticTextDirty = true;

String[] rowTexts = {
  "after the thaw the white margin loosens",
  "the last ice forgets its edge",
  "small letters soften under light",
  "water takes the shape of what was held",
  "a cold sentence opens into air",
  "the page keeps only a pale residue",
  "silence rises from the melted line",
  "each word loses its hard outline",
  "a bright hush gathers above the margin",
  "the alphabet thins into clear water",
  "what was fixed begins to breathe",
  "only the first letters remember"
};

// ===== 可调参数 =====
// 画布尺寸：如果要改尺寸，改 setup() 里的 size(600, 800)。

// 背景与文字颜色：0 是黑色，255 是白色。
int backgroundGray = 246;
int textGray = 0;

// 背景图片文件名：当前文件夹里是 backgroud.jpg。
String backgroundFile = "backgroud.jpg";

// 漂浮范围框：showBox = false 时隐藏边框，但范围仍然生效。
boolean showBox = false;
float boxX = 55;
float boxY = 105;
float boxW = 480;
float boxH = 630;
int boxGray = 0;
float boxAlpha = 120;
float boxStrokeWeight = 1.5;

// 字符碰到参考框边缘后的反弹力度：1 是完全反弹，小一点会更柔和。
float bounceDamping = 0.3;

// 字符和边框之间留一点距离，避免文字贴到框线上。
float boxPadding = 4;

// 左侧文字柱的位置：数值越小越靠左。
float pileX = 78;

// 显示多少行。
int rowCount = 12;

// 第一行的 y 坐标。
float firstRowY = 450;

// 每行之间的随机距离范围：数值越大，行距越疏，也越参差。
float minRowGap = 18;
float maxRowGap = 30;

// 每行最左侧的初始字距：数值越小，左边越密。
float minCompactSpacing = 0.45;
float maxCompactSpacing = 0.9;

// 字符越往右，字距逐渐变大的幅度：数值越大，层级疏离感越明显。
float minSpacingGrowth = 0.10;
float maxSpacingGrowth = 0.24;

// 字距增长的曲线：越大，越靠左越挤，越靠右才明显散开。
float spacingCurve = 0.1;

// 每行横向额外错位：给不同段落一点长短不一的自然感。
float rowLooseJitter = 0.8;

// 字符有多大：每个字符会在这个范围内取字号。
float minTextSize = 9;
float maxTextSize = 25;

// 随机掺入的中文字符。chineseChance 越大，中文越多。
String chineseText = "我喜欢你";
float chineseChance = 0.12;

// 鼠标离一行多近时触发这一整行：数值越大，触发范围越宽。
float touchYRange = 9;

// 一行被触发后，字符从右到左依次蒸发的间隔帧数。
int evaporationGap = 3;

// 字符被蒸发后向右上方飘散的速度范围。
float minRiseSpeed = 1.2;
float maxRiseSpeed = 3.0;
float minRightSpeed = 0.4;
float maxRightSpeed = 2.0;

// 往右、往上的整体力度：数值越大，字符越往右上角飘。
float rightPush = 1.4;
float upwardPush = 1.25;

// 飘散后的字符透明度：255 是完全不透明，不会消失。
float floatingAlpha = 255;

// 飘散时的轻微泡泡晃动幅度。
float bubbleWobble = 5;

// 持续漂浮力度：字符不消失后，用它保持细微流动。
float floatingDrift = 0.04;

// 鼠标搅动漂浮字符的范围和力度。
float stirRadius = 55;
float stirPush = 0.18;
float stirSwirl = 0.14;
float stirMaxSpeed = 3.2;

// 搅动后的阻尼：越接近 1 停得越慢，越小停得越快。
float velocityDamping = 0.992;
float rotationDamping = 0.94;
float maxRotSpeed = 0.08;

// 随机种子：换一个数字会得到另一种固定排布。
int layoutSeed = 8;

void setup() {
  size(600, 800);
  smooth(2);
  glyphFont = createFont("Times New Roman", 32);
  chineseFont = createFont("Songti SC", 32);
  textFont(glyphFont);
  bgImage = loadImage(sketchPath(backgroundFile));
  if (bgImage != null) {
    bgImage.resize(width, height);
  }
  staticTextLayer = createGraphics(width, height);
  buildGlyphs();
}

void draw() {
  if (bgImage != null) {
    image(bgImage, 0, 0);
  } else {
    background(backgroundGray);
  }

  drawGuideBox();

  triggerTouchedGlyphs();

  if (staticTextDirty) {
    rebuildStaticTextLayer();
  }
  image(staticTextLayer, 0, 0);

  for (Glyph g : glyphs) {
    if (g.floating) {
      g.update();
      g.show();
    }
  }
}

void drawGuideBox() {
  if (!showBox) return;

  noFill();
  stroke(boxGray, boxAlpha);
  strokeWeight(boxStrokeWeight);
  rect(boxX, boxY, boxW, boxH);
  noStroke();
}

void keyPressed() {
  if (key == 'r' || key == 'R') {
    buildGlyphs();
  }
}

void buildGlyphs() {
  glyphs.clear();
  randomSeed(layoutSeed);
  rowGlyphs = (ArrayList<Glyph>[]) new ArrayList[rowCount];
  rowStarted = new boolean[rowCount];
  float y = firstRowY;

  for (int r = 0; r < rowCount; r++) {
    rowGlyphs[r] = new ArrayList<Glyph>();
    String rowText = rowTexts[r % rowTexts.length];
    float spacing = random(minCompactSpacing, maxCompactSpacing);
    float spacingGrowth = random(minSpacingGrowth, maxSpacingGrowth);
    float cursor = 0;
    int visibleIndex = 0;

    for (int i = 0; i < rowText.length(); i++) {
      char c = rowText.charAt(i);
      if (c != ' ') {
        if (random(1) < chineseChance) {
          c = chineseText.charAt(int(random(chineseText.length())));
        }
        float x = pileX + cursor + random(-rowLooseJitter, rowLooseJitter);
        float s = random(minTextSize, maxTextSize);
        Glyph g = new Glyph(c, x, y, s);
        glyphs.add(g);
        rowGlyphs[r].add(g);
        visibleIndex++;
      }
      cursor += spacing + pow(visibleIndex, spacingCurve) * spacingGrowth;
    }

    y += random(minRowGap, maxRowGap);
  }

  staticTextDirty = true;
}

void rebuildStaticTextLayer() {
  staticTextLayer.beginDraw();
  staticTextLayer.clear();
  staticTextLayer.textFont(glyphFont);
  staticTextLayer.noStroke();

  for (Glyph g : glyphs) {
    if (!g.floating) {
      g.showOn(staticTextLayer);
    }
  }

  staticTextLayer.endDraw();
  staticTextDirty = false;
}

void triggerTouchedGlyphs() {
  for (int r = 0; r < rowCount; r++) {
    if (!rowStarted[r] && rowIsInRange(r)) {
      startRowEvaporation(r);
    }
  }
}

boolean rowIsInRange(int rowIndex) {
  ArrayList<Glyph> row = rowGlyphs[rowIndex];
  if (row.size() == 0) return false;

  float rowCenterY = row.get(0).homeY;
  return abs(mouseY - rowCenterY) < touchYRange;
}

void startRowEvaporation(int rowIndex) {
  rowStarted[rowIndex] = true;
  ArrayList<Glyph> row = rowGlyphs[rowIndex];

  for (int i = 0; i < row.size() - 1; i++) {
    for (int j = i + 1; j < row.size(); j++) {
      if (row.get(i).homeX > row.get(j).homeX) {
        Glyph temp = row.get(i);
        row.set(i, row.get(j));
        row.set(j, temp);
      }
    }
  }

  for (int i = 0; i < row.size(); i++) {
    Glyph g = row.get(i);
    g.floating = true;
    g.waitFrames = (row.size() - 1 - i) * evaporationGap;
  }

  staticTextDirty = true;
}

boolean isChineseChar(char c) {
  return c >= '\u4E00' && c <= '\u9FFF';
}

class Glyph {
  char c;
  float homeX;
  float homeY;
  float x;
  float y;
  float size;
  float alpha = 255;
  float vx = 0;
  float vy = 0;
  float rot = 0;
  float rotSpeed = 0;
  float wobbleSeed;
  PGraphics glyphImage;
  float imageOffsetX;
  float imageOffsetY;
  int waitFrames = -1;
  boolean evaporating = false;
  boolean floating = false;

  Glyph(char c_, float x_, float y_, float size_) {
    c = c_;
    homeX = x_;
    homeY = y_;
    x = homeX;
    y = homeY;
    size = size_;
    alpha = floatingAlpha;
    wobbleSeed = random(1000);
    makeGlyphImage();
  }

  void makeGlyphImage() {
    float pad = size * 0.55;
    int imgW = max(14, int(size * 2.6));
    int imgH = max(14, int(size * 2.6));

    imageOffsetX = -pad;
    imageOffsetY = -(pad + size);

    glyphImage = createGraphics(imgW, imgH);
    glyphImage.beginDraw();
    glyphImage.clear();
    glyphImage.textFont(isChineseChar(c) ? chineseFont : glyphFont);
    glyphImage.fill(textGray, alpha);
    glyphImage.textSize(size);
    glyphImage.text(c, pad, pad + size);
    glyphImage.endDraw();
  }

  void evaporate() {
    evaporating = true;
    vx = random(minRightSpeed, maxRightSpeed) * rightPush;
    vy = -random(minRiseSpeed, maxRiseSpeed) * upwardPush;
    rotSpeed = random(-0.035, 0.035);
  }

  void update() {
    if (waitFrames > 0) {
      waitFrames--;
      return;
    }

    if (waitFrames == 0) {
      waitFrames = -1;
      evaporate();
    }

    if (!evaporating) return;

    float wobble = sin(frameCount * 0.12 + wobbleSeed) * bubbleWobble;
    float drift = cos(frameCount * 0.07 + wobbleSeed) * floatingDrift;
    applyMouseStir();
    x += vx + wobble * 0.04 + drift;
    y += vy + drift;
    vy -= 0.012;
    bounceInsideBox();
    rot += rotSpeed;
    vx *= velocityDamping;
    vy *= velocityDamping;
    rotSpeed *= rotationDamping;
  }

  void applyMouseStir() {
    if (mouseX < boxX || mouseX > boxX + boxW || mouseY < boxY || mouseY > boxY + boxH) return;

    float dx = x - mouseX;
    float dy = y - mouseY;
    float d = sqrt(dx * dx + dy * dy);
    if (d <= 0 || d > stirRadius) return;

    float amount = 1.0 - d / stirRadius;
    float mouseSpeed = dist(mouseX, mouseY, pmouseX, pmouseY);
    float force = amount * (1.0 + mouseSpeed * 0.04);

    float nx = dx / d;
    float ny = dy / d;
    float swirlX = -ny;
    float swirlY = nx;

    vx += nx * stirPush * force + swirlX * stirSwirl * force;
    vy += ny * stirPush * force + swirlY * stirSwirl * force;

    vx = constrain(vx, -stirMaxSpeed, stirMaxSpeed);
    vy = constrain(vy, -stirMaxSpeed, stirMaxSpeed);
    rotSpeed += stirSwirl * force * 0.01;
    rotSpeed = constrain(rotSpeed, -maxRotSpeed, maxRotSpeed);
  }

  void bounceInsideBox() {
    float margin = size * 0.35 + boxPadding;
    float leftEdge = boxX + margin;
    float rightEdge = boxX + boxW - margin;
    float topEdge = boxY + margin;
    float bottomEdge = boxY + boxH - margin;

    if (x < leftEdge) {
      x = leftEdge;
      vx = abs(vx) * bounceDamping;
    }

    if (x > rightEdge) {
      x = rightEdge;
      vx = -abs(vx) * bounceDamping;
    }

    if (y < topEdge) {
      y = topEdge;
      vy = abs(vy) * bounceDamping;
    }

    if (y > bottomEdge) {
      y = bottomEdge;
      vy = -abs(vy) * bounceDamping;
    }
  }

  void show() {
    if (alpha <= 0) return;

    pushMatrix();
    translate(x, y);
    rotate(rot);
    image(glyphImage, imageOffsetX, imageOffsetY);
    popMatrix();
  }

  void showOn(PGraphics pg) {
    pg.pushMatrix();
    pg.translate(x, y);
    pg.rotate(rot);
    pg.image(glyphImage, imageOffsetX, imageOffsetY);
    pg.popMatrix();
  }
}
