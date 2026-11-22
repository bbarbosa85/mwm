// The hero animation, drawn as one SVG: three stacked windows on a dark desktop. For each app a
// shortcut focuses it, then another moves it into its slot. Windows jump instantly; every shortcut
// stays on screen for 2 seconds. The picture is a pure function of the time (20 s loop), so it can be
// frozen with ?demo=<milliseconds>.
(function () {
  var root = document.getElementById('demo');
  if (!root) return;
  var NS = 'http://www.w3.org/2000/svg';
  var W = 1600, H = 1000, MB = 44, DH = H - MB;

  function el(name, attrs, parent) {
    var e = document.createElementNS(NS, name);
    for (var k in attrs) e.setAttribute(k, attrs[k]);
    if (parent) parent.appendChild(e);
    return e;
  }
  function txt(str, attrs, parent) { var t = el('text', attrs, parent); t.textContent = str; return t; }
  var FONT = '-apple-system, "SF Pro Text", "Helvetica Neue", sans-serif';
  var MONO = 'ui-monospace, Menlo, monospace';

  // ---- Timeline ---------------------------------------------------------------------------------
  var KEYS = 2000, RESULT = 800, ACT = 400, FADE = 200, INTRO = 800, FINAL = 3200;
  var commands = [
    { kind: 'focus', id: 'safari', keys: ['opt', 'S'], label: 'Focus Safari' },
    { kind: 'move', id: 'safari', keys: ['shyper', '4'], label: 'Move to left half' },
    { kind: 'focus', id: 'xcode', keys: ['opt', 'X'], label: 'Focus Xcode' },
    { kind: 'move', id: 'xcode', keys: ['shyper', '9'], label: 'Move to top right' },
    { kind: 'focus', id: 'term', keys: ['opt', 'T'], label: 'Focus Terminal' },
    { kind: 'move', id: 'term', keys: ['shyper', '3'], label: 'Move to bottom right' }
  ];
  commands.forEach(function (c, i) {
    c.at = INTRO + i * (KEYS + RESULT); c.act = c.at + ACT; c.until = c.at + KEYS;
  });
  var RESET = commands[commands.length - 1].until + FINAL;
  var LOOP = RESET;

  // Rectangles in percent of the desktop: x, y, width, height.
  var messy = { safari: [5, 6, 58, 66], xcode: [14, 15, 58, 66], term: [23, 24, 58, 66] };
  var tidy = { safari: [1.2, 2, 48.8, 96], xcode: [51.2, 2, 47.6, 47], term: [51.2, 51, 47.6, 47] };
  function px(r) { return [r[0] / 100 * W, MB + r[1] / 100 * DH, r[2] / 100 * W, r[3] / 100 * DH]; }

  // ---- The SVG ----------------------------------------------------------------------------------
  var svg = el('svg', { viewBox: '0 0 ' + W + ' ' + H, role: 'img', preserveAspectRatio: 'xMidYMid slice' });
  svg.setAttribute('aria-label', 'Animation: three stacked windows. A shortcut focuses each app, then another moves it into its place on the screen: Safari to the left half, Xcode to the top right, Terminal to the bottom right.');
  var defs = el('defs', {}, svg);
  function grad(id, kind, attrs, stops) {
    var g = el(kind, attrs, defs); g.setAttribute('id', id);
    stops.forEach(function (s) { el('stop', { offset: s[0], 'stop-color': s[1], 'stop-opacity': s[2] === undefined ? 1 : s[2] }, g); });
  }
  grad('wp', 'linearGradient', { x1: 0, y1: 0, x2: 0.45, y2: 1 }, [[0, '#101744'], [0.55, '#2b1670'], [1, '#521a6e']]);
  grad('b1', 'radialGradient', { cx: 0.85, cy: 0.95, r: 0.6 }, [[0, '#ff5ea0', 0.8], [1, '#ff5ea0', 0]]);
  grad('b2', 'radialGradient', { cx: 0.08, cy: 1, r: 0.55 }, [[0, '#ff9646', 0.6], [1, '#ff9646', 0]]);
  grad('b3', 'radialGradient', { cx: 0.2, cy: 0, r: 0.7 }, [[0, '#4678ff', 0.8], [1, '#4678ff', 0]]);
  grad('b4', 'radialGradient', { cx: 1, cy: 0, r: 0.6 }, [[0, '#965aff', 0.75], [1, '#965aff', 0]]);
  grad('vg', 'radialGradient', { cx: 0.5, cy: 0.4, r: 0.75 }, [[0.55, '#000', 0], [1, '#000', 0.28]]);
  var shadow = el('filter', { id: 'sh', x: '-10%', y: '-10%', width: '120%', height: '125%' }, defs);
  el('feDropShadow', { dx: 0, dy: 18, stdDeviation: 22, 'flood-color': '#000', 'flood-opacity': 0.5 }, shadow);
  var panelShadow = el('filter', { id: 'psh', x: '-20%', y: '-30%', width: '140%', height: '170%' }, defs);
  el('feDropShadow', { dx: 0, dy: 24, stdDeviation: 30, 'flood-color': '#000', 'flood-opacity': 0.55 }, panelShadow);

  ['wp', 'b1', 'b2', 'b3', 'b4', 'vg'].forEach(function (id) { el('rect', { width: W, height: H, fill: 'url(#' + id + ')' }, svg); });

  // Menu bar
  el('rect', { width: W, height: MB, fill: 'rgba(20,20,26,.6)' }, svg);
  txt('Finder', { x: 26, y: 29, fill: 'rgba(255,255,255,.9)', 'font-size': 20, 'font-weight': 700, 'font-family': FONT }, svg);
  [112, 150, 188].forEach(function (x) { el('rect', { x: x, y: 19, width: 24, height: 9, rx: 4.5, fill: 'rgba(255,255,255,.45)' }, svg); });
  el('rect', { x: W - 118, y: 19, width: 24, height: 9, rx: 4.5, fill: 'rgba(255,255,255,.45)' }, svg);
  el('image', { href: 'assets/icon.png', x: W - 80, y: 10, width: 26, height: 26 }, svg);
  el('rect', { x: W - 44, y: 19, width: 24, height: 9, rx: 4.5, fill: 'rgba(255,255,255,.45)' }, svg);

  // Windows. Icons are simple stand-ins drawn on a 16 x 16 grid.
  var icons = {
    safari: function (g) {
      el('circle', { cx: 8, cy: 8, r: 7.5, fill: '#1e7bf0' }, g);
      el('circle', { cx: 8, cy: 8, r: 6, fill: 'none', stroke: '#fff', 'stroke-opacity': 0.6, 'stroke-width': 0.8 }, g);
      el('path', { d: 'M11.5 4.5 9.2 9.2 4.5 11.5 6.8 6.8z', fill: '#ff4d4d' }, g);
      el('path', { d: 'M11.5 4.5 9.2 9.2 6.8 6.8z', fill: '#fff' }, g);
    },
    xcode: function (g) {
      el('rect', { width: 16, height: 16, rx: 4, fill: '#1b8cff' }, g);
      el('path', { d: 'M4 12 12 4M5 4.5l1.2 2M11 11.5 9.8 9.5', stroke: '#fff', 'stroke-width': 1.6, 'stroke-linecap': 'round', fill: 'none' }, g);
    },
    term: function (g) {
      el('rect', { width: 16, height: 16, rx: 4, fill: '#0b0b0e', stroke: '#666', 'stroke-width': 0.8 }, g);
      el('path', { d: 'M4 5.5 7 8 4 10.5M8.5 11H12', fill: 'none', stroke: '#fff', 'stroke-width': 1.4, 'stroke-linecap': 'round', 'stroke-linejoin': 'round' }, g);
    }
  };
  var names = { safari: 'Safari', xcode: 'Xcode', term: 'Terminal' };
  var wins = {};
  var termLines = ['~ $ git pull', 'Already up to date.', '~ $ swift build', 'Build complete!', '~ $ ▍'];
  // Skeleton lines: width as a fraction of the body, and an accent for some Xcode lines.
  var fractions = [0.86, 0.7, 0.58, 0.86, 0.72, 0.58, 0.86, 0.7, 0.58, 0.86, 0.72, 0.58];
  ['safari', 'xcode', 'term'].forEach(function (id) {
    var g = el('g', {}, svg), w = { g: g };
    var clip = el('clipPath', { id: 'clip-' + id }, defs);
    w.clipRect = el('rect', { rx: 20 }, clip);
    w.bg = el('rect', { rx: 20, fill: id === 'term' ? '#14151a' : '#1e1f24', stroke: 'rgba(255,255,255,.12)', 'stroke-width': 2, filter: 'url(#sh)' }, g);
    var inner = el('g', { 'clip-path': 'url(#clip-' + id + ')' }, g);
    w.inner = inner;
    w.bar = el('rect', { x: 0, y: 0, height: 52, fill: id === 'term' ? '#23242a' : '#2a2b31' }, inner);
    w.dots = [26, 48, 70].map(function (x) { return el('circle', { cx: x, cy: 26, r: 8, fill: '#5a5b62' }, inner); });
    var ic = el('g', { transform: 'translate(94 12) scale(1.75)' }, inner); icons[id](ic);
    txt(names[id], { x: 132, y: 34, fill: 'rgba(255,255,255,.85)', 'font-size': 22, 'font-weight': 600, 'font-family': FONT }, inner);
    w.lines = [];
    if (id === 'term') {
      termLines.forEach(function (s, i) { txt(s, { x: 28, y: 108 + i * 38, fill: i % 2 ? 'rgba(126,226,168,.8)' : '#7ee2a8', 'font-size': 23, 'font-family': MONO }, inner); });
    } else {
      if (id === 'safari') w.url = el('rect', { x: 28, y: 70, height: 32, rx: 16, fill: '#34363d' }, inner);
      for (var i = 0; i < 12; i++) {
        var accent = id === 'xcode' && (i % 4 === 3 ? '#3b5fa8' : i % 7 === 6 ? '#7b4fb0' : null);
        w.lines.push({ f: fractions[i], r: el('rect', { x: 28, y: (id === 'safari' ? 130 : 84) + i * 26, height: 12, rx: 6, fill: accent || '#3a3c45' }, inner) });
      }
    }
    wins[id] = w;
  });

  // Key panels, one per command, centered on the screen.
  var CAP = 92, CGAP = 14, PLUS = 36, PAD = 52;
  var symbols = { hyper: ['⌃', '⌥', '⌘'], shyper: ['⇧', '⌃', '⌥', '⌘'], opt: ['⌥', '⇧'] };
  var panels = commands.map(function (c) {
    var g = el('g', { opacity: 0 }, svg), items = [];
    c.keys.forEach(function (k, i) { if (i) items.push({ plus: true }); (symbols[k] || [k]).forEach(function (s) { items.push({ s: s }); }); });
    var inner = items.reduce(function (a, it, i) { return a + (it.plus ? PLUS : CAP) + (i ? CGAP : 0); }, 0);
    var pw = Math.max(inner + PAD * 2, 520), ph = 250, px0 = (W - pw) / 2, py0 = MB + DH / 2 - ph / 2;
    el('rect', { x: px0, y: py0, width: pw, height: ph, rx: 44, fill: 'rgba(18,18,24,.8)', stroke: 'rgba(255,255,255,.15)', 'stroke-width': 2, filter: 'url(#psh)' }, g);
    var x = (W - inner) / 2, caps = [];
    items.forEach(function (it, i) {
      if (i) x += CGAP;
      if (it.plus) { txt('+', { x: x + PLUS / 2, y: py0 + 40 + 62, 'text-anchor': 'middle', fill: 'rgba(255,255,255,.5)', 'font-size': 36, 'font-weight': 600, 'font-family': FONT }, g); x += PLUS; return; }
      var r = el('rect', { x: x, y: py0 + 40, width: CAP, height: CAP, rx: 22, fill: '#34363e' }, g);
      el('rect', { x: x + 6, y: py0 + 40 + CAP - 6, width: CAP - 12, height: 6, rx: 3, fill: 'rgba(0,0,0,.3)' }, g);
      txt(it.s, { x: x + CAP / 2, y: py0 + 40 + 62, 'text-anchor': 'middle', fill: '#f1f2f6', 'font-size': 44, 'font-weight': 600, 'font-family': FONT }, g);
      caps.push(r); x += CAP;
    });
    txt(c.label, { x: W / 2, y: py0 + ph - 46, 'text-anchor': 'middle', fill: 'rgba(255,255,255,.88)', 'font-size': 32, 'font-weight': 600, 'font-family': FONT }, g);
    return { g: g, caps: caps };
  });

  root.appendChild(svg);

  // ---- Drawing ----------------------------------------------------------------------------------
  function clamp(v) { return Math.max(0, Math.min(1, v)); }
  var lastFront = null, lastRects = {};
  function render(t) {
    var rects = { safari: messy.safari, xcode: messy.xcode, term: messy.term }, front = 'term', shown = -1;
    if (t < RESET) commands.forEach(function (c, i) {
      if (t >= c.act) front = c.id;
      if (c.kind === 'move' && t >= c.act) rects[c.id] = tidy[c.id];
      if (t >= c.at && t < c.until) shown = i;
    });
    var order = ['safari', 'xcode', 'term'].sort(function (a, b) { return (a === front) - (b === front); });
    order.forEach(function (id) {
      var w = wins[id], r = px(rects[id]), key = r.join(',');
      if (lastRects[id] !== key) {
        lastRects[id] = key;
        w.g.setAttribute('transform', 'translate(' + r[0] + ' ' + r[1] + ')');
        w.bg.setAttribute('width', r[2]); w.bg.setAttribute('height', r[3]);
        w.clipRect.setAttribute('width', r[2]); w.clipRect.setAttribute('height', r[3]);
        w.clipRect.setAttribute('x', 0); w.clipRect.setAttribute('y', 0);
        w.bar.setAttribute('width', r[2]);
        if (w.url) w.url.setAttribute('width', r[2] - 56);
        w.lines.forEach(function (l) { l.r.setAttribute('width', l.f * (r[2] - 56)); });
      }
    });
    if (lastFront !== front) {
      lastFront = front;
      order.forEach(function (id) { svg.appendChild(wins[id].g); });
      // Keep the key panels above the windows.
      panels.forEach(function (p) { svg.appendChild(p.g); });
    }
    ['safari', 'xcode', 'term'].forEach(function (id) {
      var on = id === front, w = wins[id];
      w.bg.setAttribute('stroke', on ? 'rgba(120,160,255,.75)' : 'rgba(255,255,255,.12)');
      w.bg.setAttribute('stroke-width', on ? 3 : 2);
      ['#ff5f57', '#febc2e', '#28c840'].forEach(function (c, i) { w.dots[i].setAttribute('fill', on ? c : '#5a5b62'); });
    });
    panels.forEach(function (p, i) {
      var c = commands[i], o = 0;
      if (i === shown) o = Math.min(clamp((t - c.at) / FADE), clamp((c.until - t) / FADE));
      p.g.setAttribute('opacity', o);
      if (o > 0) { var down = t >= c.at + 300 && t < c.act + 300; p.caps.forEach(function (r) { r.setAttribute('fill', down ? '#3b6cff' : '#34363e'); }); }
    });
  }

  var frozen = new URLSearchParams(location.search).get('demo');
  var still = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  if (frozen !== null) { render(parseFloat(frozen)); return; }
  if (still) { render(RESET - 600); return; }

  var start = null, running = false, visible = true, last = 0, STEP = 1000 / 30;
  function frame(now) {
    if (!running) return;
    if (start === null) start = now;
    if (now - last >= STEP - 2) { last = now; render((now - start) % LOOP); }
    requestAnimationFrame(frame);
  }
  function play() { if (!running && visible && !document.hidden) { running = true; start = null; requestAnimationFrame(frame); } }
  function pause() { running = false; }
  if ('IntersectionObserver' in window) {
    new IntersectionObserver(function (e) { visible = e[0].isIntersecting; visible ? play() : pause(); }).observe(root);
  }
  document.addEventListener('visibilitychange', function () { document.hidden ? pause() : play(); });
  render(0); play();
})();
