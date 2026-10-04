import SwiftUI

/// Procedural life on top of the mascot sprites: breathing, sway, little idle actions
/// (hop, wiggle, stretch, tilt…), reactions (waking up, being poked, finishing) and
/// small per-mascot effects (sleepy z's, coffee steam, twinkling stars, candle glow, petals).
/// Everything is a pure function of time, so one TimelineView drives it all.
struct MascotPose {
    var scaleX = 1.0, scaleY = 1.0, angle = 0.0, dx = 0.0, dy = 0.0
}

/// What happened to the mascot, and when.
struct MascotEvents {
    var wake: Date?
    var poke: Date?
    var completed: Date?
}

enum MascotMood: Equatable {
    case idle      // ready / waiting
    case working   // a focus session is running
    case sleeping  // paused
    case resting   // break, or done
}

enum MascotMotion {
    /// One knob for the pace of every motion and effect (1 = the original speed).
    static let tempo = 0.75
    enum Action: CaseIterable { case hop, wiggle, stretch, tilt, flicker, float }

    /// The idle actions each mascot can pick from.
    static func actions(for type: CompanionType) -> [Action] {
        switch type {
        case .plant: [.wiggle, .stretch, .tilt]
        case .cat: [.stretch, .hop, .tilt]
        case .candle: [.flicker, .wiggle, .stretch]
        case .fox: [.hop, .tilt, .wiggle]
        case .coffee: [.hop, .wiggle, .tilt]
        case .moon: [.float, .tilt, .float]
        case .cactus: [.wiggle, .stretch, .hop]
        }
    }
    private static func swayDegrees(_ type: CompanionType) -> Double {
        switch type {
        case .plant: 3
        case .moon: 4
        case .cactus, .candle, .fox: 1.8
        case .cat, .coffee: 1.2
        }
    }
    static func seed(_ type: CompanionType) -> Int { (CompanionType.allCases.firstIndex(of: type) ?? 0) + 1 }

    static func pose(_ type: CompanionType, mood: MascotMood, events: MascotEvents, at date: Date, size: CGFloat) -> MascotPose {
        var pose = MascotPose()
        let t = date.timeIntervalSinceReferenceDate * tempo
        let s = Double(seed(type))

        // Breathing: slower and deeper while asleep.
        let (period, depth): (Double, Double) = switch mood {
        case .working: (3.2, 0.028)
        case .sleeping: (4.6, 0.04)
        case .resting: (3.8, 0.022)
        case .idle: (3.6, 0.02)
        }
        let breath = sin(2 * .pi * t / period + s)
        pose.scaleY *= 1 + depth * breath
        pose.scaleX *= 1 - depth * 0.55 * breath
        if mood == .sleeping { pose.scaleY *= 0.965; pose.angle -= 3 } // slumped

        // Sway; the moon also floats on its cloud.
        let sway = mood == .sleeping ? 0.4 : 1
        pose.angle += swayDegrees(type) * sway * sin(2 * .pi * t / 6.5 + s * 1.7)
        if type == .moon { pose.dy += 1.6 * sin(2 * .pi * t / 4.2) }

        // An idle action every few seconds while working or resting.
        if mood == .working || mood == .resting {
            let slot = 7.5
            let k = Int(floor(t / slot))
            if random(k, s, 1) < 0.75 {
                let start = Double(k) * slot + 1 + random(k, s, 2) * (slot - 3)
                let duration = 1.3
                let p = (t - start) / duration
                if p >= 0 && p < 1 {
                    let list = actions(for: type)
                    apply(list[Int(random(k, s, 3) * Double(list.count)) % list.count], p, size, &pose)
                }
            }
        }

        // Reactions.
        if let wake = events.wake { react(.hop, since: wake, at: date, duration: 0.75, size: size * 1.2, &pose) }
        if let poke = events.poke {
            react(.hop, since: poke, at: date, duration: 0.7, size: size, &pose)
            react(.wiggle, since: poke, at: date, duration: 0.9, size: size, &pose)
        }
        if let done = events.completed { react(.hop, since: done, at: date, duration: 0.9, size: size * 1.5, &pose) }
        return pose
    }

