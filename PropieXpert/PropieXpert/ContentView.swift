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
            UserProfileView()
                .tabItem {
                    Image(systemName: "person.crop.circle")
                    Text("Perfil")
                }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthSession())
}
