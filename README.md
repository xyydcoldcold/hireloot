<div align="center">

<img src="docs/logo.png" alt="HIRELOOT" width="420">

**A pixel-game-style to-do list that makes every job-hunting effort count.**

<a href="README.md"><img src="docs/btn-en-active.png" alt="English" height="38"></a>&nbsp;&nbsp;<a href="README.zh-CN.md"><img src="docs/btn-zh.png" alt="简体中文" height="38"></a>

<img alt="No install" src="https://img.shields.io/badge/install-none-ffcf4a?style=flat-square">
<img alt="Zero dependencies" src="https://img.shields.io/badge/dependencies-0-3ddc97?style=flat-square">
<img alt="Data stays local" src="https://img.shields.io/badge/data-stays_local-c77dff?style=flat-square">
<img alt="English and Chinese" src="https://img.shields.io/badge/lang-EN_%7C_%E4%B8%AD%E6%96%87-4ea8de?style=flat-square">

<br>

<img src="docs/en-today.png" alt="Hireloot screenshot" width="860">

</div>

> We know landing a job is hard.
> Hundreds of applications. Inboxes that stay quiet. Interviews that end with "we'll be in touch."
> **So what if we made the process a game?**

Hireloot is a pixel RPG to-do list for your job hunt. Every application, resume edit and coffee chat you finish turns into EXP, stats and gear. Every interview is a boss fight. Some days you win, some days you retreat, and either way your hero gets stronger.

You can't control when the offer comes. You can control showing up every day. Hireloot makes that part feel like progress.

## How to play

**1. Accept today's quests.** Write down what you plan to do today. A task starts as *Uncategorized*. If it counts as job-hunt effort, file it under Project, Resume, Applications, Networking or Interview Prep, and finishing it grows the matching stats and EXP.

**2. Check them off.** Rewards land right away. Anything you don't finish carries over to tomorrow, marked with how many days it's been waiting. No guilt, just a reminder.

**3. Fight bosses.** Log each interview with the company and round. Pass it and you earn +100 EXP and 50 gold. Fail it and you still walk away with +40 EXP, because every interview teaches you something. Don't know the result yet? Log it as *Pending* and settle it later.

**4. Level up, open packs.** Every level-up gives you 3 weapon packs. Tear one open to reveal a weapon: Common, Rare, Epic or Legendary, and the Epic and Legendary cards are holographic. The Armory holds all 37 weapons, and the ones you haven't found yet show only a black silhouette and "???". Duplicates add stars. Equip your favorite and your hero carries it.

![Armory](docs/en-armory.png)

**5. Look back.** The Adventure Log files every finished quest by day, so on the slow weeks you can see how much you've actually done.

![Boss fights](docs/en-boss.png)

## Start playing

**Play in your browser: [xyydcoldcold.github.io/hireloot](https://xyydcoldcold.github.io/hireloot/)**

Sign up with your email and password and your save lives in the cloud, so you can pick up on your laptop or your phone. Not ready to sign up? Choose **Play as guest**: your save stays in that browser, and moves into your account the first time you sign in.

Bookmark the page and open it each morning.

The ⚙ button in the top right switches between English and 中文, shows your account and sync status, and lets you export or import your save.

Prefer to keep everything offline? Download this repository (green **Code** button → **Download ZIP**) and open `index.html` in your browser. Without an internet connection the game runs fully local, and your progress stays in that browser's local storage.

## For tinkerers

Hireloot is plain HTML, CSS and JavaScript with no build step. The one dependency, supabase-js, is vendored in `vendor/` and only loads when cloud saves are on.

| File | What's inside |
| --- | --- |
| `index.html` | Page structure |
| `style.css` | Pixel styling |
| `app.js` | Game logic. **All reward numbers, gear tiers and titles are at the top**, so tune them however you like. |
| `i18n.js` | Every piece of UI text, in Chinese and English. Add a language by adding a block here. |
| `weapons.js` | The Armory: weapon pixel art, palettes, rarities and drop rates. Add a weapon with one line. |
| `armory.js` | Pack-opening animation, holographic cards, 8-bit sound effects and the Armory page |
| `categorizer.js` | Suggests an effort type as you type. It uses keyword rules today. Replace `suggest(text)` to plug in an LLM. |
| `fonts/` | [Fusion Pixel](https://github.com/TakWolf/fusion-pixel-font) by TakWolf, under the SIL Open Font License (see `fonts/OFL.txt`) |
| `config.js` | Cloud save settings (Supabase URL and anon key). Leave empty for local-only. |
| `cloud.js` | Email sign-in, cloud sync and conflict handling |
| `supabase/schema.sql` | Database table and row-level security rules for cloud saves |
| `vendor/` | [supabase-js](https://github.com/supabase/supabase-js) 2.119.0, MIT license, loaded only when cloud saves are on |

To connect an LLM, have `suggest(text)` return one of `project`, `resume`, `apply`, `network`, `prep`, or `null`. The file has an example that calls a local endpoint. Don't put API keys in the page itself. Route requests through a small local server or a local model such as Ollama.

Issues and pull requests are welcome.

Good luck out there, hero. 🗡️
