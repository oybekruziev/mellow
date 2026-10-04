# Mellow

macOS 26+ uchun native SwiftUI fokus taymeri. Figma dizayni va `Mellow-handoff/INSTRUCTIONS.md` asosida yaratildi. Hech qanday tashqi kutubxona yoki server kerak emas.

## Ochish

`Build/Mellow.app` faylini ikki marta bosing. Mellow Dock’da ko‘rinmaydi: u menyu panelidagi gul belgisi va suzuvchi panel orqali ishlaydi.

- Birinchi ochilishda **onboarding** chiqadi: maskot, fokus va break vaqti, ovoz, lofi musiqa va mavzu tanlanadi. Settings → “Show Welcome Again” orqali qayta ochiladi.
- Vazifani yozing va **Start Focus** bosing.
- **15 / 25 / 45 min** yoki Settings’da **1–120 min** tanlang.
- Tugallangan fokus bir gul beradi. Tanaffus gul bermaydi.
- Settings yoki hamroh ustida o‘ng tugma orqali **Plant / Cat / Candle** almashtiriladi.
- Panelni yashirish yoki ixcham qilish taymerni to‘xtatmaydi. Yashirilganda panel menyu panelidagi gul belgisiga "kirib ketadi".
- **Reja (to-do):** vazifani yozib **+** bosing, har bir vazifaga o‘z vaqtini bering.
- **Ko‘p vazifali reja:** **Plan several tasks…** havolasi, vazifa ustiga bosish, menyudagi **Plan Tasks…** yoki **⌘P** muharririni ochadi. Unda vazifalar soni (20 tagacha), hammasi uchun bitta vaqt, break uzunligi, har bir vazifaning nomi va vaqti beriladi. Nom yozilmasa “Task N” bo‘ladi; oxirgi qatorda Return yangi vazifa qo‘shadi.
- **Vazifa vaqti tugaganda:** “Start break” rejimida break o‘zi boshlanadi, keyingi vazifa **Next Task** bilan. “Let me choose” rejimida **+5 min**, **Break** yoki **Next** tanlanadi. Fokus paytida **✓** vazifani muddatidan oldin bajarilgan deb belgilaydi.
- **Lofi musiqa:** pastdagi ♪ tugmasi. Settings’da “Play lofi music during focus” yoqilsa, musiqa fokus bilan birga yonadi va o‘chadi. 13 ta CC0 trek (HoliznaCC0).
- **Maskotlar:** Plant, Cat, Candle, Fox, Coffee, Moon, Cactus. Fokus paytida 5 kadr sekundiga 4 marta aylanadi, sessiya tugaganda “uyg‘onish” yoki “gullash” animatsiyasi o‘ynaydi. Ustiga kod bilan jonlilik qo‘shilgan (`MascotMotion.swift`): nafas olish, chayqalish, har ~10 soniyada sakrash/silkinish/cho‘zilish/bosh egish, pauzada uxlash va “z z z”, davom ettirganda uyg‘onib sakrash, sichqoncha ustiga borganda kattalashish, bosilganda sakrash, sessiya tugaganda gul barglari; qahvada bug‘, oy atrofida yulduzchalar, sham nuri. Tezlik bitta `tempo` qiymati bilan boshqariladi; Reduce Motion yoqilsa va panel yashirilganda hammasi to‘xtaydi.

## Xcode

`Mellow.xcodeproj` → **Mellow** scheme → Run. Xcode 26+ va macOS 26+ talab qilinadi.

Terminal orqali:

```sh
zsh scripts/build.sh
open Build/Mellow.app
zsh scripts/test.sh
```

Boshqa Mac'larga tarqatish uchun notarizatsiyalangan DMG:

```sh
zsh scripts/release.sh
```

U Developer ID (Oybek Ruziev, 79CTV95T7T) bilan imzolaydi, Xcode'dagi Apple akkaunti orqali Apple'ga notarizatsiyaga yuboradi, tasdiqni ilovaga biriktiradi (staple) va `Build/Mellow-<version>.dmg` ni yaratadi. Notarizatsiyasiz mahalliy DMG: `zsh scripts/make_dmg.sh`.

