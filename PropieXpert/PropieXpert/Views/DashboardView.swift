import SwiftUI
import Charts
import Foundation

// --- Helpers para recurrencia y puntuales ---
protocol HasRecurrence {
    var is_recurring: Bool? { get }
    var frequency: String? { get }
    var recurrence_start_date: String? { get }
    var recurrence_end_date: String? { get }
    var date: String { get }
    var amount: Double { get }
}
extension Income: HasRecurrence {}
extension Expense: HasRecurrence {}

// NUEVA: Protocolo para crear copias de eventos con nuevas fechas
protocol EventCopyable {
    func withNewDate(_ newDate: String) -> Self
}

// Implementar EventCopyable para Income
extension Income: EventCopyable {
    func withNewDate(_ newDate: String) -> Income {
        return Income(
            id: self.id + "_" + newDate, // ID único para evitar duplicados
            property_id: self.property_id,
            type: self.type,
            amount: self.amount,
            date: newDate,
            description: self.description,
            is_recurring: self.is_recurring,
            frequency: self.frequency,
            recurrence_start_date: self.recurrence_start_date,
            recurrence_end_date: self.recurrence_end_date
        )
    }
}

// Implementar EventCopyable para Expense
extension Expense: EventCopyable {
    func withNewDate(_ newDate: String) -> Expense {
        return Expense(
            id: self.id + "_" + newDate, // ID único para evitar duplicados
            property_id: self.property_id,
            type: self.type,
            amount: self.amount,
            date: newDate,
            description: self.description,
            is_recurring: self.is_recurring,
            frequency: self.frequency,
            due_date: self.due_date,
            is_paid: self.is_paid,
            payment_date: self.payment_date,
            recurrence_start_date: self.recurrence_start_date,
            recurrence_end_date: self.recurrence_end_date
        )
    }
}

// NUEVA FUNCIÓN: Expandir eventos recurrentes para un rango de fechas
func expandRecurringForDateRange<T: HasRecurrence & EventCopyable>(
    items: [T], 
    startDate: Date, 
    endDate: Date
) -> [T] {
    let calendar = Calendar.current
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
    let simpleFormatter = DateFormatter()
    simpleFormatter.dateFormat = "yyyy-MM-dd"
    
    var expandedEvents: [T] = []
    
    for item in items {
        // Solo procesar eventos recurrentes
        guard let isRecurring = item.is_recurring, isRecurring,
              let frequency = item.frequency else {
            continue
        }
        
        let itemStartStr = item.recurrence_start_date ?? item.date
        let itemEndStr = item.recurrence_end_date ?? "2055-12-31"
        
        // Parsear fechas del evento
        guard let itemStartDate = formatter.date(from: itemStartStr) ?? simpleFormatter.date(from: itemStartStr),
              let itemEndDate = formatter.date(from: itemEndStr) ?? simpleFormatter.date(from: itemEndStr) else {
            continue
        }
        
        // Calcular el rango efectivo
        let effectiveStart = max(startDate, itemStartDate)
        let effectiveEnd = min(endDate, itemEndDate)
        
        if effectiveStart > effectiveEnd {
            continue
        }
        
        // Generar eventos para cada mes en el rango
        var currentDate = effectiveStart
        while currentDate <= effectiveEnd {
            let year = calendar.component(.year, from: currentDate)
            let month = calendar.component(.month, from: currentDate)
            
            // Calcular si este mes debe tener el evento
            let monthStart = calendar.date(from: DateComponents(year: year, month: month, day: 1))!
            let monthsDiff = calendar.dateComponents([.month], from: calendar.startOfDay(for: itemStartDate), to: monthStart).month ?? 0
            
            var shouldInclude = false
            switch frequency {
            case "monthly":
                shouldInclude = true
            case "quarterly":
                shouldInclude = monthsDiff % 3 == 0
            case "yearly":
                shouldInclude = monthsDiff % 12 == 0
            default:
                shouldInclude = false
            }
            
            if shouldInclude {
                // Crear fecha específica para este mes (mismo día que el original)
                let originalComponents = calendar.dateComponents([.day], from: itemStartDate)
                let targetDay = min(originalComponents.day ?? 1, calendar.range(of: .day, in: .month, for: monthStart)?.count ?? 1)
                
                if let eventDate = calendar.date(from: DateComponents(year: year, month: month, day: targetDay)) {
                    let eventDateString = simpleFormatter.string(from: eventDate)
                    let expandedEvent = item.withNewDate(eventDateString)
                    expandedEvents.append(expandedEvent)
                }
            }
            
            // Avanzar al siguiente mes
            currentDate = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? currentDate
            if currentDate == monthStart { break } // Evitar loop infinito
        }
    }
    
    return expandedEvents
}

