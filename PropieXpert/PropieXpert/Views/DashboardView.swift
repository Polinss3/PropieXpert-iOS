import SwiftUI
import Charts

struct DashboardSummaryItem: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let value: String
    let subtitle: String
    let color: Color
}

// Modelo real para PropertyPerformance
struct PropertyPerformance: Identifiable, Decodable {
    let id: String
    let name: String
    let type: String
    let net_income: Double
    let roi: Double
    let appreciation: Double
    let current_value: Double
    
    enum CodingKeys: String, CodingKey {
        case id = "property_id"
        case name, type, net_income, roi, appreciation, current_value
    }
}

// Nueva enum para las secciones
enum DashboardSection: String, CaseIterable, Identifiable {
    case resumen = "Resumen"
    case rendimiento = "Rendimiento"
    case graficas = "Gráficas"
    var id: String { self.rawValue }
}

struct DashboardView: View {
    @AppStorage("auth_token") var authToken: String = ""
    @State private var propertyPerformance: [PropertyPerformance] = []
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var selectedSection: DashboardSection = .resumen
    // Simulación de datos de resumen (reemplazar por datos reales de la API)
    let summaryItems: [DashboardSummaryItem] = [
        DashboardSummaryItem(icon: "house.fill", title: "Propiedades", value: "4", subtitle: "Registradas", color: .blue),
        DashboardSummaryItem(icon: "eurosign.circle.fill", title: "Valor total", value: "€850,000", subtitle: "Valor actual", color: .green),
        DashboardSummaryItem(icon: "creditcard.fill", title: "Inversión", value: "€600,000", subtitle: "Invertido", color: .purple),
        DashboardSummaryItem(icon: "chart.line.uptrend.xyaxis", title: "Apreciación", value: "€50,000", subtitle: "Ganancia", color: .orange),
        DashboardSummaryItem(icon: "arrow.down.circle.fill", title: "Ingresos mensuales", value: "€3,200", subtitle: "Este mes", color: .green),
        DashboardSummaryItem(icon: "arrow.up.circle.fill", title: "Gastos mensuales", value: "€1,200", subtitle: "Este mes", color: .red),
        DashboardSummaryItem(icon: "equal.circle.fill", title: "Neto mensual", value: "€2,000", subtitle: "Este mes", color: .gray),
        DashboardSummaryItem(icon: "calendar", title: "Ingresos anuales", value: "€38,400", subtitle: "Este año", color: .green),
        DashboardSummaryItem(icon: "calendar", title: "Gastos anuales", value: "€14,400", subtitle: "Este año", color: .red),
        DashboardSummaryItem(icon: "calendar", title: "Neto anual", value: "€24,000", subtitle: "Este año", color: .gray)
    ]
    // ROI y Hipoteca
    let roiItems: [DashboardSummaryItem] = [
        DashboardSummaryItem(icon: "percent", title: "ROI Bruto", value: "7.5%", subtitle: "Antes de gastos", color: .blue),
        DashboardSummaryItem(icon: "percent", title: "ROI Neto", value: "5.2%", subtitle: "Después de gastos", color: .green),
        DashboardSummaryItem(icon: "percent", title: "ROI Total", value: "4.1%", subtitle: "Después de hipoteca", color: .purple)
    ]
    let mortgageItems: [DashboardSummaryItem] = [
        DashboardSummaryItem(icon: "banknote", title: "Pago hipoteca", value: "€800", subtitle: "Mensual", color: .yellow),
        DashboardSummaryItem(icon: "banknote", title: "Saldo hipoteca", value: "€120,000", subtitle: "Restante", color: .orange)
    ]
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Barra de navegación superior (SegmentedControl)
                Picker("Sección", selection: $selectedSection) {
                    ForEach(DashboardSection.allCases) { section in
                        Text(section.rawValue).tag(section)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding([.top, .horizontal])
                
                Divider().padding(.bottom, 8)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // --- Sección Resumen ---
                        if selectedSection == .resumen {
                            Text("Dashboard")
                                .font(.largeTitle).bold()
                                .padding(.top, 8)
                                .padding(.horizontal)
                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(summaryItems) { item in
                                    DashboardSummaryCard(item: item)
                                }
                            }
                            .padding(.horizontal)
                            Text("Rentabilidad (ROI)")
                                .font(.headline)
                                .padding(.horizontal)
                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(roiItems) { item in
                                    DashboardSummaryCard(item: item)
                                }
                            }
                            .padding(.horizontal)
                            Text("Hipoteca")
                                .font(.headline)
                                .padding(.horizontal)
                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(mortgageItems) { item in
                                    DashboardSummaryCard(item: item)
                                }
                            }
                            .padding(.horizontal)
                        }
                        // --- Sección Rendimiento ---
                        if selectedSection == .rendimiento {
                            Text("Rendimiento de propiedades")
                                .font(.largeTitle).bold()
                                .padding([.top, .horizontal])
                            if isLoading {
                                HStack {
                                    Spacer()
                                    ProgressView("Cargando...")
                                    Spacer()
                                }
                            } else if let errorMessage = errorMessage {
                                Text(errorMessage).foregroundColor(.red).padding(.horizontal)
                            } else if propertyPerformance.isEmpty {
                                Text("No hay datos de rendimiento disponibles.")
                                    .foregroundColor(.gray)
                                    .padding(.horizontal)
                            } else {
                                VStack(spacing: 16) {
                                    ForEach(propertyPerformance) { prop in
                                        PropertyPerformanceCard(prop: prop)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                        // --- Sección Gráficas (ahora con gráfica de barras mensual) ---
                        if selectedSection == .graficas {
                            Text("Gráficas")
                                .font(.largeTitle).bold()
                                .padding([.top, .horizontal])
                            VStack(alignment: .leading, spacing: 24) {
                                Text("Ingresos y gastos mensuales")
                                    .font(.headline)
                                    .padding(.horizontal)
                                MonthlyBarChartView()
                                    .frame(height: 320)
                                    .padding(.horizontal)
                                // Aquí puedes añadir más gráficas (líneas, pastel) después
                            }
                        }
                    }
                    .padding(.vertical)
                }
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .onAppear(perform: fetchPropertyPerformance)
        }
    }
    
    func fetchPropertyPerformance() {
        isLoading = true
        errorMessage = nil
        guard let url = URL(string: "https://api.propiexpert.com/dashboard/") else {
            isLoading = false
            errorMessage = "URL inválida"
            return
        }
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
                    struct DashboardResponse: Decodable {
                        let property_performance: [PropertyPerformance]
                    }
                    let decoded = try JSONDecoder().decode(DashboardResponse.self, from: data)
                    propertyPerformance = decoded.property_performance
                } catch {
                    errorMessage = "Error al decodificar datos: \(error.localizedDescription)"
                }
            }
        }.resume()
    }
}

