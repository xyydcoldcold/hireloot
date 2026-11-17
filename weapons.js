/* Hireloot 武器库数据
 * SHAPES：武器的像素造型（竖直放置，刀尖朝上）。字母是调色板里的颜色槽：
 *   l 刃高光  b 刃身  d 刃暗面   g 护手/金属件  G 护手暗面   h 握柄  H 握柄暗面   e 宝石  E 宝石高光  w 弓弦/白光
 * PALETTES：材质配色，武器 = 造型 + 材质。
 * WEAPONS：所有武器。名字和描述在这里直接写中英文（数量多，放 i18n.js 太挤）。
 * 想加武器：往 WEAPONS 里加一行就行，id 不要改（存档用 id 记录）。
 */
window.HirelootWeapons = (function () {
  'use strict';

  const SHAPES = {
    sword: [
      '.....l.....',
      '....lbd....',
      '....lbd....',
      '....lbd....',
      '....lbd....',
      '....lbd....',
      '....lbd....',
      '....lbd....',
      '....lbd....',
      '....lbd....',
      '....lbd....',
      '....lbd....',
      '....lbd....',
      '.g..lbd..g.',
      'ggggGeGgggg',
      '.GG.hHh.GG.',
      '....Hhh....',
      '....hHh....',
      '....Hhh....',
      '....hHh....',
      '...gGeGg...',
      '....gGg....'
    ],
    dagger: [
      '....l....',
      '...lb....',
      '...lbd...',
      '...lbd...',
      '...lbd...',
      '...lbd...',
      '...lbd...',
      '..llbdd..',
      'gggGeGggg',
      '.G.hHh.G.',
      '...Hhh...',
      '...hHh...',
      '...Hhh...',
      '...geg...',
      '....g....'
    ],
    greatsword: [
      '......l......',
      '.....lbb.....',
      '....lbbbd....',
      '....lbbbd....',
      '....lbbbd....',
      '....lbbbd....',
      '....lbebd....',
      '....lbbbd....',
      '....lbbbd....',
      '....lbbbd....',
      '....lbebd....',
      '....lbbbd....',
      '....lbbbd....',
      '....lbbbd....',
      '....lbbbd....',
      'gg..lbbbd..gg',
      'ggggggegggggg',
      '.GGGGGGGGGGG.',
      '.....hHh.....',
      '.....Hhh.....',
      '.....hHh.....',
      '.....Hhh.....',
      '....gGeGg....',
      '.....ggg.....'
    ],
    katana: [
      '......l..',
      '.....lb..',
      '.....lbd.',
      '.....lbd.',
      '....lbd..',
      '....lbd..',
      '....lbd..',
      '....lbd..',
      '...lbd...',
      '...lbd...',
      '...lbd...',
      '...lbd...',
      '...lbd...',
      '...lbd...',
      '...lbd...',
      '.ggGeGgg.',
      '..GgggG..',
      '...hHh...',
      '...Hhh...',
      '...hHh...',
      '...Hhh...',
      '...hHh...',
      '...Hhh...',
      '...ggg...'
    ],
    axe: [
      '......e......',
      '..bb..H..bb..',
      '.lbbb.h.bbbd.',
      'lbbbbbhbbbbbd',
      'lbbbbbgbbbbbd',
      'lbbbbbgbbbbbd',
      'lbbbbbhbbbbbd',
      '.lbbb.h.bbbd.',
      '..bb..H..bb..',
      '......h......',
      '......H......',
      '......h......',
      '......H......',
      '.....gGg.....',
      '......h......',
      '......H......',
      '......h......',
      '......H......',
      '......h......',
      '......H......',
      '.....geg.....',
      '......g......'
    ],
    spear: [
      '....l....',
      '...lbd...',
      '...lbd...',
      '..lbbbd..',
      '..lbbbd..',
      '.lbbebbd.',
      '..lbbbd..',
      '...lbd...',
      '....d....',
      '...gGg...',
      '..e.h.e..',
      '..e.H.e..',
      '..E.h.E..',
      '....H....',
      '....h....',
      '....H....',
      '....h....',
      '....H....',
      '....h....',
      '....H....',
      '....h....',
      '....H....',
      '....h....',
      '...geg...'
    ],
    hammer: [
      '.ggggggggggg.',
      'glbbbbbbbbbdg',
      'glbbbbbbbbbdg',
      'glbbbeEebbbdg',
      'glbbbbbbbbbdg',
      'glbbbbbbbbbdg',
      '.ggggggggggg.',
      '.....GhG.....',
      '......H......',
      '......h......',
      '......H......',
      '......h......',
      '......H......',
      '......h......',
      '......H......',
      '......h......',
      '......H......',
      '......h......',
      '.....gGg.....',
      '......e......'
    ],
    staff: [
      '....eEe....',
      '...eEEee...',
      '..geEeeeg..',
      '..geeeeeg..',
      '...geeeg...',
      '..g.ggg.g..',
      '...g.h.g...',
      '.....h.....',
      '....gGg....',
      '.....H.....',
      '.....h.....',
      '.....H.....',
      '.....h.....',
      '.....H.....',
      '.....h.....',
      '.....H.....',
      '.....h.....',
      '.....H.....',
      '.....h.....',
      '.....H.....',
      '.....h.....',
      '.....H.....',
      '....ggg....'
    ],
    wand: [
      '...E...',
      '...e...',
      'eeeEeee',
      '.eeEee.',
      '..eee..',
      '.ee.ee.',
      '.e.g.e.',
      '...h...',
      '...H...',
      '...h...',
      '...H...',
      '...h...',
      '...H...',
      '...h...',
      '..gGg..',
      '...h...',
      '...H...',
      '...g...'
    ],
    bow: [
      '......hhw..',
      '.....hH.w..',
      '....hH..w..',
      '...hH...w..',
      '...hH...w..',
      '..hH....w..',
      '..hH....w..',
      '..hH....w..',
      '..hH....w..',
      '.gge....w..',
      'lbbbbbbbbbd',
      '.gge....w..',
      '..hH....w..',
      '..hH....w..',
      '..hH....w..',
      '..hH....w..',
      '...hH...w..',
      '...hH...w..',
      '....hH..w..',
      '.....hH.w..',
      '......hhw..'
    ],
    scythe: [
      '...lllbbbb...',
      '.llbbbbbbbbgg',
      'lbbbdddd..gHg',
      'lbdd......gHg',
      'ld.........h.',
      'l..........H.',
      '...........h.',
      '...........H.',
      '...........h.',
      '..........geg',
      '...........h.',
      '...........H.',
      '...........h.',
      '...........H.',
      '...........h.',
      '...........H.',
      '...........h.',
      '...........H.',
      '...........h.',
      '...........H.',
      '..........ggg'
    ],
    trident: [
      'l...l...l',
      'b..lbd..b',
      'b..lbd..b',
      'bd.lbd.db',
      'lbbbbbbbd',
      '.dbbebbd.',
      '...gGg...',
      '....h....',
      '....H....',
      '....h....',
      '....H....',
      '....h....',
      '....H....',
      '....h....',
      '....H....',
      '....h....',
      '....H....',
      '....h....',
      '....H....',
      '....h....',
      '...geg...'
    ],
    mace: [
      '.....l.....',
      '..l..b..l..',
      '...bbbbb...',
      '..bllbbbd..',
      'lbblbbbbbdl',
      '..bbbbbbd..',
      '..bbbbbdd..',
      '...ddddd...',
      '..l..d..l..',
      '.....g.....',
      '....gGg....',
      '.....h.....',
      '.....H.....',
      '.....h.....',
      '.....H.....',
      '.....h.....',
      '.....H.....',
      '.....h.....',
      '.....H.....',
      '....geg....'
    ],
    rapier: [
      '....l....',
      '....l....',
      '....b....',
      '....b....',
      '....b....',
      '....b....',
      '....b....',
      '....b....',
      '....b....',
      '....b....',
      '....b....',
      '....b....',
      '...lbd...',
      '...lbd...',
      '.ggGeGgg.',
      'g.g.h.g.g',
      'g...H...g',
      '.gg.h.gg.',
      '...gHg...',
      '....h....',
      '...geg...'
    ],
    quill: [
      '....l....',
      '...lbb...',
      '..lbbbb..',
      '..lbhbd..',
      '.lbbhbbd.',
      '.lbbhbbd.',
      '.lbbhbbd.',
      '..lbhbd..',
      '..lbhbd..',
      '...lhd...',
      '...lhd...',
      '....h....',
      '....h....',
      '....h....',
      '...gGg...',
      '...geg...',
      '...gGg...',
      '....G....',
      '....G....'
    ]
  };

  // l b d = 刃；g G = 金属件；h H = 柄；e E = 宝石；w = 弦
  const PALETTES = {
    wood:    { l: '#e0b07a', b: '#b07a3e', d: '#7a4f24', g: '#8b5a2b', G: '#5e3a1a', h: '#6b4a2b', H: '#4a3018', e: '#9fd36a', E: '#d8f5b0', w: '#f6f2e0' },
    rust:    { l: '#d8a07a', b: '#a8643c', d: '#6e3a22', g: '#7a6a5a', G: '#4e4238', h: '#5a3d26', H: '#3d2817', e: '#c0392b', E: '#ff9a8a', w: '#d9d2b8' },
    iron:    { l: '#f2f6fa', b: '#b8c4d0', d: '#6e7c8c', g: '#8d8d9e', G: '#5a5a6e', h: '#6b4a2b', H: '#4a3018', e: '#4ea8de', E: '#bfe6ff', w: '#f6f2e0' },
    steel:   { l: '#ffffff', b: '#cfd8e3', d: '#7f8fa3', g: '#c58b3a', G: '#8a5a1e', h: '#3b2a4a', H: '#251a30', e: '#e4572e', E: '#ffb59e', w: '#f6f2e0' },
    bronze:  { l: '#ffd9a0', b: '#d08a3a', d: '#8a5216', g: '#b07a12', G: '#6e4a08', h: '#5a3d26', H: '#3d2817', e: '#3ddc97', E: '#b8ffe0', w: '#f6f2e0' },
    paper:   { l: '#ffffff', b: '#fff09a', d: '#e0b830', g: '#f2c14e', G: '#a8741c', h: '#4ea8de', H: '#2c6e9e', e: '#ff6b6b', E: '#ffd0d0', w: '#ffffff' },
    coffee:  { l: '#f0d8b8', b: '#a0703e', d: '#5e3a1a', g: '#f6f2e0', G: '#b9a88a', h: '#6b4a2b', H: '#4a3018', e: '#ff9a3c', E: '#ffe0a0', w: '#f6f2e0' },
    tomato:  { l: '#ffb0a0', b: '#e4572e', d: '#9a2a14', g: '#3ddc97', G: '#1f8a5a', h: '#e4572e', H: '#9a2a14', e: '#ff6b6b', E: '#ffe0e0', w: '#f6f2e0' },
    elven:   { l: '#d8ffd0', b: '#6fcf6f', d: '#2d8a3a', g: '#c5e86a', G: '#7aa02a', h: '#5fae5f', H: '#2d6e38', e: '#ffcf4a', E: '#fff4c2', w: '#e8ffe0' },
    frost:   { l: '#ffffff', b: '#a8e4ff', d: '#4ea8de', g: '#cfe3ff', G: '#7d9ac0', h: '#3a4a9c', H: '#262f6e', e: '#7fdbff', E: '#ffffff', w: '#e8f8ff' },
    network: { l: '#f3d9ff', b: '#c77dff', d: '#7a3aa8', g: '#f2c14e', G: '#a8741c', h: '#5a3a7a', H: '#3a2350', e: '#ff8ad8', E: '#ffe0f4', w: '#f6f2e0' },
    mithril: { l: '#ffffff', b: '#9ff0ff', d: '#3aa8c8', g: '#d9d2b8', G: '#8a8470', h: '#2c3e70', H: '#1a264a', e: '#7fdbff', E: '#ffffff', w: '#e8ffff' },
    flame:   { l: '#fff4a0', b: '#ff9a3c', d: '#d0401a', g: '#5a2a2a', G: '#3a1414', h: '#3a1a1a', H: '#200c0c', e: '#ffcf4a', E: '#ffffff', w: '#ffe0a0' },
    shadow:  { l: '#b9a0e6', b: '#5a3a8a', d: '#2a1650', g: '#3a3a4a', G: '#20202c', h: '#2a2a3a', H: '#16161f', e: '#ff4a6a', E: '#ffb0c0', w: '#d0c0ff' },
    thunder: { l: '#ffffff', b: '#fff06a', d: '#c8a010', g: '#4ea8de', G: '#2c6e9e', h: '#2c3e70', H: '#1a264a', e: '#9ff0ff', E: '#ffffff', w: '#fff8c0' },
    marker:  { l: '#ffffff', b: '#e8eef4', d: '#9fb3c8', g: '#4ea8de', G: '#2c6e9e', h: '#4ea8de', H: '#2c6e9e', e: '#ff6b6b', E: '#ffffff', w: '#ffffff' },
    abyss:   { l: '#a0fff0', b: '#1fa8a0', d: '#0a5a6e', g: '#2c3e70', G: '#1a264a', h: '#1a4a5a', H: '#0c2a36', e: '#ffcf4a', E: '#fff4c2', w: '#c0fff8' },
    gold:    { l: '#ffffff', b: '#ffe27a', d: '#d0a020', g: '#ffcf4a', G: '#b07a12', h: '#c0392b', H: '#7a1e14', e: '#4ea8de', E: '#ffffff', w: '#fff4c2' },
    dragon:  { l: '#fff6e0', b: '#e8dcc0', d: '#a8946e', g: '#c0392b', G: '#7a1e14', h: '#3a1a1a', H: '#200c0c', e: '#ff4a2a', E: '#ffd080', w: '#fff6e0' },
    void:    { l: '#ffb0ff', b: '#8a2ae0', d: '#3a0a7a', g: '#1a1030', G: '#0c0618', h: '#1a1030', H: '#0c0618', e: '#3af0ff', E: '#ffffff', w: '#e0b0ff' },
    final:   { l: '#ffffff', b: '#ffd0e0', d: '#e05a8a', g: '#ffcf4a', G: '#b07a12', h: '#1a1a2a', H: '#0c0c16', e: '#ff4a6a', E: '#ffffff', w: '#ffffff' },
    prism:   { l: '#ffffff', b: '#7fdbff', d: '#c77dff', g: '#ffcf4a', G: '#b07a12', h: '#ff6b9a', H: '#c03a6a', e: '#5fd35f', E: '#ffffff', w: '#fff4c2' },
    offer:   { l: '#ffffff', b: '#fff8e0', d: '#ffcf4a', g: '#ffcf4a', G: '#b07a12', h: '#ffe27a', H: '#d0a020', e: '#5fd35f', E: '#ffffff', w: '#ffffff' }
  };

  // 稀有度：概率、基础攻击、颜色
  const RARITIES = {
    N:   { rate: 60, atk: 2,  color: '#b9bde6' },
    R:   { rate: 27, atk: 4,  color: '#4ea8de' },
    SR:  { rate: 10, atk: 7,  color: '#c77dff' },
    SSR: { rate: 3,  atk: 12, color: '#ffcf4a' }
  };
  const RARITY_ORDER = ['SSR', 'SR', 'R', 'N'];
  const PITY = 10;      // 连续这么多包没出 SR 以上，下一包保底 SR
  const MAX_STARS = 5;  // 重复抽到会升星，每颗星 +1 攻击

  // [id, 造型, 材质, 稀有度, 中文名, 英文名, 中文描述, 英文描述]
  const LIST = [
    // ---- N ----
    ['wood_sword',    'sword',      'wood',    'N', '木剑', 'Wooden Sword', '每个勇者都从这里开始。', 'Every hero starts here.'],
    ['rusty_dagger',  'dagger',     'rust',    'N', '生锈匕首', 'Rusty Dagger', '有点钝，但还能用。', 'A bit dull, but it still works.'],
    ['training_bow',  'bow',        'wood',    'N', '新手短弓', 'Training Bow', '先瞄准，再海投。', 'Aim first, then mass-apply.'],
    ['iron_sword',    'sword',      'iron',    'N', '铁剑', 'Iron Sword', '朴实可靠，就像一份干净的简历。', 'Plain and reliable, like a clean resume.'],
    ['wood_axe',      'axe',        'wood',    'N', '伐木斧', 'Woodcutter\'s Axe', '一份一份地砍，总会砍完。', 'Chop one at a time. You\'ll get through them.'],
    ['practice_spear','spear',      'iron',    'N', '训练长矛', 'Practice Spear', '每天戳一下，进步看得见。', 'Poke at it daily and watch the progress.'],
    ['apprentice_staff','staff',    'wood',    'N', '学徒法杖', 'Apprentice Staff', '顶上的绿宝石来自第一封回复邮件。', 'The green gem came from your first reply email.'],
    ['iron_hammer',   'hammer',     'iron',    'N', '铁锤', 'Iron Hammer', '把简历锤到一页纸。', 'Hammers a resume down to one page.'],
    ['coffee_stirrer','wand',       'coffee',  'N', '咖啡搅拌棒', 'Coffee Stirrer', '早上九点前的唯一法器。', 'The only magic before 9 a.m.'],
    ['sticky_knife',  'dagger',     'paper',   'N', '便利贴飞刀', 'Sticky-Note Knife', '贴满显示器，提醒你今天的任务。', 'Covers your monitor with today\'s quests.'],
    ['draft_quill',   'quill',      'wood',    'N', '草稿羽毛笔', 'Draft Quill', '写了第 17 版求职信。', 'Wrote the 17th draft of that cover letter.'],
    ['iron_mace',     'mace',       'iron',    'N', '铁钉头锤', 'Iron Mace', '敲开 ATS 系统的第一下。', 'The first knock on the ATS gate.'],
    // ---- R ----
    ['steel_sword',   'sword',      'steel',   'R', '钢剑', 'Steel Sword', '磨砺过的经历，锋利得多。', 'Polished experience cuts much sharper.'],
    ['referral_dagger','dagger',    'network', 'R', '内推匕首', 'Referral Dagger', '从侧门直接刺进面试名单。', 'Slips you through the side door to the shortlist.'],
    ['elven_bow',     'bow',        'elven',   'R', '精灵长弓', 'Elven Longbow', '百步之外命中 JD 关键词。', 'Hits JD keywords from a hundred paces.'],
    ['frost_spear',   'spear',      'frost',   'R', '霜冻长矛', 'Frost Spear', '面对冷邮件，保持冷静。', 'Stay cool through the cold emails.'],
    ['bronze_axe',    'axe',        'bronze',  'R', '青铜战斧', 'Bronze Battleaxe', '劈开「需要 5 年经验」的入门岗。', 'Cleaves through "entry level, 5 years required".'],
    ['sprint_hammer', 'hammer',     'bronze',  'R', '冲刺之锤', 'Sprint Hammer', '两周一个项目，锤得飞快。', 'One project per two-week sprint.'],
    ['pomodoro_wand', 'wand',       'tomato',  'R', '番茄钟魔杖', 'Pomodoro Wand', '25 分钟专注，5 分钟回血。', '25 minutes of focus, 5 minutes to heal.'],
    ['duelist_rapier','rapier',     'steel',   'R', '决斗刺剑', 'Duelist Rapier', '行为面试里精准的 STAR 一刺。', 'A precise STAR answer, straight to the point.'],
    ['network_trident','trident',   'network', 'R', '人脉三叉戟', 'Network Trident', '一次叉起三个 coffee chat。', 'Spears three coffee chats at once.'],
    ['caffeine_staff','staff',      'coffee',  'R', '咖啡因法杖', 'Caffeine Staff', '橙色宝石里装着一杯双份浓缩。', 'The orange orb holds a double espresso.'],
    // ---- SR ----
    ['mithril_sword', 'sword',      'mithril', 'SR', '秘银剑', 'Mithril Sword', '轻得像没有拖延症的一天。', 'Light as a day without procrastination.'],
    ['first_katana',  'katana',     'steel',   'SR', '一面斩', 'First-Round Cleaver', '拔刀一瞬，一面已过。', 'One draw and round one is done.'],
    ['flame_great',   'greatsword', 'flame',   'SR', '烈焰巨剑', 'Flame Greatsword', '燃烧的是你的项目热情。', 'Burns with your passion for side projects.'],
    ['star_staff',    'staff',      'frost',   'SR', '星辰法杖', 'Starfall Staff', '召唤一场简历流星雨。', 'Summons a meteor shower of resumes.'],
    ['shadow_scythe', 'scythe',     'shadow',  'SR', '暗影镰刀', 'Shadow Scythe', '收割所有已读不回。', 'Reaps every "seen, no reply".'],
    ['thunder_hammer','hammer',     'thunder', 'SR', '雷鸣战锤', 'Thunder Hammer', '一锤下去，系统设计题都开窍了。', 'One strike and system design just clicks.'],
    ['whiteboard_quill','quill',    'marker',  'SR', '白板之笔', 'Whiteboard Quill', '画出完美的二叉树，一次不擦。', 'Draws a perfect binary tree, no erasing.'],
    ['abyss_trident', 'trident',    'abyss',   'SR', '深海三叉戟', 'Abyss Trident', '潜入隐藏职位的深海。', 'Dives into the hidden job market.'],
    ['morning_star',  'mace',       'thunder', 'SR', '晨星', 'Morning Star', '早起投递的人会被它照亮。', 'Shines on those who apply at dawn.'],
    // ---- SSR ----
    ['holy_blade',    'sword',      'gold',    'SSR', '传说圣剑', 'Legendary Blade', '只有坚持到最后的人能拔出它。', 'Only those who never quit can draw it.'],
    ['offer_quill',   'quill',      'offer',   'SSR', 'Offer 签字笔', 'Offer Quill', '用它签下的名字，会变成工牌。', 'Whatever it signs turns into a badge.'],
    ['dragon_great',  'greatsword', 'dragon',  'SSR', '龙骨巨剑', 'Dragonbone Greatsword', '用被拒信熬成的龙骨锻造。', 'Forged from bones boiled out of rejection letters.'],
    ['void_reaper',   'scythe',     'void',    'SSR', '虚空收割者', 'Void Reaper', '连 ghosting 都能斩断。', 'It can even cut through ghosting.'],
    ['final_katana',  'katana',     'final',   'SSR', '终面之刃', 'Final Round Edge', '樱花落下时，HR 打来了电话。', 'As the petals fall, HR calls.'],
    ['prism_bow',     'bow',        'prism',   'SSR', '虹光之弓', 'Prism Bow', '每一箭都折射出一个新机会。', 'Every arrow refracts into a new opportunity.']
  ];

  const WEAPONS = LIST.map(([id, shape, pal, rarity, zh, en, zhDesc, enDesc], i) =>
    ({ id, shape, pal, rarity, order: i, name: { zh, en }, desc: { zh: zhDesc, en: enDesc } }));
  const BY_ID = Object.fromEntries(WEAPONS.map((w) => [w.id, w]));

  function rollRarity(rand, pityCount) {
    if (pityCount >= PITY - 1) {
      // 保底：只在 SR / SSR 之间按比例抽
      const r = rand() * (RARITIES.SR.rate + RARITIES.SSR.rate);
      return r < RARITIES.SSR.rate ? 'SSR' : 'SR';
    }
    let r = rand() * 100;
    for (const k of RARITY_ORDER) { // SSR → R → N 依次扣概率
      if ((r -= RARITIES[k].rate) < 0) return k;
    }
    return 'N';
  }
  function roll(rand, pityCount) {
    const rarity = rollRarity(rand, pityCount);
    const pool = WEAPONS.filter((w) => w.rarity === rarity);
    return pool[Math.floor(rand() * pool.length)];
  }
  // 武器攻击 = 稀有度基础 + (星级 - 1)
  function atkOf(id, count) {
    const w = BY_ID[id];
    if (!w || !count) return 0;
    return RARITIES[w.rarity].atk + Math.min(count, MAX_STARS) - 1;
  }

  return { SHAPES, PALETTES, RARITIES, RARITY_ORDER, PITY, MAX_STARS, WEAPONS, BY_ID, roll, atkOf };
})();
