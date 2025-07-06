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
    }
}

#Preview {
    ContentView()
}