// NUEVA FUNCIÓN: Expandir eventos puntuales para un rango de fechas
func expandPunctualForDateRange<T: HasRecurrence & EventCopyable>(
    items: [T], 
    startDate: Date, 
    endDate: Date
) -> [T] {
    let calendar = Calendar.current
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
    let simpleFormatter = DateFormatter()
    simpleFormatter.dateFormat = "yyyy-MM-dd"
    
    return items.compactMap { item in
        // Solo procesar eventos no recurrentes
        guard let isRecurring = item.is_recurring, !isRecurring else {
            return nil
        }
        
        // Parsear fecha del evento
        guard let eventDate = formatter.date(from: item.date) ?? simpleFormatter.date(from: item.date) else {
            return nil
        }
        
        // Verificar si está dentro del rango
        if eventDate >= startDate && eventDate <= endDate {
            return item
        }
        
        return nil
    }
}

// FUNCIONES LEGACY (mantener para compatibilidad con gráficas)
func expandRecurring<T: Identifiable & HasRecurrence>(items: [T], year: Int, month: Int) -> [T] {
    let calendar = Calendar.current
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
    let simpleFormatter = DateFormatter()
    simpleFormatter.dateFormat = "yyyy-MM-dd"
    
    return items.compactMap { item in
        guard let isRecurring = item.is_recurring, isRecurring,
              let frequency = item.frequency else { 
            return nil 
        }
        let startStr = item.recurrence_start_date ?? item.date
        let endStr = item.recurrence_end_date ?? "\(year)-12-31"
        
        var start: Date?
        var end: Date?
        
        start = formatter.date(from: startStr) ?? simpleFormatter.date(from: startStr)
        end = formatter.date(from: endStr) ?? simpleFormatter.date(from: endStr)
        
        guard let startDate = start, let endDate = end else { 
            return nil 
        }
        
        let currentMonth = calendar.date(from: DateComponents(year: year, month: month, day: 1))!
        if currentMonth < calendar.startOfDay(for: startDate) || currentMonth > calendar.startOfDay(for: endDate) { 
            return nil 
        }
        let monthsDiff = calendar.dateComponents([.month], from: calendar.startOfDay(for: startDate), to: currentMonth).month ?? 0
        if (frequency == "monthly") || (frequency == "quarterly" && monthsDiff % 3 == 0) || (frequency == "yearly" && monthsDiff % 12 == 0) {
            return item
        }
        return nil
    }
}

func expandPunctual<T: Identifiable & HasRecurrence>(items: [T], year: Int, month: Int) -> [T] {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
    let simpleFormatter = DateFormatter()
    simpleFormatter.dateFormat = "yyyy-MM-dd"
    
    return items.filter { item in
        guard let isRecurring = item.is_recurring, !isRecurring else { 
            return false 
        }
        
        guard let date = formatter.date(from: item.date) ?? simpleFormatter.date(from: item.date) else { 
            return false 
        }
        
        let comps = Calendar.current.dateComponents([.year, .month], from: date)
        return comps.year == year && comps.month == month
    }
}

func monthlyBarDataFromAPI(incomes: [Income], expenses: [Expense]) -> [MonthlyBarData] {
    let months = ["Ene", "Feb", "Mar", "Abr", "May", "Jun", "Jul", "Ago", "Sep", "Oct", "Nov", "Dic"]
    let currentYear = Calendar.current.component(.year, from: Date())
    var result: [MonthlyBarData] = []
    
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
    let simpleFormatter = DateFormatter()
    simpleFormatter.dateFormat = "yyyy-MM-dd"
    
    for m in 1...12 {
        var incomeSum: Double = 0
        var expenseSum: Double = 0
        
        // Calcular ingresos para este mes
        for income in incomes {
            if let isRecurring = income.is_recurring, isRecurring {
                // Evento recurrente - verificar si aplica a este mes
                if let frequency = income.frequency {
                    let startStr = income.recurrence_start_date ?? income.date
                    if let startDate = formatter.date(from: startStr) ?? simpleFormatter.date(from: startStr) {
                        let startComps = Calendar.current.dateComponents([.year, .month], from: startDate)
                        
                        if let startYear = startComps.year, let startMonth = startComps.month {
                            if currentYear >= startYear {
                                let monthsDiff = (currentYear - startYear) * 12 + (m - startMonth)
                                
                                if monthsDiff >= 0 {
                                    if frequency == "monthly" ||
                                       (frequency == "quarterly" && monthsDiff % 3 == 0) ||
                                       (frequency == "yearly" && monthsDiff % 12 == 0) {
                                        incomeSum += income.amount
                                    }
                                }
                            }
                        }
                    }
                }
            } else {
                // Evento puntual - verificar si es de este mes
                if let date = formatter.date(from: income.date) ?? simpleFormatter.date(from: income.date) {
                    let comps = Calendar.current.dateComponents([.year, .month], from: date)
                    if comps.year == currentYear && comps.month == m {
                        incomeSum += income.amount
                    }
                }
            }
        }
        
        // Calcular gastos para este mes (misma lógica)
        for expense in expenses {
            if let isRecurring = expense.is_recurring, isRecurring {
                if let frequency = expense.frequency {
                    let startStr = expense.recurrence_start_date ?? expense.date
                    if let startDate = formatter.date(from: startStr) ?? simpleFormatter.date(from: startStr) {
                        let startComps = Calendar.current.dateComponents([.year, .month], from: startDate)
                        
                        if let startYear = startComps.year, let startMonth = startComps.month {
                            if currentYear >= startYear {
                                let monthsDiff = (currentYear - startYear) * 12 + (m - startMonth)
                                
                                if monthsDiff >= 0 {
                                    if frequency == "monthly" ||
                                       (frequency == "quarterly" && monthsDiff % 3 == 0) ||
                                       (frequency == "yearly" && monthsDiff % 12 == 0) {
                                        expenseSum += expense.amount
                                    }
                                }
                            }
                        }
                    }
                }
            } else {
                if let date = formatter.date(from: expense.date) ?? simpleFormatter.date(from: expense.date) {
                    let comps = Calendar.current.dateComponents([.year, .month], from: date)
                    if comps.year == currentYear && comps.month == m {
                        expenseSum += expense.amount
                    }
                }
            }
        }
        
        result.append(MonthlyBarData(month: months[m-1], income: incomeSum, expense: expenseSum))
    }
    return result
}

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

