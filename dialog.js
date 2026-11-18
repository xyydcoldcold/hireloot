/* Hireloot 像素风确认 / 提示弹窗，替代浏览器自带的 confirm() / alert()
 *
 *   HirelootDialog.confirm({ title, body, note, ok, cancel, danger }) → Promise<boolean>
 *   HirelootDialog.alert({ title, body, ok })                         → Promise<void>
 *
 * 文字由调用方传进来（已经按当前语言翻译好）。
 * 键盘：Enter 确认，Esc 取消，Tab 在按钮间切换。点遮罩 = 取消。
 */
window.HirelootDialog = (function () {
  'use strict';

  let el = null, resolveFn = null, returnFocus = null, isConfirm = false;

  const esc = (s) => String(s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

  function build() {
    el = document.createElement('div');
    el.className = 'modal dlg-modal';
    el.hidden = true;
    el.innerHTML = '<div class="px modal-win dlg-win" role="alertdialog" aria-modal="true" aria-labelledby="dlg-title" aria-describedby="dlg-body"></div>';
    document.body.appendChild(el);
    el.addEventListener('click', (e) => {
      e.stopPropagation();
      if (e.target === el) return close(false);
      const b = e.target.closest('[data-dlg]');
      if (b) close(b.dataset.dlg === 'ok');
    });
    // 用 window 的捕获阶段，抢在设置 / 登录弹窗的 Esc 处理之前
    window.addEventListener('keydown', (e) => {
      if (!el || el.hidden) return;
      if (e.key === 'Escape') { e.preventDefault(); e.stopPropagation(); close(false); }
      else if (e.key === 'Enter') {
        // 焦点在哪个按钮就按哪个，默认是确认
        e.preventDefault(); e.stopPropagation();
        const f = document.activeElement && document.activeElement.dataset && document.activeElement.dataset.dlg;
        close(f ? f === 'ok' : true);
      }
      else if (e.key === 'Tab') {
        const btns = [...el.querySelectorAll('button')];
        const i = btns.indexOf(document.activeElement);
        e.preventDefault();
        btns[(i + (e.shiftKey ? -1 : 1) + btns.length) % btns.length].focus();
      }
    }, true);
  }

  function open(opts, confirmMode) {
    if (!el) build();
    if (resolveFn) close(false); // 已经有一个开着：先当取消处理
    isConfirm = confirmMode;
    returnFocus = document.activeElement;
    const o = opts || {};
    el.querySelector('.dlg-win').innerHTML = `
      <div class="panel-head"><h2 id="dlg-title">${esc(o.title || '')}</h2></div>
      ${o.body ? `<p id="dlg-body" class="dlg-body">${esc(o.body)}</p>` : '<p id="dlg-body" hidden></p>'}
      ${o.note ? `<p class="dlg-note">${esc(o.note)}</p>` : ''}
      <div class="dlg-btns">
        ${confirmMode ? `<button type="button" data-dlg="cancel">${esc(o.cancel || 'Cancel')}</button>` : ''}
        <button type="button" data-dlg="ok" class="${o.danger ? 'danger' : 'primary'}">${esc(o.ok || 'OK')}</button>
      </div>`;
    el.hidden = false;
    el.querySelector('[data-dlg=ok]').focus();
    return new Promise((res) => { resolveFn = res; });
  }

  function close(ok) {
    if (!el || el.hidden) return;
    el.hidden = true;
    const r = resolveFn;
    resolveFn = null;
    if (returnFocus && returnFocus.isConnected) returnFocus.focus();
    if (r) r(isConfirm ? !!ok : undefined);
  }

  return {
    confirm: (opts) => open(opts, true),
    alert: (opts) => open(opts, false),
    isOpen: () => !!el && !el.hidden
  };
})();
