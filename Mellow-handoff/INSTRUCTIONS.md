# Mellow — build instructions for an AI coding agent

You are building **Mellow**, a tiny macOS 26 (Tahoe) focus timer. It sits in a small floating Liquid Glass panel at the edge of the screen. The user types one task and starts a timer. A companion (a plant by default) grows while they work. Every finished focus session earns one flower.

Build it natively in **SwiftUI**. The Figma file is the visual source of truth, and this document is the behavioural source of truth. When the two disagree, follow this document and leave a `// NOTE:` comment.

- Figma file: https://www.figma.com/design/iVm5j9tzNuOu4nreImQWAA/Mellow (fileKey `iVm5j9tzNuOu4nreImQWAA`)
- Image assets: `./Assets/` next to this file. See §11.
- UI language: **English only**, Title Case for buttons and menu items (macOS HIG).

---

## 0. How to work

1. Read this file end to end before writing code.
2. If you have the Figma MCP, pull exact specs with `get_design_context` / `get_screenshot` using the node IDs in §12. Treat Figma output as a reference and translate it to native SwiftUI. Never paste web CSS.
3. Build in this order. Each milestone must compile, run and be checked against its acceptance list (§14) before you move on.
   - **M1:** Timer engine + state machine (no UI) + unit tests.
   - **M2:** Floating panel with all 7 states.
   - **M3:** Menu bar extra + menu.
   - **M4:** Compact view + Hide/Show.
   - **M5:** Settings + persistence.
   - **M6:** Companions (Plant / Cat / Candle) + switching.
   - **M7:** Motion + sound + accessibility polish.
4. Do not add features outside scope (§13). Do not invent copy. Use the copy deck in §9 verbatim.

---

## 1. Tech stack & project setup

- Xcode 26+, Swift 6, SwiftUI, deployment target **macOS 26.0**.
- No third-party dependencies. Use the Lucide icons as bundled SVG assets. Each Lucide icon below has an SF Symbol equivalent that you may use instead, as long as the visual weight matches.
- App type: **agent app** (no Dock icon). Set `LSUIElement = YES` in Info.plist. The app lives in the menu bar plus its floating panel.
- Bundle display name: `Mellow`. App icon: build it in Icon Composer from `Assets/mellow-logo-1024.png` as the foreground layer, over a light frosted-glass background layer. See the "App Icon" component on the Figma Components page.
- Suggested structure:

```
Mellow/
  MellowApp.swift              // @main, MenuBarExtra + panel controller bootstrap
  Model/
    SessionEngine.swift        // state machine + timer (pure, testable)
    SessionState.swift         // enums
    Settings.swift             // @AppStorage-backed settings
    DailyStats.swift           // today's flower count (resets at local midnight)
    Companion.swift            // companion type + stage mapping
  Window/
    FloatingPanel.swift        // NSPanel subclass
    PanelController.swift      // show/hide/compact, position memory
  Views/
    PanelView.swift            // switches on state
    States/ (ReadyView, FocusView, PausedView, ConfirmEndView, CompleteView, BreakView, BreakOverView)
    CompactView.swift
    SettingsView.swift
    Components/ (GlassCircleButton, TodayRow, CompanionView, ProgressCapsule, …)
  MenuBar/
    MenuBarLabel.swift
    MenuBarMenu.swift
  Resources/Assets.xcassets    // images from ./Assets
  Resources/Sounds/            // one soft chime (see §8)
MellowTests/
  SessionEngineTests.swift
```

---

## 2. Windows

### 2.1 Floating panel (`FloatingPanel: NSPanel`)
- Style mask: `[.nonactivatingPanel, .fullSizeContentView, .borderless]`. No title bar and no traffic lights.
- `isFloatingPanel = true`. `level = .floating` when "Keep panel on top" is ON, `.normal` when OFF.
- `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]`. Verify on device. Fullscreen visibility is best effort.
- `isMovableByWindowBackground = true`. Only the header empty space, logo, title and status are a drag region. Buttons must not start a drag.
- `hidesOnDeactivate = false`, `backgroundColor = .clear`, `isOpaque = false`, `hasShadow = false` (the glass view draws its own shadow).
- The panel must never steal focus from the user's app, except when the user clicks into the task text field.
- Size: width **300 pt**. Height hugs content: about 178 pt when Focusing and about 248 pt when Ready.
- Default position: top-right of the main screen's visible frame, inset 18 pt from the right edge and 14 pt below the menu bar.
- Remember the position per display (keyed by `NSScreen.localizedName`, stored in UserDefaults). Clamp it on screen-config changes.

