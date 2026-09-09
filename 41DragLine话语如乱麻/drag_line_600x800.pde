float lineThickness = 1.5; // 在这里调整线条粗细，数字越大线越粗
int lineSmooth = 20; // 在这里调整线条圆滑度，数字越大越圆滑
String letters = "Sometimes the wind writes in silence"; // 在这里调整飘出的字母内容
String letterFontName = "Luminari.ttf"; // 在这里调整字体文件名，字体文件放在 data 文件夹里
float letterMinSize = 10; // 在这里调整字母最小字号
float letterMaxSize = 20; // 在这里调整字母最大字号
float letterGap = 16; // 在这里调整字母整体密度，数字越小字母越密
float letterGapVariation = 20; // 在这里调整字母疏密变化，数字越大越不均匀
float denseChance = 0.45; // 在这里调整密集段出现概率，0 到 1 之间
float letterMinOffset = 10; // 在这里调整字母离轨迹的最小距离
float letterMaxOffset = 22; // 在这里调整字母离轨迹的最大距离，建议不要太大
float letterAngleJitter = 0.18; // 在这里调整字母角度随机感，0 是完全跟随轨迹
float letterMinFloatAmount = 0; // 在这里调整字母最小浮动幅度，0 是不动
float letterMaxFloatAmount = 10; // 在这里调整字母最大浮动幅度，数字越大晃动越明显
float letterMinFloatSpeed = 0.01; // 在这里调整字母最小浮动速度
float letterMaxFloatSpeed = 0.1; // 在这里调整字母最大浮动速度
float letterStillChance = 0.05; // 在这里调整字母不浮动的概率，0 到 1 之间
boolean letterFloatEnabled = false; // 在这里调整字母浮动开关，false 关闭，true 开启；运行时按 m 键切换
boolean letterCollisionEnabled = true; // 在这里调整静态字母碰撞掉落开关，true 开启，false 关闭
float letterCollisionScale = 0.55; // 在这里调整字母碰撞范围，数字越大越容易碰撞掉落
float letterGravity = 0.18; // 在这里调整字母掉落重力，数字越大掉得越快
float letterFloorY = 730; // 在这里调整字母落地的位置
float letterBounce = 0.32; // 在这里调整字母落地回弹力度，数字越大弹得越高
float letterFloorFriction = 0.26; // 在这里调整字母落地后的横向摩擦，数字越小滑动越快停下
float letterSettleSpeed = 0.7; // 在这里调整字母停止弹动的阈值，数字越大越快停住

PGraphics lineLayer;
PFont letterFont;
ArrayList<TrailLetter> trailLetters = new ArrayList<TrailLetter>();
float lastLetterX;
float lastLetterY;
float nextLetterGap;
boolean denseGroup = false;
int densityGroupLeft = 0;
int letterIndex = 0;
int strokeIndex = 0;

void settings() {
  size(600, 800);
  smooth(lineSmooth);
}

