import AppKit
import SwiftUI

enum MusicConnectionState {
    case connected
    case idle
    case notFound
}

final class MusicStatus: ObservableObject {
    private static let bundleID = "com.apple.Music"

    @Published var state: MusicConnectionState = .idle

    private var timer: Timer?

    init() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 4, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    func refresh() {
        let running = NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == Self.bundleID }
        if running {
            state = .connected
        } else if NSWorkspace.shared.urlForApplication(withBundleIdentifier: Self.bundleID) != nil {
            state = .idle
        } else {
            state = .notFound
        }
    }

    var color: Color {
        switch state {
        case .connected: return .green
        case .idle: return .orange
        case .notFound: return .red
        }
    }

    var text: String {
        let user = NSFullUserName()
        switch state {
        case .connected: return "\(user) — Music connected"
        case .idle: return "\(user) — Music not running (will launch when needed)"
        case .notFound: return "Music.app not found on this Mac"
        }
    }
}
