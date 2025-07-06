import SwiftUI

struct Property: Identifiable, Decodable {
    let id: String
    let name: String
    let address: String
    let property_type: String
    let purchase_price: Double
    let current_value: Double
    let bedrooms: Int
    let bathrooms: Int
    let is_rented: Bool
    let rental_price: Double?
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case name, address, property_type, purchase_price, current_value, bedrooms, bathrooms, is_rented, rental_price
    }
}

struct PropertiesView: View {
    @AppStorage("auth_token") var authToken: String = ""
    @State private var properties: [Property] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedProperty: Property? = nil
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("Cargando propiedades...")
                } else if let errorMessage = errorMessage {
                    Text(errorMessage).foregroundColor(.red)
                } else if properties.isEmpty {
                    Text("No tienes propiedades registradas.")
                        .foregroundColor(.gray)
                } else {
                    List(properties) { property in
                        Button(action: {
                            selectedProperty = property
                        }) {
                            VStack(alignment: .leading) {
                                Text(property.name).font(.headline)
                                Text(property.address).font(.subheadline).foregroundColor(.gray)
                                HStack(spacing: 12) {
                                    Text(property.property_type.capitalized)
                                    Text("Habitaciones: \(property.bedrooms)")
                                    Text("Baños: \(property.bathrooms)")
                                }.font(.caption)
                            }
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Propiedades")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { /* TODO: añadir propiedad */ }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .onAppear(perform: fetchProperties)
            .sheet(item: $selectedProperty) { property in
                PropertyDetailSheet(propertyId: property.id)
            }
        }
    }
    
    func fetchProperties() {
        isLoading = true
        errorMessage = nil
        guard let url = URL(string: "https://api.propiexpert.com/properties/") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
                if let error = error {
                    errorMessage = "Error de red: \(error.localizedDescription)"
                    return
                }
                guard let data = data else {
                    errorMessage = "No se recibieron datos del servidor."
                    return
                }
                do {
                    let decoded = try JSONDecoder().decode([Property].self, from: data)
                    properties = decoded
                } catch {
                    errorMessage = "Error al decodificar propiedades: \(error.localizedDescription)"
                }
            }
        }.resume()
    }
    
    func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        return formatter.string(from: NSNumber(value: amount)) ?? "€\(amount)"
    }
}

#Preview {
    PropertiesView()
} 