### 2.2 Compact view
- Same NSPanel, resized to **168 × 52 pt**. Anchor the morph to the panel's **top-right corner**.
- Click anywhere on the capsule (except its play/pause button) to expand back to the full panel.
- The capsule's play/pause button only toggles the timer.
- Draggable. Right-click opens the companion context menu plus "Open Panel" and "Hide Panel".

### 2.3 Settings
- A SwiftUI `.popover` anchored to the Settings toolbar button, arrow edge `.bottom`.
- ⌘, also opens it. If the panel is hidden, show the panel first.
- Close with ×, Esc or a click outside. Closing returns to the same state.

### 2.4 Menu bar extra
- `MenuBarExtra` with a custom label: the template blossom image `menubar-blossom.svg` (monochrome, 16 pt).
- While a session (focus or break) runs, append the time left in `.monospacedDigit()`, for example `24:38`. While paused, show the time with reduced opacity.
- On Complete, show the blossom alone for 5 s. Idle shows the icon only.
- Menu style: `.menu` (native NSMenu). Contents are in §6.

---

## 3. Visual system (from Figma Foundations page)

### 3.1 Material
- **Panel, compact capsule and Settings:** `.glassEffect(.regular, in: .rect(cornerRadius: 26))`. The compact capsule uses the capsule shape.
- **Glass controls:** `.buttonStyle(.glass)`.
- **The single primary action per view:** `.buttonStyle(.glassProminent)` tinted with the state tint (§3.2).
- **Panel shadow:** soft drop shadow, y 18, blur 44, black 18%, plus y 2, blur 6, black 10%. Add a 0.75 pt inner edge of white at 65% (15% in Dark).
- **Reduce Transparency:** replace the glass with a solid `windowBackgroundColor`, keep the stroke and drop the refraction.

### 3.2 Colors (provide as Asset Catalog colors with Any/Dark appearances)

| Token | Light | Dark | Used for |
|---|---|---|---|
| `labelPrimary` | #1C1C1E | #F5F5F7 | task title, timer |
| `labelSecondary` | #6E6E73 | #A1A1A6 | status, Today row, placeholders |
| `labelTertiary` | #8E8E93 | #8E8E93 | dimmed time (End early) |
| `onTint` | #FFFFFF | #0B0B0C | icons and labels on tinted buttons |
| `tintFocus` | #1F8A3F | #30D158 | Focus state |
| `tintFocusPressed` | #176B31 | #28B84C | pressed state |
| `tintBreak` | #0E7C93 | #40C8E0 | Break state |
| `tintFlower` | #E8588A | #FF7AA2 | flower accents |
| `separator` | #D1D1D6 | #3A3A3C | |
| `progressTrack` | black 8% | white 12% | |

Paused uses `labelSecondary` as its "tint": progress fill and dimmed time.

### 3.3 Typography
- **Timer:** `.system(size: 46, weight: .semibold, design: .rounded).monospacedDigit()`, tracking −1.5%.
- **Compact timer:** rounded semibold 17. **Menu bar time:** system medium 13 with monospaced digits.
- **Task title:** 13 semibold, 1 line, truncate tail, tooltip shows the full text.
- **Status / Today row:** 12 regular, secondary.
- **Complete title:** 17 semibold. **Body:** 13 regular.

### 3.4 Shape & spacing
- **Radii (concentric):** panel 26, capsule buttons 16 (fully round), grouped sections 14, menus 12, menu items 7.
- **Panel padding:** 14 horizontal, 12 top, 14 bottom. Row spacing 10, control spacing 8, inline spacing 5.
- **Hit targets:** toolbar circles 28 pt, End circle 34 pt, primary circle 44 pt, push buttons 32 pt high.

