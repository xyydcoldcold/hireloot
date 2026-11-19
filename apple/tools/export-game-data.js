#!/usr/bin/env node
/* Copies the web version's game data (weapons, sprites, icons, texts, rules) into
 * apple/Hireloot/Resources/GameData.json, so the native app and the web stay identical.
 * Run from the repo root after changing weapons.js, i18n.js or the tables at the top of app.js:
 *   node apple/tools/export-game-data.js
 */
const fs = require('fs');
const path = require('path');
const vm = require('vm');
const root = path.resolve(__dirname, '..', '..');
const read = (f) => fs.readFileSync(path.join(root, f), 'utf8');

const win = {};
vm.runInNewContext(read('weapons.js') + '\n' + read('i18n.js'), { window: win });

// app.js keeps its tables inside an IIFE; cut the two blocks out and evaluate them on their own.
const app = read('app.js');
const cut = (from, to) => {
  const a = app.indexOf(from), b = app.indexOf(to, a);
  if (a < 0 || b < 0) throw new Error('app.js changed shape near ' + from);
  return app.slice(a, b);
};
const rules = vm.runInNewContext(
  cut('const CATEGORIES = {', '// ============ 语言') +
  '({ CATEGORIES, BOSS_REWARD, BOSS_ROUNDS, ARMORS, TITLES, PACKS_PER_LEVEL })', {});
const art = vm.runInNewContext(
  cut('const HERO = [', 'function icon(') +
  '({ HERO, HELD, HELD_KEYS, BOSS, ICONS })', {});

const W = win.HirelootWeapons;
const out = {
  rules: {
    categories: Object.entries(rules.CATEGORIES).map(([key, c]) => ({ key, icon: c.icon, color: c.color, reward: Object.entries(c.reward) })),
    bossReward: rules.BOSS_REWARD,
    bossRounds: rules.BOSS_ROUNDS,
    armors: rules.ARMORS,
    titles: rules.TITLES,
    packsPerLevel: rules.PACKS_PER_LEVEL
  },
  weapons: {
    shapes: W.SHAPES,
    palettes: W.PALETTES,
    rarities: W.RARITIES,
    rarityOrder: W.RARITY_ORDER,
    pity: W.PITY,
    maxStars: W.MAX_STARS,
    list: W.WEAPONS.map((w) => ({ id: w.id, shape: w.shape, pal: w.pal, rarity: w.rarity, name: w.name, desc: w.desc }))
  },
  art: {
    hero: art.HERO,
    held: Object.fromEntries(Object.entries(art.HELD).map(([k, [top, rows]]) => [k, { top, rows }])),
    heldKeys: art.HELD_KEYS,
    boss: art.BOSS,
    icons: art.ICONS
  },
  strings: win.JQ_I18N
};
const dest = path.join(root, 'apple/Hireloot/Resources/GameData.json');
fs.writeFileSync(dest, JSON.stringify(out) + '\n');
console.log('wrote', path.relative(root, dest), fs.statSync(dest).size, 'bytes');
