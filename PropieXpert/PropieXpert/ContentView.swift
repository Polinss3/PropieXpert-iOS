//
//  ContentView.swift
//  PropieXpert
//
//  Created by Pablo Brasero Martínez on 6/7/25.
//

import SwiftUI

struct ContentView: View {
    @AppStorage("auth_token") var authToken: String = ""
    
    var body: some View {
        VStack(spacing: 0) {
            TabView {
                DashboardView()
                    .tabItem {
                        Image(systemName: "rectangle.3.offgrid")
                        Text("Dashboard")
                    }
                PropertiesView()
                    .tabItem {
                        Image(systemName: "house.fill")
                        Text("Propiedades")
                    }
                IncomeView()
                    .tabItem {
                        Image(systemName: "arrow.down.circle")
                        Text("Ingresos")
                    }
                ExpensesView()
                    .tabItem {
                        Image(systemName: "arrow.up.circle")
                        Text("Gastos")
                    }
            }
            Button(action: {
                print("[Logout] Botón de cerrar sesión pulsado")
                authToken = ""
                print("[Logout] auth_token después de borrar: \(authToken)")
            }) {
                Text("Cerrar sesión")
                    .foregroundColor(.red)
                    .padding()
            }
        }
    }
}

#Preview {
    ContentView()
}