### 3.5 Icons (Lucide, stroke 2 on a 24 grid, rendered at 16 pt, color = label)

| Use | Lucide | SF Symbol fallback |
|---|---|---|
| Settings | sliders-horizontal | slider.horizontal.3 |
| Compact View | minimize-2 | arrow.down.right.and.arrow.up.left |
| Hide Panel | eye-off | eye.slash |
| Play | play | play.fill |
| Pause | pause | pause.fill |
| End | square | stop.fill |
| Break | coffee | cup.and.saucer |
| Check | check | checkmark |
| Close | x | xmark |
| Stepper | minus, plus | minus, plus |

---

## 4. Domain model & timer engine (M1)

### 4.1 States

```swift
enum SessionPhase: Equatable {
    case ready
    case focusing(running: Bool)     // running=false → Paused (C)
    case confirmEnd(resumeRunning: Bool) // inline "End this session?" (F)
    case complete                    // D
    case onBreak(running: Bool)      // E (paused break shows same view with Resume)
    case breakOver                   // E2
}
```

### 4.2 Timer rules (date-based, never tick-counted)
- Store `endDate` while running and `remaining: TimeInterval` while paused. Derive time left as `endDate - now`. Drive the UI with `TimelineView(.periodic(from:, by: 1))`, or a 1 s `Timer` that only refreshes the view.
- Sleep/wake must not break time: on wake, recompute from `endDate`. If the session ended during sleep, go to `.complete`.
- Display format is `mm:ss`, with `h:mm:ss` only if length > 60 min. Round up so `00:00` shows only at the end.
- **Focus length:** preset 15 / 25 / 45 from the Ready segmented control, or a custom length (1–120 min) from Settings. Default 25. **Break length:** 1–60, default 5.
- Changing lengths in Settings **never** changes a running session. It applies from the next one.
- **Progress** = elapsed / total, from 0 to 1. **Companion stage:** `<0.25 → 1`, `<0.5 → 2`, `<0.75 → 3`, else `4`. Stage 4 lasts until 00:00.

### 4.3 Transitions (every one, nothing else)

| From | Event | To | Side effects |
|---|---|---|---|
| ready | startFocus(task) | focusing(running) | task = trimmed text or "Focus time"; progress 0 |
| focusing(running) | pause | focusing(paused) | freeze remaining |
| focusing(paused) | resume | focusing(running) | new endDate = now + remaining |
| focusing(any) | requestEnd | confirmEnd(resumeRunning: wasRunning) | the timer keeps its current running/paused state underneath |
| confirmEnd | keepGoing | focusing(previous running flag) | — |
| confirmEnd | confirmEnd | ready | no flower; keep the task text in the field |
| focusing(running) | reached 00:00 | complete | todayCount += 1; chime if enabled; show panel if hidden (non-activating); announce |
| complete | startBreak | onBreak(running) | uses break length |
| complete | later | ready | keep task text |
| onBreak(running) | pause / resume | onBreak(paused / running) | — |
| onBreak(any) | endBreak | breakOver | no confirm |
| onBreak(running) | reached 00:00 | breakOver | chime if enabled; **never** auto-start focus |
| breakOver | newSession | focusing(running) | same task, same focus length |
| any | quit while focusing/onBreak | — | native alert: "Quit Mellow?" / "This session will end without a flower." [Cancel] [Quit] |

A break **never** adds a flower. Ending early **never** punishes: no red, no dead plant.

### 4.4 Daily stats
- `todayCount` is stored with its date key (`yyyy-MM-dd`, local time). Reset at local midnight, checked on wake, on launch, and when the minute changes past 00:00.

### 4.5 Unit tests (required)
- Each transition in §4.3, both allowed and rejected.
- Pause/resume keeps the remaining time to ±1 s.
- Sleep simulation: advance the clock past `endDate` → `complete`.
- Stage mapping at 0, 0.249, 0.25, 0.5, 0.75 and 0.999.
- Midnight reset.
- A settings change mid-session does not change the session.

