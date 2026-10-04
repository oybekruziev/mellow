import AppKit
import Observation

/// Checks GitHub Releases for a newer Mellow and installs it in place.
///
/// - The newest release comes from `api.github.com/repos/<repo>/releases/latest`;
///   its tag (`v1.1`) is the version and its `.dmg` asset is the update.
/// - Mellow checks a few seconds after launch and then once a day. When an update is found it
///   says so (unless the user skipped that version, or a session is running — then only the
///   menu shows it). "Check for Updates…" always asks right away.
/// - Before anything is replaced, the downloaded app must carry Oybek Ruziev's Developer ID
///   signature and pass Gatekeeper. If Mellow can't replace itself (a read-only location),
///   it opens the disk image so the user can drag the new version over.
@MainActor @Observable
final class Updater {
    struct Release: Equatable {
        let version: String
        let notes: String
        let dmg: URL
        let page: URL
    }
    enum State: Equatable {
        case idle, checking, downloading, installing
        case available(Release)
        case failed(String)
    }

    private(set) var state: State = .idle
    var available: Release? { if case .available(let release) = state { release } else { nil } }

    static let repository = "oybekruziev/mellow"
    /// The Developer ID team every update must be signed by.
    static let teamID = "79CTV95T7T"
    private static let checkInterval: TimeInterval = 24 * 60 * 60

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var timer: Timer?
    /// True while a session runs: an automatic check then only marks the menu.
    @ObservationIgnored var isBusy: () -> Bool = { false }
    /// Called right before Mellow quits to relaunch into the new version.
    @ObservationIgnored var willRelaunch: () -> Void = {}

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var currentVersion: String {
        #if DEBUG
        if let fake = ProcessInfo.processInfo.environment["MELLOW_UPDATE_CURRENT"] { return fake }
        #endif
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }
    private var feedURL: URL {
        #if DEBUG
        if let feed = ProcessInfo.processInfo.environment["MELLOW_UPDATE_FEED"], let url = URL(string: feed) { return url }
        #endif
        return URL(string: "https://api.github.com/repos/\(Self.repository)/releases/latest")!
    }

    // MARK: Checking

