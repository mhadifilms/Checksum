import SwiftUI
import AppKit
import UserNotifications

final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    weak var viewModel: CloneViewModel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        // Only configure UserNotifications if running as a bundled .app
        let isBundled = (Bundle.main.bundleIdentifier != nil) && (Bundle.main.bundleURL.pathExtension == "app")
        if isBundled {
            let center = UNUserNotificationCenter.current()
            center.delegate = self
            center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
            let view = UNNotificationAction(identifier: "VIEW_DEST", title: "View", options: [.foreground])
            let category = UNNotificationCategory(identifier: "CLONE_DONE", actions: [view], intentIdentifiers: [], options: [])
            center.setNotificationCategories([category])
        }
    }
    
    func application(_ application: NSApplication, open urls: [URL]) {
        // Handle files opened with "Open With Checksum"
        if let viewModel = viewModel {
            let fileURLs = urls.filter { url in
                var isDirectory: ObjCBool = false
                return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
            }
            if !fileURLs.isEmpty {
                viewModel.addSources(urls: fileURLs)
            }
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        if response.notification.request.content.categoryIdentifier == "CLONE_DONE" {
            if response.actionIdentifier == "VIEW_DEST" || response.actionIdentifier == UNNotificationDefaultActionIdentifier {
                if let path = response.notification.request.content.userInfo["dest"] as? String {
                    let url = URL(fileURLWithPath: path)
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
            }
        }
        completionHandler()
    }
}

@main
struct ChecksumMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject var viewModel = CloneViewModel()

    init() {
        appDelegate.viewModel = viewModel
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task { NSApp.activate(ignoringOtherApps: true) }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultPosition(.center)
        .defaultSize(width: 900, height: 600)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Clear All") {
                    viewModel.sources.removeAll()
                    viewModel.destinations.removeAll()
                }
                .keyboardShortcut("r", modifiers: .command)
            }
            CommandGroup(after: .newItem) {
                Button("Start Copy") {
                    if !viewModel.sources.isEmpty && !viewModel.destinations.isEmpty && !viewModel.isCloning {
                        Task { await viewModel.startClone() }
                    }
                }
                .keyboardShortcut(.return)
                .disabled(viewModel.sources.isEmpty || viewModel.destinations.isEmpty || viewModel.isCloning)
            }
        }
    }
}


