(function () {
  "use strict";

  const WIDTH = 600;
  const HEIGHT = 800;
  const TARGET_GAP = -40;
  const MAX_STITCHES = 34;
  const AUTO_DISSOLVE_DELAY = 3000;

  const canvas = document.getElementById("stitchCanvas");
  const ctx = canvas.getContext("2d");
  const dpr = Math.max(1, Math.min(window.devicePixelRatio || 1, 2));

  let leftImage;
  let rightImage;
  let pieces = [];
  let stitches = [];
  let threadDust = [];
  let stitching = false;
  let lastStitchY = -9999;
  let lockGap = 0;
  let lockedPositions = [];
  let dissolveStartPositions = [];
  let threadDissolving = false;
  let threadDissolveProgress = 0;
  let fullyTightSince = null;
  let autoDissolveStarted = false;

  function init() {
    canvas.width = WIDTH * dpr;
    canvas.height = HEIGHT * dpr;
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);

    Promise.all([
      loadImage("./photo_left_piece.png"),
      loadImage("./photo_right_piece.png")
    ]).then(([left, right]) => {
      leftImage = left;
      rightImage = right;
      setupPieces();
      bindEvents();
      requestAnimationFrame(draw);
    });
  }

  function loadImage(src) {
    return new Promise((resolve, reject) => {
      const image = new Image();
      image.onload = () => {
        const maskCanvas = document.createElement("canvas");
        const maskCtx = maskCanvas.getContext("2d");
        maskCanvas.width = image.naturalWidth;
        maskCanvas.height = image.naturalHeight;
        maskCtx.drawImage(image, 0, 0);
        image.alphaData = maskCtx.getImageData(0, 0, maskCanvas.width, maskCanvas.height).data;
        resolve(image);
      };
      image.onerror = reject;
      image.src = src;
    });
  }

  function setupPieces() {
    const scale = 0.43;
    pieces = [
      {
        name: "left",
        img: leftImage,
        x: 58,
        y: 70,
        w: leftImage.naturalWidth * scale,
        h: leftImage.naturalHeight * scale
      },
      {
        name: "right",
        img: rightImage,
        x: 336,
        y: 102,
        w: rightImage.naturalWidth * scale,
        h: rightImage.naturalHeight * scale
      }
    ];

    lockGap = getPieceGap();
    lockedPositions = getCurrentPiecePositions();
  }

  function bindEvents() {
    canvas.addEventListener("pointerdown", handlePointerDown, { passive: false });
    canvas.addEventListener("pointermove", handlePointerMove, { passive: false });
    canvas.addEventListener("pointerup", handlePointerUp, { passive: false });
    canvas.addEventListener("pointercancel", handlePointerUp, { passive: false });
    window.addEventListener("keydown", handleKeyDown);
  }

  function handlePointerDown(event) {
    event.preventDefault();
    canvas.setPointerCapture(event.pointerId);
    const point = getPointerPoint(event);
    stitching = true;
    lastStitchY = -9999;
    addStitchAt(point.x, point.y, true);
  }

  function handlePointerMove(event) {
    event.preventDefault();
    if (!stitching || threadDissolving || autoDissolveStarted) {
      return;
    }

    const point = getPointerPoint(event);
    addStitchAt(point.x, point.y, false);
  }

  function handlePointerUp(event) {
    event.preventDefault();
    stitching = false;
  }

  function handleKeyDown(event) {
    if (event.key === "r" || event.key === "R") {
      resetSketch();
    }
  }

  function getPointerPoint(event) {
    const rect = canvas.getBoundingClientRect();
    return {
      x: ((event.clientX - rect.left) / rect.width) * WIDTH,
      y: ((event.clientY - rect.top) / rect.height) * HEIGHT
    };
  }

  function draw() {
    ctx.clearRect(0, 0, WIDTH, HEIGHT);
    ctx.fillStyle = "#ffffff";
    ctx.fillRect(0, 0, WIDTH, HEIGHT);

    if (threadDissolving) {
      updateThreadDissolve();
    } else {
      tightenPieces();
      checkAutoDissolve();
    }

    for (const piece of pieces) {
      ctx.drawImage(piece.img, piece.x, piece.y, piece.w, piece.h);
    }

    drawStitches();
    drawThreadDust();
    requestAnimationFrame(draw);
  }

  function addStitchAt(x, y, force) {
    if (threadDissolving || autoDissolveStarted) {
      return;
    }

    const seam = getSeamAt(y);
    if (!seam) {
      return;
    }

    const stitchZone = Math.max(54, Math.abs(seam.rightX - seam.leftX) * 0.7);
    const allowedZone = force ? stitchZone * 1.4 : stitchZone;
    if (Math.abs(x - seam.centerX) > allowedZone) {
      return;
    }

    if (!force && Math.abs(y - lastStitchY) < 15) {
      return;
    }

    stitches.push({
      y,
      tilt: random(-0.3, 0.3),
      widthJitter: random(-4, 8),
      cross: Math.random() < 0.2,
      grain: makeThreadGrain(),
      fibers: makeStickyFibers()
    });

    stitches.sort((a, b) => a.y - b.y);
    lastStitchY = y;
  }

  function drawStitches() {
    for (const stitch of stitches) {
      const seam = getSeamAt(stitch.y);
      if (seam) {
        drawSingleStitch(stitch, seam);
      }
    }
  }

  function drawSingleStitch(stitch, seam) {
    const centerX = seam.centerX;
    const centerY = stitch.y;
    const stitchLength = Math.max(26, seam.rightX - seam.leftX + 30 + stitch.widthJitter);
    const dissolveAmount = getStitchDissolveAmount();

    if (dissolveAmount >= 1) {
      return;
    }

    const shadowColor = lerpRgba([56, 14, 18, 0.27], [28, 23, 20, 0.47], dissolveAmount);
    const threadColor = lerpRgba([112, 31, 38, 0.86], [50, 42, 36, 0.75], dissolveAmount);
    const highlightColor = lerpRgba([148, 74, 78, 0.22], [92, 78, 62, 0.16], dissolveAmount);

    drawDissolvingThreadSegment(centerX, centerY, stitchLength, stitch.tilt, dissolveAmount, 5, shadowColor);
    drawDissolvingThreadSegment(centerX, centerY, stitchLength, stitch.tilt, dissolveAmount, 3.4, threadColor);
    drawDissolvingThreadSegment(centerX, centerY - 1, stitchLength * 0.88, stitch.tilt, dissolveAmount, 0.8, highlightColor);
    drawStickyFibers(centerX, centerY, stitchLength, stitch.tilt, dissolveAmount, stitch.fibers);
    drawThreadGrain(centerX, centerY, stitchLength, stitch.tilt, stitch.grain, 1 - dissolveAmount, dissolveAmount);

    if (stitch.cross) {
      drawDissolvingThreadSegment(centerX, centerY, stitchLength * 0.86, -stitch.tilt - 0.5, dissolveAmount, 3.2, threadColor);
    }
  }

  function drawDissolvingThreadSegment(cx, cy, length, angle, dissolveAmount, weight, color) {
    const dx = Math.cos(angle);
    const dy = Math.sin(angle);
    const halfLength = length * 0.5;
    const gapHalf = halfLength * getGapOpenAmount(dissolveAmount);

    if (gapHalf >= halfLength) {
      return;
    }

    ctx.strokeStyle = rgba(color);
    ctx.lineWidth = weight;
    ctx.lineCap = "round";
    ctx.lineJoin = "round";
    ctx.beginPath();
    ctx.moveTo(cx - dx * halfLength, cy - dy * halfLength);
    ctx.lineTo(cx - dx * gapHalf, cy - dy * gapHalf);
    ctx.moveTo(cx + dx * gapHalf, cy + dy * gapHalf);
    ctx.lineTo(cx + dx * halfLength, cy + dy * halfLength);
    ctx.stroke();
  }

  function drawStickyFibers(cx, cy, length, angle, dissolveAmount, fibers) {
    if (!threadDissolving || dissolveAmount < 0.08 || dissolveAmount > 0.92) {
      return;
    }

    const gapAmount = getGapOpenAmount(dissolveAmount);
    const halfLength = length * 0.5;
    const gapHalf = halfLength * gapAmount;
    const dx = Math.cos(angle);
    const dy = Math.sin(angle);
    const nx = -dy;
    const ny = dx;
    const fade = Math.sin(clamp(map(dissolveAmount, 0.08, 0.92, 0, Math.PI), 0, Math.PI));

    for (const fiber of fibers) {
      const pull = dissolveAmount * fiber.pull;
      const startX = cx - dx * gapHalf + nx * fiber.offset;
      const startY = cy - dy * gapHalf + ny * fiber.offset;
      const endX = cx + dx * gapHalf + nx * (fiber.offset * 0.45 + pull);
      const endY = cy + dy * gapHalf + ny * (fiber.offset * 0.45 - pull * 0.35);

      ctx.strokeStyle = rgba([93, 35, 38, (fiber.alpha / 255) * fade * (1 - dissolveAmount * 0.35)]);
      ctx.lineWidth = fiber.weight * (1 - dissolveAmount * 0.25);
      ctx.lineCap = "round";
      ctx.beginPath();
      ctx.moveTo(startX, startY);
      ctx.bezierCurveTo(
        cx - dx * gapHalf * 0.2 + nx * (fiber.offset + fiber.bow * dissolveAmount),
        cy - dy * gapHalf * 0.2 + ny * (fiber.offset + fiber.bow * dissolveAmount),
        cx + dx * gapHalf * 0.2 + nx * (fiber.offset * 0.35 - fiber.bow * dissolveAmount),
        cy + dy * gapHalf * 0.2 + ny * (fiber.offset * 0.35 - fiber.bow * dissolveAmount),
        endX,
        endY
      );
      ctx.stroke();
    }
  }

  function drawThreadGrain(cx, cy, length, angle, grains, alphaScale, dissolveAmount) {
    const dx = Math.cos(angle);
    const dy = Math.sin(angle);
    const gapHalf = 0.5 * getGapOpenAmount(dissolveAmount);

    for (const grain of grains) {
      if (threadDissolving && Math.abs(grain.t) < gapHalf) {
        continue;
      }

      const t = grain.t * length;
      const side = grain.side;
      const x = cx + dx * t - dy * side;
      const y = cy + dy * t + dx * side;

      ctx.fillStyle = rgba([58, 16, 20, (grain.alpha / 255) * alphaScale]);
      ctx.beginPath();
      ctx.arc(x, y, grain.size * 0.5, 0, Math.PI * 2);
      ctx.fill();
    }
  }

  function tightenPieces() {
    if (stitches.length === 0 || pieces.length < 2) {
      return;
    }

    const strength = getTightness();
    const targetGap = lerp(lockGap, TARGET_GAP, strength);
    const currentGap = getPieceGap();
    const pull = (currentGap - targetGap) * 0.035;

    if (Math.abs(pull) < 0.01) {
      return;
    }

    pieces[0].x += pull;
    pieces[1].x -= pull;
  }

  function checkAutoDissolve() {
    if (autoDissolveStarted || threadDissolving || stitches.length === 0) {
      return;
    }

    const fullyTight = getTightness() >= 1 && Math.abs(getPieceGap() - TARGET_GAP) < 1.5;
    if (!fullyTight) {
      fullyTightSince = null;
      return;
    }

    if (fullyTightSince === null) {
      fullyTightSince = performance.now();
    }

    if (performance.now() - fullyTightSince >= AUTO_DISSOLVE_DELAY) {
      startThreadDissolve();
    }
  }

  function startThreadDissolve() {
    autoDissolveStarted = true;
    stitching = false;
    threadDissolving = true;
    threadDissolveProgress = 0;
    threadDust = [];
    dissolveStartPositions = getCurrentPiecePositions();
  }

  function updateThreadDissolve() {
    if (!threadDissolving) {
      return;
    }

    threadDissolveProgress += 0.008;
    restorePiecesDuringDissolve();

    for (const stitch of stitches) {
      const dissolveAmount = getStitchDissolveAmount();
      if (dissolveAmount > 0.08 && dissolveAmount < 0.95 && Math.random() < 0.72) {
        const seam = getSeamAt(stitch.y);
        if (seam) {
          addThreadDust(stitch, seam, dissolveAmount);
          if (Math.random() < 0.32) {
            addThreadDust(stitch, seam, dissolveAmount);
          }
        }
      }
    }

    if (getThreadDissolveCompletion() >= 1) {
      restorePiecesDuringDissolve();
      threadDissolving = false;
      stitches = [];
      stitching = false;
      lastStitchY = -9999;
      fullyTightSince = null;
      autoDissolveStarted = false;
    }
  }

  function addThreadDust(stitch, seam, dissolveAmount) {
    const stitchLength = Math.max(26, seam.rightX - seam.leftX + 30 + stitch.widthJitter);
    const dx = Math.cos(stitch.tilt);
    const dy = Math.sin(stitch.tilt);
    const halfLength = stitchLength * 0.5;
    const front = halfLength * dissolveAmount;
    const direction = Math.random() < 0.5 ? -1 : 1;
    const along = direction * front + random(-3, 3);
    const side = random(-2.2, 2.2);

    threadDust.push({
      x: seam.centerX + dx * along - dy * side,
      y: stitch.y + dy * along + dx * side,
      vx: random(0.75, 2.25) + dx * random(-0.16, 0.16),
      vy: random(-1.75, -0.45) + dy * random(-0.12, 0.12),
      size: random(0.45, 2.1),
      life: random(70, 132),
      maxLife: 132,
      tone: Math.random(),
      swirl: random(1000),
      trail: Math.random() < 0.42
    });
  }

  function drawThreadDust() {
    for (let i = threadDust.length - 1; i >= 0; i -= 1) {
      const dust = threadDust[i];
      const alpha = map(dust.life, 0, dust.maxLife, 0, 0.49);
      const drift = pseudoNoise(dust.swirl, performance.now() * 0.0015) - 0.5;
      const nextX = dust.x + dust.vx + drift * 0.42;
      const nextY = dust.y + dust.vy - Math.abs(drift) * 0.12;

      if (dust.trail) {
        ctx.strokeStyle = rgba([88, 57, 50, alpha * 0.22]);
        ctx.lineWidth = Math.max(0.5, dust.size * 0.45);
        ctx.beginPath();
        ctx.moveTo(dust.x, dust.y);
        ctx.lineTo(dust.x - dust.vx * 2.4, dust.y - dust.vy * 2.4);
        ctx.stroke();
      }

      if (dust.tone < 0.35) {
        ctx.fillStyle = rgba([92, 31, 35, alpha]);
      } else if (dust.tone < 0.72) {
        ctx.fillStyle = rgba([73, 50, 43, alpha * 0.86]);
      } else {
        ctx.fillStyle = rgba([34, 30, 28, alpha * 0.68]);
      }

      ctx.beginPath();
      ctx.ellipse(dust.x, dust.y, dust.size * 0.68, dust.size * 0.45, 0, 0, Math.PI * 2);
      ctx.fill();

      dust.x = nextX;
      dust.y = nextY;
      dust.vx *= 0.992;
      dust.vy *= 0.988;
      dust.vy -= 0.004;
      dust.life -= 1;

      if (dust.x < -24 || dust.y < -24 || dust.x > WIDTH + 24 || dust.y > HEIGHT + 24 || dust.life <= 0) {
        threadDust.splice(i, 1);
      }
    }
  }

  function restorePiecesDuringDissolve() {
    const amount = getThreadDissolveCompletion();

    for (const piece of pieces) {
      const start = dissolveStartPositions.find((item) => item.name === piece.name);
      const target = lockedPositions.find((item) => item.name === piece.name);

      if (start && target) {
        piece.x = lerp(start.x, target.x, amount);
        piece.y = lerp(start.y, target.y, amount);
      }
    }
  }

  function getStitchDissolveAmount() {
    if (!threadDissolving) {
      return 0;
    }

    return clamp(threadDissolveProgress / 1.08, 0, 1);
  }

  function getThreadDissolveCompletion() {
    return getStitchDissolveAmount();
  }

  function getTightness() {
    return clamp(stitches.length / MAX_STITCHES, 0, 1);
  }

  function getGapOpenAmount(dissolveAmount) {
    return smoothStep(0.14, 1, dissolveAmount);
  }

  function getPieceGap() {
    return pieces[1].x - (pieces[0].x + pieces[0].w);
  }

  function getCurrentPiecePositions() {
    return pieces.map((piece) => ({
      name: piece.name,
      x: piece.x,
      y: piece.y
    }));
  }

  function getSeamAt(y) {
    if (pieces.length < 2) {
      return null;
    }

    const leftX = getVisibleEdgeX(pieces[0], y, true);
    const rightX = getVisibleEdgeX(pieces[1], y, false);

    if (leftX === null || rightX === null) {
      return null;
    }

    return {
      leftX,
      rightX,
      centerX: (leftX + rightX) * 0.5
    };
  }

  function getVisibleEdgeX(piece, screenY, fromRight) {
    if (screenY < piece.y || screenY > piece.y + piece.h) {
      return null;
    }

    const imgY = Math.floor(map(screenY, piece.y, piece.y + piece.h, 0, piece.img.naturalHeight));
    const step = Math.max(1, Math.floor(piece.img.naturalWidth / 180));
    const start = fromRight ? piece.img.naturalWidth - 1 : 0;
    const end = fromRight ? -1 : piece.img.naturalWidth;
    const direction = fromRight ? -step : step;

    for (let imgX = start; fromRight ? imgX > end : imgX < end; imgX += direction) {
      if (getAlpha(piece.img, imgX, imgY) > 10) {
        return piece.x + (imgX / piece.img.naturalWidth) * piece.w;
      }
    }

    return null;
  }

  function getAlpha(image, x, y) {
    const px = clamp(Math.floor(x), 0, image.naturalWidth - 1);
    const py = clamp(Math.floor(y), 0, image.naturalHeight - 1);
    return image.alphaData[(py * image.naturalWidth + px) * 4 + 3];
  }

  function makeThreadGrain() {
    const grain = [];

    for (let i = 0; i < 10; i += 1) {
      grain.push({
        t: random(-0.45, 0.45),
        side: random(-1.5, 1.5),
        alpha: random(18, 42),
        size: random(0.8, 1.8)
      });
    }

    return grain;
  }

  function makeStickyFibers() {
    const fibers = [];

    for (let i = 0; i < 5; i += 1) {
      fibers.push({
        offset: random(-3.2, 3.2),
        bow: random(-8, 8),
        pull: random(2, 9),
        alpha: random(42, 86),
        weight: random(0.45, 1.15)
      });
    }

    return fibers;
  }

  function resetSketch() {
    stitches = [];
    threadDust = [];
    stitching = false;
    lastStitchY = -9999;
    threadDissolving = false;
    threadDissolveProgress = 0;
    fullyTightSince = null;
    autoDissolveStarted = false;
    setupPieces();
  }

  function random(min, max) {
    if (typeof max === "undefined") {
      return Math.random() * min;
    }

    return min + Math.random() * (max - min);
  }

  function map(value, start1, stop1, start2, stop2) {
    return start2 + ((value - start1) / (stop1 - start1)) * (stop2 - start2);
  }

  function clamp(value, min, max) {
    return Math.max(min, Math.min(max, value));
  }

  function lerp(start, end, amount) {
    return start + (end - start) * amount;
  }

  function lerpRgba(a, b, amount) {
    return [
      lerp(a[0], b[0], amount),
      lerp(a[1], b[1], amount),
      lerp(a[2], b[2], amount),
      lerp(a[3], b[3], amount)
    ];
  }

  function rgba(color) {
    return `rgba(${Math.round(color[0])}, ${Math.round(color[1])}, ${Math.round(color[2])}, ${color[3]})`;
  }

  function smoothStep(edge0, edge1, value) {
    const t = clamp((value - edge0) / (edge1 - edge0), 0, 1);
    return t * t * (3 - 2 * t);
  }

  function pseudoNoise(seed, time) {
    const value = Math.sin(seed * 12.9898 + time * 78.233) * 43758.5453;
    return value - Math.floor(value);
  }

  init();
})();
