// Turns raw simulator screenshots into App Store marketing images (caption + framed screenshot).
//   node apple/tools/store-compose.js <raw dir> <out dir>
// Raw files: <device>-<lang>-<shot>.png (from store-shots.sh). Output: <out>/<lang>/<device>-<n>-<shot>.png
const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');

const [RAW, OUT] = process.argv.slice(2);
const ROOT = path.resolve(__dirname, '../..');
const FONT = 'data:font/woff2;base64,' + fs.readFileSync(path.join(ROOT, 'fonts/fusion-pixel-12px-sc.woff2')).toString('base64');

const SIZES = { iphone: [1320, 2868], ipad: [2064, 2752], mac: [2880, 1800] };
const SHOTS = ['today', 'boss', 'packs', 'card', 'armory', 'log'];
const TEXT = {
  en: {
    today: ['Every effort earns EXP', 'Turn your job-hunt to-dos into daily quests'],
    boss: ['Interviews are boss fights', 'Pass or fail, you still level up'],
    packs: ['Level up, open packs', '3 weapon packs every level'],
    card: ['Collect holo legendaries', '37 weapons, Common to Legendary'],
    armory: ['Build your armory', 'Equip your favorite weapon'],
    log: ["See how far you've come", 'Your adventure log, day by day']
  },
  zh: {
    today: ['每一份努力都有经验', '把求职待办变成每日任务'],
    boss: ['面试就是 Boss 战', '无论成败，都能升级'],
    packs: ['升级就能开卡包', '每升一级送 3 个武器卡包'],
    card: ['收集闪卡传说武器', '37 把武器，从普通到传说'],
    armory: ['打造你的武器库', '装备你最喜欢的武器'],
    log: ['回顾每一步成长', '冒险日志记录每一天']
  }
};

function html(device, title, sub, img) {
  const [W, H] = SIZES[device];
  if (device === 'mac') return macHtml(W, H, title, sub, img);
  const ipad = device === 'ipad';
  const big = ipad ? 120 : 96, small = ipad ? 60 : 48, top = ipad ? 150 : 170;
  const shotW = ipad ? 1560 : 1010;
  return `<!doctype html><html><head><style>
  @font-face { font-family: P; src: url(${FONT}) format('woff2'); }
  * { box-sizing: border-box; margin: 0; }
  html, body { width: ${W}px; height: ${H}px; overflow: hidden; }
  body {
    font-family: P, monospace; -webkit-font-smoothing: none; color: #f6f2e0;
    background:
      radial-gradient(circle at 4px 4px, rgba(255,255,255,.09) 4px, transparent 0) 0 0 / 96px 96px,
      radial-gradient(ellipse at 50% 0%, #3a2f8f 0%, transparent 55%),
      linear-gradient(180deg, #1a1840, #100f26 70%);
    display: flex; flex-direction: column; align-items: center;
  }
  h1 { margin-top: ${top}px; font-size: ${big}px; line-height: 1.2; color: #ffcf4a; font-weight: normal; text-align: center;
       text-shadow: 6px 6px 0 #b07a12, 12px 12px 0 #07061a; padding: 0 60px; }
  p { margin-top: 36px; font-size: ${small}px; color: #cfd3ff; text-align: center; text-shadow: 4px 4px 0 #07061a; padding: 0 60px; }
  .frame { margin-top: ${ipad ? 90 : 80}px; padding: 12px; background: #d9d2b8; box-shadow: 0 0 0 9px #07061a, 24px 24px 0 9px rgba(7,6,26,.6); }
  .frame img { display: block; width: ${shotW}px; border: 9px solid #07061a; image-rendering: auto; }
  .spark { position: absolute; width: 18px; height: 18px; background: #ffcf4a; box-shadow: 0 -18px 0 #ffcf4a, 0 18px 0 #ffcf4a, -18px 0 0 #ffcf4a, 18px 0 0 #ffcf4a; opacity: .85; }
  </style></head><body>
  <div class="spark" style="left:${ipad ? 160 : 110}px; top:${ipad ? 120 : 110}px"></div>
  <div class="spark" style="right:${ipad ? 180 : 120}px; top:${ipad ? 330 : 400}px; transform: scale(.7)"></div>
  <h1>${title}</h1><p>${sub}</p>
  <div class="frame"><img src="${img}"></div>
  </body></html>`;
}

