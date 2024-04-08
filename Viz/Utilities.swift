//
//  Utilities.swift
//  Grabber
//
//  Created by Alin Lupascu on 4/5/24.
//

import Foundation
import SwiftUI
import AppKit
import OSLog
import ServiceManagement

class TextItem: Identifiable {
    var id: String
    var text: String = ""

    init() {
        id = UUID().uuidString
    }
}


class RecognizedContent: ObservableObject {
    @Published var items = [TextItem]()
}



func copyTextItemsToClipboard(textItems: [TextItem]) {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()

    let combinedText = textItems.map { $0.text }.joined(separator: "\n")
    pasteboard.setString(combinedText, forType: .string)
}


func clearClipboard() {
    DispatchQueue.main.async {
        CaptureService.shared.recognizedContent.items.removeAll()
        CaptureService.shared.pasteboard.clearContents()
        previewWindow?.orderOut(nil)
        previewWindow = nil
    }
}


func playSound(named soundName: String) {
    if let sound = NSSound(named: soundName) {
        sound.play()
    }
}


class ScreenCaptureUtility {

    func captureScreenSelectionToClipboard(completion: @escaping (NSImage?) -> Void) {
        let process = Process()
        process.launchPath = "/usr/sbin/screencapture"
        process.arguments = ["-cix"]  // '-c' for clipboard, '-i' for interactive selection, '-x' for no capture sounds

        process.terminationHandler = { _ in
            DispatchQueue.main.async {
                let pasteboard = NSPasteboard.general
                if let image = pasteboard.readObjects(forClasses: [NSImage.self], options: [:])?.first as? NSImage {
                    completion(image)
                } else {
                    completion(nil)
                }
            }
        }

        process.launch()
    }
}


func printOS(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    let message = items.map { "\($0)" }.joined(separator: separator)
    let log = OSLog(subsystem: "com.alienator88.viz", category: "Application")
    os_log("%@", log: log, type: .default, message)
}


// Check app directory based on user permission
func checkAppDirectoryAndUserRole(completion: @escaping ((isInCorrectDirectory: Bool, isAdmin: Bool)) -> Void) {
    isCurrentUserAdmin { isAdmin in
        let bundlePath = Bundle.main.bundlePath as NSString
        let applicationsDir = "/Applications"
        let userApplicationsDir = "\(NSHomeDirectory())/Applications"

        var isInCorrectDirectory = false

        if isAdmin {
            // Admins can have the app in either /Applications or ~/Applications
            isInCorrectDirectory = bundlePath.deletingLastPathComponent == applicationsDir ||
            bundlePath.deletingLastPathComponent == userApplicationsDir
        } else {
            // Standard users should only have the app in ~/Applications
            isInCorrectDirectory = bundlePath.deletingLastPathComponent == userApplicationsDir
        }

        // Return both conditions: if the app is in the correct directory and if the user is an admin
        completion((isInCorrectDirectory, isAdmin))
    }
}


// Check if user is admin or standard user
func isCurrentUserAdmin(completion: @escaping (Bool) -> Void) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/zsh") // Using zsh, macOS default shell
    process.arguments = ["-c", "groups $(whoami) | grep -q ' admin '"]

    process.terminationHandler = { process in
        // On macOS, a process's exit status of 0 indicates success (admin group found in this context)
        completion(process.terminationStatus == 0)
    }

    do {
        try process.run()
    } catch {
        print("Failed to execute command: \(error)")
        completion(false)
    }
}

// Relaunch app
func relaunchApp(afterDelay seconds: TimeInterval = 0.5) -> Never {
    let task = Process()
    task.launchPath = "/bin/sh"
    task.arguments = ["-c", "sleep \(seconds); open \"\(Bundle.main.bundlePath)\""]
    task.launch()

    NSApp.terminate(nil)
    exit(0)
}

func ensureApplicationSupportFolderExists() {
    let fileManager = FileManager.default
    let supportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent("\(Bundle.main.bundleIdentifier!)")

    // Check to make sure Application Support folder exists
    if !fileManager.fileExists(atPath: supportURL.path) {
        try! fileManager.createDirectory(at: supportURL, withIntermediateDirectories: true)
        printOS("Created Application Support/\(Bundle.main.bundleIdentifier!) folder")
    }
}


func updateLaunchAtLoginStatus(newValue: Bool) {
    do {
        if newValue {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            }
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    } catch {
        print("Failed to \(newValue ? "enable" : "disable") launch at login: \(error.localizedDescription)")
    }
}


func updateOnMain(after delay: Double? = nil, _ updates: @escaping () -> Void) {
    if let delay = delay {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            updates()
        }
    } else {
        DispatchQueue.main.async {
            updates()
        }
    }
}


struct SimpleButtonBrightStyle: ButtonStyle {
    @State private var hovered = false
    let icon: String
    let help: String
    let color: Color
    let shield: Bool?

    init(icon: String, help: String, color: Color, shield: Bool? = nil) {
        self.icon = icon
        self.help = help
        self.color = color
        self.shield = shield
    }

    func makeBody(configuration: Self.Configuration) -> some View {
        HStack {
            Image(systemName: icon)
                .resizable()
                .scaledToFit()
                .frame(width: 20)
                .foregroundColor(hovered ? color.opacity(0.5) : color)
        }
        .padding(5)
        .onHover { hovering in
            withAnimation() {
                hovered = hovering
            }
        }
        .scaleEffect(configuration.isPressed ? 0.95 : 1)
        .help(help)
    }
}


extension Bundle {

    var name: String {
        func string(for key: String) -> String? {
            object(forInfoDictionaryKey: key) as? String
        }
        return string(for: "CFBundleDisplayName")
        ?? string(for: "CFBundleName")
        ?? "N/A"
    }
}

extension Bundle {

    var version: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "N/A"
    }

    var buildVersion: String {
        infoDictionary?["CFBundleVersion"] as? String ?? "N/A"
    }
}

extension Bundle {

    var copyright: String {
        func string(for key: String) -> String? {
            object(forInfoDictionaryKey: key) as? String
        }
        return string(for: "NSHumanReadableCopyright") ?? "N/A"
    }
}