void setup() {
  lineLayer = createGraphics(600, 800);
  lineLayer.beginDraw();
  lineLayer.smooth(lineSmooth);
  lineLayer.background(#f3f3f5);
  lineLayer.stroke(0);
  lineLayer.strokeWeight(lineThickness);
  lineLayer.strokeCap(ROUND);
  lineLayer.strokeJoin(ROUND);
  lineLayer.endDraw();

  stroke(0);
  strokeWeight(lineThickness);
  strokeCap(ROUND);
  strokeJoin(ROUND);
  letterFont = createFont(letterFontName, letterMaxSize);
  textFont(letterFont);
  nextLetterGap = chooseNextLetterGap();
}

void draw() {
  background(#f3f3f5);
  image(lineLayer, 0, 0);

  if (!letterFloatEnabled && letterCollisionEnabled) {
    checkLetterCollisions();
  }

  for (int i = 0; i < trailLetters.size(); i++) {
    TrailLetter l = trailLetters.get(i);
    l.update();
    l.display();
  }
}

void mouseDragged() {
  lineLayer.beginDraw();
  lineLayer.line(pmouseX, pmouseY, mouseX, mouseY);
  lineLayer.endDraw();

  if (dist(mouseX, mouseY, lastLetterX, lastLetterY) > nextLetterGap) {
    addTrailLetter(mouseX, mouseY, pmouseX, pmouseY);
    lastLetterX = mouseX;
    lastLetterY = mouseY;
    nextLetterGap = chooseNextLetterGap();
  }
}

void mousePressed() {
  lastLetterX = mouseX;
  lastLetterY = mouseY;
  nextLetterGap = chooseNextLetterGap();
  strokeIndex++;
}

void keyPressed() {
  if (key == 'm' || key == 'M') {
    letterFloatEnabled = !letterFloatEnabled;
  }

  if (key == 'r' || key == 'R') {
    resetSketch();
  }
}

void resetSketch() {
  letterFloatEnabled = false;

  lineLayer.beginDraw();
  lineLayer.background(#f3f3f5);
  lineLayer.endDraw();

  trailLetters.clear();
  letterIndex = 0;
  strokeIndex = 0;
  densityGroupLeft = 0;
  nextLetterGap = chooseNextLetterGap();
}

void addTrailLetter(float x, float y, float oldX, float oldY) {
  char c = letters.charAt(letterIndex % letters.length());
  letterIndex++;

  while (c == ' ') {
    c = letters.charAt(letterIndex % letters.length());
    letterIndex++;
  }

  float angle = atan2(y - oldY, x - oldX);
  trailLetters.add(new TrailLetter(c, x, y, angle, strokeIndex, letterIndex));
}

float chooseNextLetterGap() {
  if (densityGroupLeft <= 0) {
    denseGroup = random(1) < denseChance;
    densityGroupLeft = int(random(2, 7));
  }

  densityGroupLeft--;

  if (denseGroup) {
    float denseMin = max(3, letterGap - letterGapVariation);
    float denseMax = max(denseMin + 1, letterGap * 0.75);
    return random(denseMin, denseMax);
  } else {
    float looseMin = letterGap;
    float looseMax = max(looseMin + 1, letterGap + letterGapVariation);
    return random(looseMin, looseMax);
  }
}

void checkLetterCollisions() {
  for (int i = 0; i < trailLetters.size(); i++) {
    TrailLetter a = trailLetters.get(i);
    if (a.falling || a.landed) {
      continue;
    }

    for (int j = i + 1; j < trailLetters.size(); j++) {
      TrailLetter b = trailLetters.get(j);
      if (b.falling || b.landed) {
        continue;
      }

      if (a.strokeId == b.strokeId && abs(a.orderId - b.orderId) < 5) {
        continue;
      }

      float collisionDistance = (a.size + b.size) * letterCollisionScale;
      if (dist(a.x, a.y, b.x, b.y) < collisionDistance) {
        a.startFalling();
        b.startFalling();
        break;
      }
    }
  }
}

class TrailLetter {
  char c;
  float x;
  float y;
  float angle;
  float size;
  float floatPhase;
  float floatSpeed;
  float floatAmount;
  int strokeId;
  int orderId;
  boolean falling = false;
  boolean landed = false;
  float fallX;
  float fallY;
  float fallVX;
  float fallVY;
  float fallSpin;

  TrailLetter(char tempC, float targetX, float targetY, float tempAngle, int tempStrokeId, int tempOrderId) {
    c = tempC;
    strokeId = tempStrokeId;
    orderId = tempOrderId;
    float side = random(1) < 0.5 ? -1 : 1;
    float offset = random(letterMinOffset, letterMaxOffset) * side;
    x = targetX + cos(tempAngle + HALF_PI) * offset;
    y = targetY + sin(tempAngle + HALF_PI) * offset;
    fallX = x;
    fallY = y;
    angle = tempAngle + random(-letterAngleJitter, letterAngleJitter);
    size = random(letterMinSize, letterMaxSize);
    floatPhase = random(TWO_PI);
    if (random(1) < letterStillChance) {
      floatSpeed = 0;
      floatAmount = 0;
    } else {
      floatSpeed = random(letterMinFloatSpeed, letterMaxFloatSpeed);
      floatAmount = random(letterMinFloatAmount, letterMaxFloatAmount);
    }
  }

  void startFalling() {
    falling = true;
    fallX = x;
    fallY = y;
    fallVX = random(-0.6, 0.6);
    fallVY = random(0.4, 1.2);
    fallSpin = random(-0.04, 0.04);
  }

  void update() {
    if (falling) {
      fallX += fallVX;
      fallY += fallVY;
      fallVY += letterGravity;
      angle += fallSpin;

      keepInsideCanvas();
      landOnFloor();
    }
  }

  void keepInsideCanvas() {
    float r = size * 0.35;

    if (fallX < r) {
      fallX = r;
      fallVX *= -0.35;
    }

    if (fallX > width - r) {
      fallX = width - r;
      fallVX *= -0.35;
    }
  }

  void landOnFloor() {
    float r = size * 0.35;

    if (fallY + r >= letterFloorY) {
      fallY = letterFloorY - r;

      if (abs(fallVY) < letterSettleSpeed) {
        stopFalling();
      } else {
        fallVY *= -letterBounce;
        fallVX *= letterFloorFriction;
      }
    }
  }

  void stopFalling() {
    falling = false;
    landed = true;
    fallVX = 0;
    fallVY = 0;
    fallSpin = 0;
  }

  void display() {
    float floatingX = 0;
    float floatingY = 0;
    float floatingAngle = 0;

    if (letterFloatEnabled && !falling && !landed) {
      float t = frameCount * floatSpeed + floatPhase;
      floatingX = sin(t * 0.7) * floatAmount * 0.45;
      floatingY = cos(t) * floatAmount;
      floatingAngle = sin(t * 0.8) * 0.08;
    }

    pushMatrix();
    if (falling || landed) {
      translate(fallX, fallY);
    } else {
      translate(x + floatingX, y + floatingY);
    }
    rotate(angle + floatingAngle);
    fill(0);
    noStroke();
    textFont(letterFont);
    textSize(size);
    textAlign(CENTER, CENTER);
    text(c, 0, 0);
    popMatrix();
  }
}
