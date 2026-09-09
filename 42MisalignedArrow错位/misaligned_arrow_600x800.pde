ArrayList<FloatingArrow> arrows = new ArrayList<FloatingArrow>();

// ===== 你主要改这里 =====
// 画布尺寸在 setup() 里的 size(600, 800)，如果改文件名/画布尺寸，也一起改那里。
color backgroundColor = #eeeeee; // 背景颜色
String backgroundImageName = "background.jpg"; // 背景图片文件名，放在这个草图文件夹里
boolean useBackgroundImage = true; // true 使用背景图片，false 使用纯色背景
color arrowColor = #777777; // 箭头颜色

float minSwipe = 18; // 鼠标拖动超过这个距离才会生成反向箭头

// 方框位置：这里直接写距离画面边缘多少像素，更方便手动调整。
float boxLeftGap = 100; // 方框左边距离画面左边多少像素
float boxRightGap = 100; // 方框右边距离画面右边多少像素
float boxTopGap = 80; // 方框上边距离画面上边多少像素
float boxBottomGap = 220; // 方框下边距离画面下边多少像素
float boxAlpha = 100; // 方框透明度，0 到 255
float boxWeight = 1.5; // 方框线条粗细
float boxFlashAlpha = 150; // 箭头撞到方框时，方框闪动的透明度
float boxFlashWeight = 3; // 箭头撞到方框时，方框闪动的线条粗细
int boxFlashFrames = 5; // 方框闪动持续时间，数字越大闪动越久
float boxGlowAlpha = 0; // 方框微微发光的透明度
float boxGlowWeight = 0; // 方框微微发光的范围，数字越大发光越散

float dragHintAlpha = 120; // 鼠标拖动时，轨迹箭头的透明度
float dragHintWeight = 1.4; // 鼠标拖动时，轨迹箭头的线条粗细

float floatingArrowBody = 28; // 漂浮小箭头的身体长度，数字越大箭头越长
float floatingArrowHead = 9; // 漂浮小箭头的箭头头部大小
float floatingArrowWeight = 2; // 漂浮小箭头的线条粗细
float arrowGlowAlpha = 0; // 箭头微微发光的透明度
float arrowGlowWeight = 0; // 箭头微微发光的范围，数字越大发光越散
float floatingArrowSpeed = 1.1; // 漂浮小箭头移动速度
float floatingArrowWobble = 0.35; // 漂浮小箭头晃动幅度，0 是完全直线
float floatingArrowAppearFrames = 12; // 漂浮小箭头弹出变清晰的时间
float arrowTipDistance = 5; // 两个箭头尖距离小于这个数时，才可能触发掉落
float arrowOppositeAmount = 0.75; // 箭头方向相反的严格程度，越接近 1 越需要正面对上
float arrowFallGravity = 0.18; // 箭头掉落重力，数字越大掉得越快
float arrowFloorY = 760; // 箭头最后落在画面中的高度位置
// ===== 主要改到这里结束 =====

float pressX;
float pressY;
boolean dragging = false;
int boxFlashTimer = 0;
PImage backgroundImage;

void setup() {
  size(600, 800);
  smooth(8);
  strokeCap(ROUND);
  strokeJoin(ROUND);
  backgroundImage = loadImage(sketchPath(backgroundImageName));
}

void draw() {
  drawBackground();

  for (int i = arrows.size() - 1; i >= 0; i--) {
    FloatingArrow a = arrows.get(i);
    a.update();
  }

  checkArrowCollisions();
  drawOffsetBox();

  if (dragging) {
    drawDragHint();
  }

  for (int i = arrows.size() - 1; i >= 0; i--) {
    FloatingArrow a = arrows.get(i);
    a.display();
  }
}

void drawBackground() {
  if (useBackgroundImage && backgroundImage != null) {
    image(backgroundImage, 0, 0, width, height);
  } else {
    background(backgroundColor);
  }
}

void mousePressed() {
  pressX = mouseX;
  pressY = mouseY;
  dragging = true;
}

void mouseReleased() {
  float dragX = mouseX - pressX;
  float dragY = mouseY - pressY;
  dragging = false;

  if (dist(pressX, pressY, mouseX, mouseY) < minSwipe) {
    return;
  }

  float oppositeAngle = atan2(-dragY, -dragX);
  arrows.add(new FloatingArrow(pressX, pressY, oppositeAngle));
}

void drawDragHint() {
  float d = dist(pressX, pressY, mouseX, mouseY);

  if (d < 4) {
    return;
  }

  drawArrowFromTo(pressX, pressY, mouseX, mouseY, dragHintAlpha, dragHintWeight);
}

void drawOffsetBox() {
  float flashAmount = 0;

  if (boxFlashTimer > 0) {
    flashAmount = boxFlashTimer / float(boxFlashFrames);
    boxFlashTimer--;
  }

  noFill();
  stroke(0, boxGlowAlpha);
  strokeWeight(lerp(boxWeight, boxFlashWeight, flashAmount) + boxGlowWeight);
  rect(boxLeft(), boxTop(), boxW(), boxH());

  stroke(0, lerp(boxAlpha, boxFlashAlpha, flashAmount));
  strokeWeight(lerp(boxWeight, boxFlashWeight, flashAmount));
  rect(boxLeft(), boxTop(), boxW(), boxH());
}

void keyPressed() {
  if (key == 'r' || key == 'R') {
    resetSketch();
  }
}

void resetSketch() {
  arrows.clear();
  dragging = false;
  boxFlashTimer = 0;
}