struct DashboardSummaryCard: View {
    let item: DashboardSummaryItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: item.icon)
                    .font(.system(size: 28))
                    .foregroundColor(item.color)
                    .frame(width: 40, height: 40)
                    .background(item.color.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                Spacer()
            }
            Text(item.title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text(item.value)
                .font(.title2).bold()
                .foregroundColor(.primary)
            Text(item.subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color(.black).opacity(0.04), radius: 8, x: 0, y: 2)
    }
}

// Tarjeta visual para el rendimiento de cada propiedad
struct PropertyPerformanceCard: View {
    let prop: PropertyPerformance
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(prop.name)
                        .font(.headline)
                    Text(prop.type.capitalized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text(String(format: "%.1f%% ROI", prop.roi))
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.15))
                    .foregroundColor(.blue)
                    .cornerRadius(10)
            }
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Neto")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatCurrency(prop.net_income))
                        .font(.body).bold()
                        .foregroundColor(.green)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Apreciación")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatCurrency(prop.appreciation))
                        .font(.body)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Valor actual")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatCurrency(prop.current_value))
                        .font(.body)
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

// Datos simulados para la gráfica de barras mensual
struct MonthlyBarData: Identifiable {
    let id = UUID()
    let month: String
    let income: Double
    let expense: Double
    var net: Double { income - expense }
}

let monthlyBarData: [MonthlyBarData] = [
    MonthlyBarData(month: "Ene", income: 3200, expense: 1200),
    MonthlyBarData(month: "Feb", income: 3100, expense: 1100),
    MonthlyBarData(month: "Mar", income: 3300, expense: 1300),
    MonthlyBarData(month: "Abr", income: 3400, expense: 1250),
    MonthlyBarData(month: "May", income: 3250, expense: 1400),
    MonthlyBarData(month: "Jun", income: 3350, expense: 1200),
    MonthlyBarData(month: "Jul", income: 3500, expense: 1500),
    MonthlyBarData(month: "Ago", income: 3400, expense: 1350),
    MonthlyBarData(month: "Sep", income: 3300, expense: 1200),
    MonthlyBarData(month: "Oct", income: 3450, expense: 1400),
    MonthlyBarData(month: "Nov", income: 3550, expense: 1500),
    MonthlyBarData(month: "Dic", income: 3600, expense: 1600)
]

struct MonthlyBarChartView: View {
    // En el futuro, puedes pasar los datos reales como parámetro
    let data: [MonthlyBarData] = monthlyBarData
    
    var body: some View {
        Chart(data) { item in
            BarMark(
                x: .value("Mes", item.month),
                y: .value("Ingresos", item.income)
            )
            .foregroundStyle(Color.green.gradient)
            BarMark(
                x: .value("Mes", item.month),
                y: .value("Gastos", -item.expense)
            )
            .foregroundStyle(Color.red.gradient)
        }
        .chartYAxis {
            AxisMarks(position: .leading) {
                AxisGridLine()
                AxisTick()
                AxisValueLabel(format: .number.precision(.fractionLength(0)))
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel()
            }
        }
        .chartLegend(position: .top, alignment: .center)
        .padding(.top, 8)
    }
}

#Preview {
    DashboardView()
} 