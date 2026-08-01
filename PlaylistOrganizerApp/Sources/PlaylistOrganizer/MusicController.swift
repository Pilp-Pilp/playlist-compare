import Foundation

struct PresenceDTO: Codable {
    let id: String
    let album: String
}

struct SongRowDTO: Codable {
    let name: String
    let artist: String
    let overlapping: Bool
    let presence: [String: PresenceDTO?]
}

struct CompareResult: Codable {
    let playlists: [String]
    let rows: [SongRowDTO]
}

struct PlaylistSelection: Codable {
    let source: String
    let id: String
}

private struct ProcessResult {
    let stdout: String
    let stderr: String
    let success: Bool

    var combined: String {
        [stdout, stderr].filter { !$0.isEmpty }.joined(separator: "\n")
    }
}

enum MusicController {
    static let repoPath = "/Users/oren/Code_Space/playlist-compare"

    private static var pythonPath: String {
        let venvPython = repoPath + "/.venv/bin/python3"
        if FileManager.default.isExecutableFile(atPath: venvPython) {
            return venvPython
        }
        return "/usr/bin/python3"
    }

    /// Runs a process, draining stdout/stderr concurrently to avoid deadlocking on large output
    /// (waiting for exit before reading can hang once output exceeds the OS pipe buffer).
    private static func run(_ launchPath: String, _ arguments: [String], stdinData: Data? = nil) -> ProcessResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments
        process.currentDirectoryURL = URL(fileURLWithPath: repoPath)

        let outPipe = Pipe()
        let errPipe = Pipe()
        let inPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe
        process.standardInput = inPipe

        do {
            try process.run()
        } catch {
            return ProcessResult(stdout: "", stderr: "Failed to launch: \(error.localizedDescription)", success: false)
        }

        if let stdinData {
            inPipe.fileHandleForWriting.write(stdinData)
        }
        inPipe.fileHandleForWriting.closeFile()

        var outData = Data()
        var errData = Data()
        let group = DispatchGroup()

        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            outData = outPipe.fileHandleForReading.readDataToEndOfFile()
            group.leave()
        }
        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            group.leave()
        }
        group.wait()
        process.waitUntilExit()

        return ProcessResult(
            stdout: String(data: outData, encoding: .utf8) ?? "",
            stderr: String(data: errData, encoding: .utf8) ?? "",
            success: process.terminationStatus == 0
        )
    }

    static func listPlaylists() -> [String] {
        let script = "tell application \"Music\" to get name of every playlist"
        let result = run("/usr/bin/osascript", ["-e", script])
        guard result.success else { return [] }

        return result.stdout
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: ", ")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .sorted()
    }

    static func reorder(playlist: String, sortSpec: String) -> (output: String, success: Bool) {
        let result = run(pythonPath, [repoPath + "/reorder_live_playlist.py", playlist, sortSpec])
        return (result.combined, result.success)
    }

    static func compareJSON(playlists: [String]) -> (result: CompareResult?, error: String?) {
        let result = run(pythonPath, [repoPath + "/compare_live_playlists.py", "--json"] + playlists)
        guard result.success else {
            return (nil, result.stderr.isEmpty ? result.stdout : result.stderr)
        }
        guard let data = result.stdout.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(CompareResult.self, from: data) else {
            return (nil, "Failed to parse compare output:\n\(result.combined)")
        }
        return (decoded, nil)
    }

    static func buildPlaylist(name: String, selections: [PlaylistSelection]) -> (output: String, success: Bool) {
        let payload = try? JSONEncoder().encode(selections)
        let result = run(pythonPath, [repoPath + "/build_playlist.py", name], stdinData: payload)
        return (result.combined, result.success)
    }
}