---

## 5. Panel UI by state (M2)

Common layout, top to bottom:
1. **Header row.** Companion (46 pt), then a text column (task title + status line with a 6 pt state dot or 10 pt icon), then the toolbar: Settings, Compact View, Hide Panel (28 pt glass circles, borderless until hover).
2. **Timer row.** Big time on the left, transport controls on the right.
3. **Progress capsule.** 6 pt high, full width.
4. **Today row.** Up to 5 overlapping flowers (16 pt, `flower-icon.png`, −3 pt overlap), then the label. More than 5 shows "+N" after the 5th flower, so the panel never grows.

| State | Figma | Differences |
|---|---|---|
| **A Ready** | `26:120` | Header shows the **logo** (`mellow-logo.png`, 40 pt) + "Mellow" / "Ready to focus". Then the task TextField (glass capsule, 30 pt, placeholder "What are you working on?"). Then the timer row: duration "25:00" + **Start Focus** (prominent, play icon, 36 pt). Then the segmented control "15 min / 25 min / 45 min". Then Today. |
| **B Focusing** | `26:74` | Status "Focusing · 25 min" with a green dot. Controls: **End Session** (34 pt glass circle, square icon) + **Pause** (44 pt prominent green circle, pause icon). Progress is green. |
| **C Paused** | `27:80` | Status shows a pause icon + "Paused · 24:38 left". Time in `labelSecondary`. Controls: End Session + **Resume** (play icon). Progress is gray. The companion freezes its idle motion. |
| **F End early** | `28:199` | Time is dimmed (`labelTertiary`). The transport row is replaced inline by "End this session?" (13 semibold) and "It won't grow a flower. Today's flowers stay." (12 secondary), then [Keep Going] (prominent) and [End Session] (glass), each half width. No modal. |
| **D Complete** | `28:121` | Header title "Session complete" + status with a check icon + the task name. Message: Plant "You grew a flower.", Cat "Your cat woke up.", Candle "The candle burned down.". Detail: Plant "Nice work. Rest your eyes before the next one."; Cat / Candle "Session done — one more flower for today.". Buttons: [Later] glass + [5-min Break] prominent teal with a coffee icon. The label uses the real break length. Today row shows the new flower 4 pt larger. |
| **E Break** | `27:121` | Title "Break", status coffee icon + "Step away for a bit". Teal tint. Controls: End Break + Pause/Resume. |
| **E2 Break over** | `28:163` | Title "Break's over", status "Ready when you are". Timer row shows the next focus length + **New Session** (prominent green). |

Edge cases (shown on the Screens page):
- Long task names truncate with a tooltip.
- An empty task becomes "Focus time".
- 0 sessions shows "No flowers yet today" with one faded flower.
- 12 sessions shows 5 flowers + "+7" and "12 sessions today".

---

## 6. Menu bar menu (M3) — Figma `30:201` (running) / `30:224` (idle)

**Running:**
1. "Focusing — 24:38 left" (disabled header). In Break: "On a break — 04:59 left". In Paused: "Paused — 24:38 left".
2. The task name (disabled).
3. separator
4. "Hide Panel" / "Show Panel"
5. "Pause" / "Resume"
6. "End Session" (shows the panel in confirmEnd)
7. separator
8. "Settings…" ⌘,
9. separator
10. "Quit Mellow" ⌘Q

**Idle (Ready / Complete / Break over):**
1. "Ready to focus" (disabled)
2. separator
3. "Start Focus" (starts with the current field text)
4. "Show Panel" / "Hide Panel"
5. separator
6. "Settings…" ⌘,
7. separator
8. "Quit Mellow" ⌘Q

Hiding the panel **never** stops or pauses the timer.

---

