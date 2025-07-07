import SwiftUI

struct ContentView: View {
    @AppStorage("auth_token") var authToken: String = ""
    
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

struct DashboardTab: View {
    @Binding var authToken: String

    var body: some View {
        VStack {
            Text("Dashboard")
                .font(.largeTitle)
            Spacer()
            Button(action: {
                authToken = ""
            }) {
                Text("Cerrar sesión")
                    .foregroundColor(.red)
                    .padding(.bottom, 24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

#Preview {
    ContentView()
}
