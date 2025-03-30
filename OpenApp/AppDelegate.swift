//
//  AppDelegate.swift
//  OpenApp
//
//  Created by Alex on 30/03/25.
//

import Cocoa
import Carbon
import Foundation

// MARK: - Main Application
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var hotkeyMonitor: Any?
    var appConfig: [String: String] = [:]
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
        
        menu.addItem(NSMenuItem(title: "Edit Configuration", action: #selector(editConfiguration), keyEquivalent: "e"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusItem.menu = menu
    }
    
    // MARK: - Configuration
    func configFilePath() -> URL {
        let fileManager = FileManager.default
        let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDirectory = appSupportURL.appendingPathComponent("OpenApp")
        
        if !fileManager.fileExists(atPath: appDirectory.path) {
            try? fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true)
        }
        
        return appDirectory.appendingPathComponent(configFileName)
    }
    
    func loadConfiguration() {
        let configPath = configFilePath()
        
        if !FileManager.default.fileExists(atPath: configPath.path) {
            // Create default configuration
            appConfig = [
                "trigger": "rightCommand",  // Options: rightCommand, leftCommand, rightShift, leftShift, etc.
                "a": "Safari",
                "m": "Mail",
                "c": "Calendar"
            ]
            saveConfiguration()
        } else {
            do {
                let data = try Data(contentsOf: configPath)
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: String] {
                    appConfig = json
                }
            } catch {
                print("Error loading configuration: \(error)")
                // Create default configuration if loading fails
                appConfig = [
                    "trigger": "rightCommand",
                    "a": "Safari",
                    "m": "Mail",
                    "c": "Calendar"
                ]
                saveConfiguration()
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
                    let appURL = URL(fileURLWithPath: "/Applications/\(appName).app")
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
