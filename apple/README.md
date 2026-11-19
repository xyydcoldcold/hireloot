# Hireloot for iPhone and Mac (SwiftUI)

A native SwiftUI version of Hireloot. One Xcode target runs on iPhone, iPad and Mac.
It uses the same Supabase project, the same account and the same save JSON as the web version
at hireloot.com, so the web, your iPhone and your Mac all share one save.

## Run it

1. Open `apple/Hireloot.xcodeproj` in Xcode 16 or newer.
2. Select the **Hireloot** target → **Signing & Capabilities** → pick your Team.
   Change the bundle id (`com.hireloot.app`) if it is taken.
3. Pick a run destination: **My Mac**, an iPhone simulator, or your iPhone, and press Run.

No packages to install. The Supabase client is a small URLSession wrapper (`Cloud/Supabase.swift`).

## What is shared with the web version

| | |
|---|---|
| Rules, rewards, level curve | `Game/Rules.swift` (numbers come from `GameData.json`) |
| Weapons, sprites, icons, all texts | `Resources/GameData.json`, generated from `weapons.js`, `i18n.js` and the tables in `app.js` |
| Save format | `Game/SaveState.swift`, byte-for-byte compatible with `hireloot.v1` |
| Cloud sync | `Cloud/CloudSync.swift`: same `saves` table, same `rev` conflict check as `cloud.js` |

After changing weapons, texts or reward numbers on the web side, run this from the repo root
and commit the result (CI fails if you forget):

```sh
node apple/tools/export-game-data.js
```

## Differences from the web version

- Sign-up confirmation and password-reset emails link to hireloot.com. Confirm or set the new
  password there, then sign in in the app.
- The login session is kept in the Keychain; signing out clears the local save (the cloud copy stays).
- On iPhone, the full hero panel sits on the Today tab and the other tabs show a slim hero bar.

## Screenshots

`.github/workflows/apple.yml` builds the Mac and iPhone-simulator apps on every push that touches
`apple/`, and uploads simulator screenshots as the `hireloot-apple` artifact.
Launch arguments used for that (handy in Xcode too, under Scheme → Arguments):

| Argument | Effect |
|---|---|
| `-HLDemo YES` | Load a Lv.7 demo save (cloud sync off) |
| `-HLLang en` | Force English (`zh` for Chinese) |
| `-HLTab boss` | Start on a tab: `today`, `boss`, `armory`, `log` |
| `-HLOpenPacks YES -HLDemoPacks YES -HLAutoTear YES` | Open the pack stage and tear all packs |
| `-HLSettings YES` | Open settings on launch |

The pixel font is Fusion Pixel 12px (SIL Open Font License, `Resources/FusionPixel-OFL.txt`).