// Modelo para la respuesta completa del dashboard
struct DashboardSummary: Decodable {
    let total_properties: Int
    let total_property_value: Double
    let total_investment: Double
    let total_appreciation: Double
    let monthly_income: Double
    let monthly_expenses: Double
    let monthly_net: Double
    let yearly_income: Double
    let yearly_expenses: Double
    let yearly_net: Double
    let total_mortgage_balance: Double
    let monthly_mortgage_payments: Double
    let gross_roi: Double
    let net_roi: Double
    let total_roi: Double
}

struct DashboardData: Decodable {
    let summary: DashboardSummary
    let property_performance: [PropertyPerformance]
}

// Nueva enum para las secciones
enum DashboardSection: String, CaseIterable, Identifiable {
    case resumen = "Resumen"
    case rendimiento = "Rendimiento"
    case graficas = "Gráficas"
    case calendario = "Calendario"
    var id: String { self.rawValue }
}

struct DashboardView: View {
    @AppStorage("auth_token") var authToken: String = ""
    @State private var propertyPerformance: [PropertyPerformance] = []
    @State private var dashboardData: DashboardData? = nil
    @State private var isLoading = false
    @State private var isDashboardLoading = false
    @State private var errorMessage: String? = nil
    @State private var dashboardErrorMessage: String? = nil
    @State private var selectedSection: DashboardSection = .resumen
    // Para la gráfica de barras mensual
    @State private var incomes: [Income] = []
    @State private var expenses: [Expense] = []
    @State private var isLoadingChart = false
    @State private var chartError: String? = nil
    @State private var selectedDate: Date = Date()
    @State private var showDayEventsSheet = false
    @State private var properties: [PropertyName] = []
    
    // NUEVO: Estados para eventos expandidos de múltiples meses
    @State private var expandedIncomes: [Income] = []
    @State private var expandedExpenses: [Expense] = []
    @State private var loadedMonthRange: (start: Date, end: Date)? = nil
    @State private var currentDate = Date()

    // Datos de resumen dinámicos basados en la API
    var summaryItems: [DashboardSummaryItem] {
        guard let summary = dashboardData?.summary else {
            return []
        }
        
        return [
            DashboardSummaryItem(icon: "house.fill", title: "Propiedades", value: "\(summary.total_properties)", subtitle: "Registradas", color: .blue),
            DashboardSummaryItem(icon: "eurosign.circle.fill", title: "Valor total", value: formatCurrency(summary.total_property_value), subtitle: "Valor actual", color: .green),
            DashboardSummaryItem(icon: "creditcard.fill", title: "Inversión", value: formatCurrency(summary.total_investment), subtitle: "Invertido", color: .purple),
            DashboardSummaryItem(icon: "chart.line.uptrend.xyaxis", title: "Apreciación", value: formatCurrency(summary.total_appreciation), subtitle: "Ganancia", color: .orange),
            DashboardSummaryItem(icon: "arrow.down.circle.fill", title: "Ingresos mensuales", value: formatCurrency(summary.monthly_income), subtitle: "Este mes", color: .green),
            DashboardSummaryItem(icon: "arrow.up.circle.fill", title: "Gastos mensuales", value: formatCurrency(summary.monthly_expenses), subtitle: "Este mes", color: .red),
            DashboardSummaryItem(icon: "equal.circle.fill", title: "Neto mensual", value: formatCurrency(summary.monthly_net), subtitle: "Este mes", color: .gray),
            DashboardSummaryItem(icon: "calendar", title: "Ingresos anuales", value: formatCurrency(summary.yearly_income), subtitle: "Este año", color: .green),
            DashboardSummaryItem(icon: "calendar", title: "Gastos anuales", value: formatCurrency(summary.yearly_expenses), subtitle: "Este año", color: .red),
            DashboardSummaryItem(icon: "calendar", title: "Neto anual", value: formatCurrency(summary.yearly_net), subtitle: "Este año", color: .gray)
        ]
    }
    
