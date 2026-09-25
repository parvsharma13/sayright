import Foundation

/// Diagnostics for bug reports: app names, accessibility roles, character counts.
/// Never the user's text — see docs/PRIVACY.md.
enum Log {
    /// `~/Library/Logs`, not `/tmp`: files in /tmp are world-readable, and which apps
    /// someone writes in is nobody else's business on a shared machine.
    static let path: String = {
        let library = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first
        let directory = library?.appending(path: "Logs")
            ?? URL(fileURLWithPath: NSHomeDirectory()).appending(path: "Library/Logs")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appending(path: "SayRight.log").path
    }()

    /// Small enough that it never becomes a forgotten multi-megabyte record of which
    /// apps someone used.
    static let maxBytes = 256 * 1024

    static func append(_ message: String) {
        let line = "\(Date().formatted(date: .numeric, time: .standard)) \(message)\n"
        let manager = FileManager.default

        if !manager.fileExists(atPath: path) {
            manager.createFile(atPath: path, contents: nil,
                               attributes: [.posixPermissions: 0o600])
        }
        if let size = try? manager.attributesOfItem(atPath: path)[.size] as? Int, size > maxBytes {
            try? Data().write(to: URL(fileURLWithPath: path))
        }
        guard let handle = FileHandle(forWritingAtPath: path) else { return }
        handle.seekToEndOfFile()
        handle.write(Data(line.utf8))
        try? handle.close()
    }
}

/// Earlier builds logged to /tmp, which is world-readable. Remove it on launch rather
/// than leaving it behind for the life of the machine.
func removeLegacyLog() {
    try? FileManager.default.removeItem(atPath: "/tmp/sayright.log")
}

func dbg(_ message: String) {
    Log.append(message)
}
