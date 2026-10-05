import SwiftUI
import AppKit

@main
struct WiFiTroubleshootingApp: App {
    @NSApplicationDelegateAdaptor(AppLifecycle.self) private var lifecycle
    @StateObject private var store = AppStore()
    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(store)
                .frame(minWidth: 1040, minHeight: 720)
                .task { lifecycle.sessions = store.sessions; NSApplication.shared.setActivationPolicy(.regular); NSApplication.shared.activate(ignoringOtherApps: true); store.start() }
        }
        .defaultSize(width: 1320, height: 880)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("สแกนเครือข่าย") { Task { await store.scan() } }.keyboardShortcut("r")
                Button("เปิดการสำรวจ…") { store.openSurvey() }.keyboardShortcut("o")
                Button("ส่งออกการสำรวจ…") { store.exportSurvey() }.keyboardShortcut("s", modifiers: [.command, .shift])
            }
        }
    }
}

@MainActor
final class AppLifecycle: NSObject, NSApplicationDelegate {
    weak var sessions: SessionStore?
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let sessions, sessions.isRecording || sessions.busy || sessions.hasUnsavedChanges else { return .terminateNow }
        Task {
            while sessions.busy { try? await Task.sleep(for: .milliseconds(100)) }
            if sessions.isRecording { await sessions.stop() }
            while sessions.busy { try? await Task.sleep(for: .milliseconds(100)) }
            sender.reply(toApplicationShouldTerminate: !sessions.hasUnsavedChanges)
        }
        return .terminateLater
    }
}
