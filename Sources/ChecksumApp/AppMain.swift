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
    }
}


