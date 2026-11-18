/* Hireloot 云存档 —— 邮箱密码登录（Supabase Auth）+ 每人一份 JSON 存档
 *
 * config.js 里没填 Supabase 配置时，这个文件什么都不做，游戏是纯本地模式。
 *
 * 数据流：
 *   - 本地 localStorage 永远是“当前存档”，断网也能玩
 *   - 登录后每次保存都会排队上传（1.5 秒防抖），失败了联网后自动重试
 *   - 云端每次保存 rev +1；上传时带上本机最后一次同步的 rev，
 *     对不上说明别的设备改过 → 弹窗让玩家选保留哪一份，绝不偷偷覆盖
 *   - 游客（没登录）玩出来的存档，第一次登录时自动搬进账号
 */
(function () {
  'use strict';

  const cfg = window.HIRELOOT_CONFIG || {};
  const enabled = !!(cfg.supabaseUrl && cfg.supabaseAnonKey);
  const META_KEY = 'hireloot.cloud'; // { uid, rev, dirty }：本机缓存属于谁、对应云端第几版、有没有没传上去的改动
  const GUEST_KEY = 'hireloot.guest'; // 选过“游客试玩”就不再自动弹登录框
  const TABLE = 'saves';
  const LIB_SRC = 'vendor/supabase-js-2.119.0.min.js';

  let H = null;          // window.Hireloot
  let sb = null;         // Supabase client
  let user = null;       // 当前登录用户
  let status = 'idle';   // idle | syncing | synced | offline | error
  let pushTimer = null, pushing = false, saveSeq = 0, pulling = null;
  let mode = 'login';    // 弹窗模式：login | signup | forgot | recover | conflict
  let conflict = null;   // { cloud: {data, rev} }
  let modalReturn = null;
  let greet = null;      // 'new' 新注册 | 'back' 老用户登录：同步完后打招呼

  const $ = (sel, root = document) => root.querySelector(sel);
  const t = (k, v) => H.t(k, v);
  const ls = {
    get(k) { try { return localStorage.getItem(k); } catch (e) { return null; } },
    set(k, v) { try { localStorage.setItem(k, v); } catch (e) { /* ignore */ } },
    del(k) { try { localStorage.removeItem(k); } catch (e) { /* ignore */ } }
  };
  function readMeta() {
    try { const m = JSON.parse(ls.get(META_KEY)); if (m && typeof m === 'object') return { uid: m.uid || null, rev: +m.rev || 0, dirty: !!m.dirty }; } catch (e) { /* ignore */ }
    return { uid: null, rev: 0, dirty: false };
  }
  function writeMeta(m) { ls.set(META_KEY, JSON.stringify(m)); }

  // ============ 同步 ============
  function setStatus(s) { status = s; renderAccount(); }

  function onSave() {
    if (!enabled || !user) return;
    saveSeq++;
    const m = readMeta();
    if (m.uid === user.id && !m.dirty) writeMeta({ ...m, dirty: true });
    clearTimeout(pushTimer);
    pushTimer = setTimeout(push, 1500);
  }

  async function push() {
    if (!user || pushing) return;
    const m = readMeta();
    if (m.uid !== user.id || !m.dirty) return;
    if (!navigator.onLine) { setStatus('offline'); return; }
    pushing = true;
    setStatus('syncing');
    const seq = saveSeq;
    const data = H.getState();
    try {
      let res;
      if (!m.rev) {
        res = await sb.from(TABLE).insert({ user_id: user.id, data, rev: 1 }).select('rev');
        if (res.error && res.error.code === '23505') res = { data: [] }; // 云端已经有了 → 当冲突处理
      } else {
        res = await sb.from(TABLE).update({ data, rev: m.rev + 1 }).eq('user_id', user.id).eq('rev', m.rev).select('rev');
      }
      if (res.error) throw res.error;
      if (!res.data || !res.data.length) { pushing = false; await pull(); return; } // 别的设备先改了
      const cur = readMeta();
      if (cur.uid !== user.id) return; // 中途退出登录了
      writeMeta({ uid: user.id, rev: res.data[0].rev, dirty: saveSeq !== seq });
      pushing = false;
      if (saveSeq !== seq) push(); else setStatus('synced');
    } catch (err) {
      console.warn('[Hireloot cloud] push failed', err);
      pushing = false;
      setStatus(navigator.onLine ? 'error' : 'offline');
      clearTimeout(pushTimer);
      pushTimer = setTimeout(push, 30000); // 半分钟后再试
    } finally {
      pushing = false;
    }
  }

  const summary = (s) => ({ t: (s.tasks || []).length, b: (s.interviews || []).length });
  const sameSave = (a, b) => JSON.stringify(a) === JSON.stringify(b);

  // 拉云端存档，和本机对比
  function pull() {
    if (!pulling) pulling = doPull().finally(() => { pulling = null; maybeGreet(); });
    return pulling;
  }
  async function doPull() {
    if (!user) return;
    if (!navigator.onLine) { setStatus('offline'); return; }
    setStatus('syncing');
    const uid = user.id;
    const res = await sb.from(TABLE).select('data, rev').eq('user_id', uid).maybeSingle();
    if (!user || user.id !== uid) return;
    if (res.error) { console.warn('[Hireloot cloud] pull failed', res.error); setStatus('error'); return; }
    const row = res.data;
    const m = readMeta();
    const local = H.getState();

    if (m.uid && m.uid !== uid) {
      // 本机缓存是另一个账号的（比如登录过期没点退出），不能混进来
      if (row) adopt(row); else { H.replaceState(H.emptyState()); writeMeta({ uid, rev: 0, dirty: true }); push(); }
      return;
    }
    if (!row) {
      // 新账号：把本机存档（游客存档或空档）作为第一份云存档
      greet = 'new';
      writeMeta({ uid, rev: 0, dirty: true });
      return push();
    }
    if (m.uid === uid) {
      if (row.rev === m.rev) { if (m.dirty) return push(); return setStatus('synced'); }
      if (!m.dirty || sameSave(local, row.data)) return adopt(row);
      return askConflict(row); // 两边都改过
    }
    // 游客存档第一次遇到已有存档的账号
    if (H.isEmptyState() || sameSave(local, row.data)) return adopt(row);
    return askConflict(row);
  }

  function adopt(row) {
    H.replaceState(row.data);
    writeMeta({ uid: user.id, rev: row.rev, dirty: false });
    setStatus('synced');
  }

  function askConflict(row) {
    conflict = { cloud: row };
    setStatus('idle');
    openModal('conflict');
  }

  function resolveConflict(which) {
    const row = conflict && conflict.cloud;
    conflict = null;
    closeModal(true);
    if (!row || !user) return;
    if (which === 'cloud') adopt(row);
    else { writeMeta({ uid: user.id, rev: row.rev, dirty: true }); push(); }
    maybeGreet();
  }

  // ============ 登录状态 ============
  function signedIn(u) {
    const changed = !user || user.id !== u.id;
    user = u;
    ls.del(GUEST_KEY);
    renderAccount();
    if (mode !== 'recover' && mode !== 'conflict' && mode !== 'welcome') closeModal();
    if (changed) pull();
  }

  async function logout() {
    if (!user) return;
    clearTimeout(pushTimer);
    const m = readMeta();
    if (m.dirty && navigator.onLine) await push();
    if (readMeta().dirty && !(await window.HirelootDialog.confirm({
      title: t('cloud.logoutTitle'), body: t('cloud.logoutUnsynced'),
      ok: t('cloud.logout'), cancel: t('dlg.cancel'), danger: true
    }))) return;
    user = null;
    try { await sb.auth.signOut({ scope: 'local' }); } catch (e) { /* ignore */ }
    // 退出后清掉这台电脑上的存档缓存（数据还在云端）
    ls.del(META_KEY);
    H.replaceState(H.emptyState());
    setStatus('idle');
    $('#settings').hidden = true;
    openModal('login');
  }

  // ============ 界面 ============
  const errText = (err) => {
    const msg = (err && (err.message || err.error_description)) || String(err);
    const code = err && err.code;
    if (code === 'invalid_credentials' || /invalid login credentials/i.test(msg)) return t('cloud.err.cred');
    if (code === 'email_not_confirmed' || /email not confirmed/i.test(msg)) return t('cloud.err.unconfirmed');
    if (code === 'user_already_exists' || /already registered/i.test(msg)) return t('cloud.err.exists');
    if (code === 'weak_password' || /password should/i.test(msg)) return t('cloud.err.weak');
    if (/rate limit|too many|over_.*_rate_limit/i.test(msg + ' ' + code)) return t('cloud.err.rate');
    if (/fetch|network/i.test(msg)) return t('cloud.err.network');
    return msg;
  };
  const here = () => location.origin + location.pathname;

  function modalHtml() {
    const esc = H.esc;
    const lang = H.getLang();
    const langSeg = `<div class="seg auth-lang">${[['zh', '中文'], ['en', 'EN']].map(([l, label]) =>
      `<button type="button" class="${l === lang ? 'active' : ''}" data-act="lang" data-lang="${l}" aria-pressed="${l === lang}">${label}</button>`).join('')}</div>`;
    const head = (title, closable = true) => `<div class="panel-head"><h2 id="auth-title">${esc(title)}</h2><div class="auth-head-r">${langSeg}${closable ? `<button class="del" data-act="auth-close" aria-label="${esc(t('settings.close'))}">✕</button>` : ''}</div></div>`;
    if (mode === 'conflict') {
      const c = summary(conflict.cloud.data), l = summary(H.getState());
      return `${head(t('cloud.conflict.title'), false)}
        <p class="auth-text">${esc(t('cloud.conflict.body'))}</p>
        <div class="conflict-opts">
          <button class="conflict-opt" data-act="conflict" data-which="cloud">${H.icon('cloud', 3)}<b>${esc(t('cloud.conflict.cloud'))}</b><small>${esc(t('cloud.conflict.count', c))}</small></button>
          <button class="conflict-opt" data-act="conflict" data-which="local">${H.icon('chest', 3)}<b>${esc(t('cloud.conflict.local'))}</b><small>${esc(t('cloud.conflict.count', l))}</small></button>
        </div>
        <p class="hint">${esc(t('cloud.conflict.hint'))}</p>`;
    }
    if (mode === 'welcome') {
      return `${head(t('cloud.welcome.title'), false)}
        <p class="auth-text">${esc(t('cloud.welcome.body'))}</p>
        <form class="auth-form" data-form="welcome" autocomplete="off">
          <label><span>${esc(t('cloud.welcome.name'))}</span><input name="name" maxlength="${H.NAME_MAX}" value="${esc(H.getName())}" placeholder="${esc(t('hero.namePh'))}" spellcheck="false"></label>
          <button type="submit" class="primary">${esc(t('cloud.welcome.go'))}</button>
          <button type="button" class="linkish" data-act="auth-close-force">${esc(t('cloud.welcome.later'))}</button>
        </form>`;
    }
    if (mode === 'recover') {
      return `${head(t('cloud.recover.title'), false)}
        <form class="auth-form" data-form="recover" autocomplete="on">
          <label><span>${esc(t('cloud.newPassword'))}</span><input name="password" type="password" autocomplete="new-password" minlength="6" required></label>
          <p class="auth-msg" role="status"></p>
          <button type="submit" class="primary">${esc(t('cloud.recover.submit'))}</button>
        </form>`;
    }
    const tabs = mode === 'forgot' ? '' : `<div class="seg auth-tabs">
        <button type="button" class="${mode === 'login' ? 'active' : ''}" data-act="auth-mode" data-mode="login" aria-pressed="${mode === 'login'}">${esc(t('cloud.login'))}</button>
        <button type="button" class="${mode === 'signup' ? 'active' : ''}" data-act="auth-mode" data-mode="signup" aria-pressed="${mode === 'signup'}">${esc(t('cloud.signup'))}</button>
      </div>`;
    const pw = mode === 'forgot' ? '' : `<label><span>${esc(t('cloud.password'))}</span><input name="password" type="password" autocomplete="${mode === 'signup' ? 'new-password' : 'current-password'}" minlength="6" required></label>`;
    const submit = { login: 'cloud.login.submit', signup: 'cloud.signup.submit', forgot: 'cloud.forgot.submit' }[mode];
    const links = mode === 'forgot'
      ? `<button type="button" class="linkish" data-act="auth-mode" data-mode="login">${esc(t('cloud.back'))}</button>`
      : (mode === 'login' ? `<button type="button" class="linkish" data-act="auth-mode" data-mode="forgot">${esc(t('cloud.forgot'))}</button>` : '');
    const guest = user ? '' : `<div class="auth-guest"><button type="button" data-act="auth-guest">${esc(t('cloud.guest'))}</button><p class="hint">${esc(t('cloud.guestHint'))}</p></div>`;
    return `${head(mode === 'forgot' ? t('cloud.forgot.title') : t('cloud.title'))}
      ${tabs}
      ${mode === 'forgot' ? `<p class="auth-text">${esc(t('cloud.forgot.body'))}</p>` : ''}
      <form class="auth-form" data-form="${mode}" autocomplete="on">
        <label><span>${esc(t('cloud.email'))}</span><input name="email" type="email" autocomplete="email" required maxlength="254" value="${esc(lastEmail)}"></label>
        ${pw}
        <p class="auth-msg" role="status"></p>
        <button type="submit" class="primary">${esc(t(submit))}</button>
        ${links}
      </form>
      ${guest}`;
  }
  let lastEmail = '';

  function modal() { return $('#auth'); }
  function openModal(m) {
    if (m) mode = m;
    const el = modal();
    if (el.hidden) modalReturn = document.activeElement;
    el.querySelector('.modal-win').innerHTML = modalHtml();
    el.hidden = false;
    const f = el.querySelector('input:not([value]), input[value=""], input') || el.querySelector('button');
    if (f) f.focus();
  }
  function closeModal(force) {
    const el = modal();
    if (el.hidden) return;
    if (!force && (mode === 'conflict' || mode === 'recover')) return;
    el.hidden = true;
    mode = 'login';
    if (modalReturn && modalReturn.isConnected) modalReturn.focus();
  }
  function say(form, text, ok) {
    const p = form.querySelector('.auth-msg');
    p.textContent = text || '';
    p.classList.toggle('ok', !!ok);
  }

  async function submit(form) {
    const kind = form.dataset.form;
    if (kind === 'welcome') { H.setName(form.elements.name.value); closeModal(true); return; }
    const email = form.email ? form.email.value.trim() : '';
    const password = form.password ? form.password.value : '';
    if (email) lastEmail = email;
    if (form.password && password.length < 6) return say(form, t('cloud.err.weak'));
    const btn = form.querySelector('button[type=submit]');
    btn.disabled = true;
    say(form, t('cloud.wait'), true);
    try {
      if (kind === 'login') {
        const { data, error } = await sb.auth.signInWithPassword({ email, password });
        if (error) throw error;
        greet = 'back';
        if (data.user) signedIn(data.user);
      } else if (kind === 'signup') {
        const { data, error } = await sb.auth.signUp({ email, password, options: { emailRedirectTo: here() } });
        if (error) throw error;
        // 开了邮箱验证时，已注册的邮箱会返回一个没有 identities 的假用户
        if (data.user && Array.isArray(data.user.identities) && !data.user.identities.length) throw { code: 'user_already_exists' };
        if (data.session) signedIn(data.user);
        else say(form, t('cloud.signup.check', { e: email }), true);
      } else if (kind === 'forgot') {
        const { error } = await sb.auth.resetPasswordForEmail(email, { redirectTo: here() });
        if (error) throw error;
        say(form, t('cloud.forgot.sent', { e: email }), true);
      } else if (kind === 'recover') {
        const { error } = await sb.auth.updateUser({ password });
        if (error) throw error;
        mode = 'login';
        closeModal(true);
        window.HirelootDialog.alert({ title: t('cloud.recover.done'), ok: t('dlg.ok') });
      }
    } catch (err) {
      console.warn('[Hireloot cloud]', err);
      say(form, errText(err));
    } finally {
      if (btn.isConnected) btn.disabled = false;
    }
  }

  // 打招呼：新注册弹欢迎窗口（顺便起名），老用户登录弹一条“欢迎回来”
  function maybeGreet() {
    if (!greet || !user) return;
    const el = modal();
    if (el && !el.hidden && (mode === 'conflict' || mode === 'recover')) return; // 先处理完冲突再说
    const g = greet;
    greet = null;
    if (g === 'new') { openModal('welcome'); return; }
    const st = H.computeStats();
    const name = H.getName() || t('hero.noName');
    let toast = $('#welcome-toast');
    if (!toast) {
      toast = document.createElement('div');
      toast.id = 'welcome-toast';
      toast.className = 'welcome-toast';
      toast.setAttribute('role', 'status');
      document.body.appendChild(toast);
    }
    toast.innerHTML = `<b>${H.esc(t('cloud.back.title', { n: name }))}</b><small>Lv.${st.lv} · ${H.esc(H.titleName(st.lv))}</small>`;
    toast.classList.remove('show');
    void toast.offsetWidth;
    toast.classList.add('show');
  }

  // 设置里的“账号”一行
  function renderAccount() {
    const row = $('#account-row');
    if (!row) return;
    const esc = H.esc;
    if (!user) {
      row.innerHTML = `<div class="set-label">${esc(t('cloud.account'))}<small>${esc(t('cloud.guestNow'))}</small></div>
        <div class="seg"><button data-act="auth-open">${esc(t('cloud.loginSignup'))}</button></div>`;
    } else {
      row.innerHTML = `<div class="set-label">${esc(t('cloud.account'))}<small class="acct-email">${esc(user.email || '')}</small>
        <small class="sync sync-${status}">${H.icon('cloud', 2)}${esc(t('cloud.status.' + status))}</small></div>
        <div class="seg"><button data-act="auth-logout">${esc(t('cloud.logout'))}</button></div>`;
    }
  }

  function loadLib() {
    if (window.supabase && window.supabase.createClient) return Promise.resolve();
    return new Promise((ok, fail) => {
      const s = document.createElement('script');
      s.src = LIB_SRC;
      s.onload = ok; s.onerror = fail;
      document.head.appendChild(s);
    });
  }

  async function init(api) {
    H = api;
    if (!enabled) return;
    // 设置面板里插一行“账号”
    const dataRow = $('#settings [data-act="export"]').closest('.set-row');
    const row = document.createElement('div');
    row.className = 'set-row';
    row.id = 'account-row';
    dataRow.parentNode.insertBefore(row, dataRow);
    // 登录弹窗
    const m = document.createElement('div');
    m.id = 'auth';
    m.className = 'modal auth-modal';
    m.hidden = true;
    m.innerHTML = '<div class="px modal-win" role="dialog" aria-modal="true" aria-labelledby="auth-title"></div>';
    document.body.appendChild(m);
    renderAccount();

    m.addEventListener('click', (e) => { if (e.target === m) closeModal(); });
    m.addEventListener('submit', (e) => { e.preventDefault(); submit(e.target); });
    document.addEventListener('keydown', (e) => { if (e.key === 'Escape' && !m.hidden) { e.stopPropagation(); closeModal(); } }, true);
    document.addEventListener('click', (e) => {
      const btn = e.target.closest('[data-act]');
      if (!btn) return;
      const act = btn.dataset.act;
      if (act === 'auth-open') { $('#settings').hidden = true; openModal('login'); }
      else if (act === 'auth-close') closeModal();
      else if (act === 'auth-close-force') closeModal(true);
      else if (act === 'auth-mode') { const f = modal().querySelector('input[name=email]'); if (f) lastEmail = f.value.trim(); openModal(btn.dataset.mode); }
      else if (act === 'auth-guest') { ls.set(GUEST_KEY, '1'); closeModal(); }
      else if (act === 'auth-logout') logout();
      else if (act === 'conflict') resolveConflict(btn.dataset.which);
    });

    try { await loadLib(); } catch (e) { console.warn('[Hireloot cloud] could not load supabase-js'); return; }
    sb = window.supabase.createClient(cfg.supabaseUrl, cfg.supabaseAnonKey, {
      auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true, storageKey: 'hireloot.auth' }
    });
    let first = true;
    sb.auth.onAuthStateChange((event, session) => {
      // 回调里不要直接 await Supabase 调用（官方建议），放到下一轮
      setTimeout(() => {
        if (event === 'PASSWORD_RECOVERY') { if (session) signedIn(session.user); openModal('recover'); return; }
        if (session && session.user) { if (event !== 'TOKEN_REFRESHED') signedIn(session.user); }
        else if (event === 'SIGNED_OUT' && user) { user = null; renderAccount(); }
        if (first) {
          first = false;
          if (!session && !ls.get(GUEST_KEY)) openModal('login');
        }
      }, 0);
    });

    window.addEventListener('online', () => { if (user) { if (readMeta().dirty) push(); else pull(); } });
    window.addEventListener('offline', () => { if (user) setStatus('offline'); });
    // 看看别的设备有没有改过：切回标签页、窗口重新获得焦点（并排开着的窗口不会触发 visibilitychange），
    // 以及页面开着时每 30 秒一次。正在打字或者弹窗开着时先不拉，免得打断
    let lastPull = 0;
    const freshPull = () => {
      if (!user || pushing || document.visibilityState !== 'visible') return;
      const a = document.activeElement;
      if (a && a.tagName === 'INPUT' && a.value) return;
      if (!$('#auth').hidden) return;
      if (Date.now() - lastPull < 5000) return;
      lastPull = Date.now();
      pull();
    };
    document.addEventListener('visibilitychange', () => {
      if (document.visibilityState === 'visible') freshPull();
      else if (user && readMeta().dirty) { clearTimeout(pushTimer); push(); }
    });
    window.addEventListener('focus', freshPull);
    setInterval(freshPull, 30000);
  }

  window.HirelootCloud = {
    init, onSave,
    enabled: () => enabled,
    rerender() {
      renderAccount();
      const el = $('#auth');
      if (!el || el.hidden) return;
      // 换语言时保留已经输入的内容
      const vals = {};
      el.querySelectorAll('input[name]').forEach((i) => { vals[i.name] = i.value; });
      if (vals.email !== undefined) lastEmail = vals.email.trim();
      el.querySelector('.modal-win').innerHTML = modalHtml();
      el.querySelectorAll('input[name]').forEach((i) => { if (vals[i.name] !== undefined) i.value = vals[i.name]; });
      const b = el.querySelector('.auth-lang .active');
      if (b) b.focus();
    }
  };
})();
