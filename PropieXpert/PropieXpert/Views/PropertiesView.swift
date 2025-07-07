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
    @State private var showAddPropertySheet = false
    
    var body: some View {
        ZStack {
            NavigationView {
                VStack {
                    if isLoading {
                        ProgressView("Cargando propiedades...")
                    } else if let errorMessage = errorMessage {
                        Text(errorMessage).foregroundColor(.red)
                    } else if properties.isEmpty {
                        VStack(spacing: 12) {
                            Text("No tienes propiedades registradas.")
                                .foregroundColor(.gray)
                            Text("Pulsa el botón '+' para añadir una propiedad.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(properties) { property in
                                    PropertyCard(property: property)
                                        .padding(.horizontal)
                                        .onTapGesture {
                                            selectedProperty = property
                                        }
                                }
                            }
                            .padding(.top)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationTitle("Propiedades")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: { showAddPropertySheet = true }) {
                            Image(systemName: "plus")
                        }
                    }
                }
                .onAppear(perform: fetchProperties)
                .sheet(item: $selectedProperty) { property in
                    PropertyDetailSheet(propertyId: property.id)
                }
                .sheet(isPresented: $showAddPropertySheet) {
                    AddPropertySheet(onPropertyAdded: {
                        fetchProperties()
                    })
                }
            }
        }
        .ignoresSafeArea(.container, edges: .all)
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

struct PropertyCard: View {
    let property: Property
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(property.name)
                    .font(.headline)
                Spacer()
                Text(property.property_type.capitalized)
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.15))
                    .foregroundColor(.blue)
                    .cornerRadius(10)
            }
            if !property.address.isEmpty {
                Text(property.address)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Valor actual")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatCurrency(property.current_value))
                        .font(.body).bold()
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Precio compra")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatCurrency(property.purchase_price))
                        .font(.body)
                }
            }
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Habitaciones")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(property.bedrooms)")
                        .font(.body)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Baños")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(property.bathrooms)")
                        .font(.body)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Alquilada")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(property.is_rented ? "Sí" : "No")
                        .font(.body)
                        .foregroundColor(property.is_rented ? .green : .orange)
                }
                if let rent = property.rental_price, property.is_rented {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Alquiler")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(formatCurrency(rent))
                            .font(.body)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color(.black).opacity(0.04), radius: 8, x: 0, y: 2)
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