    private static func react(_ action: Action, since start: Date, at date: Date, duration: Double, size: CGFloat, _ pose: inout MascotPose) {
        let p = date.timeIntervalSince(start) * tempo / duration
        if p >= 0 && p < 1 { apply(action, p, size, &pose) }
    }

    /// One action at progress `p` (0…1).
    private static func apply(_ action: Action, _ p: Double, _ size: CGFloat, _ pose: inout MascotPose) {
        let bell = sin(.pi * p)
        switch action {
        case .hop:
            // Crouch, jump, land with a little squash.
            if p < 0.18 {
                let q = sin(.pi * p / 0.18)
                pose.scaleY *= 1 - 0.1 * q; pose.scaleX *= 1 + 0.07 * q
            } else if p < 0.82 {
                let q = (p - 0.18) / 0.64
                pose.dy -= Double(size) * 0.16 * sin(.pi * q)
                pose.scaleY *= 1 + 0.05 * sin(.pi * q); pose.scaleX *= 1 - 0.03 * sin(.pi * q)
            } else {
                let q = sin(.pi * (p - 0.82) / 0.18)
                pose.scaleY *= 1 - 0.08 * q; pose.scaleX *= 1 + 0.05 * q
            }
        case .wiggle:
            pose.angle += 8 * sin(2 * .pi * 3 * p) * (1 - p)
        case .stretch:
            pose.scaleY *= 1 + 0.11 * bell; pose.scaleX *= 1 - 0.05 * bell
        case .tilt:
            pose.angle += 10 * sqrt(bell)
        case .flicker:
            let f = 1 + 0.035 * sin(2 * .pi * 7 * p) * bell
            pose.scaleX *= f; pose.scaleY *= 2 - f
        case .float:
            pose.dy -= Double(size) * 0.09 * bell
        }
    }

    /// Stable pseudo-random number in 0..<1.
    static func random(_ k: Int, _ seed: Double, _ salt: Int) -> Double {
        var x = UInt64(bitPattern: Int64(k &* 73_856_093 ^ Int(seed) &* 19_349_663 ^ salt &* 83_492_791))
        x ^= x >> 33; x &*= 0xff51_afd7_ed55_8ccd
        x ^= x >> 33; x &*= 0xc4ce_b9fe_1a85_ec53
        x ^= x >> 33
        return Double(x % 10_000) / 10_000
    }

    // MARK: Effects

    /// Drawn behind the sprite (candle glow).
    static func drawBack(_ context: inout GraphicsContext, canvas: CGSize, type: CompanionType, mood: MascotMood, at date: Date, size: CGFloat) {
        guard type == .candle, mood == .working || mood == .resting else { return }
        let t = date.timeIntervalSinceReferenceDate * tempo
        let pulse = 0.55 + 0.25 * sin(2 * .pi * t / 1.7) + 0.08 * sin(2 * .pi * t * 3.1)
        let center = CGPoint(x: canvas.width / 2, y: canvas.height / 2 - size * 0.22)
        let radius = size * 0.42
        let gradient = Gradient(colors: [Color.orange.opacity(0.32 * pulse), Color.orange.opacity(0)])
        context.fill(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
                     with: .radialGradient(gradient, center: center, startRadius: 0, endRadius: radius))
    }

