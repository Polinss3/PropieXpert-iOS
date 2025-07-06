//
//  ContentView.swift
//  PropieXpert
//
//  Created by Pablo Brasero Martínez on 6/7/25.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
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
            FlowView()
                .tabItem {
                    Image(systemName: "arrow.left.arrow.right")
                    Text("Flujo")
                }
            PlaceholderView()
                .tabItem {
                    Image(systemName: "ellipsis")
                    Text("Más")
                }
        }
    }
}

#Preview {
    ContentView()
}
