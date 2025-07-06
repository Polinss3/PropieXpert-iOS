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

struct FinancialSummary: Decodable {
    let total_income: Double
    let total_expenses: Double
    let net_income: Double
    let mortgage_payment: Double
    let cash_flow: Double
    let gross_roi: Double
    let net_roi: Double
    let total_roi: Double
    let property_value: Double
    let value_appreciation: Double
}

enum PropertyDetailTab: String, CaseIterable, Identifiable {
    case detalles = "Detalles"
    case financiero = "Financiero"
    case ingresosGastos = "Ingresos y Gastos"
    case documentos = "Documentos"
    case hipoteca = "Hipoteca"
    var id: String { self.rawValue }
}

struct PropertyDetailSheet: View {
    let propertyId: String
    @AppStorage("auth_token") var authToken: String = ""
    @Environment(\.dismiss) var dismiss
    @State private var property: PropertyDetail? = nil
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var selectedTab: PropertyDetailTab = .detalles
    @State private var financialSummary: FinancialSummary? = nil
    @State private var isLoadingFinancial = false
    @State private var errorFinancial: String? = nil
    // TODO: Añadir estados para ingresos/gastos, documentos, hipoteca
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Picker("Sección", selection: $selectedTab) {
                    ForEach(PropertyDetailTab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding([.top, .horizontal])
                Divider()
                Group {
                    switch selectedTab {
                    case .detalles:
                        detallesSection
                    case .financiero:
                        financieroSection
                    case .ingresosGastos:
                        ingresosGastosSection
                    case .documentos:
                        documentosSection
                    case .hipoteca:
                        hipotecaSection
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle("Detalle")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
            .onAppear(perform: {
                fetchPropertyDetail()
                // Pre-cargar financiero
                fetchFinancialSummary()
            })
        }
    }
    
    // MARK: - Secciones
    var detallesSection: some View {
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
    }
    
    var financieroSection: some View {
        Group {
            if isLoadingFinancial {
                ProgressView("Cargando resumen financiero...")
            } else if let errorFinancial = errorFinancial {
                Text(errorFinancial).foregroundColor(.red)
            } else if let summary = financialSummary {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Ingresos totales").font(.caption).foregroundColor(.gray)
                                Text("€\(Int(summary.total_income))").bold().foregroundColor(.green)
                            }
                            Spacer()
                            VStack(alignment: .leading) {
                                Text("Gastos totales").font(.caption).foregroundColor(.gray)
                                Text("€\(Int(summary.total_expenses))").bold().foregroundColor(.red)
                            }
                        }
                        Divider()
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Ingresos netos").font(.caption).foregroundColor(.gray)
                                Text("€\(Int(summary.net_income))").bold().foregroundColor(.blue)
                            }
                            Spacer()
                            VStack(alignment: .leading) {
                                Text("Cash Flow").font(.caption).foregroundColor(.gray)
                                Text("€\(Int(summary.cash_flow))").bold().foregroundColor(.green)
                            }
                        }
                        Divider()
                        VStack(alignment: .leading, spacing: 8) {
                            Text("ROI Bruto: \(String(format: "%.2f", summary.gross_roi))%")
                            Text("ROI Neto: \(String(format: "%.2f", summary.net_roi))%")
                            Text("ROI Total: \(String(format: "%.2f", summary.total_roi))%")
                        }
                        Divider()
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Pago hipoteca: €\(Int(summary.mortgage_payment))")
                            Text("Valor propiedad: €\(Int(summary.property_value))")
                            Text("Revalorización: €\(Int(summary.value_appreciation))")
                        }
                    }
                    .padding()
                }
            } else {
                Text("No hay datos financieros.")
            }
        }
    }
    
    var ingresosGastosSection: some View {
        VStack {
            Text("Ingresos y Gastos")
                .font(.headline)
                .padding()
            Text("(Próximamente: listado real de ingresos y gastos)")
                .foregroundColor(.gray)
        }
    }
    
    var documentosSection: some View {
        VStack {
            Text("Documentos")
                .font(.headline)
                .padding()
            Text("(Próximamente: listado real de documentos)")
                .foregroundColor(.gray)
        }
    }
    
    var hipotecaSection: some View {
        VStack {
            Text("Hipoteca")
                .font(.headline)
                .padding()
            Text("(Próximamente: datos reales de hipoteca)")
                .foregroundColor(.gray)
        }
    }
    
    // MARK: - Carga de datos
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
    
    func fetchFinancialSummary() {
        isLoadingFinancial = true
        errorFinancial = nil
        guard let url = URL(string: "https://api.propiexpert.com/properties/\(propertyId)/financial-summary") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isLoadingFinancial = false
                if let error = error {
                    errorFinancial = "Error de red: \(error.localizedDescription)"
                    return
                }
                guard let data = data else {
                    errorFinancial = "No se recibieron datos del servidor."
                    return
                }
                do {
                    let decoded = try JSONDecoder().decode(FinancialSummary.self, from: data)
                    financialSummary = decoded
                } catch {
                    errorFinancial = "Error al decodificar resumen financiero: \(error.localizedDescription)"
                }
            }
        }.resume()
    }
} 