    // ROI dinámico basado en la API
    var roiItems: [DashboardSummaryItem] {
        guard let summary = dashboardData?.summary else {
            return []
        }
        
        return [
            DashboardSummaryItem(icon: "percent", title: "ROI Bruto", value: formatPercentage(summary.gross_roi), subtitle: "Antes de gastos", color: .blue),
            DashboardSummaryItem(icon: "percent", title: "ROI Neto", value: formatPercentage(summary.net_roi), subtitle: "Después de gastos", color: .green),
            DashboardSummaryItem(icon: "percent", title: "ROI Total", value: formatPercentage(summary.total_roi), subtitle: "Después de hipoteca", color: .purple)
        ]
    }
    
    // Hipoteca dinámica basada en la API
    var mortgageItems: [DashboardSummaryItem] {
        guard let summary = dashboardData?.summary else {
            return []
        }
        
        return [
            DashboardSummaryItem(icon: "banknote", title: "Pago hipoteca", value: formatCurrency(summary.monthly_mortgage_payments), subtitle: "Mensual", color: .yellow),
            DashboardSummaryItem(icon: "banknote", title: "Saldo hipoteca", value: formatCurrency(summary.total_mortgage_balance), subtitle: "Restante", color: .orange)
        ]
    }
    
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
                            
