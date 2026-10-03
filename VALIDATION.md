# Mellow validation — 2026-10-03

## Automated checks

- Swift 6 core compiled and all **9 Swift Testing tests passed**.
- The transition test covers **90 state/event combinations**, including rejected actions.
- Clock tests cover pause/resume precision, sleep past the deadline, completion exactly once, confirmation expiry, early ending, break completion without flowers, formatting, quarter-stage boundaries, local midnight, and next-session settings.
- Xcode **Release build succeeded** for both **arm64 and x86_64**, deployment target macOS 26.0.
- The delivered `Build/Mellow.app` passes `codesign --verify --deep`; it has a local ad-hoc signature.
- All **22 original handoff assets** exist in the catalog, are nonempty, and have unchanged file sizes. Every Light/Dark color token's opacity was checked; named colors were also resolved through AppKit in both appearances.

## Native UI checks

The app was launched on this Mac and inspected through its accessibility tree and native screenshots.

| Milestone | Observed result |
| --- | --- |
| M1 Engine | Automated checks above passed. |
| M2 Panel | Entered Ready, Focus, Paused, Confirm End, Complete, Break, and Break Over. The content is 300 pt wide. Transport controls, task text, progress, and Today row render. Empty text starts as “Focus time”. |
| M3 Menu bar | Native MenuBarExtra and state-dependent menu compile; Hide/Show and Settings are wired to the same model. The separate status-item menu has not received a full UI walkthrough. |
| M4 Compact | Entered the 168 × 52 pt capsule, then expanded it by clicking its content. Hiding the running panel and reopening with ⌘, preserved the running clock. |
| M5 Settings | Duration, companion, and appearance changes work. A mid-session duration change did not alter the active timer. 25-min focus, 5-min break, System appearance, and Plant were restored. Settings persisted after relaunch. |
| M6 Companions | Plant, Cat, and Candle rendered; Candle's wax and flame changed during a real 1-min session. Switching through Settings and the context menu retained the session. Completion awarded exactly one flower. |
| M7 Polish | Quit during a session showed the specified native alert. Keyboard shortcuts, empty-task Return, context menu, sound preference, and Light/Dark rendering were exercised. Reduce Motion/Transparency and VoiceOver support are implemented but were not toggled globally on the user's Mac. |

Rendered snapshots of all seven panel states, the compact capsule and Settings: `Build/Screenshots/`. Regenerate them from a Debug build with `MELLOW_SNAPSHOT_DIR=<folder> Mellow.app/Contents/MacOS/Mellow` (add `MELLOW_SNAPSHOT_DARK=1` for Dark). Offscreen rendering does not reproduce Liquid Glass exactly, so the live panel can look slightly different.

## Implementation choices and limits

- Native Liquid Glass follows the actual OS backdrop, so its material differs from Figma's gray mockup background. Mockup wallpapers are not shipped.
- Buttons, segmented controls, switches and steppers are drawn to the Figma component specs instead of `.glassProminent` / native controls. The panel is non-activating, so native controls rendered in their inactive (washed-out gray) style; the custom styles keep the tint colors at all times and expose the same accessibility roles.
- Icons are the Figma file's Lucide SVGs, bundled as template vector assets.
- Settings use an injectable UserDefaults-backed observable model rather than property wrappers for storage, allowing the same engine and persistence code to be tested without touching the app's preferences.
- Settings is a popover whose sections follow Figma node 29:195. Every state was compared visually with its Figma frame; a pixel-by-pixel ±2 pt audit has not been performed.
- The app icon uses the provided blossom PNG. Separate Icon Composer glass layers were not authored.
- A session that expires while its end confirmation is visible completes normally and earns its flower. Next-session settings also take precedence for New Session. Both choices are marked with `// NOTE:` and covered by tests.
- Actual OS sleep, multi-monitor hot-plug, fullscreen Spaces, and a full VoiceOver walkthrough remain device-level checks. The clock's sleep and midnight behavior were tested with an injected clock.
- Distribution through the App Store or to other Macs requires the owner's Developer ID/App Store signing and notarization. The current bundle is intended for local use.

## Update — plan, music, mascots (2026-10-03)

- 11 Swift Testing tests pass (new: plan order with automatic breaks, early end keeps the task pending).
- Debug and Release builds succeed; 13 CC0 mp3 files are bundled (app ≈ 96 MB).
- Snapshots `10-plan.png`, `11-plan-break.png`, `12-mascots.png` in `Build/Screenshots/`.
- Compact ↔ panel now morphs the glass with a spring and pins the content top-right; the window grows first and shrinks after the animation. Hide/show slides the panel into and out of the menu bar item. These animations and the single-click expand (WindowDragGesture + tap) were built but could not be watched on screen from here; check them on device.
- Mascots: 11 sprite sheets generated in ChatGPT, sliced with a shared baseline; also placed on the Figma page "Assets & Mascots" (board "Mascots v2").

## Audit — 2026-10-03

