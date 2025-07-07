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

func expandRecurring<T: Identifiable & HasRecurrence>(items: [T], year: Int, month: Int) -> [T] {
    let calendar = Calendar.current
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    return items.compactMap { item in
        guard let isRecurring = item.is_recurring, isRecurring,
              let frequency = item.frequency else { return nil }
        let startStr = item.recurrence_start_date ?? item.date
        let endStr = item.recurrence_end_date ?? "\(year)-12-31"
        guard let start = formatter.date(from: startStr),
              let end = formatter.date(from: endStr) else { return nil }
        let currentMonth = calendar.date(from: DateComponents(year: year, month: month, day: 1))!
        if currentMonth < calendar.startOfDay(for: start) || currentMonth > calendar.startOfDay(for: end) { return nil }
        let monthsDiff = calendar.dateComponents([.month], from: calendar.startOfDay(for: start), to: currentMonth).month ?? 0
        if (frequency == "monthly") || (frequency == "quarterly" && monthsDiff % 3 == 0) || (frequency == "yearly" && monthsDiff % 12 == 0) {
            return item
        }
        return nil
    }
}

func expandPunctual<T: Identifiable & HasRecurrence>(items: [T], year: Int, month: Int) -> [T] {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    return items.filter { item in
        guard let isRecurring = item.is_recurring, !isRecurring else { return false }
        guard let date = formatter.date(from: item.date) else { return false }
        let comps = Calendar.current.dateComponents([.year, .month], from: date)
        return comps.year == year && comps.month == month
    }
}

