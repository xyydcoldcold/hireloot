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
          <div class="card-name">${locked ? t('armory.locked') : H.esc(w.name[lang] || w.name.zh)}</div>
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
  let session = null; // { slots: [{ state: 'sealed'|'busy'|'open', pull }], fromLevelUp }

  function packHtml(i) {
    return `<button class="pack" data-act="pack-tear" data-i="${i}" aria-label="${t('pack.hint')}">
      <span class="pack-top"><span class="crimp"></span></span>
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
    const sealed = session.slots.filter((s) => s.state === 'sealed').length;
    const busy = session.slots.some((s) => s.state === 'busy');
    const done = !sealed && !busy;
    const left = H.computeStats().packs;
    const box = $('.stage-actions', stage());
    box.innerHTML = done
      ? `${left ? `<button data-act="pack-more">${t('pack.more', { n: Math.min(3, left) })}</button>` : ''}<button class="primary" data-act="pack-done">${t('pack.done')}</button>`
      : `${sealed === session.slots.length ? `<button data-act="pack-later">${t('pack.later')}</button>` : ''}<button class="primary" data-act="pack-all" ${busy && !sealed ? 'disabled' : ''}>${t('pack.all')}</button>`;
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

  async function tear(i) {
    if (!session) return;
    const slot = session.slots[i];
    if (!slot || slot.state !== 'sealed') return;
    slot.state = 'busy';
    const p = slot.pull = pull();
    const r = p.w.rarity;
    renderActions();
    const el = $(`.slot[data-slot="${i}"]`, stage());
    const pack = $('.pack', el);
    el.style.setProperty('--rc', RAR[r].color);
    el.classList.add('r-' + r);

    // 1. 蓄力
    const charge = { N: 520, R: 760, SR: 1150, SSR: 1700 }[r];
    pack.classList.add('charging');
    pack.disabled = true;
    const ticks = Math.round(charge / 110);
    for (let k = 0; k < ticks; k++) setTimeout(() => Sfx.tick(isHigh(r) ? k * 1.4 : k), (reduced() ? 0 : k * 110));
    if (r === 'SSR') stage().classList.add('rumble');
    await wait(charge);

    // 2. 撕开
    Sfx.tear();
    pack.classList.add('torn');
    el.classList.add('beam');
    stage().classList.remove('rumble');
    await wait(260);

    // 3. 卡牌升起、翻面
    el.insertAdjacentHTML('beforeend', cardHtml(p.w, { count: p.count, flipped: false }).replace('class="card ', 'class="card rising '));
    const card = $('.card', el);
    await wait(420);
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
    const idx = session.slots.map((s, i) => (s.state === 'sealed' ? i : -1)).filter((i) => i >= 0);
    for (const i of idx) { tear(i); await wait(380); }
  }

  function burst(slotEl, r) {
    const n = { N: 10, R: 16, SR: 26, SSR: 40 }[r];
    const colors = r === 'SSR' ? ['#ffcf4a', '#ff6b9a', '#7fdbff', '#5fd35f', '#fff4c2'] : [RAR[r].color, '#ffffff', '#fff4c2'];
    const box = document.createElement('div');
    box.className = 'bits';
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
      case 'pack-tear': tear(+btn.dataset.i); return true;
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
    viewer().addEventListener('click', (e) => { if (e.target === viewer()) closeViewer(); });
    document.addEventListener('keydown', (e) => {
      if (e.key !== 'Escape') return;
      if (!viewer().hidden) { closeViewer(); e.stopPropagation(); }
      else if (session && !stage().hidden && !session.slots.some((s) => s.state === 'busy')) closeStage();
    }, true);
    render(H.computeStats());
  }

  return { init, render, handle, openStage, sfxOn: () => sfxOn, cardHtml };
})();
