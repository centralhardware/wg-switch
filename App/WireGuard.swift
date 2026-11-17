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