                            if isDashboardLoading {
                                HStack {
                                    Spacer()
                                    ProgressView("Cargando datos del dashboard...")
                                    Spacer()
                                }
                                .padding()
                            } else if let dashboardErrorMessage = dashboardErrorMessage {
                                VStack {
                                    Text("Error al cargar datos del dashboard")
                                        .font(.headline)
                                        .foregroundColor(.red)
                                    Text(dashboardErrorMessage)
                                        .foregroundColor(.red)
                                        .multilineTextAlignment(.center)
                                    Button("Reintentar") {
                                        fetchDashboardData()
                                    }
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                                }
                                .padding(.horizontal)
                            } else if dashboardData == nil {
                                Text("No hay datos disponibles")
                                    .foregroundColor(.gray)
                                    .padding(.horizontal)
                            } else {
                                LazyVGrid(columns: columns, spacing: 16) {
                                    ForEach(summaryItems) { item in
                                        DashboardSummaryCard(item: item)
                                    }
                                }
                                .padding(.horizontal)
                                
                                Text("Rentabilidad (ROI)")
                                    .font(.headline)
                                    .padding(.horizontal)
                                    .padding(.top)
                                LazyVGrid(columns: columns, spacing: 16) {
                                    ForEach(roiItems) { item in
                                        DashboardSummaryCard(item: item)
                                    }
                                }
                                .padding(.horizontal)
                                
                                Text("Hipoteca")
                                    .font(.headline)
                                    .padding(.horizontal)
                                    .padding(.top)
                                LazyVGrid(columns: columns, spacing: 16) {
                                    ForEach(mortgageItems) { item in
                                        DashboardSummaryCard(item: item)
                                    }
                                }
                                .padding(.horizontal)
                            }
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
                                if isLoadingChart {
                                    HStack { Spacer(); ProgressView("Cargando..."); Spacer() }
                                } else if let chartError = chartError {
                                    Text(chartError).foregroundColor(.red).padding(.horizontal)
                                } else {
                                    MonthlyBarChartView(data: monthlyBarDataFromAPI(incomes: incomes, expenses: expenses))
                                        .frame(height: 320)
                                        .padding(.horizontal)
                                }
                                // Aquí puedes añadir más gráficas (líneas, pastel) después
                            }
                        }
                        // --- NUEVA SECCIÓN CALENDARIO ---
                        if selectedSection == .calendario {
                            Text("Calendario de ingresos y gastos")
                                .font(.largeTitle).bold()
                                .padding([.top, .horizontal])
                            DashboardCalendarView(
                                expandedIncomes: expandedIncomes,
                                expandedExpenses: expandedExpenses,
                                selectedDate: $selectedDate,
                                showDayEventsSheet: $showDayEventsSheet,
                                currentDate: $currentDate,
                                onMonthChanged: { newMonth in
                                    ensureMonthDataLoaded(for: newMonth)
                                }
                            )
                        }
                    }
                    .padding(.vertical)
                }
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .onAppear {
                fetchDashboardData()
                fetchIncomesAndExpenses()
                fetchProperties()
            }
            // Sheet para mostrar eventos del día seleccionado
            .sheet(isPresented: $showDayEventsSheet) {
                DayEventsSheetView(
                    date: selectedDate,
                    expandedIncomes: expandedIncomes,
                    expandedExpenses: expandedExpenses,
                    properties: properties,
                    onClose: { showDayEventsSheet = false }
                )
            }
        }
    }
    
    func fetchDashboardData() {
        isDashboardLoading = true
        dashboardErrorMessage = nil
        guard let url = URL(string: "https://api.propiexpert.com/dashboard/") else {
            isDashboardLoading = false
            dashboardErrorMessage = "URL inválida"
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isDashboardLoading = false
                if let error = error {
                    dashboardErrorMessage = "Error de red: \(error.localizedDescription)"
                    return
                }
                guard let data = data else {
                    dashboardErrorMessage = "No se recibieron datos del servidor."
                    return
                }
                do {
                    let decoded = try JSONDecoder().decode(DashboardData.self, from: data)
                    dashboardData = decoded
                    // También actualizar la lista de performance para mantener compatibilidad
                    propertyPerformance = decoded.property_performance
                } catch {
                    dashboardErrorMessage = "Error al decodificar datos: \(error.localizedDescription)"
                    print("Dashboard decode error: \(error)")
                }
            }
        }.resume()
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
    
    func fetchIncomesAndExpenses() {
        isLoadingChart = true
        chartError = nil
        let group = DispatchGroup()
        var fetchedIncomes: [Income] = []
        var fetchedExpenses: [Expense] = []
        var errorOccurred: String? = nil
        // Incomes
        group.enter()
        guard let urlIncomes = URL(string: "https://api.propiexpert.com/incomes/") else { chartError = "URL de ingresos inválida"; return }
        var reqIncomes = URLRequest(url: urlIncomes)
        reqIncomes.httpMethod = "GET"
        reqIncomes.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        URLSession.shared.dataTask(with: reqIncomes) { data, response, error in
            defer { group.leave() }
            if let error = error { errorOccurred = "Error ingresos: \(error.localizedDescription)"; return }
            guard let data = data else { errorOccurred = "No datos de ingresos"; return }
            do {
                fetchedIncomes = try JSONDecoder().decode([Income].self, from: data)
            } catch {
                errorOccurred = "Error decodificando ingresos: \(error.localizedDescription)"
            }
        }.resume()
        // Expenses
        group.enter()
        guard let urlExpenses = URL(string: "https://api.propiexpert.com/expenses/") else { chartError = "URL de gastos inválida"; return }
        var reqExpenses = URLRequest(url: urlExpenses)
        reqExpenses.httpMethod = "GET"
        reqExpenses.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        URLSession.shared.dataTask(with: reqExpenses) { data, response, error in
            defer { group.leave() }
            if let error = error { errorOccurred = "Error gastos: \(error.localizedDescription)"; return }
            guard let data = data else { errorOccurred = "No datos de gastos"; return }
            do {
                fetchedExpenses = try JSONDecoder().decode([Expense].self, from: data)
            } catch {
                errorOccurred = "Error decodificando gastos: \(error.localizedDescription)"
            }
        }.resume()
        // Cuando ambos terminen
        group.notify(queue: .main) {
            isLoadingChart = false
            if let errorOccurred = errorOccurred {
                chartError = errorOccurred
            } else {
                incomes = fetchedIncomes
                expenses = fetchedExpenses
                // NUEVO: Expandir eventos para múltiples meses al obtener los datos
                expandEventsForInitialLoad()
            }
        }
    }
    
    // NUEVA FUNCIÓN: Expandir eventos para carga inicial (4 meses)
    func expandEventsForInitialLoad() {
        let calendar = Calendar.current
        let now = Date()
        
        // Calcular rango: 2 meses atrás hasta 2 meses adelante
        let startDate = calendar.date(byAdding: .month, value: -2, to: now) ?? now
        let endDate = calendar.date(byAdding: .month, value: 2, to: now) ?? now
        
        expandEventsForDateRange(from: startDate, to: endDate)
    }
    
    // Expandir eventos para un rango de fechas específico
    func expandEventsForDateRange(from startDate: Date, to endDate: Date) {
        print("DEBUG: Expandiendo eventos del \(startDate) al \(endDate)")
        
        // Limpiar eventos expandidos y recalcular todo
        expandedIncomes.removeAll()
        expandedExpenses.removeAll()
        
        // Usar las nuevas funciones para evitar duplicados
        let recurringIncomes = expandRecurringForDateRange(items: incomes, startDate: startDate, endDate: endDate)
        let punctualIncomes = expandPunctualForDateRange(items: incomes, startDate: startDate, endDate: endDate)
        
        let recurringExpenses = expandRecurringForDateRange(items: expenses, startDate: startDate, endDate: endDate)
        let punctualExpenses = expandPunctualForDateRange(items: expenses, startDate: startDate, endDate: endDate)
        
        // Combinar todos los eventos
        expandedIncomes = recurringIncomes + punctualIncomes
        expandedExpenses = recurringExpenses + punctualExpenses
        
        print("DEBUG: Expandidos \(expandedIncomes.count) ingresos y \(expandedExpenses.count) gastos")
        
        // Actualizar el rango de meses cargados
        loadedMonthRange = (start: startDate, end: endDate)
    }
    
    // NUEVA FUNCIÓN: Asegurar que los datos de un mes específico estén cargados
    func ensureMonthDataLoaded(for date: Date) {
        let calendar = Calendar.current
        
        guard let range = loadedMonthRange else {
            // Si no hay rango cargado, expandir alrededor de la fecha
            let start = calendar.date(byAdding: .month, value: -1, to: date) ?? date
            let end = calendar.date(byAdding: .month, value: 1, to: date) ?? date
            expandEventsForDateRange(from: start, to: end)
            return
        }
        
        // Verificar si la fecha está dentro del rango cargado
        let monthStart = calendar.dateInterval(of: .month, for: date)?.start ?? date
        
        if monthStart < range.start || monthStart > range.end {
            // La fecha está fuera del rango, expandir el rango
            let newStart = min(monthStart, range.start)
            let newEnd = max(monthStart, range.end)
            
            // Añadir un poco de margen (1 mes a cada lado)
            let expandedStart = calendar.date(byAdding: .month, value: -1, to: newStart) ?? newStart
            let expandedEnd = calendar.date(byAdding: .month, value: 1, to: newEnd) ?? newEnd
            
            expandEventsForDateRange(from: expandedStart, to: expandedEnd)
        }
    }
    
    func fetchProperties() {
        guard let url = URL(string: "https://api.propiexpert.com/properties/") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let data = data {
                    if let decoded = try? JSONDecoder().decode([PropertyName].self, from: data) {
                        properties = decoded
                    }
                }
            }
        }.resume()
    }
    
    func getPropertyName(for propertyId: String) -> String {
        properties.first(where: { $0._id == propertyId })?.name ?? "Propiedad desconocida"
    }
    
    func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        return formatter.string(from: NSNumber(value: amount)) ?? "€\(amount)"
    }
    
    func formatPercentage(_ value: Double) -> String {
        return String(format: "%.1f%%", value)
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
    let data: [MonthlyBarData]
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
                AxisValueLabel()
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

struct DashboardCalendarView: View {
    let expandedIncomes: [Income]
    let expandedExpenses: [Expense]
    @Binding var selectedDate: Date
    @Binding var showDayEventsSheet: Bool
    @Binding var currentDate: Date
    var onMonthChanged: (Date) -> Void
    
    private let calendar = Calendar.current
    private let dateFormatter = DateFormatter()
    private let simpleDateFormatter = DateFormatter()
    
    init(expandedIncomes: [Income], expandedExpenses: [Expense], selectedDate: Binding<Date>, showDayEventsSheet: Binding<Bool>, currentDate: Binding<Date>, onMonthChanged: @escaping (Date) -> Void) {
        self.expandedIncomes = expandedIncomes
        self.expandedExpenses = expandedExpenses
        self._selectedDate = selectedDate
        self._showDayEventsSheet = showDayEventsSheet
        self._currentDate = currentDate
        self.onMonthChanged = onMonthChanged
        // Arreglar: Configurar ambos formatters para manejar diferentes formatos
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        simpleDateFormatter.dateFormat = "yyyy-MM-dd"
    }
    
    // Helpers para obtener eventos del mes usando datos expandidos
    func eventsByDay(for month: Date) -> [Date: (Int, Int)] {
        var dict: [Date: (Int, Int)] = [:] // [fecha: (ingresos, gastos)]
        let year = calendar.component(.year, from: month)
        let monthNum = calendar.component(.month, from: month)
        
        // print("DEBUG: Procesando eventos expandidos para \(monthNum)/\(year)")
        
        // Filtrar eventos expandidos por mes
        let monthIncomes = expandedIncomes.filter { income in
            guard let date = dateFromString(income.date) else { return false }
            return calendar.component(.year, from: date) == year && 
                   calendar.component(.month, from: date) == monthNum
        }
        
        let monthExpenses = expandedExpenses.filter { expense in
            guard let date = dateFromString(expense.date) else { return false }
            return calendar.component(.year, from: date) == year && 
                   calendar.component(.month, from: date) == monthNum
        }
        
        // print("DEBUG: Ingresos del mes: \(monthIncomes.count)")
        // print("DEBUG: Gastos del mes: \(monthExpenses.count)")
        
        for income in monthIncomes {
            if let date = dateFromString(income.date) {
                let dayStart = calendar.startOfDay(for: date)
                dict[dayStart, default: (0,0)].0 += 1
            }
        }
        
        for expense in monthExpenses {
            if let date = dateFromString(expense.date) {
                let dayStart = calendar.startOfDay(for: date)
                dict[dayStart, default: (0,0)].1 += 1
            }
        }
        
        // print("DEBUG: Total días con eventos en \(monthNum)/\(year): \(dict.count)")
        return dict
    }
    
    // Helper para parsear fecha
    func dateFromString(_ str: String) -> Date? {
        // Intentar parseado con formato ISO primero, luego formato simple
        return dateFormatter.date(from: str) ?? simpleDateFormatter.date(from: str)
    }
    
    // Obtener los días del mes
    func daysInMonth(for date: Date) -> [Date] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: date),
              let monthFirstWeek = calendar.dateInterval(of: .weekOfYear, for: monthInterval.start),
              let monthLastWeek = calendar.dateInterval(of: .weekOfYear, for: monthInterval.end - 1) else {
            return []
        }
        
        var days: [Date] = []
        var day = monthFirstWeek.start
        while day < monthLastWeek.end {
            days.append(day)
            day = calendar.date(byAdding: .day, value: 1, to: day)!
        }
        return days
    }
    
    // Verificar si una fecha pertenece al mes actual
    func isInCurrentMonth(date: Date, currentMonth: Date) -> Bool {
        return calendar.isDate(date, equalTo: currentMonth, toGranularity: .month)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Header con navegación de mes
            HStack {
                Button(action: {
                    let newDate = calendar.date(byAdding: .month, value: -1, to: currentDate) ?? currentDate
                    currentDate = newDate
                    onMonthChanged(newDate)
                }) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
                
                Spacer()
                
                Text(DateFormatter().monthYearString(from: currentDate))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: {
                    let newDate = calendar.date(byAdding: .month, value: 1, to: currentDate) ?? currentDate
                    currentDate = newDate
                    onMonthChanged(newDate)
                }) {
                    Image(systemName: "chevron.right")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal, 20)
            
            // Días de la semana con mejor estilo
            HStack(spacing: 0) {
                ForEach(["L", "M", "X", "J", "V", "S", "D"], id: \.self) { day in
                    Text(day)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 16)
            
            // Grid del calendario
            let days = daysInMonth(for: currentDate)
            let events = eventsByDay(for: currentDate)
            
            // Contenedor del calendario con estilo moderno
            VStack(spacing: 0) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                    ForEach(days, id: \.self) { date in
                        let isCurrentMonth = isInCurrentMonth(date: date, currentMonth: currentDate)
                        let dayEvents = events[calendar.startOfDay(for: date)] ?? (0, 0)
                        let isToday = calendar.isDateInToday(date)
                        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
                        
                        VStack(spacing: 4) {
                            Text("\(calendar.component(.day, from: date))")
                                .font(.system(size: 16, weight: isToday ? .bold : .medium))
                                .foregroundColor(
                                    isSelected ? .white :
                                    isToday ? .blue :
                                    isCurrentMonth ? .primary : .secondary
                                )
                            
                            // Indicadores de eventos - Puntos verdes (ingresos) y rojos (gastos)
                            HStack(spacing: 2) {
                                if dayEvents.0 > 0 {
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 12, height: 12)
                                        .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                                        .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                                }
                                if dayEvents.1 > 0 {
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 12, height: 12)
                                        .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                                        .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                                }
                            }
                            .frame(height: 16)
                        }
                        .frame(width: 44, height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(isSelected ? Color.primary : (isToday ? Color.blue.opacity(0.1) : Color.clear))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isToday ? Color.blue : Color.clear, lineWidth: 2)
                        )
                        .contentShape(Rectangle())
                        .scaleEffect(isSelected ? 0.95 : 1.0)
                        .animation(.easeInOut(duration: 0.2), value: isSelected)
                        .onTapGesture {
                            selectedDate = date
                            showDayEventsSheet = true
                        }
                    }
                }
                .padding(16)
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
            )
            .padding(.horizontal, 16)
        }
        .padding(.vertical)
    }
}