## 7. Settings (M5) — Figma `29:195`
- Title "Settings" (17 semibold) + close × (28 pt).
- Grouped inset glass sections:
  1. **Companion:** three `CompanionTile`s (Plant / Cat / Candle), 76×86, the selected one with a 2 pt tint ring. Below them: "Tip: right-click the companion in the panel to switch."
  2. **Timer:** "Focus length" stepper (1–120, shows "25 min") and "Break length" stepper (1–60).
  3. **Behavior:** "Play sound when done" (Switch, default ON; plays a preview when turned on) and "Keep panel on top" (Switch, default ON).
  4. **Appearance:** segmented "System / Light / Dark" (default System). Applies `NSApp.appearance`.
- Footnote: "New lengths apply from your next session."
- Persist everything with `@AppStorage`: `focusMinutes`, `breakMinutes`, `soundOn`, `keepOnTop`, `appearance`, `companion`, `lastTask`, `panelOrigin.<screen>`, `todayCount`, `todayKey`.

---

## 8. Companions (M6) — Figma `45:2180` (`Companion` set), board "Companions" on Screens page

`enum CompanionType: String { case plant, cat, candle }`. Default is `plant`.

| State → | Ready | Focus stage 1 / 2 / 3 / 4 | Paused | Complete | Break / Break over |
|---|---|---|---|---|---|
| **Plant** | plant-01-seed | 01-seed / 02-sprout / 03-leaves / 04-bud | current stage, motion frozen | plant-05-flower | plant-05-flower |
| **Cat** | cat-wake-01 | cat-wake-01 (breathing) | cat-wake-01 (slow breathing) | wake sequence 01→05, then hold 05 | cat-wake-05 with blink (06) |
| **Candle** | candle-body-1, unlit | body-1/2/3/4, flame lit | current body, flame at 55% | body-4, flame out | body-4, unlit |

- **Switching:** Settings tiles, or right-click / Control-click the companion in the panel or capsule. The context menu (Figma `45:2268`) shows "Companion" header, then ✓ Plant / Cat / Candle, then a separator, then "Settings…".
- On switch: 250 ms cross-fade. The session, progress and flower count are unchanged. The new companion shows at the current stage.
- **Candle composition:** the body image fills the companion box. The flame is a separate layer, about 0.36 × box width, horizontally centred. Its base (at 83% of the flame image height) sits on the wick top. The wick top is at `box.minY + (116 + k) / 512 × bodyHeight`, where k = 0 / 20 / 40 / 60 for bodies 1–4. Keep the flame base fixed while it animates.
- **Cat:** all frames share the same canvas and resting baseline (y = 395/512). Swap frames in place.
- Every companion yields exactly one flower per completed focus session.

---

## 9. Copy deck (use verbatim)

**Ready**
- Placeholder: "What are you working on?"
- Empty task: "Focus time"
- Start button: "Start Focus"
- Presets: "15 min", "25 min", "45 min"

**Status lines**
- "Focusing · 25 min"
- "Paused · 24:38 left"
- "Step away for a bit"
- "Ready when you are"
- "Ready to focus"

**Buttons**
- "Pause", "Resume"
- "End Session", "Keep Going"
- "5-min Break" (use the real break length), "Later"
- "End Break", "New Session"

**End early**
- "End this session?" / "It won't grow a flower. Today's flowers stay."

**Complete**
- Plant: "You grew a flower." / "Nice work. Rest your eyes before the next one."
- Cat and Candle: see §5, row D.

**Break over**
- "Break's over"

**Today row**
- "No flowers yet today"
- "1 session today"
- "N sessions today"

**Settings**
- "Companion", "Focus length", "Break length"
- "Play sound when done", "Keep panel on top"
- "Appearance" — "System" / "Light" / "Dark"
- "New lengths apply from your next session."

**Tooltips**
- "Settings"
- "Compact View"
- "Hide Panel — timer keeps running"
- "Open Panel"
- "Pause", "Resume", "End Session"
- Companion tooltip: "Leaves · 62% grown" (stage name + percent)

**Quit alert**
- Title: "Quit Mellow?"
- Message: "This session will end without a flower."
- Buttons: "Cancel", "Quit"

---

## 10. Interactions, shortcuts & motion (M7)