// Mac: raw images are 1x window captures; drawn at exactly 2x with nearest-neighbour scaling.
function macHtml(W, H, title, sub, img) {
  const png = Buffer.from(img.split(',')[1], 'base64'), iw = png.readUInt32BE(16), ih = png.readUInt32BE(20);
  return `<!doctype html><html><head><style>
  @font-face { font-family: P; src: url(${FONT}) format('woff2'); }
  * { box-sizing: border-box; margin: 0; }
  html, body { width: ${W}px; height: ${H}px; overflow: hidden; }
  body {
    font-family: P, monospace; -webkit-font-smoothing: none; color: #f6f2e0;
    background:
      radial-gradient(circle at 4px 4px, rgba(255,255,255,.09) 4px, transparent 0) 0 0 / 96px 96px,
      radial-gradient(ellipse at 50% 0%, #3a2f8f 0%, transparent 55%),
      linear-gradient(180deg, #1a1840, #100f26 70%);
    display: flex; flex-direction: column; align-items: center;
  }
  h1 { margin-top: 60px; font-size: 96px; line-height: 1.1; color: #ffcf4a; font-weight: normal; text-align: center;
       text-shadow: 6px 6px 0 #b07a12, 12px 12px 0 #07061a; }
  p { margin-top: 18px; font-size: 48px; color: #cfd3ff; text-align: center; text-shadow: 4px 4px 0 #07061a; }
  .frame { margin-top: 44px; padding: 10px; background: #d9d2b8; box-shadow: 0 0 0 8px #07061a, 22px 22px 0 8px rgba(7,6,26,.6); }
  .win { border: 8px solid #07061a; overflow: hidden; }
  .frame img { display: block; image-rendering: pixelated; }
  .spark { position: absolute; width: 18px; height: 18px; background: #ffcf4a; box-shadow: 0 -18px 0 #ffcf4a, 0 18px 0 #ffcf4a, -18px 0 0 #ffcf4a, 18px 0 0 #ffcf4a; opacity: .85; }
  </style></head><body>
  <div class="spark" style="left:200px; top:120px"></div>
  <div class="spark" style="right:220px; top:200px; transform: scale(.7)"></div>
  <h1>${title}</h1><p>${sub}</p>
  <div class="frame"><div class="win" style="max-height:${H - 340}px"><img src="${img}" style="width:${iw * 2}px; height:${ih * 2}px"></div></div>
  </body></html>`;
}

(async () => {
  const b = await chromium.launch();
  let n = 0;
  for (const device of (process.env.DEVICES || Object.keys(SIZES).join(',')).split(',')) {
    const [W, H] = SIZES[device];
    const page = await b.newPage({ viewport: { width: W, height: H }, deviceScaleFactor: 1 });
    for (const lang of ['en', 'zh']) {
      fs.mkdirSync(path.join(OUT, lang), { recursive: true });
      SHOTS.forEach(() => {});
      for (let i = 0; i < SHOTS.length; i++) {
        const shot = SHOTS[i];
        const src = path.join(RAW, `${device}-${lang}-${shot}.png`);
        if (!fs.existsSync(src)) { console.warn('missing', src); continue; }
        const img = 'data:image/png;base64,' + fs.readFileSync(src).toString('base64');
        const [t, s] = TEXT[lang][shot];
        await page.setContent(html(device, t, s, img));
        await page.evaluate(() => document.fonts.ready);
        await page.waitForTimeout(100);
        const out = path.join(OUT, lang, `${device}-${i + 1}-${shot}.png`);
        await page.screenshot({ path: out });
        n++;
      }
    }
    await page.close();
  }
  await b.close();
  console.log('wrote', n, 'images');
})();