extension DateFormatter {
    func monthYearString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date).capitalized
    }
}

struct DayEventsSheetView: View {
    let date: Date
    let expandedIncomes: [Income]
    let expandedExpenses: [Expense]
    let properties: [PropertyName]
    var onClose: () -> Void
    
    private let calendar = Calendar.current
    private let dateFormatter = DateFormatter()
    private let simpleDateFormatter = DateFormatter()
    
    init(date: Date, expandedIncomes: [Income], expandedExpenses: [Expense], properties: [PropertyName], onClose: @escaping () -> Void) {
        self.date = date
        self.expandedIncomes = expandedIncomes
        self.expandedExpenses = expandedExpenses
        self.properties = properties
        self.onClose = onClose
        // Arreglar: Configurar ambos formatters para manejar diferentes formatos
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        simpleDateFormatter.dateFormat = "yyyy-MM-dd"
    }
    
    private func getPropertyName(for propertyId: String) -> String {
        properties.first(where: { $0._id == propertyId })?.name ?? "Propiedad desconocida"
    }
    
    // Obtener eventos para el día específico desde los datos expandidos
    private var dayIncomes: [Income] {
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        
        return expandedIncomes.filter { income in
            // Intentar parsear la fecha del ingreso
            guard let incomeDate = dateFormatter.date(from: income.date) ?? simpleDateFormatter.date(from: income.date) else {
                return false
            }
            
            // Comparar año, mes y día
            return calendar.component(.year, from: incomeDate) == year &&
                   calendar.component(.month, from: incomeDate) == month &&
                   calendar.component(.day, from: incomeDate) == day
        }
    }
    
