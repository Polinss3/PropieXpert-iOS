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
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("Cargando propiedades...")
                        .padding()
                } else if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding()
                    Button("Reintentar") {
                        fetchProperties()
                    }
                    .padding()
                } else if properties.isEmpty {
                    VStack(spacing: 16) {
                        Text("No tienes propiedades aún.")
                            .foregroundColor(.gray)
                        Button(action: { /* TODO: Añadir propiedad */ }) {
                            Label("Añadir propiedad", systemImage: "plus")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else {
                    List {
                        ForEach(properties) { property in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(property.name)
                                        .font(.headline)
                                    Spacer()
                                    Text(property.property_type.capitalized)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                Text(property.address)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                HStack(spacing: 16) {
                                    Text("Compra: \(formatCurrency(property.purchase_price))")
                                    Text("Valor: \(formatCurrency(property.current_value))")
                                }
                                .font(.footnote)
                                HStack(spacing: 16) {
                                    Text("Habitaciones: \(property.bedrooms)")
                                    Text("Baños: \(property.bathrooms)")
                                }
                                .font(.footnote)
                                if property.is_rented, let rent = property.rental_price {
                                    Text("Alquilada: \(formatCurrency(rent))/mes")
                                        .font(.footnote)
                                        .foregroundColor(.green)
                                }
                                HStack {
                                    Spacer()
                                    Button(role: .destructive) {
                                        // TODO: Eliminar propiedad
                                    } label: {
                                        Image(systemName: "trash")
                                    }
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    }
                    .listStyle(.plain)
                    Button(action: { /* TODO: Añadir propiedad */ }) {
                        Label("Añadir propiedad", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .padding()
                }
            }
            .navigationTitle("Propiedades")
        }
        .onAppear {
            fetchProperties()
        }
    }
    
    func fetchProperties() {
        guard let url = URL(string: "http://localhost:8000/properties/") else {
            errorMessage = "URL del backend inválida"
            return
        }
        isLoading = true
        errorMessage = nil
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
                if let error = error {
                    errorMessage = "Error de red: \(error.localizedDescription)"
                    return
                }
                guard let data = data else {
                    errorMessage = "No se recibió respuesta del servidor"
                    return
                }
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                    errorMessage = "Error \(httpResponse.statusCode): \(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))"
                    return
                }
                do {
                    let props = try JSONDecoder().decode([Property].self, from: data)
                    properties = props
                } catch {
                    errorMessage = "Error al decodificar propiedades: \(error.localizedDescription)"
                }
            }
        }
        task.resume()
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