func monthlyBarDataFromAPI(incomes: [Income], expenses: [Expense]) -> [MonthlyBarData] {
    let months = ["Ene", "Feb", "Mar", "Abr", "May", "Jun", "Jul", "Ago", "Sep", "Oct", "Nov", "Dic"]
    let currentYear = Calendar.current.component(.year, from: Date())
    var result: [MonthlyBarData] = []
    for m in 1...12 {
        let monthIncomes = expandRecurring(items: incomes, year: currentYear, month: m) + expandPunctual(items: incomes, year: currentYear, month: m)
        let monthExpenses = expandRecurring(items: expenses, year: currentYear, month: m) + expandPunctual(items: expenses, year: currentYear, month: m)
        let incomeSum = monthIncomes.reduce(0) { $0 + $1.amount }
        let expenseSum = monthExpenses.reduce(0) { $0 + $1.amount }
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
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var selectedSection: DashboardSection = .resumen
    // Para la gráfica de barras mensual
    @State private var incomes: [Income] = []
    @State private var expenses: [Expense] = []
    @State private var isLoadingChart = false
    @State private var chartError: String? = nil
    @State private var selectedDate: Date = Date()
    @State private var showDayEventsSheet = false
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
                                incomes: incomes,
                                expenses: expenses,
                                selectedDate: $selectedDate,
                                showDayEventsSheet: $showDayEventsSheet
                            )
                        }
                    }
                    .padding(.vertical)
                }
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .onAppear {
                fetchPropertyPerformance()
                fetchIncomesAndExpenses()
            }
            // Sheet para mostrar eventos del día seleccionado
            .sheet(isPresented: $showDayEventsSheet) {
                DayEventsSheetView(
                    date: selectedDate,
                    incomes: incomes,
                    expenses: expenses,
                    onClose: { showDayEventsSheet = false }
                )
            }
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
            }
        }
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
    let incomes: [Income]
    let expenses: [Expense]
    @Binding var selectedDate: Date
    @Binding var showDayEventsSheet: Bool
    @State private var currentDate = Date()
    
    private let calendar = Calendar.current
    private let dateFormatter = DateFormatter()
    
    init(incomes: [Income], expenses: [Expense], selectedDate: Binding<Date>, showDayEventsSheet: Binding<Bool>) {
        self.incomes = incomes
        self.expenses = expenses
        self._selectedDate = selectedDate
        self._showDayEventsSheet = showDayEventsSheet
        dateFormatter.dateFormat = "yyyy-MM-dd"
    }
    
    // Helpers para obtener eventos del mes
    func eventsByDay(for month: Date) -> [Date: (Int, Int)] {
        var dict: [Date: (Int, Int)] = [:] // [fecha: (ingresos, gastos)]
        let year = calendar.component(.year, from: month)
        let monthNum = calendar.component(.month, from: month)
        
        // Expandir eventos recurrentes y puntuales
        let allIncomes = expandRecurring(items: incomes, year: year, month: monthNum) + expandPunctual(items: incomes, year: year, month: monthNum)
        let allExpenses = expandRecurring(items: expenses, year: year, month: monthNum) + expandPunctual(items: expenses, year: year, month: monthNum)
        
        for income in allIncomes {
            if let date = dateFromString(income.date) {
                dict[date, default: (0,0)].0 += 1
            }
        }
        for expense in allExpenses {
            if let date = dateFromString(expense.date) {
                dict[date, default: (0,0)].1 += 1
            }
        }
        return dict
    }
    
    // Helper para parsear fecha
    func dateFromString(_ str: String) -> Date? {
        return dateFormatter.date(from: str)
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
                    currentDate = calendar.date(byAdding: .month, value: -1, to: currentDate) ?? currentDate
                }) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                Text(DateFormatter().monthYearString(from: currentDate))
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: {
                    currentDate = calendar.date(byAdding: .month, value: 1, to: currentDate) ?? currentDate
                }) {
                    Image(systemName: "chevron.right")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal)
            
            // Días de la semana
            HStack {
                ForEach(["L", "M", "X", "J", "V", "S", "D"], id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal)
            
            // Grid del calendario
            let days = daysInMonth(for: currentDate)
            let events = eventsByDay(for: currentDate)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                ForEach(days, id: \.self) { date in
                    let isCurrentMonth = isInCurrentMonth(date: date, currentMonth: currentDate)
                    let dayEvents = events[date] ?? (0, 0)
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
                        
                        // Indicadores de eventos
                        HStack(spacing: 2) {
                            if dayEvents.0 > 0 {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 6, height: 6)
                            }
                            if dayEvents.1 > 0 {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 6, height: 6)
                            }
                        }
                        .frame(height: 8)
                    }
                    .frame(width: 40, height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isSelected ? Color.blue : Color.clear)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedDate = date
                        if dayEvents.0 > 0 || dayEvents.1 > 0 {
                            showDayEventsSheet = true
                        }
                    }
                }
            }
            .padding(.horizontal)
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
    let incomes: [Income]
    let expenses: [Expense]
    var onClose: () -> Void
    
    private let calendar = Calendar.current
    private let dateFormatter = DateFormatter()
    
    init(date: Date, incomes: [Income], expenses: [Expense], onClose: @escaping () -> Void) {
        self.date = date
        self.incomes = incomes
        self.expenses = expenses
        self.onClose = onClose
        dateFormatter.dateFormat = "yyyy-MM-dd"
    }
    
    // Obtener eventos para el día específico
    private var dayIncomes: [Income] {
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        let dayStr = dateFormatter.string(from: date)
        
        // Expandir eventos recurrentes y puntuales para el mes
        let allIncomes = expandRecurring(items: incomes, year: year, month: month) + 
                        expandPunctual(items: incomes, year: year, month: month)
        
        // Filtrar por el día específico
        return allIncomes.filter { income in
            income.date == dayStr
        }
    }
    
    private var dayExpenses: [Expense] {
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        let dayStr = dateFormatter.string(from: date)
        
        // Expandir eventos recurrentes y puntuales para el mes
        let allExpenses = expandRecurring(items: expenses, year: year, month: month) + 
                         expandPunctual(items: expenses, year: year, month: month)
        
        // Filtrar por el día específico
        return allExpenses.filter { expense in
            expense.date == dayStr
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