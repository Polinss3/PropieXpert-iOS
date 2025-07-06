//
//  PropieXpertApp.swift
//  PropieXpert
//
//  Created by Pablo Brasero Martínez on 6/7/25.
//

import SwiftUI
import GoogleSignIn

@main
struct PropieXpertApp: App {
    @AppStorage("auth_token") var authToken: String = ""

    init() {
        // Inicialización manual de GoogleSignIn
        if let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
           let dict = NSDictionary(contentsOfFile: path),
           let clientID = dict["CLIENT_ID"] as? String {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
            print("[GoogleSignIn] CLIENT_ID configurado manualmente: \(clientID)")
        } else {
            print("[GoogleSignIn] No se pudo encontrar CLIENT_ID en GoogleService-Info.plist")
        }
    }

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
