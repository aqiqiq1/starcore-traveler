/* DS03 runtime preview.
 *
 * Pure background: base_sky -> sky -> G3/G4/G5 -> G1/G2 -> sea_main+shadows
 * -> arch_stone -> sea_near+shadow_low -> rock_remnants_static -> debris.
 * G1 and G2 are both drawn before the same sea_main; there is deliberately no
 * right-foot overlay / re-cover branch.
 *
 * The same file is used by preview.html (external PNGs) and by the single-file
 * build (window.__DS03_ASSET_DATA__ lookup).  Nothing else in the drawing or
 * timing code is rewritten by the packager.
 */
(() => {
  "use strict";

  const cfg = window.DS03_CONFIG;
  if (!cfg) throw new Error("DS03_CONFIG missing");

  const W = cfg.canvas[0];
  const H = cfg.canvas[1];
  const S = cfg.render_scale || 2;
  const P = cfg.sea_period;
  const DW = W * S;
  const DH = H * S;
  const params = new URLSearchParams(location.search);

  const canvas = document.getElementById("frame");
  const ctx = canvas.getContext("2d", { alpha: false });
  canvas.width = DW;
  canvas.height = DH;
  ctx.imageSmoothingEnabled = false;

  const mainC = document.createElement("canvas");
  const nearC = document.createElement("canvas");
  for (const c of [mainC, nearC]) {
    c.width = DW;
    c.height = DH;
  }
  const mctx = mainC.getContext("2d");
  const nctx = nearC.getContext("2d");
  for (const c of [mctx, nctx]) c.imageSmoothingEnabled = false;

  // 0.5 logical px at 2x = one device pixel.  Positions never interpolate.
  const q = (v) => Math.round(v * S) / S;
  const d = (v) => Math.round(v * S);

  const errors = [];
  window.addEventListener("error", (event) => {
    errors.push(String(event.message || event.error || "error"));
  });
  window.addEventListener("unhandledrejection", (event) => {
    errors.push(String(event.reason || "unhandledrejection"));
  });

  const assetKeys = [];
  const addKey = (key) => {
    if (typeof key === "string" && key && !assetKeys.includes(key)) assetKeys.push(key);
  };
  addKey(cfg.base.file);
  for (const section of ["groups", "static", "sky", "sea", "shadows", "debris"]) {
    for (const item of cfg[section]) addKey(item.file);
  }

  const embedded = window.__DS03_ASSET_DATA__ || null;
  const imgs = new Map();
  const failed = [];
  let loaded = 0;
  let rockSprite = null;
  let renderCount = 0;

  let resolveReady;
  const ready = new Promise((resolve) => {
    resolveReady = resolve;
  });

  function afterLoad() {
    loaded++;
    if (loaded < assetKeys.length) return;
    buildStaticSprites();
    draw();
    resolveReady({ failed: failed.slice(), errors: errors.slice() });
  }

  for (const key of assetKeys) {
    const im = new Image();
    im.onload = afterLoad;
    im.onerror = () => {
      failed.push(key);
      afterLoad();
    };
    if (embedded && !embedded[key]) {
      failed.push(key + " (missing embedded data)");
      afterLoad();
    } else {
      im.src = embedded ? embedded[key] : key;
    }
    imgs.set(key, im);
  }

  function buildStaticSprites() {
    const rock = cfg.static.find((item) => item.id === "rock_remnants_static");
    if (!rock) return;
    const img = imgs.get(rock.file);
    if (!img || !img.complete || !img.naturalWidth) return;
    const c = document.createElement("canvas");
    c.width = d(rock.size[0]);
    c.height = d(rock.size[1]);
    const x = c.getContext("2d");
    x.imageSmoothingEnabled = false;
    x.drawImage(img, 0, 0, c.width, c.height);
    // Runtime-only filter: remove the isolated small old shadow/blade under
    // debris_low.  art_assets/rock_remnants_static.png is never modified.
    for (const rect of rock.exclude_mask_rects || []) {
      x.clearRect(
        d(rect[0]),
        d(rect[1]),
        d(rect[2] - rect[0]),
        d(rect[3] - rect[1])
      );
    }
    rockSprite = c;
  }

  // ---------- debug / review modes (not game UI) ----------
  const skip = new Set();
  const mode = params.get("mode") || "";
  const addSkip = (...names) => names.forEach((name) => skip.add(name));
  if (mode === "noclouds") addSkip("seaMain", "seaNear", "shadows");
  if (mode === "seaonly") addSkip("sky", "groups", "arch", "rock", "debris");
  if (mode === "skyonly") addSkip("groups", "seaMain", "seaNear", "shadows", "arch", "rock", "debris");
  if (mode === "groupsonly") addSkip("sky", "seaMain", "seaNear", "shadows", "arch", "rock", "debris");
  if (mode === "baseonly") addSkip("sky", "groups", "seaMain", "seaNear", "shadows", "arch", "rock", "debris");
  if (mode === "rockonly") addSkip("sky", "groups", "seaMain", "seaNear", "shadows", "arch", "debris");
  for (const token of (params.get("skip") || "").split(",")) {
    if (token) skip.add(token);
  }

  const debug = {
    skip,
    mode,
    seams: params.get("seams") === "1",
    forceFloat: params.get("force") || "",
    worst: params.get("worst") || "",
    hideUI: params.get("ui") === "0",
  };

  // ---------- clock ----------
  let t = 0;
  let playing = params.get("pause") !== "1";
  let tBase = 0;
  let tAnchor = performance.now();
  let lastRaf = performance.now();
  let uiHidden = debug.hideUI;

  if (params.has("t")) {
    const v = parseFloat(params.get("t"));
    t = Number.isFinite(v) ? Math.max(0, v) : 0;
  }
  tBase = t;
  tAnchor = performance.now();

  function currentT() {
    return playing ? tBase + (performance.now() - tAnchor) / 1000 : t;
  }

  // ---------- motion ----------
  function skyX(spec) {
    const cycle = W + spec.size[0] + spec.wrap_gap;
    let x = spec.x0 + ((spec.speed * t) % cycle);
    if (x > W + 8) x -= cycle; // reset wholly off-screen, never a visible rewind
    return q(x);
  }

  function rockBob(r) {
    return r.amp_y * Math.sin((2 * Math.PI * t) / r.period + r.phase);
  }

  function floatDy(g) {
    // Static groups are a real runtime early-out, not a zero amplitude trick:
    // debug force/worst modes are checked only after this, so they cannot move
    // a disabled group either.
    if (g.float && g.float.enabled === false) return 0;
    if (debug.worst === "island") {
      if (g.id === "G5") return g.float.amp;
    }
    if (debug.forceFloat === "up") return -g.float.amp;
    if (debug.forceFloat === "down") return g.float.amp;
    return g.float.amp * Math.sin((2 * Math.PI * (t + g.float.phase)) / g.float.period);
  }

  function groupPlacement(g) {
    if (g.float && g.float.enabled === false) {
      // Bypass quantization too: worldY is exactly the art offset.
      return { dyFormula: 0, y: g.offset[1], dyRendered: 0 };
    }
    const dyFormula = floatDy(g);
    const y = q(g.offset[1] + dyFormula);
    return { dyFormula, y, dyRendered: y - g.offset[1] };
  }

  // ---------- drawing ----------
  function drawBase(target) {
    if (skip.has("base")) return;
    target.drawImage(imgs.get(cfg.base.file), 0, 0, DW, DH);
  }

  function drawSky(target) {
    if (skip.has("sky")) return;
    for (const spec of cfg.sky) {
      const img = imgs.get(spec.file);
      if (!img || !img.complete) continue;
      const x = skyX(spec);
      if (x < W && x + spec.size[0] > 0) {
        target.drawImage(img, d(x), d(spec.y0), d(spec.size[0]), d(spec.size[1]));
      }
    }
  }

  function drawGroups(target) {
    if (skip.has("groups")) return;
    const ordered = cfg.groups.slice().sort((a, b) => a.depth - b.depth || a.order - b.order);
    for (const g of ordered) {
      const img = imgs.get(g.file);
      if (!img || !img.complete) continue;
      const place = groupPlacement(g);
      target.drawImage(
        img,
        d(g.offset[0]),
        d(place.y),
        d(g.size[0]),
        d(g.size[1])
      );
    }
  }

  function drawSea(target, spec, shadows, phase) {
    target.clearRect(0, 0, DW, DH);
    const tex = imgs.get(spec.file);
    const x0 = q(phase);
    // +phase draws the texture to the right.  The left periodic copy
    // (phase-P) fills the gap behind x=phase, so motion stays one-way.
    for (let k = -1; k <= 0; k++) {
      const x = x0 + k * P;
      if (x < W && x + P > 0) target.drawImage(tex, d(x), 0, d(P), d(H));
    }
    if (!skip.has("shadows")) {
      target.globalCompositeOperation = "source-atop";
      for (const sh of shadows) {
        const p = shadowPlacement(sh, spec, phase);
        if (!p) continue;
        target.globalAlpha = p.alpha;
        target.drawImage(
          imgs.get(sh.file),
          d(p.sx),
          d(p.sy),
          d(p.width),
          d(p.height)
        );
        target.globalAlpha = 1;
      }
      target.globalCompositeOperation = "source-over";
    }
  }

  function shadowPlacement(sh, spec, phase) {
    const r = rockByName.get(sh.rock);
    if (!r) return null;
    const bob = rockBob(r);
    const amp = Math.max(0.1, r.amp_y);
    const high = bob < -0.5 * r.amp_y;
    const grow = high && sh.name !== "shadow_low" ? 1 : 0;
    let sx, sy, sc;
    if (sh.name === "shadow_low") {
      sx = r.x0 + sh.dx - 0.2 * bob;
      sc = Math.max(0.88, Math.min(1, 1 + 0.12 * (bob / amp)));
    } else {
      sx = r.x0 + sh.dx - 0.4 * bob;
      sc = Math.max(0.7, Math.min(1, 1 + 0.3 * (bob / amp)));
    }
    const idx = Math.max(0, Math.min(W - 1, Math.floor(sx + sh.size[0] / 2)));
    // world_x - phase samples the same cloud surface visible at idx.
    const surf = spec.top[((idx - Math.round(phase)) % P + P) % P];
    if (sh.name === "shadow_low") sy = surf + sh.dy - 0.3 * bob;
    else sy = surf + sh.dy - 0.5 * bob;
    return {
      name: sh.name,
      surface: sh.surface,
      sx,
      sy,
      alpha: sc,
      width: sh.size[0] + grow * 2,
      height: sh.size[1] + grow,
      cloudTopAtPlacement: surf,
      bob,
      high,
      grow,
    };
  }

  function drawStatic(target) {
    if (!skip.has("arch")) {
      const arch = cfg.static.find((item) => item.id === "arch_stone");
      const img = imgs.get(arch.file);
      if (img && img.complete) {
        target.drawImage(
          img,
          d(arch.offset[0]),
          d(arch.offset[1]),
          d(arch.size[0]),
          d(arch.size[1])
        );
      }
    }
    if (!skip.has("rock")) {
      const rock = cfg.static.find((item) => item.id === "rock_remnants_static");
      const sprite = rockSprite;
      if (sprite) {
        target.drawImage(sprite, d(rock.offset[0]), d(rock.offset[1]));
      }
    }
  }

  function drawDebris(target) {
    if (skip.has("debris")) return;
    for (const r of cfg.debris) {
      const img = imgs.get(r.file);
      if (!img || !img.complete) continue;
      const y = q(r.y0 + rockBob(r));
      target.drawImage(img, d(r.x0), d(y), d(r.size[0]), d(r.size[1]));
    }
  }

  const seaMain = cfg.sea.find((s) => s.name === "sea_main");
  const seaNear = cfg.sea.find((s) => s.name === "sea_near");
  const shadowMain = cfg.shadows.filter((s) => s.surface === "sea_main");
  const shadowNear = cfg.shadows.filter((s) => s.surface === "sea_near");
  const rockByName = new Map(cfg.debris.map((r) => [r.name, r]));

  function seaPhase(spec) {
    return q((spec.speed * t) % P) % P;
  }

  function drawSeams(target, phaseMain, phaseNear) {
    if (!debug.seams) return;
    target.save();
    target.lineWidth = 2;
    target.strokeStyle = "rgba(255,90,90,.92)";
    if (phaseMain <= W) {
      const x = d(phaseMain) + 0.5;
      target.beginPath();
      target.moveTo(x, d(250));
      target.lineTo(x, d(296));
      target.stroke();
    }
    target.strokeStyle = "rgba(255,214,90,.92)";
    if (phaseNear <= W) {
      const x = d(phaseNear) + 0.5;
      target.beginPath();
      target.moveTo(x, d(278));
      target.lineTo(x, d(H));
      target.stroke();
    }
    target.restore();
  }

  function draw() {
    if (failed.length) {
      if (readout) readout.textContent = "资源加载失败: " + failed[0];
      return;
    }
    if (loaded < assetKeys.length) return;

    const phaseMain = seaPhase(seaMain);
    const phaseNear = seaPhase(seaNear);
    renderCount++;

    ctx.globalAlpha = 1;
    ctx.globalCompositeOperation = "source-over";
    drawBase(ctx);
    drawSky(ctx);
    drawGroups(ctx);

    if (!skip.has("seaMain")) {
      drawSea(mctx, seaMain, shadowMain, phaseMain);
      ctx.drawImage(mainC, 0, 0);
    }
    if (!skip.has("arch") || !skip.has("rock")) drawStatic(ctx);
    if (!skip.has("seaNear")) {
      drawSea(nctx, seaNear, shadowNear, phaseNear);
      ctx.drawImage(nearC, 0, 0);
    }
    drawDebris(ctx);
    drawSeams(ctx, phaseMain, phaseNear);

    if (timeEl) timeEl.textContent = `t = ${t.toFixed(2)} s`;
    if (readout) {
      const mainU = seaMain.speed * t;
      const nearU = seaNear.speed * t;
      const gs = cfg.groups
        .slice()
        .sort((a, b) => a.id.localeCompare(b.id))
        .map((g) => `${g.id} ${groupPlacement(g).dyRendered >= 0 ? "+" : ""}${groupPlacement(g).dyRendered.toFixed(1)}${g.float.enabled === false ? "·static" : ""}`);
      const flags = [];
      if (skip.size) flags.push("skip=" + Array.from(skip).join("+"));
      if (debug.worst) flags.push("worst=" + debug.worst);
      if (debug.forceFloat) flags.push("force=" + debug.forceFloat);
      readout.textContent =
        `main +${mainU.toFixed(1)}px  phase ${phaseMain.toFixed(1)}\n` +
        `near +${nearU.toFixed(1)}px  phase ${phaseNear.toFixed(1)}\n` +
        `${gs.join("  ")}${flags.length ? "\n" + flags.join("  ") : ""}`;
    }
    if (scrub) {
      const max = Math.max(parseFloat(scrub.max) || 0, Math.ceil(t + 30), 360);
      scrub.max = String(max);
      scrub.value = String(Math.min(max, t));
    }
  }

  // ---------- time / UI ----------
  const $ = (id) => document.getElementById(id);
  const playBtn = $("play");
  const timeEl = $("time");
  const scratch = $("scrub");
  const readout = $("readout");
  const hud = $("hud");

  if (debug.seams && $("seamMark")) $("seamMark").classList.add("on");
  if (uiHidden && hud) hud.classList.add("hidden");
  if (scratch) {
    scratch.value = String(t);
    scratch.max = String(Math.max(360, Math.ceil(t + 30)));
  }

  function setPlaying(v) {
    if (v && !playing) {
      tBase = t;
      tAnchor = performance.now();
    } else if (!v && playing) {
      t = currentT();
    }
    playing = v;
    if (playBtn) playBtn.textContent = playing ? "暂停" : "继续";
  }

  function setTime(v, pause = true) {
    t = Math.max(0, v);
    tBase = t;
    tAnchor = performance.now();
    if (scratch) {
      const max = Math.max(360, Math.ceil(t + 30));
      scratch.max = String(max);
      scratch.value = String(Math.min(max, t));
    }
    if (pause) setPlaying(false);
    draw();
  }

  function reset() {
    setTime(0, true);
    setPlaying(true);
  }

  if (playBtn) playBtn.onclick = () => setPlaying(!playing);
  if ($("reset")) $("reset").onclick = reset;
  if (scratch) scratch.oninput = () => setTime(parseFloat(scratch.value), true);

  if ($("seamBefore")) {
    $("seamBefore").onclick = () => {
      debug.seams = true;
      $("seamMark").classList.add("on");
      setTime(cfg.inspection.seam_t - 0.8, true);
    };
  }
  if ($("seamAfter")) {
    $("seamAfter").onclick = () => {
      debug.seams = true;
      $("seamMark").classList.add("on");
      setTime(cfg.inspection.seam_t + 0.8, true);
    };
  }
  if ($("seamMark")) {
    $("seamMark").onclick = () => {
      debug.seams = !debug.seams;
      $("seamMark").classList.toggle("on", debug.seams);
      draw();
    };
  }
  if ($("skyWrap")) {
    $("skyWrap").onclick = () => {
      debug.seams = false;
      $("seamMark").classList.remove("on");
      setTime(cfg.inspection.sky_wrap_t + 0.2, true);
    };
  }
  if ($("bridgeUp")) $("bridgeUp").onclick = () => setTime(cfg.inspection.bridge_static_t1, true);
  if ($("bridgeDown")) $("bridgeDown").onclick = () => setTime(cfg.inspection.bridge_static_t2, true);
  if ($("bridgeJoint")) $("bridgeJoint").onclick = () => setTime(cfg.inspection.bridge_joint_t, true);
  if ($("islandGap")) $("islandGap").onclick = () => setTime(cfg.inspection.island_min_t, true);
  if ($("g3g1Gap")) $("g3g1Gap").onclick = () => setTime(cfg.inspection.g3_g1_min_t, true);
  if ($("cloudToggle")) {
    $("cloudToggle").onclick = () => {
      const hidden = skip.has("seaMain");
      if (hidden) {
        skip.delete("seaMain");
        skip.delete("seaNear");
      } else {
        skip.add("seaMain");
        skip.add("seaNear");
      }
      $("cloudToggle").classList.toggle("on", !hidden);
      $("cloudToggle").textContent = hidden ? "关云检查" : "开云检查";
      draw();
    };
  }
  if ($("hideUI")) {
    $("hideUI").onclick = () => {
      uiHidden = true;
      hud.classList.add("hidden");
    };
  }
  addEventListener("keydown", (event) => {
    if (event.key.toLowerCase() === "h") {
      uiHidden = !uiHidden;
      hud.classList.toggle("hidden", uiHidden);
    }
    if (event.key === " ") {
      event.preventDefault();
      setPlaying(!playing);
    }
  });

  // ---------- public inspection API ----------
  window.DS03 = {
    ready,
    canvas,
    config: cfg,
    assetKeys,
    get t() {
      return t;
    },
    get playing() {
      return playing;
    },
    setTime,
    pause: () => setPlaying(false),
    resume: () => setPlaying(true),
    reset,
    draw,
    setDebug(patch) {
      if (patch && typeof patch === "object") {
        if (Array.isArray(patch.skip)) {
          skip.clear();
          patch.skip.forEach((name) => skip.add(name));
        }
        if (typeof patch.seams === "boolean") debug.seams = patch.seams;
        if (typeof patch.forceFloat === "string") debug.forceFloat = patch.forceFloat;
        if (typeof patch.worst === "string") debug.worst = patch.worst;
      }
      draw();
    },
    state() {
      t = currentT();
      const phaseMain = seaPhase(seaMain);
      const phaseNear = seaPhase(seaNear);
      return {
        t,
        playing,
        phaseMain,
        phaseNear,
        mainUnwrapped: seaMain.speed * t,
        nearUnwrapped: seaNear.speed * t,
        mainSeamX: phaseMain <= W ? phaseMain : null,
        nearSeamX: phaseNear <= W ? phaseNear : null,
        sky: cfg.sky.map((s) => ({ name: s.name, renderedX: skyX(s), unwrapped: s.x0 + s.speed * t })),
        groups: cfg.groups.map((g) => {
          const p = groupPlacement(g);
          return {
            id: g.id,
            dyFormula: p.dyFormula,
            dyRendered: p.dyRendered,
            worldY: g.offset[1] + p.dyRendered,
            bottomY: g.offset[1] + g.size[1] + p.dyRendered,
            amp: g.float.amp,
            period: g.float.period,
            phase: g.float.phase,
            enabled: g.float.enabled !== false,
            static: g.float.enabled === false,
          };
        }),
        debris: cfg.debris.map((r) => ({ name: r.name, y: r.y0 + rockBob(r), bob: rockBob(r) })),
        shadows: cfg.shadows.map((sh) => {
          const spec = sh.surface === "sea_near" ? seaNear : seaMain;
          const phase = sh.surface === "sea_near" ? phaseNear : phaseMain;
          return shadowPlacement(sh, spec, phase);
        }),
        skip: Array.from(skip),
        mode,
        worst: debug.worst,
        forceFloat: debug.forceFloat,
        renderCount,
        failed: failed.slice(),
      };
    },
    capture() {
      return canvas.toDataURL("image/png");
    },
  };

  // ---------- optional browser self-test (hidden in normal review) ----------
  async function runSelftest() {
    const wait = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
    const state = () => window.DS03.state();
    const setDebug = (patch) => window.DS03.setDebug(patch);
    const result = {
      protocol: location.protocol,
      href: location.href,
      embedded: Boolean(embedded),
      embeddedAssetCount: embedded ? Object.keys(embedded).length : 0,
      assetKeyCount: assetKeys.length,
      failed: failed.slice(),
      errors: errors.slice(),
      canvas: { width: canvas.width, height: canvas.height },
    };
    await ready;
    await wait(80);
    const savedT = t;
    const savedPlaying = playing;
    setTime(5, true);
    setPlaying(false);
    const p0 = state().t;
    await wait(220);
    const p1 = state().t;
    setPlaying(true);
    await wait(320);
    const p2 = state().t;
    setPlaying(false);
    result.pauseResume = {
      before: p0,
      paused: p1,
      afterResume: p2,
      pausedStable: Math.abs(p1 - p0) < 0.01,
      advanced: p2 - p1 > 0.15,
    };

    const click = (id) => {
      const el = document.getElementById(id);
      if (!el) return false;
      el.click();
      return true;
    };
    const resetClicked = click("reset");
    await wait(80);
    const afterReset = state();
    setPlaying(false);
    result.resetButton = {
      clicked: resetClicked,
      t: afterReset.t,
      playing: afterReset.playing,
      ok: afterReset.t >= 0 && afterReset.t < 1.2,
    };

    if (afterReset.playing) setPlaying(false);
    const scrubEl = document.getElementById("scrub");
    let scrubOk = false;
    if (scrubEl) {
      scrubEl.value = "12";
      scrubEl.dispatchEvent(new Event("input", { bubbles: true }));
      await wait(30);
      scrubOk = Math.abs(state().t - 12) < 0.01;
    }
    result.scrub = { ok: scrubOk, t: state().t };

    click("play");
    await wait(260);
    const playAdvanced = state().t;
    const playPlaying = state().playing;
    click("play");
    await wait(50);
    const playPaused = state().t;
    result.playButton = {
      advanced: playAdvanced > afterReset.t + 0.12,
      playing: playPlaying,
      pausedStable: Math.abs(state().t - playPaused) < 0.01,
      ok: playPlaying && playAdvanced > afterReset.t + 0.12,
    };

    click("bridgeUp");
    await wait(40);
    const upState = state();
    click("bridgeDown");
    await wait(40);
    const downState = state();
    click("islandGap");
    await wait(40);
    const islandState = state();
    const g = (s, id) => s.groups.find((item) => item.id === id);
    const bridgeStatic = (s) =>
      ["G1", "G2"].every((id) => {
        const item = g(s, id);
        return item.static === true && item.dyFormula === 0 && item.dyRendered === 0;
      });
    setDebug({ forceFloat: "up", worst: "" });
    const forceUpState = state();
    setDebug({ forceFloat: "down", worst: "" });
    const forceDownState = state();
    setDebug({ forceFloat: "", worst: "bridge" });
    const worstBridgeState = state();
    setDebug({ forceFloat: "", worst: "island" });
    const worstIslandState = state();
    setDebug({ forceFloat: "", worst: "" });
    click("cloudToggle");
    await wait(40);
    const cloudOff = state();
    click("cloudToggle");
    await wait(40);
    const cloudOn = state();
    result.inspectionButtons = {
      up: { t: upState.t, G1: g(upState, "G1").dyRendered, G2: g(upState, "G2").dyRendered },
      down: { t: downState.t, G1: g(downState, "G1").dyRendered, G2: g(downState, "G2").dyRendered },
      island: { t: islandState.t },
      forceUp: { G1: g(forceUpState, "G1").dyRendered, G2: g(forceUpState, "G2").dyRendered },
      forceDown: { G1: g(forceDownState, "G1").dyRendered, G2: g(forceDownState, "G2").dyRendered },
      worstBridge: { G1: g(worstBridgeState, "G1").dyRendered, G2: g(worstBridgeState, "G2").dyRendered },
      worstIsland: {
        G1: g(worstIslandState, "G1").dyRendered,
        G2: g(worstIslandState, "G2").dyRendered,
        G5: g(worstIslandState, "G5").dyRendered,
      },
      cloudOffSkip: cloudOff.skip,
      cloudOnSkip: cloudOn.skip,
      ok:
        bridgeStatic(upState) &&
        bridgeStatic(downState) &&
        bridgeStatic(forceUpState) &&
        bridgeStatic(forceDownState) &&
        bridgeStatic(worstBridgeState) &&
        bridgeStatic(worstIslandState) &&
        Math.abs(g(worstIslandState, "G5").dyRendered) <= 0.5 &&
        cloudOff.skip.includes("seaMain") &&
        cloudOff.skip.includes("seaNear") &&
        !cloudOn.skip.includes("seaMain") &&
        !cloudOn.skip.includes("seaNear"),
    };

    const seamClicked = click("seamBefore");
    await wait(40);
    result.seamBefore = {
      clicked: seamClicked,
      t: state().t,
      markerOn: document.getElementById("seamMark")?.classList.contains("on") || false,
      nearSeamX: state().nearSeamX,
      mainSeamX: state().mainSeamX,
    };
    const seamAfterClicked = click("seamAfter");
    await wait(40);
    result.seamAfter = {
      clicked: seamAfterClicked,
      t: state().t,
      markerOn: document.getElementById("seamMark")?.classList.contains("on") || false,
    };
    const wrapClicked = click("skyWrap");
    await wait(40);
    result.skyWrap = { clicked: wrapClicked, t: state().t };

    const hideClicked = click("hideUI");
    await wait(30);
    result.hideUI = {
      clicked: hideClicked,
      hidden: document.getElementById("hud")?.classList.contains("hidden") || false,
    };
    if (hideClicked) {
      document.getElementById("hud")?.classList.remove("hidden");
    }

    const resources = performance
      .getEntriesByType("resource")
      .map((entry) => entry.name)
      .filter((name) => !name.startsWith("data:"));
    result.resources = resources;
    result.externalRequests = resources.filter((name) => /^https?:/i.test(name));
    result.scripts = Array.from(document.scripts)
      .map((s) => s.src)
      .filter(Boolean);
    result.links = Array.from(document.querySelectorAll("link")).map((l) => l.href);
    result.finalState = state();
    result.done = true;

    setTime(savedT, true);
    if (savedPlaying) setPlaying(true);
    let out = document.getElementById("selftest");
    if (!out) {
      out = document.createElement("pre");
      out.id = "selftest";
      out.hidden = true;
      document.body.appendChild(out);
    }
    out.textContent = JSON.stringify(result, null, 2);
    document.title = "DS03 SELFTEST DONE";
  }

  if (params.get("selftest") === "1") {
    runSelftest().catch((error) => {
      let out = document.getElementById("selftest");
      if (!out) {
        out = document.createElement("pre");
        out.id = "selftest";
        document.body.appendChild(out);
      }
      out.textContent = JSON.stringify({ done: false, error: String(error) });
      document.title = "DS03 SELFTEST FAILED";
    });
  }

  setPlaying(playing);
  draw();
  requestAnimationFrame(function frame(now) {
    lastRaf = now;
    t = currentT();
    draw();
    requestAnimationFrame(frame);
  });
  // rAF is the primary clock.  Some embedded/background views throttle it;
  // this fallback draws only if rAF has been silent for 250 ms.
  setInterval(() => {
    if (playing && performance.now() - lastRaf > 250) {
      t = currentT();
      draw();
    }
  }, 100);
})();
