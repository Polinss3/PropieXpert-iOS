//
//  PropieXpertApp.swift
//  PropieXpert
//
//  Created by Pablo Brasero Martínez on 6/7/25.
//

import SwiftUI

@main
struct PropieXpertApp: App {
    @AppStorage("auth_token") var authToken: String = ""

    var body: some Scene {
        WindowGroup {
            if authToken.isEmpty {
                LoginView()
            } else {
                ContentView()
            }
        }
    }
}
