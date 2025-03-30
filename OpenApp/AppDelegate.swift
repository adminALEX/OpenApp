//
//  AppDelegate.swift
//  OpenApp
//
//  Created by Alex on 30/03/25.
//

import Cocoa
import Carbon
import Foundation
import ServiceManagement

// MARK: - Main Application
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var hotkeyMonitor: Any?
    var appConfig: [String: String] = [
        "trigger": "rightCommand",
        "a": "Safari",
        "m": "Mail",
        "c": "Calendar"
    ]
    let configFileName = "openapp_config.json"
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Request accessibility permissions
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true]
        let accessibilityEnabled = AXIsProcessTrustedWithOptions(options as CFDictionary)
        
        if !accessibilityEnabled {
            print("Warning: Accessibility permissions not granted. OpenApp may not work properly.")
            // Show alert to user
            let alert = NSAlert()
            alert.messageText = "Accessibility Permissions Required"
            alert.informativeText = "OpenApp needs accessibility permissions to detect global hotkeys. Please grant permission in System Preferences > Security & Privacy > Privacy > Accessibility."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
        
        // Create status item in menu bar
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "command", accessibilityDescription: "OpenApp")
        }
        
        // Enable "Open at Login" by default
        enableLaunchAtLogin()
        
        setupMenu()
        loadConfiguration()
        registerHotkeys()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Unregister hotkeys when app quits
        if let monitor = hotkeyMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
    
    // MARK: - Menu Setup
    func setupMenu() {
        let menu = NSMenu()
        
        menu.addItem(NSMenuItem(title: "Edit Configuration", action: #selector(editConfiguration), keyEquivalent: ","))
        
        // Add "Launch at Login" menu item
        let launchAtLoginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchAtLoginItem.state = isLaunchAtLoginEnabled() ? .on : .off
        menu.addItem(launchAtLoginItem)
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusItem.menu = menu
    }
    
    // MARK: - Launch at Login
    func enableLaunchAtLogin() {
        if !isLaunchAtLoginEnabled() {
            if #available(macOS 13.0, *) {
                // For macOS 13+ (Ventura and later)
                do {
                    try SMAppService.mainApp.register()
                    print("Successfully registered app to launch at login")
                } catch {
                    print("Failed to register app to launch at login: \(error)")
                }
            } else {
                // For older macOS versions - we need to deploy a helper app
                print("On older macOS versions, consider using a helper app approach")
                // We'll need to implement a different approach for older systems
                // Usually this involves a helper app that's registered to launch at login
                showOlderMacOSAlert()
            }
        }
    }
    
    func showOlderMacOSAlert() {
        let alert = NSAlert()
        alert.messageText = "Open at Login Support"
        alert.informativeText = "Your macOS version requires manually adding this app to Login Items in System Preferences > Users & Groups > Login Items."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    func isLaunchAtLoginEnabled() -> Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        } else {
            // For older versions, we can't reliably check
            // We would need to use a helper app approach
            return false
        }
    }
    
    @objc func toggleLaunchAtLogin() {
        if #available(macOS 13.0, *) {
            do {
                if isLaunchAtLoginEnabled() {
                    try SMAppService.mainApp.unregister()
                    print("Unregistered app from launch at login")
                } else {
                    try SMAppService.mainApp.register()
                    print("Registered app to launch at login")
                }
                
                // Update menu item state
                if let menuItem = statusItem.menu?.item(withTitle: "Launch at Login") {
                    menuItem.state = isLaunchAtLoginEnabled() ? .on : .off
                }
            } catch {
                print("Failed to toggle launch at login: \(error)")
                let alert = NSAlert()
                alert.messageText = "Launch at Login Error"
                alert.informativeText = "Failed to change Launch at Login setting: \(error.localizedDescription)"
                alert.alertStyle = .warning
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
        } else {
            // For older macOS versions, direct users to System Preferences
            showOlderMacOSAlert()
        }
    }
    
    // MARK: - Configuration
    func configFilePath() -> URL {
        let fileManager = FileManager.default
        let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDirectory = appSupportURL.appendingPathComponent("OpenApp")
        
        if !fileManager.fileExists(atPath: appDirectory.path) {
            print("Creating Application Support directory...")
            try? fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true)
        }else{
            print("Using existing Application Support directory...")
        }
        
        return appDirectory.appendingPathComponent(configFileName)
    }
    
    func loadConfiguration() {
        let configPath = configFilePath()
        
        if !FileManager.default.fileExists(atPath: configPath.path) {
            saveConfiguration()
        } else {
            do {
                let data = try Data(contentsOf: configPath)
                if let dataString = String(data: data, encoding: .utf8) {
                    print("confguration: \(dataString)")
                } else {
                    print("Failed to convert Data to String")
                }
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: String] {
                    appConfig = json
                }
            } catch {
                print("Error loading configuration: \(error)")
                let alert = NSAlert()
                alert.messageText = "Error loading configuration"
                alert.runModal();
            }
        }
    }
    
    func saveConfiguration() {
        do {
            let data = try JSONSerialization.data(withJSONObject: appConfig, options: .prettyPrinted)
            try data.write(to: configFilePath())
        } catch {
            print("Error saving configuration: \(error)")
        }
    }
    
    @objc func editConfiguration() {
        // Open the config file in the default editor
        NSWorkspace.shared.open(configFilePath())
    }
    
    // MARK: - Hotkey Registration
    func registerHotkeys() {
        if let monitor = hotkeyMonitor {
            NSEvent.removeMonitor(monitor)
        }
        
        guard let trigger = appConfig["trigger"] else { return }
        print("Registering hotkey trigger: \(trigger)")
        
        // Set up event monitor for key down events
        hotkeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return }
            
            // Define the raw values for right and left modifier keys
            let rightCommandMask: UInt = 0x0010
            let leftCommandMask: UInt = 0x0008
            let rightShiftMask: UInt = 0x0004
            let leftShiftMask: UInt = 0x0002
            let rightOptionMask: UInt = 0x0040
            let leftOptionMask: UInt = 0x0020
            
            // Get the raw value of the flags
            let rawFlags = event.modifierFlags.rawValue
            
            // Check which modifier is pressed based on the trigger configuration
            let triggerPressed: Bool
            switch appConfig["trigger"] {
            case "rightCommand":
                triggerPressed = event.modifierFlags.contains(.command) && (rawFlags & rightCommandMask != 0)
            case "leftCommand":
                triggerPressed = event.modifierFlags.contains(.command) && (rawFlags & leftCommandMask != 0)
            case "rightShift":
                triggerPressed = event.modifierFlags.contains(.shift) && (rawFlags & rightShiftMask != 0)
            case "leftShift":
                triggerPressed = event.modifierFlags.contains(.shift) && (rawFlags & leftShiftMask != 0)
            case "rightOption":
                triggerPressed = event.modifierFlags.contains(.option) && (rawFlags & rightOptionMask != 0)
            case "leftOption":
                triggerPressed = event.modifierFlags.contains(.option) && (rawFlags & leftOptionMask != 0)
            default:
                triggerPressed = false
            }
            
            if triggerPressed {
                // Get the character that was pressed
                if let character = event.charactersIgnoringModifiers?.lowercased() {
                    self.handleHotkey(key: character)
                }
            }
        }

    }

    func handleHotkey(key: String) {
        guard let appName = appConfig[key] else {
            print("No app configured for key: \(key)")
            return
        }

        print("Launching/focusing app: \(appName)")

        let workspace = NSWorkspace.shared
        let apps = workspace.runningApplications
        let foundApp = apps.first { $0.localizedName == appName }

        if let app = foundApp {
            app.activate()
        } else {
                let bundleID = getBundleIdentifier(for: appName)
                if !bundleID.isEmpty {
                    if let appURL = workspace.urlForApplication(withBundleIdentifier: bundleID) {
                        let configuration = NSWorkspace.OpenConfiguration()
                        workspace.openApplication(at: appURL, configuration: configuration) { (app, error) in
                            if let error = error {
                                print("Error launching app with bundle ID \(bundleID): \(error)")
                            } else {
                                print("App launched successfully with bundle ID \(bundleID)")
                            }
                        }
                    } else {
                        print("Could not find app URL for bundle ID \(bundleID)")
                    }
                } else {
                    var appURL = URL(fileURLWithPath: "/Applications/\(appName).app")

                    if appName.hasPrefix("~") || appName.hasPrefix("/") {
                        // Expand tilde (~) if present
                        let expandedPath = URL(fileURLWithPath: (appName as NSString).expandingTildeInPath)
                        appURL = expandedPath
                    }

                    let configuration = NSWorkspace.OpenConfiguration()
                    workspace.openApplication(at: appURL, configuration: configuration) { (app, error) in
                        if let error = error {
                            print("Error launching app by name \(appName): \(error)")
                        } else {
                            print("App launched successfully by name \(appName)")
                        }
                    }
                }
           
        }
    }

    
    func getBundleIdentifier(for appName: String) -> String {
        // Common bundle identifiers
        let bundleMap: [String: String] = [
            "Safari": "com.apple.Safari",
            "Mail": "com.apple.Mail",
            "Calendar": "com.apple.iCal",
            "Notes": "com.apple.Notes",
            "Reminders": "com.apple.reminders",
            "Messages": "com.apple.iChat",
            "Music": "com.apple.Music",
            "Photos": "com.apple.Photos",
            "Maps": "com.apple.Maps",
            "Terminal": "com.apple.Terminal",
            "System Settings": "com.apple.systempreferences"
        ]
        
        return bundleMap[appName] ?? ""
    }
}