Fixed:
- **Confirm-end timer** was drawn in the normal label color; it is dimmed (`labelTertiary`) again as in Figma.
- **Compact capsule button** paused/started the wrong thing in Confirm End and Complete; it now opens the panel there and shows matching icons and tooltips.
- **Settings from a hidden or compact panel** opened the popover while the panel was still moving; it now waits for the panel to settle.
- **Hide/show race**: showing the panel while it was fading or tucking away (including with Reduce Motion) could still close it. A dedicated state now lets show() win. After a display change while hidden, the panel comes back to a clamped spot.
- **Energy**: the session clock publishes once per second instead of four times; the timer has tolerance; mascots redraw at their 5 fps only while running and stop after the finale (they no longer redraw at 30 fps forever); sprite frame lookups are cached. Pausing still captures the exact remaining time.
- **Dead code and art**: the old plant / cat / candle renderers and 13 unused images were removed (originals stay in `Mellow-handoff/Assets`). `create_project.py` no longer copies them back over the new sprite frames.
- **App size**: music re-encoded from 320 kbps mp3 to 160 kbps AAC; the app went from 96 MB to 53 MB. Original mp3 files are in `Mellow-handoff/Music-original/`.
- **Plan list** height no longer cuts the last row by the separators; rows keep their buttons reachable for VoiceOver.
- **Links** accept `instagram.com/name` without `https://`.
- **Snapshot tool** used nine preference domains and left them behind; it now uses one scratch domain and wipes it.
- Info.plist gains `LSApplicationCategoryType` (Productivity); Release enables the hardened runtime.

Checked and left as is:
- The thin vertical ticks at the ends of capsule strokes in `Build/Screenshots` come from AppKit's `cacheDisplay` rasterizer used by the snapshot tool. The same views rendered with SwiftUI's `ImageRenderer` have no ticks; the live app is unaffected.

Still to verify on device: the morph, the menu bar tuck animation, single-click expand, and the Mellow menu bar icon (it may be hidden behind the notch when the menu bar is full).

## Crash fix — compact ↔ panel (2026-10-03)

- **Symptom:** the app quit while switching between the compact capsule and the full panel.
- **Cause:** `NSGenericException` — "more Update Constraints in Window passes than there are views". Two things resized the window at once:
  - the NSHostingView, as the window's content view, animated the window size itself (`updateAnimatedWindowSize`);
  - `resize(contentSize:)` set the frame from inside SwiftUI's layout pass.
- **Fix:**
  - the hosting view now sits in a plain container view, so SwiftUI no longer resizes the window;
  - window size changes are applied on the next run-loop turn and coalesced.
- **Verification:** new Debug-only stress test, `MELLOW_STRESS=<cycles> [MELLOW_STRESS_PAUSE=<s>]`. It drives the real panel through compact/expand, hide/show, settings and session changes.
  - Before the fix it crashed within 60 cycles.
  - After the fix: 3 × 120 cycles at mixed speeds, plus 150 cycles each at 20 ms, 120 ms and 300 ms. All exited cleanly, with no console warnings.

## Smooth morphing and onboarding (2026-10-03)

- The panel window is now a fixed transparent canvas, and one shared glass background springs between sizes (spring 0.5 s, bounce 0.14). This covers panel ↔ compact, onboarding pages and taller or shorter states. Content is masked to the glass, so nothing is cut off or spills outside while it moves. Content blurs in after the glass starts moving and leaves quickly.
- Outside the glass, clicks pass through to the apps behind: `ignoresMouseEvents` follows the pointer, using global and local mouse-moved monitors.
- Hide/show into the menu bar now adds a blur and uses springier timing.
- First-run onboarding has 4 steps:
  1. welcome, with the author's social icons (Instagram, X, LinkedIn, Threads, YouTube);
  2. companion;
  3. focus and break length, sound, keep on top;
  4. lofi music with a preview, and appearance.
  Settings shares the same section views; "Show Welcome Again" reopens it.
- Snapshots `13-onboarding-1…4.png`.
- Stress: 150 cycles each at 20 ms, 150 ms and 500 ms, now including onboarding open/close. All clean. The stress run restores the real `onboarded` flag afterwards.

## Full audit, second pass (2026-10-03)

Two review passes, one on window/engine/concurrency and one on SwiftUI/UX/accessibility. Fixed:

- **Window:**
  - Hiding the panel while it was still sliding out of the menu bar saved a half-way spot as its home. It now returns to its real position.
  - The position is saved once and restored on whichever display it was left on. Before, it was saved per display name and read back only for the main display.
  - No crash when no display is attached (clamshell login).
  - Toggling Reduce Motion between hide and show no longer stops the position from being saved.
- **Energy:**
  - The clock timer runs only while a timer is running. An idle or hidden Mellow no longer wakes 4×/s; the midnight reset uses `NSCalendarDayChanged`.
  - The mouse gate is skipped while the panel is hidden.
  - Mascot sprites and the music equalizer stop drawing while the panel is hidden.
- **Engine:**
  - "New Session" after a finished plan clears the plan and uses the task field, not the last plan task's title.
  - A session that ended before midnight while the Mac slept no longer counts for the next day.
- **Behavior:**
  - Settings can't be queued during onboarding and pop up later. The delayed open is also cancelled if the panel was hidden or collapsed in the meantime.
  - ⌘L from the compact capsule now focuses the task field.
  - The menu's "End Session" during the end confirmation shows the panel instead of doing nothing.
  - Space no longer triggers "Keep Going" while the end confirmation has a focused button.
  - The quit alert takes keyboard focus.
  - With a plan, the focus-length presets step aside, since each task has its own length; presets now match onboarding (15/25/45/60, keys 1–4).
  - Turning "music during focus" on no longer stops the onboarding preview; ⌘W during onboarding stops it.
  - "Show Welcome Again" is disabled, with a tooltip, while a session runs.
  - The onboarding button is now "Done" with a check, since it does not start a timer.
- **Look and accessibility:**
  - Labels added for icon-only buttons (plan row remove/±, next track, music preview); plan rows are adjustable with VoiceOver and the keyboard.
  - The task field carries its own label and focus.
  - The timer reads "Focus length" when idle.
  - No one-frame flower flash before it blooms; a short "N today" label when the music controls share the row.
  - Compact text shrinks slightly instead of truncating.
  - The off switch has a visible outline in Light.
- **Verification:** 13 unit tests (2 new), 17 snapshots, and a 150-cycle stress run at 60 ms all pass.