    /// Drawn over the sprite (z's, steam, stars, petals).
    static func drawFront(_ context: inout GraphicsContext, canvas: CGSize, type: CompanionType, mood: MascotMood,
                          events: MascotEvents, at date: Date, size: CGFloat) {
        let t = date.timeIntervalSinceReferenceDate * tempo
        let mid = CGPoint(x: canvas.width / 2, y: canvas.height / 2)

        if mood == .sleeping {
            // Three z's drifting up and to the right.
            for i in 0..<3 {
                let p = (t / 2.6 + Double(i) / 3).truncatingRemainder(dividingBy: 1)
                let x = mid.x + size * (0.22 + 0.22 * p) + 2 * sin(p * 6)
                let y = mid.y - size * (0.2 + 0.45 * p)
                let opacity = sin(.pi * p)
                context.draw(Text("z").font(.system(size: size * (0.16 + 0.12 * p), weight: .bold, design: .rounded))
                                .foregroundStyle(Color.secondary.opacity(opacity)), at: CGPoint(x: x, y: y))
            }
        }

        if type == .coffee && (mood == .working || mood == .resting) {
            // Soft steam puffs rising from the cup.
            var steam = context
            steam.addFilter(.blur(radius: size * 0.035))
            for i in 0..<4 {
                let p = (t / 2.2 + Double(i) / 4).truncatingRemainder(dividingBy: 1)
                let x = mid.x - size * 0.06 + size * 0.07 * sin(p * 7 + Double(i)) + size * 0.05 * Double(i % 2)
                let y = mid.y - size * (0.22 + 0.42 * p)
                let r = size * (0.04 + 0.05 * p)
                steam.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                           with: .color(.white.opacity(0.55 * sin(.pi * p))))
            }
        }

        if type == .moon && mood != .sleeping {
            // Little stars that twinkle in turn.
            let spots: [(Double, Double)] = [(-0.42, -0.38), (0.44, -0.28), (0.36, 0.3), (-0.46, 0.18)]
            for (i, spot) in spots.enumerated() {
                let glow = pow(max(0, sin(2 * .pi * (t / 2.8 + Double(i) * 0.27))), 3)
                guard glow > 0.02 else { continue }
                context.draw(Text("✦").font(.system(size: size * (0.12 + 0.05 * glow)))
                                .foregroundStyle(Color(red: 1, green: 0.85, blue: 0.42).opacity(glow)),
                             at: CGPoint(x: mid.x + size * spot.0, y: mid.y + size * spot.1))
            }
        }

        if (type == .plant || type == .cactus) && mood == .working {
            // Now and then a sparkle of growth near the top.
            let slot = 5.0
            let k = Int(floor(t / slot))
            let p = (t - Double(k) * slot) / 1.4
            if p < 1 && random(k, Double(seed(type)), 9) < 0.6 {
                let x = mid.x + size * (random(k, 1, 4) - 0.5) * 0.6
                let y = mid.y - size * (0.32 + 0.12 * p)
                context.draw(Text("✦").font(.system(size: size * 0.14))
                                .foregroundStyle(Color(red: 1, green: 0.78, blue: 0.86).opacity(sin(.pi * p))),
                             at: CGPoint(x: x, y: y))
            }
        }

        if let done = events.completed {
            // A burst of petals when the session is complete.
            let elapsed = date.timeIntervalSince(done) * tempo
            let duration = 1.8
            if elapsed >= 0 && elapsed < duration {
                let p = elapsed / duration
                for i in 0..<14 {
                    let angle = Double(i) / 14 * 2 * .pi + random(i, 3, 5)
                    let speed = size * (0.55 + 0.4 * random(i, 3, 6))
                    let x = mid.x + cos(angle) * speed * p
                    let y = mid.y - size * 0.1 + sin(angle) * speed * p * 0.8 + size * 0.6 * p * p // falls
                    let r = size * 0.05
                    var petal = context
                    petal.translateBy(x: x, y: y)
                    petal.rotate(by: .radians(angle + p * 6))
                    let colors: [Color] = [Color(red: 0.97, green: 0.66, blue: 0.77), Color(red: 1, green: 0.85, blue: 0.42), .white]
                    petal.fill(Path(ellipseIn: CGRect(x: -r, y: -r * 0.6, width: r * 2, height: r * 1.2)),
                               with: .color(colors[i % colors.count].opacity(1 - p)))
                }
            }
        }
    }
}
