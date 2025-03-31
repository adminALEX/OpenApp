import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ConfigurationEditorView: View {
    @Binding var appConfig: [String: String]
    @Environment(\.presentationMode) var presentationMode
    @State private var newAppPath: String = ""
    @State private var newHotkey: String = ""

    let availableTriggers = ["rightCommand", "leftCommand", "rightShift", "leftShift", "rightOption", "leftOption", "rightControl", "leftControl"]

    var body: some View {
           ScrollView { // Use ScrollView for content that exceeds screen size
               VStack(alignment: .leading, spacing: 15) {
                   Text("Edit Configuration")
                       .font(.headline)

                   // Trigger Key Selection
                   VStack(alignment: .leading) {
                       Text("Trigger Key:")
                       Picker("Select Trigger Key", selection: Binding(
                           get: { appConfig["trigger"] ?? "rightCommand" },
                           set: { appConfig["trigger"] = $0 }
                       )) {
                           ForEach(availableTriggers, id: \.self) { trigger in
                               Text(trigger).tag(trigger)
                           }
                       }
                       .pickerStyle(MenuPickerStyle())
                   }

                   Divider()

                   // Hotkey to App Mapping
                   Text("Hotkey Mappings:")
                       .font(.subheadline)

                   ForEach(appConfig.keys.sorted(), id: \.self) { key in
                       if key != "trigger" {
                           HStack {
                               Text("Key \(key):")
                               TextField("Enter app name or path", text: Binding(
                                   get: { appConfig[key] ?? "" },
                                   set: { appConfig[key] = $0 }
                               ))
                                   .textFieldStyle(RoundedBorderTextFieldStyle())

                               Button("Select App") {
                                   selectApplicationPath(for: key)
                               }
                           }
                       }
                   }

                   // Add New Mapping
                   HStack {
                       TextField("New Hotkey", text: $newHotkey)
                           .textFieldStyle(RoundedBorderTextFieldStyle())
                       TextField("Application Path", text: $newAppPath)
                           .textFieldStyle(RoundedBorderTextFieldStyle())
                       Button("Select App") {
                           selectApplicationPathForNew()
                       }
                       Button("Add") {
                           addMapping()
                       }
                   }

                   Spacer()

                   // Buttons (Save & Cancel)
                   HStack {
                       Button("Cancel") {
                           presentationMode.wrappedValue.dismiss()
                       }
                       Spacer()
                       Button("Save") {
                           saveConfiguration()
                           presentationMode.wrappedValue.dismiss()
                       }.buttonStyle(DefaultButtonStyle())
                   }
               }
               .padding()
               .frame(maxWidth: .infinity, maxHeight: .infinity) // Make the VStack expand
           }
       }
    
    func selectApplicationPathForNew() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [UTType.application]
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = false
        
        openPanel.begin { (result) in
            if result == .OK, let url = openPanel.url {
                newAppPath = url.path
            }
        }
    }

    func selectApplicationPath(for key: String) {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [UTType.application]
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = false

        openPanel.begin { (result) in
            if result == .OK, let url = openPanel.url {
                appConfig[key] = url.path
            }
        }
    }

    func addMapping() {
        guard !newHotkey.isEmpty, !newAppPath.isEmpty else { return }
        appConfig[newHotkey] = newAppPath
        newHotkey = ""
        newAppPath = ""
    }


    func saveConfiguration() {
        do {
            let fileManager = FileManager.default
            let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let appDirectory = appSupportURL.appendingPathComponent("OpenApp")
            let configFile = appDirectory.appendingPathComponent("openapp_config.json")

            let data = try JSONSerialization.data(withJSONObject: appConfig, options: .prettyPrinted)
            try data.write(to: configFile)
        } catch {
            print("Error saving configuration: \(error)")
        }
    }
}

