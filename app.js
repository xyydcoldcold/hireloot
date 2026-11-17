/* Hireloot —— 主逻辑（纯原生 JS，数据存在浏览器 localStorage） */
(function () {
  'use strict';

  // ============ 规则配置（想改数值就改这里） ============
  // none = 默认无分类：普通待办，不加属性
  // 文字（名称、说明）在 i18n.js 里
  const CATEGORIES = {
    none:    { icon: null,     color: '#6b6890', reward: {} },
    project: { icon: 'sword',  color: '#e4572e', reward: { atk: 3, exp: 20 } },
    resume:  { icon: 'shield', color: '#4ea8de', reward: { def: 3, exp: 15 } },
    apply:   { icon: 'mail',   color: '#f2c14e', reward: { exp: 30 } },
    network: { icon: 'heart',  color: '#c77dff', reward: { cha: 2, ally: 1, exp: 15 } },
    prep:    { icon: 'book',   color: '#3ddc97', reward: { int: 3, exp: 15 } }
  };
  const CATEGORY_KEYS = Object.keys(CATEGORIES);
  const EFFORT_KEYS = CATEGORY_KEYS.filter((k) => k !== 'none'); // 五类努力

  // Boss 战（面试）奖励。智力会在记录面试时提供额外经验加成
  const BOSS_REWARD = {
    pending: { exp: 0,   gold: 0 },
    pass:    { exp: 100, gold: 50 },
    fail:    { exp: 40,  gold: 0 }
  };
  const BOSS_ROUNDS = ['oa', 'phone', 'r1', 'r2', 'r3', 'final', 'hr', 'other'];

  // [门槛, 名称序号, 颜色]；名称在 i18n.js 的 weapons / armors / titles 里
  const WEAPONS = [[0, 0, null], [3, 1, '#a0522d'], [15, 2, '#c0c0c0'], [30, 3, '#e8eef4'], [60, 4, '#7fdbff'], [100, 5, '#ffd700']];
  const ARMORS = [[0, 0, '#8a7a63'], [3, 1, '#8b5a2b'], [15, 2, '#9e9e9e'], [30, 3, '#b0bec5'], [60, 4, '#4fc3f7'], [100, 5, '#e53935']];
  const TITLES = [[1, 0], [3, 1], [5, 2], [8, 3], [12, 4], [16, 5], [20, 6]];

  // ============ 语言 ============
  const LANG_KEY = 'hireloot.lang';
  let lang = 'zh';
  try { if (localStorage.getItem(LANG_KEY) === 'en') lang = 'en'; } catch (e) { /* ignore */ }
  function t(key, vars) {
    let v = (window.JQ_I18N[lang] || {})[key];
    if (v === undefined) v = window.JQ_I18N.zh[key];
    if (typeof v !== 'string') return v;
    return vars ? v.replace(/\{(\w+)\}/g, (m, k) => (k in vars ? vars[k] : m)) : v;
  }
  const catLabel = (k) => t('cat.' + (CATEGORIES[k] ? k : 'none'));
  const titleName = (lv) => t('titles')[tier(TITLES, lv)[1]];
  // 旧存档里轮次存的是中文，这里兼容
  const LEGACY_ROUNDS = { '笔试 / OA': 'oa', '电话面': 'phone', '一面': 'r1', '二面': 'r2', '三面': 'r3', '终面': 'final', 'HR 面': 'hr', '其他': 'other' };
  function roundLabel(r) {
    const k = BOSS_ROUNDS.includes(r) ? r : LEGACY_ROUNDS[r];
    return k ? t('round.' + k) : r;
  }

  // ============ 存储 ============
  const STORE_KEY = 'hireloot.v1';
  // 旧名字 JobQuest 时期的存档，第一次打开时自动搬过来
  try {
    for (const k of ['v1', 'lang', 'tab']) {
      const old = localStorage.getItem('jobquest.' + k);
      if (old !== null && localStorage.getItem('hireloot.' + k) === null) localStorage.setItem('hireloot.' + k, old);
    }
  } catch (e) { /* ignore */ }
  function emptyState() { return { version: 1, tasks: [], interviews: [] }; }
  function load() {
    try {
      const s = JSON.parse(localStorage.getItem(STORE_KEY));
      if (s && Array.isArray(s.tasks) && Array.isArray(s.interviews)) return s;
    } catch (e) { /* ignore */ }
    return emptyState();
  }
  let state = load();
  function save() { localStorage.setItem(STORE_KEY, JSON.stringify(state)); }

  // ============ 工具 ============
  const $ = (sel, root = document) => root.querySelector(sel);
  const uid = () => Date.now().toString(36) + Math.random().toString(36).slice(2, 7);
  function ymd(d = new Date()) {
    const p = (n) => String(n).padStart(2, '0');
    return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}`;
  }
  function daysBetween(a, b) {
    return Math.round((new Date(b + 'T00:00:00') - new Date(a + 'T00:00:00')) / 86400000);
  }
  function prettyDate(s) {
    const [y, m, d] = s.split('-').map(Number);
    const date = new Date(y, m - 1, d);
    if (lang === 'en') return date.toLocaleDateString('en-US', { weekday: 'short', month: 'short', day: 'numeric' });
    return `${m}月${d}日 周${t('weekdays')[date.getDay()]}`;
  }
  function esc(s) {
    return String(s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  }
  function rewardText(r) {
    return Object.entries(r).filter(([, v]) => v).map(([k, v]) => `+${v} ${t('stat.' + k)}`).join(' ');
  }
  const catExp = (t) => (CATEGORIES[t.category] || CATEGORIES.none).reward.exp || 0;
  function tier(list, v) { let t = list[0]; for (const x of list) if (v >= x[0]) t = x; return t; }

  // ============ 属性计算（全部由记录推导，撤销也不会出错） ============
  function bossReward(iv) {
    const base = BOSS_REWARD[iv.result] || BOSS_REWARD.pending;
    const bonus = iv.result === 'pending' ? 0 : (iv.bonus || 0);
    return { exp: base.exp + bonus, gold: base.gold };
  }
  function computeStats(s = state) {
    const st = { atk: 0, def: 0, int: 0, cha: 0, ally: 0, exp: 0, gold: 0, bosses: 0, wins: 0 };
    for (const t of s.tasks) {
      if (!t.doneDate) continue;
      const r = (CATEGORIES[t.category] || CATEGORIES.none).reward;
      for (const k in r) st[k] += r[k];
    }
    for (const iv of s.interviews) {
      const r = bossReward(iv);
      st.exp += r.exp; st.gold += r.gold;
      st.bosses += 1;
      if (iv.result === 'pass') st.wins += 1;
    }
    Object.assign(st, levelInfo(st.exp));
    return st;
  }
  function levelInfo(exp) {
    let lv = 1, need = 100, rest = exp;
    while (rest >= need) { rest -= need; lv += 1; need = 100 + (lv - 1) * 50; }
    return { lv, cur: rest, need };
  }
  // 智力 → Boss 战经验加成（记录时锁定）
  function intBonus(int) { return Math.min(100, Math.floor(int / 3) * 5); }

  // ============ 像素小人 ============
  const HERO = [
    '.....hhhhh......',
    '....hHhhhhh.....',
    '....hsssssh...w.',
    '....sesssess..w.',
    '....sssssss...w.',
    '.....ssmss....w.',
    '...aaaaaaaaa..w.',
    '..aaAaaaaaAaa.w.',
    '..sa.aaaaa.asswg',
    '..s..AaaaA...ggg',
    '.....yyyyy....g.',
    '.....pp.pp......',
    '.....pp.pp......',
    '.....pp.pp......',
    '....bbb.bbb.....',
    '................'
  ];
  const BOSS = [
    '...r........r...',
    '...rr......rr...',
    '....rrrrrrrr....',
    '...rrrrrrrrrr...',
    '..rrwwrrrrwwrr..',
    '..rrwkrrrrwkrr..',
    '.rrrrrrrrrrrrrr.',
    '.rrrryyyyyyrrrr.',
    'rrrrryryyryrrrrr',
    'rr.rrrrrrrrrr.rr',
    'r..rrrrrrrrrr..r',
    '...rrr....rrr...',
    '..rrrr....rrrr..'
  ];
  // ============ 像素图标（不依赖系统字体/emoji） ============
  const K = '#0c0b16';
  const ICONS = {
    sword:  { map: ['......ww', '.....wwl', '....wwl.', 'g..wwl..', '.gwwl...', '..gg....', '.g..g...', 'g.......'], pal: { w: '#e8eef4', l: '#9fb3c8', g: '#c58b3a' } },
    shield: { map: ['kkkkkkkk', 'kllllllk', 'kllyyllk', 'klyyyylk', 'kllyyllk', '.kllllk.', '..kllk..', '...kk...'], pal: { k: K, l: '#4ea8de', y: '#f4f1de' } },
    mail:   { map: ['kkkkkkkk', 'koyyyyok', 'kyoyyoyk', 'kyyooyyk', 'kyyyyyyk', 'kyyyyyyk', 'kkkkkkkk'], pal: { k: K, y: '#f2c14e', o: '#a8741c' } },
    heart:  { map: ['.kk..kk.', 'krrkkrrk', 'kwrrrrrk', 'krrrrrrk', '.krrrrk.', '..krrk..', '...kk...'], pal: { k: K, r: '#c77dff', w: '#f3d9ff' } },
    book:   { map: ['kkkkkkkk', 'kggggggk', 'kgwwwwgk', 'kggggggk', 'kggggggk', 'kggggggk', 'kwwwwwwk', 'kkkkkkkk'], pal: { k: K, g: '#3ddc97', w: '#f4f1de' } },
    ally:   { map: ['.kk...kk.', 'kssk.kssk', '.kk...kk.', '.........', 'kbbbkpppk', 'kbbbkpppk', 'kkkkkkkkk'], pal: { k: K, s: '#f1c27d', b: '#4ea8de', p: '#e4572e' } },
    coin:   { map: ['..kkkk..', '.kyyyyk.', 'kywyyoyk', 'kywyyoyk', 'kyyyyoyk', '.kyooyk.', '..kkkk..'], pal: { k: K, y: '#f2c14e', w: '#fff4c2', o: '#a8741c' } },
    scroll: { map: ['.kkkkkkk', 'kyyyyyyk', '.kwwwwk.', '.kwkkwk.', '.kwwwwk.', '.kwkkwk.', 'kyyyyyyk', 'kkkkkkk.'], pal: { k: K, y: '#c58b3a', w: '#f6f2e0' } },
    demon:  { map: ['k......k', 'kk....kk', '.krrrrk.', 'krwrrwrk', 'krrrrrrk', 'kryyyyrk', '.krrrrk.', '..kkkk..'], pal: { k: K, r: '#d04a5a', w: '#fff', y: '#ffcf4a' } },
    castle: { map: ['g.g..g.g', 'gggggggg', 'gGggggGg', 'ggg..ggg', 'gg.kk.gg', 'gg.kk.gg', 'gggggggg'], pal: { g: '#b9bde6', G: '#7d83c0', k: K } },
    trophy: { map: ['yyyyyyyy', '.ywyyyy.', '.ywyyyy.', '..yyyy..', '...yy...', '...yy...', '..oooo..'], pal: { y: '#ffcf4a', w: '#fff4c2', o: '#b07a12' } },
    skull:  { map: ['.wwwwww.', 'wwwwwwww', 'wkkwwkkw', 'wkkwwkkw', 'wwwkkwww', '.wwwwww.', '.w.ww.w.'], pal: { w: '#f6f2e0', k: K } },
    hourglass: { map: ['oooooooo', '.wyyyyw.', '..wyyw..', '...ww...', '..w..w..', '.wyyyyw.', 'oooooooo'], pal: { o: '#c58b3a', y: '#ffcf4a', w: '#cfe3ff' } },
    gear:   { map: ['....gg....', '.g.gggg.g.', '..gggggg..', '.gggkkggg.', 'gggk..kggg', 'gggk..kggg', '.gggkkggg.', '..gggggg..', '.g.gggg.g.', '....gg....'], pal: { g: '#d9d2b8', k: '#7d83c0' } },
    none:   { map: ['kkkkkkkk', 'kwwwwwwk', 'kwkkkkwk', 'kwwwwwwk', 'kwkkkwwk', 'kwwwwwwk', 'kkkkkkkk'], pal: { k: K, w: '#a9a5c9' } }
  };
  function icon(name, px = 2) {
    const ic = ICONS[name] || ICONS.none;
    return `<span class="ico">${sprite(ic.map, ic.pal, px)}</span>`;
  }

  // ============ 像素下拉框 ============
  const PICKER_OPTIONS = {
    get cat() { return CATEGORY_KEYS.map((k) => ({ value: k, label: catLabel(k), icon: CATEGORIES[k].icon || 'none' })); },
    get round() { return BOSS_ROUNDS.map((r) => ({ value: r, label: t('round.' + r) })); }
  };
  const optHtml = (o) => `${o.icon ? icon(o.icon) : ''}<span>${esc(o.label)}</span>`;
  function picker(name, value, extra = '', cls = '') {
    const opts = PICKER_OPTIONS[name];
    const cur = opts.find((o) => o.value === value) || opts[0];
    return `<div class="picker ${cls}" data-picker="${name}" data-value="${esc(cur.value)}" ${extra}>
      <button type="button" class="picker-btn" data-act="picker-open" aria-haspopup="listbox" aria-expanded="false">${optHtml(cur)}<span class="caret">▼</span></button>
      <ul class="picker-menu" role="listbox" hidden>${opts.map((o) =>
        `<li><button type="button" role="option" data-act="picker-pick" data-value="${esc(o.value)}" aria-selected="${o.value === cur.value}">${optHtml(o)}</button></li>`).join('')}</ul>
    </div>`;
  }
  function setPicker(el, value) {
    const o = PICKER_OPTIONS[el.dataset.picker].find((x) => x.value === value);
    if (!o) return;
    el.dataset.value = value;
    el.querySelector('.picker-btn').innerHTML = optHtml(o) + '<span class="caret">▼</span>';
    el.querySelectorAll('[role=option]').forEach((b) => b.setAttribute('aria-selected', b.dataset.value === value));
  }
  function closePickers(except) {
    document.querySelectorAll('.picker.open').forEach((p) => {
      if (p === except) return;
      p.classList.remove('open');
      p.querySelector('.picker-menu').hidden = true;
      p.querySelector('.picker-btn').setAttribute('aria-expanded', 'false');
    });
  }
  function openPicker(p) {
    closePickers(p);
    const menu = p.querySelector('.picker-menu');
    const open = menu.hidden;
    p.classList.toggle('open', open);
    menu.hidden = !open;
    p.querySelector('.picker-btn').setAttribute('aria-expanded', String(open));
    if (open) {
      // 底部空间不够就向上展开
      const r = p.getBoundingClientRect();
      p.classList.toggle('up', window.innerHeight - r.bottom < menu.offsetHeight + 12 && r.top > menu.offsetHeight);
      (menu.querySelector('[aria-selected=true]') || menu.querySelector('button')).focus();
    }
  }

  function shade(hex, f) {
    const n = parseInt(hex.slice(1), 16);
    const ch = (v) => Math.max(0, Math.min(255, Math.round(v * f)));
    return '#' + [n >> 16, (n >> 8) & 255, n & 255].map((v) => ch(v).toString(16).padStart(2, '0')).join('');
  }
  // outline: 自动给精灵描一圈黑边
  function sprite(map, palette, size, outline) {
    if (outline) {
      const W = Math.max(...map.map((r) => r.length));
      const grid = ['.'.repeat(W + 2), ...map.map((r) => '.' + r.padEnd(W, '.') + '.'), '.'.repeat(W + 2)];
      const filled = (x, y) => grid[y] && palette[grid[y][x]];
      map = grid.map((row, y) => [...row].map((ch, x) =>
        !palette[ch] && (filled(x - 1, y) || filled(x + 1, y) || filled(x, y - 1) || filled(x, y + 1)) ? '§' : ch).join(''));
      palette = Object.assign({}, palette, { '§': outline });
    }
    const h = map.length, w = Math.max(...map.map((r) => r.length));
    let rects = '';
    map.forEach((row, y) => [...row].forEach((ch, x) => {
      const c = palette[ch];
      if (c) rects += `<rect x="${x}" y="${y}" width="1.02" height="1.02" fill="${c}"/>`;
    }));
    return `<svg viewBox="0 0 ${w} ${h}" width="${w * size}" height="${h * size}" shape-rendering="crispEdges" aria-hidden="true">${rects}</svg>`;
  }
  function heroSprite(st) {
    const weapon = tier(WEAPONS, st.atk), armor = tier(ARMORS, st.def);
    return sprite(HERO, {
      h: '#3b2a1a', s: '#f1c27d', e: '#1b1a2b', m: '#c0392b',
      a: armor[2], A: shade(armor[2], 0.72), y: '#f2c14e', p: '#2c3e70', b: '#3b2a1a', H: '#6b4a2b',
      w: weapon[2], g: weapon[2] ? '#8d6e63' : null
    }, 8, '#0c0b16');
  }
  function bossSprite(result) {
    const body = result === 'pass' ? '#6b6b7b' : result === 'fail' ? '#b23a48' : '#8e44ad';
    return sprite(BOSS, { r: body, w: '#fff', k: '#111', y: '#f2c14e' }, 4, '#0c0b16');
  }

  // ============ 渲染 ============
  let lastLevel = null;

  function renderHero(st) {
    const weapon = tier(WEAPONS, st.atk), armor = tier(ARMORS, st.def);
    $('#hero').innerHTML = `
      <div class="hero-top">
        <div class="avatar">${heroSprite(st)}</div>
        <div>
          <div class="lv">Lv.${st.lv}</div>
          <div class="title">${titleName(st.lv)}</div>
        </div>
      </div>
      <div class="bar-label"><span>EXP</span><span>${st.cur} / ${st.need}</span></div>
      <div class="bar"><i style="width:${(st.cur / st.need * 100).toFixed(1)}%"></i></div>
      <ul class="stats">
        <li><b style="color:${CATEGORIES.project.color}">${icon('sword')}${t('stat.atk')}</b><span>${st.atk}</span></li>
        <li><b style="color:${CATEGORIES.resume.color}">${icon('shield')}${t('stat.def')}</b><span>${st.def}</span></li>
        <li><b style="color:${CATEGORIES.prep.color}">${icon('book')}${t('stat.int')}</b><span>${st.int}</span></li>
        <li><b style="color:${CATEGORIES.network.color}">${icon('heart')}${t('stat.cha')}</b><span>${st.cha}</span></li>
        <li><b>${icon('ally')}${t('stat.ally')}</b><span>${st.ally}</span></li>
        <li><b style="color:var(--gold)">${icon('coin')}${t('stat.gold')}</b><span>${st.gold}</span></li>
      </ul>
      <div class="equip">
        <div><small>${t('hero.weapon')}</small>${t('weapons')[weapon[1]]}</div>
        <div><small>${t('hero.armor')}</small>${t('armors')[armor[1]]}</div>
      </div>
      <div class="equip">
        <div><small>${t('hero.boss')}</small>${t('hero.bossVal', { w: st.wins, n: st.bosses })}</div>
        <div><small>${t('hero.bonus')}</small>+${intBonus(st.int)} EXP</div>
      </div>`;
  }


  function taskRow(task, today) {
    const c = CATEGORIES[task.category] || CATEGORIES.none;
    const done = !!task.doneDate;
    const late = !done ? daysBetween(task.createdDate, today) : 0;
    return `<li class="task ${done ? 'done' : ''}" data-id="${task.id}" style="--c:${c.color}">
      <button class="chk" data-act="toggle" aria-label="${done ? t('task.undo') : t('task.complete')}">${done ? '✔' : ''}</button>
      <div class="task-main">
        <div class="task-title">${esc(task.title)}</div>
        <div class="task-meta">
          ${picker('cat', CATEGORIES[task.category] ? task.category : 'none', '', 'tag')}
          ${late > 0 ? `<span class="late">${t('task.late', { n: late })}</span>` : ''}
          <span class="reward">${rewardText(c.reward) || `<i>${t('task.noReward')}</i>`}</span>
        </div>
      </div>
      <button class="del" data-act="del" aria-label="${t('task.del')}">✕</button>
    </li>`;
  }

  function renderToday() {
    const today = ymd();
    $('#today-date').textContent = prettyDate(today);
    const pending = state.tasks.filter((t) => !t.doneDate)
      .sort((a, b) => a.createdDate.localeCompare(b.createdDate) || a.createdAt - b.createdAt);
    const doneToday = state.tasks.filter((t) => t.doneDate === today)
      .sort((a, b) => (b.doneAt || 0) - (a.doneAt || 0));
    $('#pending-list').innerHTML = pending.length
      ? pending.map((t) => taskRow(t, today)).join('')
      : `<li class="empty">${t('today.empty')}</li>`;
    $('#done-count').textContent = doneToday.length;
    $('#done-list').innerHTML = doneToday.map((t) => taskRow(t, today)).join('') ||
      `<li class="empty">${t('today.doneEmpty')}</li>`;
    const gained = doneToday.reduce((s, t) => s + catExp(t), 0) +
      state.interviews.filter((iv) => iv.date === today).reduce((s, iv) => s + bossReward(iv).exp, 0);
    $('#today-exp').textContent = t('today.exp', { n: gained });
  }

  function renderHistory() {
    const done = state.tasks.filter((t) => t.doneDate);
    const counts = {};
    CATEGORY_KEYS.forEach((k) => (counts[k] = 0));
    done.forEach((t) => (counts[t.category] = (counts[t.category] || 0) + 1));
    $('#history-summary').innerHTML = CATEGORY_KEYS.map((k) =>
      `<div class="sum-cell" style="--c:${CATEGORIES[k].color}"><b>${counts[k]}</b><small>${icon(CATEGORIES[k].icon || 'none')}${catLabel(k)}</small></div>`).join('');

    const byDate = {};
    done.forEach((t) => (byDate[t.doneDate] = byDate[t.doneDate] || []).push(t));
    const dates = Object.keys(byDate).sort().reverse();
    const today = ymd();
    $('#history-list').innerHTML = dates.length ? dates.map((d, i) => {
      const list = byDate[d];
      const exp = list.reduce((s, t) => s + catExp(t), 0);
      return `<details class="day px" ${i === 0 ? 'open' : ''}>
        <summary>${t('log.day', { date: prettyDate(d), today: d === today ? t('log.today') : '', n: list.length, exp })}</summary>
        <ul class="tasks">${list.map((t) => taskRow(t, today)).join('')}</ul>
      </details>`;
    }).join('') : `<p class="empty">${t('log.empty')}</p>`;
  }

  function renderBoss() {
    const list = [...state.interviews].sort((a, b) => b.date.localeCompare(a.date) || b.createdAt - a.createdAt);
    $('#boss-list').innerHTML = list.length ? list.map((iv) => {
      const r = bossReward(iv);
      const status = iv.result === 'pass' ? `<span class="win">${t('boss.won')}</span>`
        : iv.result === 'fail' ? `<span class="lose">${t('boss.lost')}</span>`
        : `<span class="wait">${t('boss.wait')}</span>`;
      const actions = iv.result === 'pending'
        ? `<button data-act="boss-pass">${t('boss.pass')}</button><button data-act="boss-fail">${t('boss.fail')}</button>` : '';
      return `<li class="boss px ${iv.result}" data-id="${iv.id}">
        <div class="boss-sprite">${bossSprite(iv.result)}</div>
        <div class="boss-main">
          <div class="boss-name">${esc(iv.company)} <small>· ${esc(roundLabel(iv.round))}</small></div>
          <div class="boss-meta">${prettyDate(iv.date)} · ${status}</div>
          ${iv.note ? `<div class="boss-note">${esc(iv.note)}</div>` : ''}
          <div class="boss-meta">${iv.result === 'pending'
            ? t('boss.settle', { p: BOSS_REWARD.pass.exp + (iv.bonus || 0), g: BOSS_REWARD.pass.gold, f: BOSS_REWARD.fail.exp + (iv.bonus || 0) })
            : t('boss.reward', { r: rewardText(r) }) + (iv.bonus ? t('boss.bonus', { n: iv.bonus }) : '')}</div>
          <div class="boss-actions">${actions}<button class="del" data-act="boss-del">${t('task.del')}</button></div>
        </div>
      </li>`;
    }).join('') : `<li class="empty">${t('boss.empty')}</li>`;
  }

  function renderAll() {
    const st = computeStats();
    renderHero(st);
    renderToday();
    renderHistory();
    renderBoss();
    return st;
  }

  // ============ 动效 ============
  function floatText(anchor, text, color) {
    if (!text) return;
    const r = anchor.getBoundingClientRect();
    const el = document.createElement('div');
    el.className = 'float';
    el.textContent = text;
    el.style.left = (r.left + r.width / 2) + 'px';
    el.style.top = (r.top + window.scrollY) + 'px';
    if (color) el.style.color = color;
    document.body.appendChild(el);
    setTimeout(() => el.remove(), 1200);
  }
  function levelUp(st) {
    const el = $('#levelup');
    el.innerHTML = `<div>LEVEL UP!</div><small>Lv.${st.lv} · ${titleName(st.lv)}</small>`;
    el.classList.remove('show'); void el.offsetWidth; el.classList.add('show');
  }
  function commit(anchor, text, color) {
    save();
    const st = renderAll();
    if (anchor) floatText(anchor, text, color);
    if (lastLevel !== null && st.lv > lastLevel) levelUp(st);
    lastLevel = st.lv;
  }

  // ============ 事件 ============
  const form = $('#add-form'), input = $('#add-input'), hint = $('#add-hint');
  $('#add-cat-slot').outerHTML = picker('cat', 'none', 'id="add-cat"');
  let sel = $('#add-cat');
  let suggestTimer = null, suggestion = null;
  function showHint() {
    const k = sel.dataset.value;
    const sug = suggestion && suggestion !== k && CATEGORIES[suggestion]
      ? `<button type="button" class="chip" data-act="use-suggest">${icon(CATEGORIES[suggestion].icon)}${esc(t('add.suggest', { c: catLabel(suggestion) }))}</button>` : '';
    const desc = k === 'none' ? '' : `<span>${esc(t('add.hint', { label: catLabel(k), desc: t('desc.' + k), reward: rewardText(CATEGORIES[k].reward) }))}</span>`;
    hint.innerHTML = desc + sug;
  }
  input.addEventListener('input', () => {
    clearTimeout(suggestTimer);
    suggestTimer = setTimeout(async () => {
      suggestion = null;
      if (window.HirelootCategorizer && input.value.trim()) {
        try { suggestion = await window.HirelootCategorizer.suggest(input.value); } catch (e) { console.warn('分类器出错：', e); }
      }
      showHint();
    }, 250);
  });
  form.addEventListener('submit', (e) => {
    e.preventDefault();
    const title = input.value.trim();
    if (!title) return;
    state.tasks.push({ id: uid(), title, category: sel.dataset.value, createdDate: ymd(), createdAt: Date.now(), doneDate: null, doneAt: null });
    input.value = ''; suggestion = null; setPicker(sel, 'none'); showHint();
    commit();
    input.focus();
  });

  document.addEventListener('click', (e) => {
    const btn = e.target.closest('[data-act]');
    if (!e.target.closest('.picker')) closePickers();
    if (!btn) return;
    const act = btn.dataset.act;
    const li = btn.closest('[data-id]');
    const id = li && li.dataset.id;

    if (act === 'picker-open') { openPicker(btn.closest('.picker')); return; }
    if (act === 'picker-pick') {
      const p = btn.closest('.picker');
      const v = btn.dataset.value;
      closePickers();
      p.querySelector('.picker-btn').focus();
      if (p.dataset.value === v) return;
      if (p.id === 'add-cat') { setPicker(p, v); showHint(); }
      else if (p.dataset.picker === 'cat' && li) {
        const task = state.tasks.find((x) => x.id === id);
        if (task) { task.category = v; commit(); }
      } else setPicker(p, v);
      return;
    }
    if (act === 'use-suggest') { setPicker(sel, suggestion); showHint(); input.focus(); return; }

    if (act === 'toggle') {
      const task = state.tasks.find((x) => x.id === id);
      if (!task) return;
      const c = CATEGORIES[task.category] || CATEGORIES.none;
      if (task.doneDate) { task.doneDate = null; task.doneAt = null; commit(); }
      else { task.doneDate = ymd(); task.doneAt = Date.now(); commit(btn, rewardText(c.reward), c.color); }
    } else if (act === 'del') {
      const task = state.tasks.find((x) => x.id === id);
      if (task && confirm(t('task.delConfirm', { t: task.title }) + (task.doneDate ? t('task.delConfirmDone') : ''))) {
        state.tasks = state.tasks.filter((x) => x.id !== id); commit();
      }
    } else if (act === 'boss-pass' || act === 'boss-fail') {
      const iv = state.interviews.find((x) => x.id === id);
      if (!iv) return;
      iv.result = act === 'boss-pass' ? 'pass' : 'fail';
      commit(btn, rewardText(bossReward(iv)), iv.result === 'pass' ? '#f2c14e' : '#ff8a80');
    } else if (act === 'boss-del') {
      const iv = state.interviews.find((x) => x.id === id);
      if (iv && confirm(t('boss.delConfirm', { c: iv.company, r: roundLabel(iv.round) }))) {
        state.interviews = state.interviews.filter((x) => x.id !== id); commit();
      }
    } else if (act === 'tab') {
      document.querySelectorAll('.tab').forEach((b) => b.classList.toggle('active', b === btn));
      document.querySelectorAll('.view').forEach((v) => v.hidden = v.id !== btn.dataset.view);
      try { localStorage.setItem('hireloot.tab', btn.dataset.view); } catch (err) { /* ignore */ }
    } else if (act === 'export') {
      const blob = new Blob([JSON.stringify(state, null, 2)], { type: 'application/json' });
      const a = document.createElement('a');
      a.href = URL.createObjectURL(blob);
      a.download = `${t('export.name')}-${ymd()}.json`;
      a.click();
      setTimeout(() => URL.revokeObjectURL(a.href), 1000);
    } else if (act === 'import') {
      $('#import-file').click();
    } else if (act === 'settings') {
      openSettings();
    } else if (act === 'settings-close') {
      closeSettings();
    } else if (act === 'lang') {
      setLang(btn.dataset.lang);
    }
  });

  // 下拉框键盘操作
  document.addEventListener('keydown', (e) => {
    const p = e.target.closest && e.target.closest('.picker');
    if (e.key === 'Escape' && !$('#settings').hidden && !document.querySelector('.picker.open')) { closeSettings(); return; }
    if (e.key === 'Escape') { const o = document.querySelector('.picker.open'); closePickers(); if (o) o.querySelector('.picker-btn').focus(); return; }
    if (!p || !p.classList.contains('open')) return;
    if (e.key === 'ArrowDown' || e.key === 'ArrowUp') {
      e.preventDefault();
      const opts = [...p.querySelectorAll('[role=option]')];
      const i = opts.indexOf(document.activeElement);
      const n = e.key === 'ArrowDown' ? Math.min(opts.length - 1, i + 1) : Math.max(0, i - 1);
      opts[n].focus();
    } else if (e.key === 'Tab') closePickers();
  });

  $('#import-file').addEventListener('change', async (e) => {
    const f = e.target.files[0];
    e.target.value = '';
    if (!f) return;
    try {
      const s = JSON.parse(await f.text());
      if (!Array.isArray(s.tasks) || !Array.isArray(s.interviews)) throw new Error(t('import.bad'));
      if (confirm(t('import.confirm', { t: s.tasks.length, b: s.interviews.length }))) {
        state = s; lastLevel = null; commit(); closeSettings();
      }
    } catch (err) { alert(t('import.fail') + err.message); }
  });

  // Boss 表单
  const bossForm = $('#boss-form');
  $('#boss-round-slot').outerHTML = picker('round', 'r1', 'id="boss-round"');
  $('#boss-date').value = ymd();
  bossForm.addEventListener('submit', (e) => {
    e.preventDefault();
    const company = $('#boss-company').value.trim();
    if (!company) return;
    const result = bossForm.elements.result.value;
    const iv = {
      id: uid(), company, round: $('#boss-round').dataset.value, result,
      date: $('#boss-date').value || ymd(), note: $('#boss-note').value.trim(),
      bonus: intBonus(computeStats().int), createdAt: Date.now()
    };
    state.interviews.push(iv);
    $('#boss-company').value = ''; $('#boss-note').value = '';
    bossForm.querySelector('input[value=pending]').checked = true;
    const btn = bossForm.querySelector('button[type=submit]');
    commit(btn, result === 'pending' ? t('boss.engage') : rewardText(bossReward(iv)), result === 'pass' ? '#f2c14e' : '#ff8a80');
  });

  // ============ 设置 / 语言 ============
  const settings = $('#settings');
  let settingsReturn = null;
  function openSettings() {
    settingsReturn = document.activeElement;
    settings.hidden = false;
    renderSettings();
    (settings.querySelector('.lang-btn.active') || settings.querySelector('button')).focus();
  }
  function closeSettings() {
    settings.hidden = true;
    if (settingsReturn) settingsReturn.focus();
  }
  settings.addEventListener('click', (e) => { if (e.target === settings) closeSettings(); });
  function renderSettings() {
    settings.querySelectorAll('.lang-btn').forEach((b) => {
      const on = b.dataset.lang === lang;
      b.classList.toggle('active', on);
      b.setAttribute('aria-pressed', String(on));
    });
  }
  function applyStaticText() {
    document.documentElement.lang = lang === 'en' ? 'en' : 'zh-CN';
    document.title = t('doc.title');
    document.querySelectorAll('[data-i18n]').forEach((el) => { el.textContent = t(el.dataset.i18n); });
    document.querySelectorAll('[data-i18n-ph]').forEach((el) => { el.placeholder = t(el.dataset.i18nPh); });
    document.querySelectorAll('[data-i18n-aria]').forEach((el) => { el.setAttribute('aria-label', t(el.dataset.i18nAria)); });
  }
  function setLang(l) {
    if (!window.JQ_I18N[l] || l === lang) return;
    lang = l;
    try { localStorage.setItem(LANG_KEY, l); } catch (e) { /* ignore */ }
    applyStaticText();
    // 下拉框跟着换语言（保留当前选择）
    const addVal = $('#add-cat').dataset.value, roundVal = $('#boss-round').dataset.value;
    $('#add-cat').outerHTML = picker('cat', addVal, 'id="add-cat"');
    sel = $('#add-cat');
    $('#boss-round').outerHTML = picker('round', roundVal, 'id="boss-round"');
    showHint();
    renderAll();
    renderSettings();
  }

  // 跨过午夜自动刷新“今天”
  let currentDay = ymd();
  setInterval(() => { if (ymd() !== currentDay) { currentDay = ymd(); renderAll(); } }, 60000);

  // 初始化
  document.querySelectorAll('[data-icon]').forEach((el) => { el.outerHTML = icon(el.dataset.icon, +(el.dataset.px || 2)); });
  applyStaticText();
  showHint();
  lastLevel = renderAll().lv;
  try {
    const tab = localStorage.getItem('hireloot.tab');
    const b = tab && document.querySelector(`.tab[data-view="${tab}"]`);
    if (b) b.click();
  } catch (err) { /* ignore */ }

  // 暴露给分类器 / 调试用
  window.Hireloot = { CATEGORIES, CATEGORY_KEYS, EFFORT_KEYS, computeStats, getState: () => state, setLang };
})();
