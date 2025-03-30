//
//  OpenAppApp.swift
//  OpenApp
//
//  Created by Alex on 30/03/25.
//

import SwiftUI

import SwiftUI

@main
struct OpenAppApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
