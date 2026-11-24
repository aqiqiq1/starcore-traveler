/* DS02 preview: +x one-way cloud motion, true 1278px sea period, no reset. */
(() => {
  "use strict";
  const cfg = window.DS02_CONFIG;
  const W = cfg.canvas[0], H = cfg.canvas[1], S = cfg.render_scale || 2;
  const P = cfg.sea_period;
  const DW = W * S, DH = H * S;
  const canvas = document.getElementById("frame");
  const ctx = canvas.getContext("2d", { alpha: false });
  canvas.width = DW; canvas.height = DH;
  ctx.imageSmoothingEnabled = false;

  const mainC = document.createElement("canvas");
  const nearC = document.createElement("canvas");
  for (const c of [mainC, nearC]) { c.width = DW; c.height = DH; }
  const mctx = mainC.getContext("2d");
  const nctx = nearC.getContext("2d");
  for (const c of [mctx, nctx]) c.imageSmoothingEnabled = false;

  const srcs = new Set();
  srcs.add("layers/base_static.png");
  srcs.add(cfg.arch_overlay);
  srcs.add(cfg.island_overlay);
  for (const s of cfg.sky) srcs.add(s.file);
  for (const s of cfg.sea) srcs.add(s.file);
  for (const d of cfg.debris) srcs.add(d.file);
  for (const s of cfg.shadows) srcs.add(s.file);
  const imgs = new Map();
  let loaded = 0, failed = [];
  for (const src of srcs) {
    const im = new Image();
    im.onload = () => {
      loaded++;
      if (loaded === srcs.size) draw();
    };
    im.onerror = () => { failed.push(src); draw(); };
    im.src = src;
    imgs.set(src, im);
  }

  const q = v => Math.round(v * S) / S;      // half logical px at 2x = 1 device px
  const d = v => Math.round(v * S);          // device px, never filtered
  const seaMain = cfg.sea.find(s => s.name === "sea_main");
  const seaNear = cfg.sea.find(s => s.name === "sea_near");
  const rockByName = new Map(cfg.debris.map(r => [r.name, r]));
  const shadowMain = cfg.shadows.filter(s => s.surface === "sea_main");
  const shadowNear = cfg.shadows.filter(s => s.surface === "sea_near");
  const rightBank = cfg.sky.find(s => s.name === "sky_bank_right");
  const seamProbeX = cfg.seam_probe_x || 430;

  let t = 0;
  let playing = true;
  let showSeams = false;
  let tBase = 0;
  let tAnchor = performance.now();
  let lastRaf = performance.now();
  let uiHidden = false;

  const $ = id => document.getElementById(id);
  const playBtn = $("play"), timeEl = $("time"), scratch = $("scrub"), readout = $("readout");
  const hud = $("hud");
  const periodEl = $("period");
  if (periodEl) periodEl.textContent = P.toString();

  const params = new URLSearchParams(location.search);
  if (params.has("t")) t = Math.max(0, parseFloat(params.get("t")) || 0);
  if (params.get("pause") === "1") playing = false;
  if (params.get("seams") === "1") showSeams = true;
  if (showSeams) $("seamMark").classList.add("on");
  tBase = t;
  tAnchor = performance.now();
  if (params.get("ui") === "0") { uiHidden = true; hud.classList.add("hidden"); }
  scratch.max = Math.max(120, Math.ceil(t + 30)).toString();
  scratch.value = t.toString();

  function skyX(spec) {
    const cycle = W + spec.size[0] + spec.wrap_gap;
    let x = spec.x0 + ((spec.speed * t) % cycle);
    if (x > W + 8) x -= cycle;
    return q(x);
  }

  function rockBob(r) {
    return r.amp_y * Math.sin(2 * Math.PI * t / r.period + r.phase);
  }

  function drawSea(c, spec, shadows, phase) {
    c.clearRect(0, 0, DW, DH);
    const tex = imgs.get(spec.file);
    // +phase draws the texture to the right. The left periodic copy (phase-P)
    // fills the gap behind x=phase, so the flow is continuous and one-way.
    const x0 = q(phase);
    for (let k = -1; k <= 0; k++) {
      const x = x0 + k * P;
      if (x < W && x + P > 0) {
        c.drawImage(tex, d(x), 0, d(P), d(H));
      }
    }
    // projected shadows: source-atop means the cloud alpha is the only surface
    c.globalCompositeOperation = "source-atop";
    for (const sh of shadows) {
      const r = rockByName.get(sh.rock);
      const bob = rockBob(r);
      const amp = Math.max(0.1, r.amp_y);
      const high = bob < -0.5 * r.amp_y;
      const grow = high && sh.name !== "shadow_low" ? 1 : 0;
      let sx, sy, sc;
      if (sh.name === "shadow_low") {
        sx = r.x0 + sh.dx - 0.20 * bob;
        sc = Math.max(0.88, Math.min(1, 1 + 0.12 * (bob / amp)));
      } else {
        sx = r.x0 + sh.dx - 0.40 * bob;
        sc = Math.max(0.70, Math.min(1, 1 + 0.30 * (bob / amp)));
      }
      const idx = Math.max(0, Math.min(W - 1, Math.floor(sx + sh.size[0] / 2)));
      // world_x - phase: sample the same cloud surface that is visible here.
      const surf = spec.top[((idx - Math.round(phase)) % P + P) % P];
      if (sh.name === "shadow_low") sy = surf + sh.dy - 0.30 * bob;
      else sy = surf + sh.dy - 0.50 * bob;
      c.globalAlpha = sc;
      c.drawImage(imgs.get(sh.file), d(sx), d(sy), d(sh.size[0] + grow * 2), d(sh.size[1] + grow));
      c.globalAlpha = 1;
    }
    c.globalCompositeOperation = "source-over";
  }

  function draw() {
    if (failed.length) {
      readout.textContent = "资源加载失败: " + failed[0];
      return;
    }
    if (loaded < srcs.size) return;

    const phaseMain = q((seaMain.speed * t) % P) % P;
    const phaseNear = q((seaNear.speed * t) % P) % P;

    ctx.globalAlpha = 1;
    ctx.globalCompositeOperation = "source-over";
    ctx.drawImage(imgs.get("layers/base_static.png"), 0, 0, DW, DH);

    for (const s of cfg.sky) {
      const x = skyX(s);
      if (x < W && x + s.size[0] > 0) {
        ctx.drawImage(imgs.get(s.file), d(x), d(s.y0), d(s.size[0]), d(s.size[1]));
      }
    }

    drawSea(mctx, seaMain, shadowMain, phaseMain);
    ctx.drawImage(mainC, 0, 0);
    ctx.drawImage(imgs.get(cfg.arch_overlay), 0, 0, DW, DH);
    ctx.drawImage(imgs.get(cfg.island_overlay), 0, 0, DW, DH);

    drawSea(nctx, seaNear, shadowNear, phaseNear);
    ctx.drawImage(nearC, 0, 0);

    for (const r of cfg.debris) {
      const y = q(r.y0 + rockBob(r));
      ctx.drawImage(imgs.get(r.file), d(r.x0), d(y), d(r.size[0]), d(r.size[1]));
    }

    if (showSeams) {
      // phase is the screen x of texture column 0; the left copy starts at
      // phase-P (offscreen), so the visible period seam is x=phase.
      const seamMain = phaseMain;
      const seamNear = phaseNear;
      ctx.save();
      ctx.lineWidth = 2;
      ctx.strokeStyle = "rgba(255,90,90,.92)";
      if (seamMain <= W) {
        const x = d(seamMain) + 0.5;
        ctx.beginPath(); ctx.moveTo(x, d(250)); ctx.lineTo(x, d(296)); ctx.stroke();
      }
      ctx.strokeStyle = "rgba(255,214,90,.92)";
      if (seamNear <= W) {
        const x = d(seamNear) + 0.5;
        ctx.beginPath(); ctx.moveTo(x, d(278)); ctx.lineTo(x, DH); ctx.stroke();
      }
      ctx.restore();
    }

    const mainU = seaMain.speed * t, nearU = seaNear.speed * t;
    timeEl.textContent = `t = ${t.toFixed(2)} s`;
    readout.textContent =
      `main +${mainU.toFixed(1)}px  phase ${phaseMain.toFixed(1)}\n` +
      `near +${nearU.toFixed(1)}px  phase ${phaseNear.toFixed(1)}\n` +
      `seam main ${phaseMain.toFixed(1)}  near ${phaseNear.toFixed(1)}`;
    scratch.value = Math.min(parseFloat(scratch.max), t).toString();
  }

  function currentT() {
    return playing ? tBase + (performance.now() - tAnchor) / 1000 : t;
  }

  function frame(now) {
    lastRaf = now;
    t = currentT();
    draw();
    requestAnimationFrame(frame);
  }

  function setPlaying(v) {
    if (v && !playing) {
      tBase = t;
      tAnchor = performance.now();
    } else if (!v && playing) {
      t = currentT();
    }
    playing = v;
    playBtn.textContent = playing ? "暂停" : "继续";
  }

  function setTime(v, pause = true) {
    t = Math.max(0, v);
    tBase = t;
    tAnchor = performance.now();
    scratch.max = Math.max(120, Math.ceil(t + 30)).toString();
    if (pause) setPlaying(false);
    draw();
  }

  playBtn.onclick = () => setPlaying(!playing);
  $("reset").onclick = () => { setTime(0, true); setPlaying(true); };
  scratch.oninput = () => setTime(parseFloat(scratch.value), true);
  $("seamBefore").onclick = () => {
    showSeams = true;
    $("seamMark").classList.add("on");
    // both shelves show a seam in this frame: near x=430, main x=250.7
    setTime(seamProbeX / seaNear.speed - 0.8, true);
  };
  $("seamAfter").onclick = () => {
    showSeams = true;
    $("seamMark").classList.add("on");
    setTime(seamProbeX / seaNear.speed + 0.8, true);
  };
  $("seamMark").onclick = () => {
    showSeams = !showSeams;
    $("seamMark").classList.toggle("on", showSeams);
    draw();
  };
  $("skyWrap").onclick = () => {
    const cycle = W + rightBank.size[0] + rightBank.wrap_gap;
    const resetT = (W + 8 - rightBank.x0) / rightBank.speed;
    setTime(resetT + 0.2, true);
    showSeams = false;
    $("seamMark").classList.remove("on");
    draw();
  };
  $("hideUI").onclick = () => {
    uiHidden = true;
    hud.classList.add("hidden");
  };
  addEventListener("keydown", (e) => {
    if (e.key.toLowerCase() === "h") {
      uiHidden = !uiHidden;
      hud.classList.toggle("hidden", uiHidden);
    }
    if (e.key === " ") {
      e.preventDefault();
      setPlaying(!playing);
    }
  });

  window.DS02 = {
    get t() { return t; },
    setTime,
    pause: () => setPlaying(false),
    resume: () => setPlaying(true),
    reset: () => { setTime(0, true); setPlaying(true); },
    state() {
      t = currentT();
      const phaseMain = q((seaMain.speed * t) % P) % P;
      const phaseNear = q((seaNear.speed * t) % P) % P;
      return {
        t, playing,
        mainUnwrapped: seaMain.speed * t, nearUnwrapped: seaNear.speed * t,
        mainPhase: phaseMain, nearPhase: phaseNear,
        mainSeamX: phaseMain <= W ? phaseMain : null,
        nearSeamX: phaseNear <= W ? phaseNear : null,
        sky: cfg.sky.map(s => ({ name: s.name, renderedX: skyX(s), unwrapped: s.x0 + s.speed * t })),
        rocks: cfg.debris.map(r => ({ name: r.name, y: r.y0 + rockBob(r), bob: rockBob(r) })),
      };
    },
  };
  setPlaying(playing);
  draw();
  requestAnimationFrame(frame);
  // rAF is the primary clock. Some embedded/background views throttle it;
  // this fallback only draws when rAF has been silent for 250 ms.
  setInterval(() => {
    if (playing && performance.now() - lastRaf > 250) {
      t = currentT();
      draw();
    }
  }, 100);
})();