    private var dayExpenses: [Expense] {
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        
        return expandedExpenses.filter { expense in
            // Intentar parsear la fecha del gasto
            guard let expenseDate = dateFormatter.date(from: expense.date) ?? simpleDateFormatter.date(from: expense.date) else {
                return false
            }
            
            // Comparar año, mes y día
            return calendar.component(.year, from: expenseDate) == year &&
                   calendar.component(.month, from: expenseDate) == month &&
                   calendar.component(.day, from: expenseDate) == day
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                if dayIncomes.isEmpty && dayExpenses.isEmpty {
                    Text("No hay ingresos ni gastos para este día.")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    if !dayIncomes.isEmpty {
                        Section(header: Text("Ingresos (\(dayIncomes.count))")) {
                            ForEach(dayIncomes) { income in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(typeLabel(for: income.type))
                                            .font(.headline)
                                            .foregroundColor(.green)
                                        Spacer()
                                        if income.is_recurring == true {
                                            Text("Recurrente")
                                                .font(.caption)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 2)
                                                .background(Color.blue.opacity(0.2))
                                                .foregroundColor(.blue)
                                                .cornerRadius(4)
                                        }
                                    }
                                    Text(getPropertyName(for: income.property_id))
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.blue)
                                    Text(formatCurrency(income.amount))
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.green)
                                    if let desc = income.description, !desc.isEmpty {
                                        Text(desc)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    
                    if !dayExpenses.isEmpty {
                        Section(header: Text("Gastos (\(dayExpenses.count))")) {
                            ForEach(dayExpenses) { expense in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(typeLabel(for: expense.type))
                                            .font(.headline)
                                            .foregroundColor(.red)
                                        Spacer()
                                        if expense.is_recurring == true {
                                            Text("Recurrente")
                                                .font(.caption)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 2)
                                                .background(Color.blue.opacity(0.2))
                                                .foregroundColor(.blue)
                                                .cornerRadius(4)
                                        }
                                    }
                                    Text(getPropertyName(for: expense.property_id))
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.blue)
                                    Text(formatCurrency(expense.amount))
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.red)
                                    if let desc = expense.description, !desc.isEmpty {
                                        Text(desc)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Eventos del \(formattedDate)")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cerrar") {
                    onClose()
                }
                .foregroundColor(.blue)
            )
        }
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "d 'de' MMMM"
        return formatter.string(from: date)
    }
}

func typeLabel(for type: String) -> String {
    switch type {
    case "maintenance": return "Mantenimiento"
    case "utilities": return "Suministros"
    case "taxes": return "Impuestos"
    case "insurance": return "Seguro"
    case "mortgage": return "Hipoteca"
    case "repairs": return "Reparaciones"
    case "improvements": return "Mejoras"
    case "management": return "Gestión"
    case "other": return "Otro"
    default: return type.capitalized
    }
}

func formatCurrency(_ amount: Double) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencyCode = "EUR"
    return formatter.string(from: NSNumber(value: amount)) ?? "€\(amount)"
}

extension Date {
    func startOfMonth() -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: self)
        return calendar.date(from: components) ?? self
    }
}

#Preview {
    DashboardView()
} 