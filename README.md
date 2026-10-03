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
- **Ko‘p vazifali reja:** maydondagi ro‘yxat tugmasi yoki **Edit** muharririni ochadi. Unda vazifalar soni (20 tagacha), hammasi uchun bitta vaqt, break uzunligi, har bir vazifaning nomi va vaqti beriladi. Nom yozilmasa “Task N” bo‘ladi; oxirgi qatorda Return yangi vazifa qo‘shadi.
- **Vazifa vaqti tugaganda:** “Start break” rejimida break o‘zi boshlanadi, keyingi vazifa **Next Task** bilan. “Let me choose” rejimida **+5 min**, **Break** yoki **Next** tanlanadi. Fokus paytida **✓** vazifani muddatidan oldin bajarilgan deb belgilaydi.
- **Lofi musiqa:** pastdagi ♪ tugmasi. Settings’da “Play lofi music during focus” yoqilsa, musiqa fokus bilan birga yonadi va o‘chadi. 13 ta CC0 trek (HoliznaCC0).
- **Maskotlar:** Plant, Cat, Candle, Fox, Coffee, Moon, Cactus. Fokus paytida 5 kadr sekundiga 5 marta aylanadi, sessiya tugaganda “uyg‘onish” yoki “gullash” animatsiyasi o‘ynaydi.

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