Full table: Figma page **Interactions**. Animated references: Figma page **Motion** (select a frame → Play).

### 10.1 Keyboard (only while the panel is key or the app is active, plus menu shortcuts)

| Key | Action |
|---|---|
| Space | Start / Pause / Resume (the current primary action) |
| Return | Start Focus (in the field) / Keep Going / 5-min Break / New Session |
| Esc | Keep Going (in confirm) / Later (in Complete) / close Settings |
| ⌘. | End Session / End Break |
| ⌘M | Compact View ↔ panel |
| ⌘W | Hide Panel |
| ⌘, | Settings |
| ⌘Q | Quit |
| ⌘L | Focus the task field |
| 1 / 2 / 3 | Pick 15 / 25 / 45 in Ready |

Every control needs a visible keyboard focus ring (2 pt tint) and an `accessibilityLabel` equal to its tooltip.

### 10.2 Motion spec

| Animation | Trigger | Implementation | Reduce Motion |
|---|---|---|---|
| Stage change | progress crosses a quarter | `.contentTransition(.opacity)` 250 ms easeOut + scale 0.97→1 | cross-fade only |
| Plant sway | while running | rotation −2°↔+2°, anchor = pot base (UnitPoint(x: 0.5, y: 0.84)), 2 s per swing, easeInOut, `.phaseAnimator` | off |
| Bloom | focus ends | bud→flower cross-fade + scale 0.9→1 spring (response 0.4, dampingFraction 1) | fade |
| New flower | 400 ms after bloom | scale 0.2→1.18→1 + fade in, 400 ms | fade |
| Cat breathing | while running (paused: 4 s cycle) | scaleY 1↔1.018, anchor = baseline (y 395/512), 1.5 s in / 1.5 s out | off |
| Cat wake | focus ends | `TimelineView(.animation)`, frames 01→05 at 6 fps, hold 05 | jump to 05 |
| Cat blink | 1 s after waking, then every 8–12 s in Break | 05→06 for 200 ms →05 | off |
| Candle flicker | while running | cross-fade flame 01→02→03, 800 ms each + scaleY 1↔1.04, anchor = flame base. Paused: 1600 ms, opacity 0.55 | static flame-01 |
| Candle burn-down | each quarter | body cross-fade 250 ms; flame moves down with the wick | keep |
| Candle blow-out | focus ends | flame opacity 1→0 + scaleY 1→0.6, 500 ms easeIn | fade |
| Panel ↔ Compact | ⌘M, button, capsule click | `NSPanel.setFrame(_:display:animate:)`, or a SwiftUI `matchedGeometryEffect` morph anchored top-right; spring response 0.35, damping 1; content cross-fade 150 ms | cross-fade, no size tween |
| Pause/Resume press | mouse-down | scale 0.94 for 80 ms, spring back; pause↔play icon `.contentTransition(.symbolEffect(.replace))` or a 150 ms cross-fade; time opacity 1↔0.45 | no scale |
| Focus→Break tint | 5-min Break | tint color cross-fade 300 ms easeInOut; progress resets | instant |
| Popover / menu | open/close | system default | system |
| Hide / Show | button / menu | fade + scale 0.98, 200 ms | fade |
| Digits | duration change | `.contentTransition(.numericText())` | none |

### 10.3 Sound
- One soft chime at the end of a focus and at the end of a break, if "Play sound when done" is ON.
- Use a short, gentle bundled sound (≤1 s), or `NSSound(named: "Glass")` as a placeholder.
- Respect system volume. No sound on start, pause or switching.

### 10.4 Accessibility announcements
Post `AccessibilityNotification.Announcement` for:
- "Focus started, 25 minutes"
- "Session complete. You grew a flower."
- "Break started"
- "Break over"

---

## 11. Assets (`./Assets/`)

All PNGs are transparent. Add them to `Assets.xcassets` as single-scale images: 512² renders crisply up to 128 pt @2x.

