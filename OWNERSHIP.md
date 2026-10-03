# Mellow — mualliflik va egalik hujjati

> Bu hujjat yuridik maslahat emas. Rasmiy ro'yxatdan o'tkazish uchun tegishli idora yoki intellektual mulk bo'yicha yurist bilan maslahatlashing.

## 1. Mualliflik bayonoti

| | |
|---|---|
| Mahsulot | Mellow — macOS uchun fokus taymer (to-do reja, lofi musiqa, animatsion maskotlar) |
| Muallif va egasi | Oybek Ruziev |
| Aloqa | r.oybek2001@gmail.com |
| Yaratilgan sana | 2026-yil oktabr (birinchi build: 2026-10-03) |
| Bundle ID | `uz.oybek.Mellow` |
| Dizayn manbasi | Figma fayli `iVm5j9tzNuOu4nreImQWAA` (muallif akkauntida) |
| Tarqatish | Bepul (freeware) |
| Huquqlar | © 2026 Oybek Ruziev. Barcha huquqlar himoyalangan. |

Muallifga tegishli qismlar: g'oya va mahsulot konsepsiyasi, Figma dizayni, foydalanuvchi interfeysi, manba kodi (`Mellow/`, `Sources/MellowCore/`, `Tests/`), copy (matnlar), maskotlarni tanlash va tahrirlash.

Uchinchi tomon materiallari (muallifga tegishli emas, litsenziya asosida ishlatiladi) — `CREDITS.md` ga qarang:
- Lofi musiqa: HoliznaCC0, CC0 1.0 (jamoat mulki).
- Ikonkalar: Lucide, ISC litsenziyasi.

## 2. Mualliflikni isbotlovchi dalillar — nima qilish kerak

Eng kuchli dalil — **sanasi bor, o'zgartirib bo'lmaydigan, sizning nomingiz bilan bog'langan yozuvlar**. Quyidagilarni tartib bilan qiling:

1. **Git tarixi (bugunoq).** Loyiha hali git repozitoriy emas. `git init` qilib, birinchi commit'ni hozir qiling va **private** GitHub repozitoriyga push qiling. Har bir commit sanasi va muallifi saqlanadi. Imkon bo'lsa commit'larni SSH/GPG kalit bilan imzolang (`git config commit.gpgsign true`).
2. **Vaqt muhri (bepul).** Har bir relizda manba kodining zip arxivi uchun SHA-256 hash oling va uni [OpenTimestamps](https://opentimestamps.org) orqali muhrlang. Bu fayl aynan shu sanada sizda bo'lganini mustaqil isbotlaydi.
   ```bash
   zip -r mellow-src-1.0.zip Mellow Sources Tests Package.swift *.md && shasum -a 256 mellow-src-1.0.zip
   ```
3. **Apple Developer ID bilan imzolash.** Apple Developer Program'ga (yiliga $99) **o'z ismingiz** bilan a'zo bo'ling va ilovani Developer ID bilan imzolab, notarizatsiya qiling. Shunda har bir nusxada "Developer: Oybek Ruziev" turadi. Bu boshqa Mac'larda ilova ochilishi uchun ham kerak. Mac App Store'ga chiqarsangiz, "Seller" maydonida ham sizning ismingiz chiqadi.
4. **Figma fayli.** Fayl o'z akkauntingizda tursin va egasi faqat siz bo'ling. Figma version history'si dizaynning qachon chizilganini ko'rsatadi. Asosiy sahifalarni vaqti-vaqti bilan PDF qilib eksport qilib saqlang.
5. **Ommaviy e'lon.** Sayt (landing), Product Hunt, X/Threads/LinkedIn postlari — sanasi bor ommaviy yozuvlar. Saytni [web.archive.org](https://web.archive.org) da arxivlatib qo'ying.
6. **Rasmiy ro'yxatdan o'tkazish (O'zbekiston).** O'zbekistonda kompyuter dasturlarini rasmiy ro'yxatdan o'tkazish xizmati bor. U Adliya vazirligi huzuridagi intellektual mulk idorasi (ima.uz) va my.gov.uz orqali ko'rsatiladi. Mualliflik huquqi ro'yxatsiz ham paydo bo'ladi, lekin guvohnoma nizo paytida kuchli hujjat bo'ladi. Talablar va to'lovlarni ima.uz saytidan tekshiring.
7. **Nom (trademark).** "Mellow" so'zi keng tarqalgan, shu nomli boshqa ilova va brendlar bo'lishi mumkin. Oldin [WIPO Global Brand Database](https://branddb.wipo.int) va ima.uz bazasidan tekshiring. Nom band bo'lsa, o'ziga xosroq nom tanlang (masalan, "Mellow Focus") va nom bilan logoni tovar belgisi sifatida ro'yxatdan o'tkazishni ko'rib chiqing. Kodni boshqalar ko'chirsa ham, nom va logo sizniki bo'lib qoladi.

## 3. Litsenziya tanlovi (bepul ilova uchun)

| Variant | Ma'nosi | Kimga mos |
|---|---|---|
| **Freeware, barcha huquqlar himoyalangan** (hozirgi `LICENSE`) | Hamma bepul ishlatadi, lekin kodni nusxalash, o'zgartirish, sotish mumkin emas | Mahsulot ustidan to'liq nazorat kerak bo'lsa (tavsiya) |
| Open source (MIT) | Kodni hamma ko'chirib, o'zgartirib, hatto sotishi mumkin; faqat sizning ismingiz saqlanishi shart | Portfolio va hamjamiyat uchun; nomni trademark bilan himoyalash shart |

## 4. Sun'iy intellekt bilan yaratilgan qismlar

- Maskot rasmlari ChatGPT orqali generatsiya qilingan. OpenAI shartlariga ko'ra natijalar sizga tegishli. Lekin ko'p davlatlarda (masalan, AQSh) faqat AI yaratgan tasvir mualliflik huquqi bilan to'liq himoyalanmaydi. Promptlar, tanlov va tahrirlash yozuvlarini saqlang (`Mellow-handoff/Generated/`). Kelajakda maskotlarni rassom bilan qayta chizdirsangiz, ular to'liq sizniki bo'ladi.
- Kod AI yordamida yozilgan, lekin g'oya, talablar, dizayn va qabul qilish qarorlari sizniki. Bu jarayon yozuvlarini (Figma, handoff hujjati, git tarixi) saqlab qo'ying.

## 5. Ilova ichidagi belgilar

- Settings → "Made by Oybek Ruziev" bo'limi va ijtimoiy tarmoq havolalari (`Mellow/Views/AboutView.swift`).
- `CREDITS.md` — uchinchi tomon materiallari.
- Info.plist: `NSHumanReadableCopyright = "© 2026 Oybek Ruziev"` (Finder → Get Info oynasida ko'rinadi).
