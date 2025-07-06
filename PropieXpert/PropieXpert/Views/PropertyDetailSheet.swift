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
    let square_meters: Double?
    // ... otros campos si los necesitas
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case name, address, property_type, purchase_price, current_value, bedrooms, bathrooms, is_rented, rental_price, description, amenities, notes, square_meters
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
                    VStack(alignment: .leading, spacing: 20) {
                        // Header
                        HStack(alignment: .center, spacing: 12) {
                            Image(systemName: "house.fill")
                                .resizable()
                                .frame(width: 36, height: 36)
                                .foregroundColor(.accentColor)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(property.name)
                                    .font(.largeTitle).bold()
                                Text(property.address)
                                    .font(.title3)
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.bottom, 8)
                        // Card
                        VStack(spacing: 0) {
                            DetailRow(label: "Tipo de Propiedad", value: property.property_type.capitalized)
                            DetailRow(label: "Dormitorios", value: "\(property.bedrooms)")
                            DetailRow(label: "Baños", value: "\(property.bathrooms)")
                            DetailRow(label: "Metros Cuadrados", value: property.square_meters != nil ? "\(Int(property.square_meters!)) m²" : "-")
                            DetailRow(label: "Precio de Compra", value: formatCurrency(property.purchase_price))
                            DetailRow(label: "Valor Actual", value: formatCurrency(property.current_value))
                            DetailRow(label: "Alquilada", value: property.is_rented ? "Sí" : "No")
                            if property.is_rented, let rent = property.rental_price {
                                DetailRow(label: "Precio Alquiler", value: formatCurrency(rent))
                            }
                        }
                        .padding(.vertical, 20)
                        .padding(.horizontal, 16)
                        .background(Color(.systemGray6))
                        .cornerRadius(16)
                        .padding(.bottom, 4)
                        // Descripción
                        if let description = property.description, !description.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 6) {
                                    Image(systemName: "doc.text")
                                        .foregroundColor(.accentColor)
                                    Text("Descripción")
                                        .font(.headline)
                                }
                                Text(description)
                                    .font(.body)
                                    .foregroundColor(.primary)
                            }
                            .padding(.top, 8)
                        }
                        // Amenities
                        if let amenities = property.amenities, !amenities.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 6) {
                                    Image(systemName: "checkmark.seal")
                                        .foregroundColor(.accentColor)
                                    Text("Comodidades")
                                        .font(.headline)
                                }
                                WrapHStack(items: amenities, spacing: 8) { amenity in
                                    Text(amenity)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color(.systemGray5))
                                        .cornerRadius(12)
                                        .font(.subheadline)
                                }
                            }
                        }
                        // Notas
                        if let notes = property.notes, !notes.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 6) {
                                    Image(systemName: "note.text")
                                        .foregroundColor(.accentColor)
                                    Text("Notas")
                                        .font(.headline)
                                }
                                Text(notes)
                                    .font(.body)
                                    .foregroundColor(.primary)
                            }
                            .padding(.top, 8)
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
                    VStack(alignment: .leading, spacing: 24) {
                        // Resumen Financiero
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "eurosign.circle")
                                    .foregroundColor(.accentColor)
                                Text("Resumen Financiero")
                                    .font(.headline)
                            }
                            HStack(spacing: 12) {
                                FinancialCard(title: "Ingresos Totales", value: formatCurrency(summary.total_income), color: .green)
                                FinancialCard(title: "Gastos Totales", value: formatCurrency(summary.total_expenses), color: .red)
                                FinancialCard(title: "Ingresos Netos", value: formatCurrency(summary.net_income), color: .blue)
                            }
                        }
                        // Métricas de Rendimiento
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                    .foregroundColor(.accentColor)
                                Text("Métricas de Rendimiento")
                                    .font(.headline)
                            }
                            VStack(spacing: 12) {
                                HStack(spacing: 12) {
                                    FinancialCard(title: "ROI Bruto", value: String(format: "%.2f%%", summary.gross_roi), color: .green)
                                    FinancialCard(title: "Pago de Hipoteca", value: formatCurrency(summary.mortgage_payment), color: .gray)
                                }
                                HStack(spacing: 12) {
                                    FinancialCard(title: "ROI Neto", value: String(format: "%.2f%%", summary.net_roi), color: .blue)
                                    FinancialCard(title: "Flujo de Caja", value: formatCurrency(summary.cash_flow), color: .green)
                                }
                                HStack(spacing: 12) {
                                    FinancialCard(title: "ROI Total", value: String(format: "%.2f%%", summary.total_roi), color: .purple)
                                    FinancialCard(title: "Apreciación del Valor", value: formatCurrency(summary.value_appreciation), color: .blue)
                                }
                            }
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

// Helper para hacer un HStack que envuelve (wrap) los amenities
struct WrapHStack<Data: RandomAccessCollection, Content: View>: View where Data.Element: Hashable {
    let items: Data
    let spacing: CGFloat
    let content: (Data.Element) -> Content
    
    @State private var totalHeight = CGFloat.zero
    
    var body: some View {
        GeometryReader { geometry in
            self.generateContent(in: geometry)
        }
        .frame(height: totalHeight)
    }
    
    private func generateContent(in geometry: GeometryProxy) -> some View {
        var width = CGFloat.zero
        var height = CGFloat.zero
        return ZStack(alignment: .topLeading) {
            ForEach(Array(items), id: \.self) { item in
                content(item)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 0)
                    .alignmentGuide(.leading, computeValue: { d in
                        if abs(width - d.width) > geometry.size.width {
                            width = 0
                            height -= d.height + spacing
                        }
                        let result = width
                        if item == items.last {
                            width = 0 // last item
                        } else {
                            width -= d.width + spacing
                        }
                        return result
                    })
                    .alignmentGuide(.top, computeValue: { _ in
                        let result = height
                        if item == items.last {
                            height = 0 // last item
                        }
                        return result
                    })
            }
        }
        .background(viewHeightReader($totalHeight))
    }
    
    private func viewHeightReader(_ binding: Binding<CGFloat>) -> some View {
        GeometryReader { geometry in
            Color.clear
                .preference(key: HeightPreferenceKey.self, value: geometry.size.height)
        }
        .onPreferenceChange(HeightPreferenceKey.self) { value in
            binding.wrappedValue = value
        }
    }
}

private struct HeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

// Helper para formato moneda
extension PropertyDetailSheet {
    func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "€\(amount)"
    }
}

// Helper para filas de detalles con más margen
struct DetailRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack {
            Text(label)
                .font(.headline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.title3)
                .foregroundColor(.primary)
        }
        .padding(.vertical, 8)
    }
}

// Helper para tarjetas financieras
struct FinancialCard: View {
    let title: String
    let value: String
    let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.title3).bold()
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
} 