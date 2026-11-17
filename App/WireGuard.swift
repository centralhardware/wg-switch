import Foundation

/// Talks to wg-quick through `sudo -n` (rules installed by scripts/install-sudoers.sh).
enum WireGuard {
    static let configDir = "/etc/wireguard"
    static let runDir = "/var/run/wireguard"   // wg-quick on macOS writes <name>.name here while a tunnel is up

    struct Failure: Error, LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    static func profiles() throws -> [String] {
        let out = try run(["/bin/ls", configDir])
        return out.split(separator: "\n").map(String.init)
            .filter { $0.hasSuffix(".conf") }
            .map { String($0.dropLast(5)) }
            .sorted()
    }

    static func active() -> [String] {
        let files = (try? FileManager.default.contentsOfDirectory(atPath: runDir)) ?? []
        return files.filter { $0.hasSuffix(".name") }.map { String($0.dropLast(5)) }.sorted()
    }

    static func up(_ name: String) throws { _ = try run([wgQuick, "up", name]) }
    static func down(_ name: String) throws { _ = try run([wgQuick, "down", name]) }

    /// Only one tunnel at a time: tear everything down, then bring `name` up.
    /// Toggling the already-active profile just turns it off.
    static func toggle(_ name: String) throws {
        let current = active()
        for p in current { try down(p) }
        if !current.contains(name) { try up(name) }
    }

    /// True when the failure means the sudoers rule is missing.
    static func needsAccess(_ message: String?) -> Bool {
        message?.contains("password is required") ?? false
    }

    /// Installs /etc/sudoers.d/wgswitch through the standard macOS admin prompt
    /// (same rule as scripts/install-sudoers.sh).
    static func installSudoers() throws {
        let bin = (wgQuick as NSString).deletingLastPathComponent
        let rules = """
        Cmnd_Alias WGSWITCH = \(bin)/wg-quick up *, \(bin)/wg-quick down *, /bin/ls /etc/wireguard
        Defaults!WGSWITCH secure_path="\(bin):/usr/bin:/bin:/usr/sbin:/sbin"
        \(NSUserName()) ALL=(root) NOPASSWD: WGSWITCH

        """
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("wgswitch.sudoers")
        try rules.write(to: tmp, atomically: true, encoding: .utf8)
        let shell = "/usr/sbin/visudo -cf '\(tmp.path)' && /usr/bin/install -m 0440 -o root -g wheel '\(tmp.path)' /etc/sudoers.d/wgswitch"
        let source = "do shell script \"\(shell)\" with administrator privileges"
        var err: NSDictionary?
        NSAppleScript(source: source)?.executeAndReturnError(&err)
        try? FileManager.default.removeItem(at: tmp)
        if let err {
            throw Failure(message: err[NSAppleScript.errorMessage] as? String ?? "Could not install the sudo rule")
        }
    }

    static var wgQuick: String {
        ["/opt/homebrew/bin/wg-quick", "/usr/local/bin/wg-quick"]
            .first { FileManager.default.isExecutableFile(atPath: $0) } ?? "/opt/homebrew/bin/wg-quick"
    }

    @discardableResult
    private static func run(_ args: [String]) throws -> String {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        p.arguments = ["-n"] + args
        let out = Pipe(), err = Pipe()
        p.standardOutput = out
        p.standardError = err
        try p.run()
        p.waitUntilExit()
        let stdout = String(decoding: out.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        let stderr = String(decoding: err.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        guard p.terminationStatus == 0 else {
            throw Failure(message: stderr.isEmpty ? "exit \(p.terminationStatus)" : stderr.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return stdout
    }
}