    func start() {
        #if DEBUG
        // Test hook: with a fake feed, check right away instead of once a day.
        if ProcessInfo.processInfo.environment["MELLOW_UPDATE_FEED"] != nil {
            Task { await check(userInitiated: false) }
            return
        }
        #endif
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in self?.checkIfDue() }
        let timer = Timer(timeInterval: 60 * 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkIfDue() }
        }
        timer.tolerance = 10 * 60
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func checkIfDue() {
        let last = defaults.object(forKey: "updateLastCheck") as? Date ?? .distantPast
        guard Date.now.timeIntervalSince(last) >= Self.checkInterval else { return }
        Task { await check(userInitiated: false) }
    }

    /// `userInitiated`: from "Check for Updates…" — always answers, even "you're up to date".
    func check(userInitiated: Bool) async {
        switch state {
        case .checking, .downloading, .installing: return
        default: break
        }
        state = .checking
        do {
            let release = try await fetchLatest()
            defaults.set(Date.now, forKey: "updateLastCheck")
            guard let release, Self.isNewer(release.version, than: currentVersion) else {
                state = .idle
                if userInitiated { showUpToDate() }
                return
            }
            state = .available(release)
            #if DEBUG
            if ProcessInfo.processInfo.environment["MELLOW_UPDATE_AUTOINSTALL"] != nil { await install(release); return }
            #endif
            let skipped = defaults.string(forKey: "updateSkippedVersion") == release.version
            if userInitiated || (!skipped && !isBusy()) { offer(release) }
        } catch {
            state = .idle
            if userInitiated { showError("Couldn't check for updates", error) }
        }
    }

    private func fetchLatest() async throws -> Release? {
        var request = URLRequest(url: feedURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Mellow/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse {
            if http.statusCode == 404 { return nil } // no release published yet
            guard http.statusCode == 200 else { throw UpdateError.server(http.statusCode) }
        }
        let feed = try JSONDecoder().decode(GitHubRelease.self, from: data)
        guard !feed.draft, !feed.prerelease,
              let asset = feed.assets.first(where: { $0.name.lowercased().hasSuffix(".dmg") }) else { return nil }
        let version = feed.tagName.hasPrefix("v") ? String(feed.tagName.dropFirst()) : feed.tagName
        return Release(version: version, notes: Self.plainText(feed.body ?? ""), dmg: asset.browserDownloadURL, page: feed.htmlURL)
    }

    static func isNewer(_ candidate: String, than current: String) -> Bool {
        candidate.compare(current, options: .numeric) == .orderedDescending
    }

    /// Release notes are Markdown; the alert shows them as short plain text.
    static func plainText(_ markdown: String) -> String {
        let lines = markdown.components(separatedBy: .newlines).compactMap { line -> String? in
            var line = line.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("SHA-256") || line == "---" { return nil }
            while line.hasPrefix("#") { line.removeFirst() }
            if line.hasPrefix("- ") || line.hasPrefix("* ") { line = "• " + line.dropFirst(2) }
            for mark in ["**", "`"] { line = line.replacingOccurrences(of: mark, with: "") }
            return line.trimmingCharacters(in: .whitespaces)
        }
        var text = lines.joined(separator: "\n")
        while text.contains("\n\n\n") { text = text.replacingOccurrences(of: "\n\n\n", with: "\n\n") }
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.count > 700 ? String(text.prefix(700)) + "…" : text
    }

    // MARK: Asking

    /// Shows the update and what to do with it.
    func offer(_ release: Release) {
        NSApp.activate()
        let alert = NSAlert()
        alert.icon = NSApp.applicationIconImage
        alert.messageText = "Mellow \(release.version) is available"
        var info = "You have version \(currentVersion)."
        if isBusy() { info += " Installing ends the current session." }
        if !release.notes.isEmpty { info += "\n\n" + release.notes }
        alert.informativeText = info
        alert.addButton(withTitle: "Install and Relaunch")
        alert.addButton(withTitle: "Later")
        alert.addButton(withTitle: "Release Notes")
        alert.showsSuppressionButton = true
        alert.suppressionButton?.title = "Skip this version"
        let answer = alert.runModal()
        if alert.suppressionButton?.state == .on { defaults.set(release.version, forKey: "updateSkippedVersion") }
        switch answer {
        case .alertFirstButtonReturn: Task { await install(release) }
        case .alertThirdButtonReturn: NSWorkspace.shared.open(release.page)
        default: break
        }
    }

    private func showUpToDate() {
        NSApp.activate()
        let alert = NSAlert()
        alert.icon = NSApp.applicationIconImage
        alert.messageText = "Mellow is up to date"
        alert.informativeText = "Version \(currentVersion) is the newest version."
        alert.runModal()
    }

    private func showError(_ title: String, _ error: Error) {
        NSApp.activate()
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = (error as? UpdateError)?.message ?? error.localizedDescription
        alert.runModal()
    }

    // MARK: Installing

    func install(_ release: Release) async {
        state = .downloading
        var mount: URL?
        do {
            let (download, response) = try await URLSession.shared.download(from: release.dmg)
            if let http = response as? HTTPURLResponse, http.statusCode != 200 { throw UpdateError.server(http.statusCode) }
            let work = FileManager.default.temporaryDirectory.appending(path: "MellowUpdate-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
            let dmg = work.appending(path: "Mellow.dmg")
            try FileManager.default.moveItem(at: download, to: dmg)

            state = .installing
            let mountPoint = work.appending(path: "mount")
            try await Self.run("/usr/bin/hdiutil", ["attach", "-nobrowse", "-readonly", "-noautoopen", "-mountpoint", mountPoint.path, dmg.path])
            mount = mountPoint
            let newApp = mountPoint.appending(path: "Mellow.app")
            try await Self.verify(newApp, version: release.version)

            let current = Bundle.main.bundleURL
            do {
                try await Self.replace(current, with: newApp, staging: work)
            } catch {
                // Can't write next to the running app: let the user drag the new version over.
                state = .available(release)
                NSWorkspace.shared.open(mountPoint)
                showError("Drag the new Mellow to Applications", UpdateError.notWritable(current.deletingLastPathComponent().path))
                return
            }
            try? await Self.run("/usr/bin/hdiutil", ["detach", "-quiet", mountPoint.path])
            relaunch(current)
        } catch {
            if let mount { try? await Self.run("/usr/bin/hdiutil", ["detach", "-quiet", "-force", mount.path]) }
            state = .available(release)
            showError("The update couldn't be installed", error)
        }
    }

    /// The new app must be Mellow, the promised version, signed with our Developer ID, and accepted by Gatekeeper.
    private static func verify(_ app: URL, version: String) async throws {
        let info = NSDictionary(contentsOf: app.appending(path: "Contents/Info.plist"))
        guard info?["CFBundleIdentifier"] as? String == Bundle.main.bundleIdentifier,
              info?["CFBundleShortVersionString"] as? String == version else { throw UpdateError.untrusted }
        let requirement = "=anchor apple generic and certificate leaf[subject.OU] = \"\(teamID)\""
        do {
            try await run("/usr/bin/codesign", ["--verify", "--deep", "--strict", "-R", requirement, app.path])
            try await run("/usr/sbin/spctl", ["--assess", "--type", "execute", app.path])
        } catch {
            throw UpdateError.untrusted
        }
    }

    /// Copies the new app next to the old one, then swaps them in one step.
    private static func replace(_ current: URL, with newApp: URL, staging: URL) async throws {
        let staged = current.deletingLastPathComponent().appending(path: ".Mellow-update-\(UUID().uuidString).app")
        try await run("/usr/bin/ditto", [newApp.path, staged.path])
        do {
            _ = try FileManager.default.replaceItemAt(current, withItemAt: staged)
        } catch {
            try? FileManager.default.removeItem(at: staged)
            throw error
        }
    }

    private func relaunch(_ app: URL) {
        let pid = ProcessInfo.processInfo.processIdentifier
        let script = "while /bin/kill -0 \(pid) 2>/dev/null; do /bin/sleep 0.2; done; /usr/bin/open \"$0\""
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", script, app.path]
        try? process.run()
        willRelaunch()
        NSApp.terminate(nil)
    }

    /// Runs a tool off the main thread; a non-zero exit throws.
    nonisolated private static func run(_ tool: String, _ arguments: [String]) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: tool)
            process.arguments = arguments
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            process.terminationHandler = { finished in
                if finished.terminationStatus == 0 { continuation.resume() }
                else { continuation.resume(throwing: UpdateError.tool(URL(fileURLWithPath: tool).lastPathComponent, finished.terminationStatus)) }
            }
            do { try process.run() } catch { continuation.resume(throwing: error) }
        }
    }
}

enum UpdateError: Error {
    case server(Int), untrusted, tool(String, Int32), notWritable(String)
    var message: String {
        switch self {
        case .server(let code): "The update server answered with an error (\(code)). Try again later."
        case .untrusted: "The download isn't a Mellow release signed by its developer, so it was not installed."
        case .tool(let name, let code): "\(name) failed (\(code))."
        case .notWritable(let folder): "Mellow can't replace itself in “\(folder)”. The new version is open in Finder — drag it to Applications."
        }
    }
}

/// The parts of GitHub's release JSON that Mellow reads.
private struct GitHubRelease: Decodable {
    struct Asset: Decodable {
        let name: String
        let browserDownloadURL: URL
        enum CodingKeys: String, CodingKey { case name, browserDownloadURL = "browser_download_url" }
    }
    let tagName: String
    let body: String?
    let draft: Bool
    let prerelease: Bool
    let htmlURL: URL
    let assets: [Asset]
    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name", body, draft, prerelease, htmlURL = "html_url", assets
    }
}
