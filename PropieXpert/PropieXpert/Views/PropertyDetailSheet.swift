import SwiftUI

struct PropertyDetail: Decodable {
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
    let description: String?
    let amenities: [String]?
    let notes: String?
    // ... otros campos si los necesitas
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case name, address, property_type, purchase_price, current_value, bedrooms, bathrooms, is_rented, rental_price, description, amenities, notes
    }
}

struct PropertyDetailSheet: View {
    let propertyId: String
    @AppStorage("auth_token") var authToken: String = ""
    @Environment(\.dismiss) var dismiss
    @State private var property: PropertyDetail? = nil
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView("Cargando propiedad...")
                } else if let errorMessage = errorMessage {
                    Text(errorMessage).foregroundColor(.red)
                } else if let property = property {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text(property.name).font(.title).bold()
                            Text(property.address).font(.subheadline).foregroundColor(.gray)
                            HStack(spacing: 16) {
                                Text(property.property_type.capitalized)
                                Text("Habitaciones: \(property.bedrooms)")
                                Text("Baños: \(property.bathrooms)")
                            }.font(.caption)
                            Divider()
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("Precio de compra").font(.caption).foregroundColor(.gray)
                                    Text("€\(Int(property.purchase_price))").bold()
                                }
                                Spacer()
                                VStack(alignment: .leading) {
                                    Text("Valor actual").font(.caption).foregroundColor(.gray)
                                    Text("€\(Int(property.current_value))").bold()
                                }
                            }
                            Divider()
                            HStack {
                                Text("Alquilada:")
                                Text(property.is_rented ? "Sí" : "No")
                                if let rental = property.rental_price {
                                    Text("| Precio alquiler: €\(Int(rental))")
                                }
                            }.font(.subheadline)
                            if let description = property.description, !description.isEmpty {
                                Divider()
                                Text("Descripción").font(.headline)
                                Text(description)
                            }
                            if let amenities = property.amenities, !amenities.isEmpty {
                                Divider()
                                Text("Comodidades").font(.headline)
                                ForEach(amenities, id: \.self) { amenity in
                                    Text("• \(amenity)")
                                }
                            }
                            if let notes = property.notes, !notes.isEmpty {
                                Divider()
                                Text("Notas").font(.headline)
                                Text(notes)
                            }
                        }
                        .padding()
                    }
                } else {
                    Text("No se encontró la propiedad.")
                }
            }
            .navigationTitle("Detalle")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
            .onAppear(perform: fetchPropertyDetail)
        }
    }
    
    func fetchPropertyDetail() {
        isLoading = true
        errorMessage = nil
        guard let url = URL(string: "https://api.propiexpert.com/properties/\(propertyId)") else { return }
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
                    let decoded = try JSONDecoder().decode(PropertyDetail.self, from: data)
                    property = decoded
                } catch {
                    errorMessage = "Error al decodificar propiedad: \(error.localizedDescription)"
                }
            }
        }.resume()
    }
} 