Yangi versiyani chiqarish: `MARKETING_VERSION` ni oshiring va `zsh scripts/release.sh --publish` ni ishga tushiring. U notarizatsiyalangan DMG yasaydi va uni darhol Cloudflare R2'ga (`download.bemellow.cc/Mellow.dmg`) yuklaydi — saytdagi Download tugmasi va versiya yozuvi o'zi yangilanadi. Buning uchun shu Mac'da wrangler Cloudflare'ga login qilingan bo'lishi kifoya (`npx wrangler login`); GitHub'da token kerak emas. Keyin GitHub'da shu DMG biriktirilgan release chiqaring:

```sh
gh release create v1.1 Build/Mellow-1.1.dmg --title "Mellow 1.1" --generate-notes
```

**Ilova ichidagi yangilanish:** Mellow ishga tushgandan 5 soniya keyin va keyin kuniga bir marta GitHub'dagi eng oxirgi Release'ni tekshiradi (`releases/latest`; tag `v1.2` → versiya `1.2`, biriktirilgan `.dmg` → yangilanish). Yangi versiya topilsa, "Mellow 1.2 is available" oynasi chiqadi: **Install and Relaunch**, **Later**, **Release Notes** va "Skip this version". Sessiya ketayotgan bo'lsa, oyna chiqmaydi — faqat menyuda "Update to Mellow 1.2…" paydo bo'ladi. Menyudagi **Check for Updates…** va Settings'dagi **Check for Updates** darhol tekshiradi. O'rnatishdan oldin yuklangan ilova Developer ID (79CTV95T7T) imzosi va Gatekeeper'dan o'tishi shart. Ilova o'zini almashtira olmasa (masalan, yozib bo'lmaydigan papkada bo'lsa), DMG Finder'da ochiladi. Shuning uchun har bir Release'ga bitta notarizatsiyalangan `.dmg` biriktiring va tag'ni `v<MARKETING_VERSION>` qilib qo'ying. Draft va pre-release'lar e'tiborga olinmaydi.

Brauzerda fayl `Mellow-<version>.dmg` nomi bilan saqlanadi. Tayyor DMG'ni alohida yuklash: `zsh scripts/publish.sh`. Zaxira yo'l: `.github/workflows/publish-dmg.yml` ni Actions'dan qo'lda ishga tushirish — buning uchun repo'da `CLOUDFLARE_API_TOKEN` secret'i (Workers R2 Storage: Edit) kerak.

Sayt (`website/`) `bemellow.cc` da Cloudflare Worker sifatida turadi. O'zgarishdan keyin:

```sh
cd website && npx wrangler deploy
```

## Qisqa tugmalar

Panel yoki app faol bo‘lganda: Space — boshlash/pauza/davom, Return — asosiy amal, Esc — tasdiqni bekor qilish yoki Settings’ni yopish; ⌘M — ixcham rejim, ⌘W — yashirish, ⌘, — Settings, ⌘. — tugatish, ⌘L — vazifa maydoni, ⌘Q — chiqish. Ready holatida 1/2/3 — vaqt presetlari.

## Kod

- `Sources/MellowCore` — testlanadigan sana asosidagi taymer, holatlar, kunlik hisob va sozlamalar.
- `Mellow/Window` — nonactivating NSPanel va ekran bo‘yicha joylashuv xotirasi.
- `Mellow/Views` — Liquid Glass panel, Figma komponentlari (tugmalar, segment, switch, stepper), Settings va hamroh animatsiyalari.
- `Mellow/Debug` — faqat Debug build: barcha holatlarni PNG qilib chiqaradi (`MELLOW_SNAPSHOT_DIR`).
- `Mellow/MenuBar` — native menu bar label va menyu.
- `Tests/MellowCoreTests` — 16 ta test; holat/event jadvalidagi barcha kombinatsiyalar va reja (to-do) oqimi tekshiriladi.
- `Mellow/Resources/Assets.xcassets` — handoff’dagi asl assetlar va Light/Dark rang tokenlari.

- `Mellow/Music` — lofi pleyer, `Mellow/Resources/Music` — treklar.
- `scripts/slice_sprites.swift` — ChatGPT sprite sheet’ini 512×512 kadrlarga kesadi (`Mellow-handoff/Generated/` → Assets).

UI ingliz tilida, topshiriqqa muvofiq. Tekshiruv tafsilotlari: `VALIDATION.md`. Mualliflik: `OWNERSHIP.md`, `LICENSE`, `CREDITS.md`.