class FloatingArrow {
  float x;
  float y;
  float angle;
  float vx;
  float vy;
  float life = 0;
  float speed = floatingArrowSpeed;
  float wobbleSeed = random(1000);
  float body = floatingArrowBody;
  float head = floatingArrowHead;
  boolean falling = false;
  boolean landed = false;
  float fallSpeed = 0;
  float fallSpin = 0;

  FloatingArrow(float startX, float startY, float startAngle) {
    float margin = body * 0.6;
    x = constrain(startX, boxLeft() + margin, boxRight() - margin);
    y = constrain(startY, boxTop() + margin, boxBottom() - margin);
    angle = startAngle;
    vx = cos(angle) * speed;
    vy = sin(angle) * speed;
  }

  void update() {
    life++;

    if (landed) {
      return;
    }

    if (falling) {
      fallSpeed += arrowFallGravity;
      x += vx * 0.35;
      y += fallSpeed;
      angle += fallSpin;

      if (y > arrowFloorY) {
        y = arrowFloorY;
        vx = 0;
        fallSpeed = 0;
        landed = true;
      }

      return;
    }

    x += vx;
    y += vy;

    float sideWobble = sin(life * 0.08 + wobbleSeed) * floatingArrowWobble;
    x += cos(angle + HALF_PI) * sideWobble;
    y += sin(angle + HALF_PI) * sideWobble;

    float margin = body * 0.6;
    float leftWall = boxLeft() + margin;
    float rightWall = boxRight() - margin;
    float topWall = boxTop() + margin;
    float bottomWall = boxBottom() - margin;
    boolean hitBox = false;

    if (x < leftWall || x > rightWall) {
      vx *= -1;
      x = constrain(x, leftWall, rightWall);
      hitBox = true;
    }

    if (y < topWall || y > bottomWall) {
      vy *= -1;
      y = constrain(y, topWall, bottomWall);
      hitBox = true;
    }

    if (hitBox) {
      flashBox();
    }

    angle = atan2(vy, vx);
  }

  void display() {
    float appear = constrain(life / floatingArrowAppearFrames, 0, 1);
    float alpha = 255 * appear;
    float scaleAmount = 0.75 + 0.25 * appear;

    pushMatrix();
    translate(x, y);
    rotate(angle);
    scale(scaleAmount);

    noFill();

    float headAngle = PI / 4.0;

    stroke(arrowColor, arrowGlowAlpha * appear);
    strokeWeight(floatingArrowWeight + arrowGlowWeight);
    drawLocalArrowLines(headAngle);

    stroke(arrowColor, alpha);
    strokeWeight(floatingArrowWeight);
    drawLocalArrowLines(headAngle);

    popMatrix();
  }

  void drawLocalArrowLines(float headAngle) {
    line(-body * 0.5, 0, body * 0.5, 0);
    line(body * 0.5, 0, body * 0.5 - cos(headAngle) * head, -sin(headAngle) * head);
    line(body * 0.5, 0, body * 0.5 - cos(headAngle) * head, sin(headAngle) * head);
  }

  void startFalling() {
    if (falling || landed) {
      return;
    }

    falling = true;
    fallSpeed = random(1.2, 2.4);
    fallSpin = random(-0.045, 0.045);
  }

  float tipX() {
    return x + cos(angle) * body * 0.5;
  }

  float tipY() {
    return y + sin(angle) * body * 0.5;
  }
}

void flashBox() {
  boxFlashTimer = boxFlashFrames;
}

void checkArrowCollisions() {
  for (int i = 0; i < arrows.size(); i++) {
    FloatingArrow a = arrows.get(i);

    if (a.falling || a.landed) {
      continue;
    }

    for (int j = i + 1; j < arrows.size(); j++) {
      FloatingArrow b = arrows.get(j);

      if (b.falling || b.landed) {
        continue;
      }

      if (arrowsFacingEachOther(a, b)) {
        a.startFalling();
        b.startFalling();
        break;
      }
    }
  }
}

boolean arrowsFacingEachOther(FloatingArrow a, FloatingArrow b) {
  float tipDistance = dist(a.tipX(), a.tipY(), b.tipX(), b.tipY());
  float directionDot = cos(a.angle) * cos(b.angle) + sin(a.angle) * sin(b.angle);

  return tipDistance < arrowTipDistance && directionDot < -arrowOppositeAmount;
}

float boxLeft() {
  return boxLeftGap;
}

float boxRight() {
  return width - boxRightGap;
}

float boxTop() {
  return boxTopGap;
}

float boxBottom() {
  return height - boxBottomGap;
}

float boxW() {
  return boxRight() - boxLeft();
}

float boxH() {
  return boxBottom() - boxTop();
}

void drawArrowFromTo(float x1, float y1, float x2, float y2, float alpha, float weight) {
  float angle = atan2(y2 - y1, x2 - x1);
  float len = dist(x1, y1, x2, y2);
  float head = constrain(len * 0.22, 8, 22);
  float headAngle = PI / 4.0;

  noFill();

  stroke(arrowColor, arrowGlowAlpha * alpha / 255.0);
  strokeWeight(weight + arrowGlowWeight);
  drawArrowLines(x1, y1, x2, y2, angle, head, headAngle);

  stroke(arrowColor, alpha);
  strokeWeight(weight);
  drawArrowLines(x1, y1, x2, y2, angle, head, headAngle);
}

void drawArrowLines(float x1, float y1, float x2, float y2, float angle, float head, float headAngle) {
  line(x1, y1, x2, y2);
  line(x2, y2, x2 - cos(angle - headAngle) * head, y2 - sin(angle - headAngle) * head);
  line(x2, y2, x2 - cos(angle + headAngle) * head, y2 - sin(angle + headAngle) * head);
}