| File | Size | Use |
|---|---|---|
| plant-01-seed … plant-05-flower.png | 512² | Plant companion stages; the pot is locked to the same position in every stage |
| cat-wake-01 … 06.png | 512² | 01 asleep, 02 head starting to lift, 03 eyes slit, 04 eyes half open, 05 awake, 06 blink. Shared baseline. |
| candle-body-1 … 4.png | 512² | Wax heights (1 = full). The wick moves down 20 px (at 512) per step. |
| flame-01-center / 02-left / 03-right.png | 512² | Flame frames; base at y ≈ 424/512 |
| flower-icon.png | 256² | Today-row flower (same blossom as the logo) |
| mellow-logo.png / mellow-logo-1024.png | 512² / 1024² | Ready header logo, About, app icon foreground |
| menubar-blossom.svg | 16 pt template | Menu bar icon. Set "Render As: Template Image". |

The wallpapers in Figma are only for mockups. Do not ship them.

---

## 12. Figma node map (fileKey `iVm5j9tzNuOu4nreImQWAA`)

**Pages:** Overview `0:1`, Foundations `2:2`, Components `2:3`, Screens `2:4`, Prototype `2:5`, Assets & Mascots `2:6`, Interactions, Motion.

| Component | Node | Component | Node |
|---|---|---|---|
| Panel/Ready | 26:120 | Button (capsule) | 13:82 |
| Panel/Focus | 26:74 | CircleButton | 22:70 |
| Panel/Paused | 27:80 | TextField | 25:45 |
| Panel/Confirm end | 28:199 | SegmentedControl | 25:51 |
| Panel/Complete | 28:121 | Switch | 25:62 |
| Panel/Break | 27:121 | Stepper | 25:63 |
| Panel/Break over | 28:163 | Progress | 25:102 |
| Compact | 29:194 | TodayRow | 26:73 |
| Settings | 29:195 | Companion | 45:2180 |
| MenuBarItem | 30:200 | CompanionTile | 45:2248 |
| Menu/Running | 30:201 | Menu/Companion | 45:2268 |
| Menu/Idle | 30:224 | Logo / App Icon | 40:269 / 40:270 |
| Icons (Lucide) | section 4:2 | Menu bar glyph | 40:285 |

---

## 13. Out of scope for v1 (do not build)

- Accounts or servers.
- Friends, leaderboards, a store or AI.
- App or website blocking.
- Statistics pages beyond today's count.
- Water or other reminders.
- System notifications (completion is shown in the panel plus sound only).
- Multiple tasks or a task list.
- Auto-starting breaks or focus.
- Any punishment mechanic.

---

## 14. Acceptance checklist

**M1 Engine**
- [ ] All tests in §4.5 pass.
- [ ] The timer survives sleep/wake and display changes.

**M2 Panel**
- [ ] All 7 states match Figma within ±2 pt and the colors in §3.2, in Light and Dark.
- [ ] The panel never steals focus. The drag region excludes buttons.
- [ ] Long task names truncate and show a tooltip. 0 and many sessions render correctly.

**M3 Menu bar**
- [ ] The label shows the blossom plus time while running.
- [ ] The menu items match §6 for each state.
- [ ] Hide/Show never affects the timer.

**M4 Compact**
- [ ] Morphs at the top-right anchor.
- [ ] Clicking the capsule expands it. Its button only toggles the timer.
- [ ] Position is remembered per display.

**M5 Settings**
- [ ] Persists across relaunch.
- [ ] Length changes apply only to the next session.
- [ ] Theme switching works live. Keep-on-top switches the window level.

**M6 Companions**
- [ ] Switching from Settings and from right-click keeps progress.
- [ ] Stage mapping is correct for all 3 types.
- [ ] The candle flame stays on the wick at every wax height.

**M7 Polish**
- [ ] Every animation in §10.2 is implemented and Reduce Motion is respected.
- [ ] Reduce Transparency gives a solid panel.
- [ ] VoiceOver labels and announcements, keyboard shortcuts and visible focus rings all work.
- [ ] The chime toggle works.
- [ ] The Quit alert appears only during a session.

When you finish each milestone, report what you built, which checklist items pass, and anything you deviated from with the reason.
