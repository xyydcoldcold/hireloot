/* Hireloot —— 卡包 & 武器库
 * 开包的节奏参考了卡牌游戏常见的「蓄力 → 撕开 → 翻牌 → 庆祝」四段式：
 *   1. 蓄力：卡包抖动，缝隙里漏出稀有度颜色的光（越稀有抖得越久、光越强）
 *   2. 撕开：包顶飞出去，光柱冲出来
 *   3. 翻牌：卡牌从包里升起再翻面
 *   4. 庆祝：闪屏 + 像素粒子 + 8-bit 音效，史诗/传说还有震屏和横幅
 * 镭射卡面参考 pokemon-cards-css 的做法：彩虹渐变层用 color-dodge 叠在卡面上，
 * 位置跟着鼠标走，再叠一层高光。这里把渐变改成硬色阶 + 扫描线，保持像素感。
 */
window.HirelootArmory = (function () {
  'use strict';
  const W = window.HirelootWeapons;
  const RAR = W.RARITIES;
  let H = null; // app.js 暴露的工具，init 时传进来
  const $ = (s, r = document) => r.querySelector(s);
  const t = (...a) => H.t(...a);
  const reduced = () => window.matchMedia && matchMedia('(prefers-reduced-motion: reduce)').matches;
  const wait = (ms) => new Promise((r) => setTimeout(r, reduced() ? Math.min(ms, 120) : ms));
  const A = () => H.getState().armory;
  const isHigh = (r) => r === 'SR' || r === 'SSR';

  // ============ 8-bit 音效（WebAudio 现场合成，不需要音频文件） ============
  const SFX_KEY = 'hireloot.sfx';
  let sfxOn = true;
  try { sfxOn = localStorage.getItem(SFX_KEY) !== 'off'; } catch (e) { /* ignore */ }
  let ctx = null;
  function ac() {
    if (!sfxOn) return null;
    try {
      ctx = ctx || new (window.AudioContext || window.webkitAudioContext)();
      if (ctx.state === 'suspended') ctx.resume();
    } catch (e) { return null; }
    return ctx;
  }
  function tone(freq, dur, { type = 'square', vol = 0.05, at = 0, to = null } = {}) {
    const c = ac(); if (!c) return;
    const o = c.createOscillator(), g = c.createGain();
    const t0 = c.currentTime + at;
    o.type = type;
    o.frequency.setValueAtTime(freq, t0);
    if (to) o.frequency.exponentialRampToValueAtTime(to, t0 + dur);
    g.gain.setValueAtTime(vol, t0);
    g.gain.exponentialRampToValueAtTime(0.0001, t0 + dur);
    o.connect(g).connect(c.destination);
    o.start(t0); o.stop(t0 + dur + 0.02);
  }
  function noise(dur, vol = 0.08, at = 0) {
    const c = ac(); if (!c) return;
    const len = Math.floor(c.sampleRate * dur);
    const buf = c.createBuffer(1, len, c.sampleRate);
    const d = buf.getChannelData(0);
    for (let i = 0; i < len; i++) d[i] = (Math.random() * 2 - 1) * (1 - i / len);
    const s = c.createBufferSource(), g = c.createGain(), f = c.createBiquadFilter();
    f.type = 'highpass'; f.frequency.value = 1200;
    s.buffer = buf; g.gain.value = vol;
    s.connect(f).connect(g).connect(c.destination);
    s.start(c.currentTime + at);
  }
  const NOTES = [523, 659, 784, 1047, 1319, 1568, 2093];
  const Sfx = {
    tick(i) { tone(220 + i * 40, 0.05, { vol: 0.03 }); },
    tear() { noise(0.25, 0.12); tone(180, 0.2, { to: 900, vol: 0.04 }); },
    reveal(r) {
      const n = { N: 2, R: 3, SR: 5, SSR: 7 }[r];
      for (let i = 0; i < n; i++) tone(NOTES[i], 0.12, { at: i * 0.06, vol: 0.045 });
      if (r === 'SSR') {
        [1047, 1319, 1568].forEach((f) => tone(f, 0.7, { at: n * 0.06 + 0.05, vol: 0.035, type: 'triangle' }));
        tone(2093, 0.5, { at: n * 0.06 + 0.1, vol: 0.03 });
      } else if (r === 'SR') {
        [784, 988, 1175].forEach((f) => tone(f, 0.45, { at: n * 0.06 + 0.04, vol: 0.03, type: 'triangle' }));
      }
    },
    rip(p) { noise(0.05, 0.05 + p * 0.05); tone(300 + p * 500, 0.04, { vol: 0.025 }); },
    star() { tone(1568, 0.08, { vol: 0.04 }); tone(2093, 0.16, { at: 0.08, vol: 0.04 }); },
    click() { tone(660, 0.05, { vol: 0.03 }); }
  };

  // ============ 卡牌 ============
  function weaponSvg(w, locked, px = 4) {
    const shape = W.SHAPES[w.shape];
    if (locked) {
      // 黑色剪影 + 一圈暗蓝描边
      const pal = {};
      for (const row of shape) for (const ch of row) if (ch !== '.') pal[ch] = '#07061a';
      return H.sprite(shape, pal, px, '#4a5094');
    }
    return H.sprite(shape, W.PALETTES[w.pal], px, '#0c0b16');
  }
  // 名字长度（中文算两格），太长的卡名换小一号字
  const nameLen = (s) => [...s].reduce((n, c) => n + (c.charCodeAt(0) > 255 ? 2 : 1), 0);
  // opts: { locked, count, back, mini, flipped }
  function cardHtml(w, opts = {}) {
    const lang = H.getLang();
    const r = RAR[w.rarity];
    const count = opts.count || 0;
    const locked = !!opts.locked;
    const atk = locked ? '???' : t('card.atk', { n: W.atkOf(w.id, Math.max(1, count)) });
    const stars = locked ? '' : Array.from({ length: W.MAX_STARS }, (_, i) =>
      `<i class="${i < Math.max(1, count) ? 'on' : ''}">★</i>`).join('');
    const equipped = !locked && A().equipped === w.id;
    return `<div class="card r-${w.rarity} ${locked ? 'locked' : ''} ${opts.mini ? 'mini' : ''} ${opts.flipped === false ? '' : 'flipped'}" style="--rc:${r.color}" data-weapon="${w.id}">
      <div class="card-inner">
        <div class="card-back"><span class="back-emblem">${H.icon('pack', 4)}</span><span class="back-logo">HIRELOOT</span></div>
        <div class="card-front">
          <div class="card-top"><span class="rar">${w.rarity}</span><span class="atk">${atk}</span></div>
          <div class="card-art"><div class="rays"></div>${weaponSvg(w, locked, opts.mini ? 3 : 4)}</div>
          <div class="card-name ${!locked && nameLen(w.name[lang] || w.name.zh) > 16 ? 'long' : ''}">${locked ? t('armory.locked') : H.esc(w.name[lang] || w.name.zh)}</div>
          <div class="card-stars">${stars || `<span class="rar-name">${t('rarity.' + w.rarity)}</span>`}</div>
          <div class="card-desc">${locked ? t('armory.lockedDesc') : H.esc(w.desc[lang] || w.desc.zh)}</div>
          ${equipped && opts.mini ? `<span class="eq-badge">${t('armory.equipped')}</span>` : ''}
          <div class="holo"></div><div class="glare"></div>${w.rarity === 'SSR' && !locked ? '<div class="sparkles"><i></i><i></i><i></i><i></i><i></i></div>' : ''}
        </div>
      </div>
    </div>`;
  }

  // 鼠标/手指移动时卡牌倾斜，镭射层跟着移动
  function bindTilt() {
    document.addEventListener('pointermove', (e) => {
      const card = e.target.closest && e.target.closest('.card.flipped:not(.locked)');
      if (!card || reduced()) return;
      const r = card.getBoundingClientRect();
      const x = Math.min(1, Math.max(0, (e.clientX - r.left) / r.width));
      const y = Math.min(1, Math.max(0, (e.clientY - r.top) / r.height));
      card.classList.add('tilting');
      card.style.setProperty('--mx', (x * 100).toFixed(1) + '%');
      card.style.setProperty('--my', (y * 100).toFixed(1) + '%');
      card.style.setProperty('--rx', ((0.5 - y) * 18).toFixed(1) + 'deg');
      card.style.setProperty('--ry', ((x - 0.5) * 22).toFixed(1) + 'deg');
    });
    document.addEventListener('pointerout', (e) => {
      const card = e.target.closest && e.target.closest('.card.tilting');
      if (!card || card.contains(e.relatedTarget)) return;
      card.classList.remove('tilting');
      ['--mx', '--my', '--rx', '--ry'].forEach((k) => card.style.removeProperty(k));
    });
  }

  // ============ 开包舞台 ============
  const stage = () => $('#pack-stage');
  // 卡包状态：sealed 没动过 → tearing 正在撕（已经抽好）→ busy 开包演出中 → open 已翻开
  let session = null; // { slots: [{ state, pull }], fromLevelUp }

  // 包顶画两份：左边 t-l 是已经撕开的部分（跟着手指翘起来），右边 t-r 还连着包身。--p 是撕开进度 0~1
  function packHtml(i) {
    return `<button class="pack" data-act="pack-tear" data-i="${i}" aria-label="${t('pack.hint')}">
      <span class="pack-top t-r"><span class="crimp"></span></span>
      <span class="pack-top t-l"><span class="crimp"></span></span>
      <span class="tear-line"></span>
      <span class="tear-guide">${t('pack.tearHere')}</span>
      <span class="pack-body">
        <span class="pack-logo">HIRELOOT</span>
        <span class="pack-emblem">${H.icon('chest', 5)}</span>
        <span class="pack-sub">WEAPON PACK</span>
        <span class="crimp"></span>
      </span>
      <span class="pack-foil"></span>
    </button>`;
  }

  function openStage(fromLevelUp) {
    const st = H.computeStats();
    if (!st.packs) return;
    if (session && !stage().hidden) return; // 已经开着
    const n = Math.min(3, st.packs);
    session = { slots: Array.from({ length: n }, () => ({ state: 'sealed' })), fromLevelUp: !!fromLevelUp, returnFocus: document.activeElement };
    const el = stage();
    el.innerHTML = `<div class="stage-flash"></div>
      <div class="stage-win" role="dialog" aria-modal="true" aria-labelledby="stage-title">
        <div class="stage-title" id="stage-title">${fromLevelUp ? `<b>${t('pack.titleLv')}</b>` : ''}<span>${t('pack.title', { n })}</span></div>
        <div class="slots">${session.slots.map((s, i) => `<div class="slot" data-slot="${i}">${packHtml(i)}</div>`).join('')}</div>
        <div class="stage-hint">${t('pack.hint')}</div>
        <div class="stage-actions"></div>
        <div class="banner" aria-live="polite"></div>
      </div>`;
    el.hidden = false;
    document.body.classList.add('no-scroll');
    renderActions();
    Sfx.click();
    const first = el.querySelector('.pack');
    if (first) first.focus();
  }

  function renderActions() {
    if (!session) return;
    const sealed = session.slots.filter((s) => s.state === 'sealed' || s.state === 'tearing').length;
    const busy = session.slots.some((s) => s.state === 'busy');
    const untouched = session.slots.every((s) => s.state === 'sealed');
    const done = !sealed && !busy;
    const left = H.computeStats().packs;
    const box = $('.stage-actions', stage());
    box.innerHTML = done
      ? `${left ? `<button data-act="pack-more">${t('pack.more', { n: Math.min(3, left) })}</button>` : ''}<button class="primary" data-act="pack-done">${t('pack.done')}</button>`
      : `${untouched ? `<button data-act="pack-later">${t('pack.later')}</button>` : ''}<button class="primary" data-act="pack-all" ${busy && !sealed ? 'disabled' : ''}>${t('pack.all')}</button>`;
    $('.stage-hint', stage()).style.visibility = done ? 'hidden' : '';
  }

  function closeStage() {
    const el = stage();
    el.hidden = true; el.innerHTML = '';
    document.body.classList.remove('no-scroll');
    const back = session && session.returnFocus;
    session = null;
    H.refresh();
    if (back && back.isConnected) back.focus();
  }

  // 抽一张：立刻写进存档（中途刷新也不会丢）
  function pull() {
    const a = A();
    const w = W.roll(Math.random, a.pity);
    a.pity = isHigh(w.rarity) ? 0 : a.pity + 1;
    const before = a.owned[w.id] || 0;
    a.owned[w.id] = before + 1;
    a.opened += 1;
    if (!a.equipped || !a.owned[a.equipped]) a.equipped = w.id; // 第一把武器自动装备
    H.save();
    return { w, isNew: before === 0, starUp: before > 0 && before < W.MAX_STARS, count: before + 1 };
  }

  // ---------- 撕包 ----------
  const TEAR_DONE = 0.82; // 撕过这个比例就算撕开
  const slotEl = (i) => $(`.slot[data-slot="${i}"]`, stage());

  // 第一次碰到卡包时就抽好（这样撕的时候缝里漏出的光就是稀有度的颜色）
  function arm(i) {
    const slot = session && session.slots[i];
    if (!slot || (slot.state !== 'sealed' && slot.state !== 'tearing')) return null;
    if (!slot.pull) {
      slot.pull = pull();
      const el = slotEl(i), r = slot.pull.w.rarity;
      el.style.setProperty('--rc', RAR[r].color);
      el.classList.add('r-' + r);
    }
    slot.state = 'tearing';
    renderActions();
    return slot;
  }

  // 设置撕开进度：像素化取整，每撕开一截响一声、掉一点纸屑
  function setProgress(i, p) {
    const el = slotEl(i), pack = el && $('.pack', el);
    if (!pack) return;
    const w = pack.offsetWidth || 1;
    const px = Math.round((p * w) / 4) * 4;
    p = Math.min(1, px / w);
    const prev = +pack.dataset.p || 0;
    pack.style.setProperty('--p', p.toFixed(3));
    pack.dataset.p = p;
    const step = Math.floor(p * 10), prevStep = Math.floor(prev * 10);
    if (step > prevStep) {
      Sfx.rip(p);
      scraps(el, p);
    }
  }

  // 拖动撕包
  let drag = null;
  function bindDrag() {
    stage().addEventListener('pointerdown', (e) => {
      const pack = e.target.closest('.pack');
      if (!pack || e.button > 0 || !session) return;
      const i = +pack.dataset.i;
      const slot = session.slots[i];
      if (!slot || (slot.state !== 'sealed' && slot.state !== 'tearing')) return;
      drag = { i, pack, x0: e.clientX, moved: false, w: pack.offsetWidth, base: +pack.dataset.p || 0 };
      pack.setPointerCapture(e.pointerId);
      pack.classList.add('grab');
    });
    stage().addEventListener('pointermove', (e) => {
      if (!drag) return;
      const dx = e.clientX - drag.x0;
      if (!drag.moved && Math.abs(dx) < 6) return;
      if (!drag.moved) { drag.moved = true; if (!arm(drag.i)) { drag = null; return; } drag.pack.classList.add('dragging'); }
      const p = Math.max(drag.base, Math.min(1, drag.base + dx / (drag.w * 0.9)));
      setProgress(drag.i, p);
      if (p >= TEAR_DONE) { const i = drag.i; endDrag(); finish(i); }
    });
    const end = () => {
      if (!drag) return;
      const { pack, moved } = drag;
      endDrag();
      if (moved) {
        pack.dataset.dragged = '1'; // 吞掉松手后那次 click
        // 没撕够：弹回去一点（已经撕开的口子保留在 0.15，有「撕了一半」的感觉）
        const p = +pack.dataset.p || 0;
        if (p < TEAR_DONE) { pack.classList.add('snap'); setProgress(+pack.dataset.i, Math.min(p, 0.15)); setTimeout(() => pack.classList.remove('snap'), 250); }
      }
    };
    stage().addEventListener('pointerup', end);
    stage().addEventListener('pointercancel', end);
  }
  function endDrag() {
    if (!drag) return;
    drag.pack.classList.remove('grab', 'dragging');
    drag = null;
  }

  // 点一下 / 全部打开：自动撕一遍（同样的动画，只是程序替你拖）
  async function autoTear(i) {
    if (!arm(i)) return;
    const el = slotEl(i), pack = $('.pack', el);
    pack.classList.add('dragging');
    let p = +pack.dataset.p || 0;
    while (p < 1) {
      p = Math.min(1, p + 0.1);
      setProgress(i, p);
      await wait(32);
    }
    pack.classList.remove('dragging');
    finish(i);
  }

  async function finish(i) {
    const slot = session && session.slots[i];
    if (!slot || slot.state !== 'tearing') return;
    slot.state = 'busy';
    renderActions();
    const p = slot.pull, r = p.w.rarity;
    const el = slotEl(i), pack = $('.pack', el);

    // 1. 撕开：包顶飞走，光柱冲出
    Sfx.tear();
    pack.disabled = true;
    pack.classList.add('torn');
    el.classList.add('beam');
    burst(el, 'N', true);
    await wait(240);

    // 2. 卡牌背面朝上升起，按稀有度蓄力抖动、发光
    el.insertAdjacentHTML('beforeend', cardHtml(p.w, { count: p.count, flipped: false }).replace('class="card ', 'class="card rising charging '));
    const card = $('.card', el);
    const charge = { N: 380, R: 600, SR: 1000, SSR: 1500 }[r];
    const ticks = Math.round(charge / 110);
    for (let k = 0; k < ticks; k++) setTimeout(() => Sfx.tick(isHigh(r) ? k * 1.4 : k), reduced() ? 0 : 200 + k * 110);
    if (r === 'SSR') stage().classList.add('rumble');
    await wait(charge);
    stage().classList.remove('rumble');

    // 3. 翻面
    card.classList.remove('charging', 'rising');
    card.classList.add('flipped');
    pack.remove();

    // 4. 庆祝
    Sfx.reveal(r);
    burst(el, r);
    if (r !== 'N') flash(r);
    if (isHigh(r)) {
      stage().classList.remove('quake'); void stage().offsetWidth; stage().classList.add('quake');
      banner(t(r === 'SSR' ? 'pack.ssr' : 'pack.sr'), r);
    }
    await wait(300);
    if (p.isNew) badge(el, t('pack.new'), 'new');
    else if (p.starUp) { badge(el, t('pack.starUp'), 'up'); setTimeout(Sfx.star, 120); }
    else badge(el, t('pack.maxed'), 'max');
    slot.state = 'open';
    el.classList.remove('beam');
    renderActions();
    const next = $('.pack', stage()) || $('.stage-actions .primary', stage());
    if (next && document.activeElement === document.body) next.focus();
  }

  async function tearAll() {
    if (!session) return;
    const idx = session.slots.map((s, i) => (s.state === 'sealed' || s.state === 'tearing' ? i : -1)).filter((i) => i >= 0);
    for (const i of idx) { autoTear(i); await wait(450); }
  }

  // 撕口处掉出的小纸屑
  function scraps(el, p) {
    const pack = $('.pack', el);
    if (!pack || reduced()) return;
    const b = document.createElement('i');
    b.className = 'scrap';
    b.style.left = (p * 100).toFixed(1) + '%';
    b.style.setProperty('--dx', Math.round(Math.random() * 24 - 12) + 'px');
    pack.appendChild(b);
    setTimeout(() => b.remove(), 700);
  }

  function burst(slotEl, r, paper) {
    const n = paper ? 12 : { N: 10, R: 16, SR: 26, SSR: 40 }[r];
    const colors = paper ? ['#c77dff', '#d9d2b8', '#4a2a9a', '#ffcf4a']
      : r === 'SSR' ? ['#ffcf4a', '#ff6b9a', '#7fdbff', '#5fd35f', '#fff4c2'] : [RAR[r].color, '#ffffff', '#fff4c2'];
    const box = document.createElement('div');
    box.className = 'bits' + (paper ? ' paper' : '');
    for (let k = 0; k < n; k++) {
      const a = (k / n) * Math.PI * 2 + Math.random() * 0.4;
      const d = 90 + Math.random() * (isHigh(r) ? 160 : 90);
      const b = document.createElement('i');
      b.style.setProperty('--dx', Math.round(Math.cos(a) * d / 4) * 4 + 'px');
      b.style.setProperty('--dy', Math.round(Math.sin(a) * d / 4) * 4 + 'px');
      b.style.setProperty('--c', colors[k % colors.length]);
      b.style.animationDelay = (Math.random() * 0.12).toFixed(2) + 's';
      box.appendChild(b);
    }
    slotEl.appendChild(box);
    setTimeout(() => box.remove(), 1400);
  }
  function flash(r) {
    const f = $('.stage-flash', stage());
    if (!f) return;
    f.style.setProperty('--rc', RAR[r].color);
    f.classList.remove('go'); void f.offsetWidth; f.classList.add('go');
  }
  function banner(text, r) {
    const b = $('.banner', stage());
    if (!b) return;
    b.textContent = text;
    b.className = 'banner r-' + r;
    void b.offsetWidth; b.classList.add('go');
  }
  function badge(slotEl, text, kind) {
    slotEl.insertAdjacentHTML('beforeend', `<span class="pull-badge ${kind}">${H.esc(text)}</span>`);
  }

  // ============ 武器库页面 ============
  function render(st) {
    if (!H || !$('#armory-grid')) return;
    const a = A();
    const owned = W.WEAPONS.filter((w) => a.owned[w.id]).length;
    $('#armory-count').textContent = t('armory.count', { n: owned, total: W.WEAPONS.length });
    const toNext = st.need - st.cur;
    $('#pack-shelf').innerHTML = st.packs
      ? `<div class="shelf-packs">${Array.from({ length: Math.min(st.packs, 6) }, () => `<span class="shelf-pack">${H.icon('pack', 4)}</span>`).join('')}</div>
         <div class="shelf-main"><p>${t('armory.packs', { n: st.packs })}</p><button class="primary pack-cta" data-act="open-packs">${t('pack.btn', { n: Math.min(3, st.packs) })}</button></div>`
      : `<div class="shelf-packs empty">${H.icon('pack', 4)}</div><div class="shelf-main"><p>${t('armory.noPacks', { n: toNext })}</p></div>`;
    $('#pack-shelf').insertAdjacentHTML('beforeend', `<p class="pity">${t('armory.pity', { n: W.PITY - a.pity })}</p>`);
    $('#armory-grid').innerHTML = W.RARITY_ORDER.map((r) => {
      const list = W.WEAPONS.filter((w) => w.rarity === r);
      const got = list.filter((w) => a.owned[w.id]).length;
      return `<section class="px panel rar-sec" style="--rc:${RAR[r].color}">
        <div class="panel-head"><h2>${t('rarity.' + r)} <span class="rar-tag">${r}</span></h2><span class="pill">${got} / ${list.length}</span></div>
        <div class="card-grid">${list.map((w) => `<button class="card-slot" data-act="card-view" data-weapon="${w.id}" aria-label="${H.esc(a.owned[w.id] ? w.name[H.getLang()] : t('armory.locked'))}">${cardHtml(w, { locked: !a.owned[w.id], count: a.owned[w.id], mini: true })}</button>`).join('')}</div>
      </section>`;
    }).join('');
  }

  // 武器详情（大卡 + 装备按钮）
  const viewer = () => $('#card-view');
  let viewerReturn = null;
  function openViewer(id) {
    const w = W.BY_ID[id];
    if (!w) return;
    const a = A();
    const count = a.owned[id] || 0;
    const equipped = a.equipped === id;
    viewerReturn = document.activeElement;
    viewer().innerHTML = `<div class="viewer" role="dialog" aria-modal="true">
      ${cardHtml(w, { locked: !count, count })}
      <div class="viewer-actions">
        ${count ? `<button class="${equipped ? '' : 'primary'}" data-act="${equipped ? 'unequip' : 'equip'}" data-weapon="${id}">${t(equipped ? 'armory.unequip' : 'armory.equip')}</button>` : ''}
        <button data-act="viewer-close">${t('settings.close')}</button>
      </div>
    </div>`;
    viewer().hidden = false;
    const b = $('.viewer-actions button', viewer());
    if (b) b.focus();
  }
  function closeViewer() {
    viewer().hidden = true; viewer().innerHTML = '';
    if (viewerReturn && viewerReturn.isConnected) viewerReturn.focus();
  }

  // ============ 事件（app.js 的点击代理会先问这里） ============
  function handle(act, btn) {
    switch (act) {
      case 'open-packs': openStage(false); return true;
      case 'pack-tear':
        if (btn.dataset.dragged) { delete btn.dataset.dragged; return true; }
        autoTear(+btn.dataset.i); return true;
      case 'pack-all': tearAll(); return true;
      case 'pack-later': case 'pack-done': closeStage(); return true;
      case 'pack-more': {
        const ret = session && session.returnFocus;
        stage().hidden = true; session = null;
        openStage(false);
        if (session) session.returnFocus = ret;
        return true;
      }
      case 'card-view': openViewer(btn.dataset.weapon); return true;
      case 'viewer-close': closeViewer(); return true;
      case 'equip': case 'unequip': {
        A().equipped = act === 'equip' ? btn.dataset.weapon : null;
        if (act === 'equip') Sfx.star();
        H.refresh();
        openViewer(btn.dataset.weapon);
        return true;
      }
      case 'sfx':
        sfxOn = btn.dataset.sfx === 'on';
        try { localStorage.setItem(SFX_KEY, sfxOn ? 'on' : 'off'); } catch (e) { /* ignore */ }
        if (sfxOn) Sfx.click();
        H.renderSettings();
        return true;
      default: return false;
    }
  }

  function init(api) {
    H = api;
    bindTilt();
    bindDrag();
    viewer().addEventListener('click', (e) => { if (e.target === viewer()) closeViewer(); });
    document.addEventListener('keydown', (e) => {
      if (e.key !== 'Escape') return;
      if (!viewer().hidden) { closeViewer(); e.stopPropagation(); }
      else if (session && !stage().hidden && session.slots.every((s) => s.state === 'sealed' || s.state === 'open')) closeStage();
    }, true);
    render(H.computeStats());
  }

  return { init, render, handle, openStage, sfxOn: () => sfxOn, cardHtml };
})();
