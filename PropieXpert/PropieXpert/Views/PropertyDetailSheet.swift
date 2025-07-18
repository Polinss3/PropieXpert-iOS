import SwiftUI
import Foundation
// Los modelos Income y Expense vienen de Models.swift
// Importa el modelo Mortgage
// ... existing code ...
// Income y Expense ya están disponibles por Models.swift en el mismo target

struct PropertyDetail: Decodable {
    let id: String
    let name: String
    let address: String
    let property_type: String
    let purchase_price: Double
    let current_value: Double? // Ahora opcional
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
    // Hipoteca
    @State private var mortgage: Mortgage? = nil
    @State private var isLoadingMortgage = false
    @State private var errorMortgage: String? = nil
    @State private var showAddMortgageSheet = false
    @State private var showEditMortgageSheet = false
    @State private var showDeleteAlert = false
    // Estados para ingresos y gastos
    @State private var incomes: [Income] = []
    @State private var expenses: [Expense] = []
    @State private var isLoadingIncomes = false
    @State private var isLoadingExpenses = false
    @State private var errorIncomes: String? = nil
    @State private var errorExpenses: String? = nil
    
    // --- Cálculo de saldo actual (igual que web) ---
    func calculateCurrentBalance(_ mortgage: Mortgage) -> Double {
        let P = mortgage.initial_amount
        let n = Double(mortgage.years) * 12
        var r = 0.0
        if mortgage.type == "fixed" {
            r = (mortgage.interest_rate_fixed ?? 0) / 100 / 12
        } else if mortgage.type == "variable" {
            r = (mortgage.interest_rate_variable ?? 0) / 100 / 12
        } else if mortgage.type == "mixed" {
            r = (mortgage.interest_rate_fixed ?? 0) / 100 / 12
        }
        let A = mortgage.monthly_payment
        guard let startDateStr = mortgage.start_date, let start = isoDate(from: startDateStr) else { return P }
        let now = Date()
        let calendar = Calendar.current
        let k = max(0, min(Int(n), calendar.dateComponents([.month], from: start, to: now).month ?? 0))
        if P == 0 || n == 0 || A == 0 || r == 0 { return P }
        let balance = P * pow(1 + r, Double(k)) - A * ((pow(1 + r, Double(k)) - 1) / r)
        return max(0, balance)
    }
    func isoDate(from string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.date(from: string)
    }
    // --- Fin cálculo saldo actual ---
    
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
                fetchMortgage()
                fetchIncomesAndExpenses()
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
                            DetailRow(label: "Valor Actual", value: property.current_value != nil ? formatCurrency(property.current_value!) : "—")
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
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.up.arrow.down.circle.fill")
                    .foregroundColor(.accentColor)
                Text("Ingresos y Gastos")
                    .font(.title2).bold()
            }
            .padding(.top)
            .padding(.horizontal)
            if isLoadingIncomes || isLoadingExpenses {
                ProgressView("Cargando ingresos y gastos...")
                    .padding()
            } else if let errorIncomes = errorIncomes {
                Text(errorIncomes).foregroundColor(.red).padding()
            } else if let errorExpenses = errorExpenses {
                Text(errorExpenses).foregroundColor(.red).padding()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        // Ingresos
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.down.circle.fill")
                                    .foregroundColor(.green)
                                Text("Ingresos").font(.title3).bold()
                            }
                            if incomes.isEmpty {
                                Text("No hay ingresos para esta propiedad.")
                                    .foregroundColor(.gray)
                                    .padding(.leading, 4)
                            } else {
                                ForEach(incomes) { income in
                                    IncomeExpenseCard(
                                        icon: iconForIncomeType(income.type),
                                        iconColor: .green,
                                        title: typeLabelIncome(income.type),
                                        amount: formatCurrency(income.amount),
                                        amountColor: .green,
                                        date: formatDate(income.date),
                                        description: income.description
                                    )
                                }
                            }
                        }
                        // Gastos
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.up.circle.fill")
                                    .foregroundColor(.red)
                                Text("Gastos").font(.title3).bold()
                            }
                            if expenses.isEmpty {
                                Text("No hay gastos para esta propiedad.")
                                    .foregroundColor(.gray)
                                    .padding(.leading, 4)
                            } else {
                                ForEach(expenses) { expense in
                                    IncomeExpenseCard(
                                        icon: iconForExpenseType(expense.type),
                                        iconColor: .red,
                                        title: typeLabelExpense(expense.type),
                                        amount: formatCurrency(expense.amount),
                                        amountColor: .red,
                                        date: formatDate(expense.date),
                                        description: expense.description
                                    )
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
        }
    }
    
    var hipotecaSection: some View {
        Group {
            if isLoadingMortgage {
                ProgressView("Cargando hipoteca...")
            } else if let errorMortgage = errorMortgage {
                Text(errorMortgage).foregroundColor(.red)
            } else if let m = mortgage {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Hipoteca").font(.title2).bold()
                            Spacer()
                            Button("Editar") { showEditMortgageSheet = true }
                                .padding(.trailing, 8)
                            Button(role: .destructive) { showDeleteAlert = true } label: {
                                Text("Eliminar")
                            }
                        }
                        Divider()
                        Group {
                            HStack {
                                Text("Tipo:").bold()
                                Text(m.type.capitalized)
                            }
                            HStack {
                                Text("Importe inicial:").bold()
                                Text(formatCurrency(m.initial_amount))
                            }
                            HStack {
                                Text("Saldo actual:").bold()
                                Text(formatCurrency(calculateCurrentBalance(m)))
                            }
                            HStack {
                                Text("Años:").bold()
                                Text("\(m.years)")
                            }
                            if let f = m.interest_rate_fixed, (m.type == "fixed" || m.type == "mixed") {
                                HStack {
                                    Text("Interés fijo:").bold()
                                    Text("\(String(format: "%.2f", f)) %")
                                }
                            }
                            if let v = m.interest_rate_variable, (m.type == "variable" || m.type == "mixed") {
                                HStack {
                                    Text("Interés variable:").bold()
                                    Text("\(String(format: "%.2f", v)) %")
                                }
                            }
                            HStack {
                                Text("Cuota mensual:").bold()
                                Text(formatCurrency(m.monthly_payment))
                            }
                            if let total = m.total_to_pay {
                                HStack {
                                    Text("Total a pagar:").bold()
                                    Text(formatCurrency(total))
                                }
                            }
                            if let s = m.start_date {
                                HStack {
                                    Text("Fecha inicio:").bold()
                                    Text(s)
                                }
                            }
                            if let e = m.end_date {
                                HStack {
                                    Text("Fecha fin:").bold()
                                    Text(e)
                                }
                            }
                            if let b = m.bank_name, !b.isEmpty {
                                HStack {
                                    Text("Banco:").bold()
                                    Text(b)
                                }
                            }
                            if let a = m.account_number, !a.isEmpty {
                                HStack {
                                    Text("Nº de cuenta:").bold()
                                    Text(a)
                                }
                            }
                            if let d = m.description, !d.isEmpty {
                                HStack(alignment: .top) {
                                    Text("Descripción:").bold()
                                    Text(d)
                                }
                            }
                            if let p = m.payment_day {
                                HStack {
                                    Text("Día de pago:").bold()
                                    Text("\(p)")
                                }
                            }
                            if let f = m.fixed_rate_period {
                                HStack {
                                    Text("Años tipo fijo:").bold()
                                    Text("\(f)")
                                }
                            }
                            if let r = m.reference_number, !r.isEmpty {
                                HStack {
                                    Text("Referencia:").bold()
                                    Text(r)
                                }
                            }
                            if let auto = m.is_automatic_payment {
                                HStack {
                                    Text("Pago automático:").bold()
                                    Text(auto ? "Sí" : "No")
                                }
                            }
                        }
                    }
                    .padding()
                }
                .sheet(isPresented: $showEditMortgageSheet, onDismiss: fetchMortgage) {
                    MortgageSheet(propertyId: propertyId, mortgage: m, onSave: {
                        fetchMortgage()
                    }, onDelete: {
                        fetchMortgage()
                    })
                }
                .alert("¿Eliminar hipoteca?", isPresented: $showDeleteAlert) {
                    Button("Eliminar", role: .destructive) { deleteMortgage() }
                    Button("Cancelar", role: .cancel) {}
                } message: {
                    Text("Esta acción no se puede deshacer.")
                }
            } else {
                VStack(spacing: 16) {
                    Text("No hay hipoteca registrada para esta propiedad.")
                        .foregroundColor(.gray)
                    Button("Añadir hipoteca") { showAddMortgageSheet = true }
                }
                .sheet(isPresented: $showAddMortgageSheet, onDismiss: fetchMortgage) {
                    MortgageSheet(propertyId: propertyId, onSave: {
                        fetchMortgage()
                    })
                }
            }
        }
        .onAppear(perform: fetchMortgage)
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
    
    func fetchMortgage() {
        isLoadingMortgage = true
        errorMortgage = nil
        print("[DEBUG] fetchMortgage: propertyId = \(propertyId)")
        guard let url = URL(string: "https://api.propiexpert.com/mortgages/property/\(propertyId)") else { print("[DEBUG] URL inválida"); return }
        print("[DEBUG] fetchMortgage: url = \(url)")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isLoadingMortgage = false
                if let error = error {
                    print("[DEBUG] fetchMortgage: error = \(error.localizedDescription)")
                    errorMortgage = "Error de red: \(error.localizedDescription)"
                    mortgage = nil
                    return
                }
                if let httpResponse = response as? HTTPURLResponse {
                    print("[DEBUG] fetchMortgage: statusCode = \(httpResponse.statusCode)")
                }
                guard let data = data else {
                    print("[DEBUG] fetchMortgage: data es nil")
                    errorMortgage = "No se recibieron datos del servidor."
                    mortgage = nil
                    return
                }
                print("[DEBUG] fetchMortgage: data (raw) = \(String(data: data, encoding: .utf8) ?? "<binario>")")
                do {
                    if data.isEmpty {
                        print("[DEBUG] fetchMortgage: data vacío, no hay hipoteca")
                        mortgage = nil
                        return
                    }
                    let decoded = try JSONDecoder().decode([Mortgage].self, from: data)
                    print("[DEBUG] fetchMortgage: decoded = \(decoded)")
                    mortgage = decoded.first
                    if decoded.isEmpty {
                        print("[DEBUG] fetchMortgage: array vacío tras decodificar")
                        mortgage = nil
                    }
                } catch {
                    print("[DEBUG] fetchMortgage: error decodificando = \(error)")
                    if !data.isEmpty {
                        errorMortgage = "Error al decodificar hipoteca: \(error.localizedDescription)"
                    } else {
                        mortgage = nil
                    }
                }
            }
        }.resume()
    }
    
    // --- Eliminar hipoteca ---
    func deleteMortgage() {
        guard let m = mortgage else { return }
        isLoadingMortgage = true
        errorMortgage = nil
        guard let url = URL(string: "https://api.propiexpert.com/mortgages/\(m.id)") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isLoadingMortgage = false
                if let error = error {
                    errorMortgage = "Error de red: \(error.localizedDescription)"
                    return
                }
                guard let httpResponse = response as? HTTPURLResponse else {
                    errorMortgage = "Respuesta inválida del servidor."
                    return
                }
                if httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
                    mortgage = nil
                    fetchMortgage()
                } else {
                    if let data = data, let msg = String(data: data, encoding: .utf8) {
                        errorMortgage = "Error: \(msg)"
                    } else {
                        errorMortgage = "Error desconocido al eliminar."
                    }
                }
            }
        }.resume()
    }
    
    // Fetch de ingresos y gastos de la propiedad
    func fetchIncomesAndExpenses() {
        fetchIncomes()
        fetchExpenses()
    }
    func fetchIncomes() {
        isLoadingIncomes = true
        errorIncomes = nil
        guard let url = URL(string: "https://api.propiexpert.com/incomes/property/\(propertyId)") else { isLoadingIncomes = false; return }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isLoadingIncomes = false
                if let error = error {
                    errorIncomes = "Error de red: \(error.localizedDescription)"
                    return
                }
                guard let data = data else {
                    errorIncomes = "No se recibieron datos del servidor."
                    return
                }
                do {
                    let decoded = try JSONDecoder().decode([Income].self, from: data)
                    incomes = decoded
                } catch {
                    errorIncomes = "Error al decodificar ingresos: \(error.localizedDescription)"
                }
            }
        }.resume()
    }
    func fetchExpenses() {
        isLoadingExpenses = true
        errorExpenses = nil
        guard let url = URL(string: "https://api.propiexpert.com/expenses/property/\(propertyId)") else { isLoadingExpenses = false; return }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isLoadingExpenses = false
                if let error = error {
                    errorExpenses = "Error de red: \(error.localizedDescription)"
                    return
                }
                guard let data = data else {
                    errorExpenses = "No se recibieron datos del servidor."
                    return
                }
                do {
                    let decoded = try JSONDecoder().decode([Expense].self, from: data)
                    expenses = decoded
                } catch {
                    errorExpenses = "Error al decodificar gastos: \(error.localizedDescription)"
                }
            }
        }.resume()
    }
    // Helpers para mostrar tipo y fecha
    func typeLabelIncome(_ type: String) -> String {
        switch type {
        case "rent": return "Alquiler"
        case "deposit": return "Depósito"
        case "sale": return "Venta"
        case "interest": return "Interés"
        case "dividends": return "Dividendos"
        case "other": return "Otro"
        default: return type.capitalized
        }
    }
    func typeLabelExpense(_ type: String) -> String {
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
    func formatDate(_ dateString: String) -> String {
        let formats = ["yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd"]
        for format in formats {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "es_ES")
            formatter.dateFormat = format
            if let date = formatter.date(from: dateString) {
                let outputFormatter = DateFormatter()
                outputFormatter.locale = Locale(identifier: "es_ES")
                outputFormatter.dateFormat = "dd-MM-yyyy"
                return outputFormatter.string(from: date)
            }
        }
        return dateString
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

// NUEVO: Componente de tarjeta para ingresos/gastos
struct IncomeExpenseCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let amount: String
    let amountColor: Color
    let date: String
    let description: String?
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                    .font(.system(size: 22, weight: .bold))
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.headline)
                    Spacer()
                    Text(amount)
                        .font(.headline)
                        .foregroundColor(amountColor)
                }
                HStack(spacing: 8) {
                    Text(date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if let desc = description, !desc.isEmpty {
                        Text("·")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(desc)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(14)
        .background(Color(.systemBackground))
        .cornerRadius(14)
        .shadow(color: Color(.black).opacity(0.06), radius: 4, x: 0, y: 2)
        .padding(.vertical, 2)
    }
}
// NUEVO: Helpers para iconos
extension PropertyDetailSheet {
    func iconForIncomeType(_ type: String) -> String {
        switch type {
        case "rent": return "eurosign.circle.fill"
        case "deposit": return "tray.and.arrow.down.fill"
        case "sale": return "house.fill"
        case "interest": return "percent"
        case "dividends": return "chart.pie.fill"
        case "other": return "plus.circle.fill"
        default: return "arrow.down.circle.fill"
        }
    }
    func iconForExpenseType(_ type: String) -> String {
        switch type {
        case "maintenance": return "wrench.and.screwdriver.fill"
        case "utilities": return "bolt.fill"
        case "taxes": return "doc.text.fill"
        case "insurance": return "shield.fill"
        case "mortgage": return "building.columns.fill"
        case "repairs": return "hammer.fill"
        case "improvements": return "paintbrush.fill"
        case "management": return "person.2.fill"
        case "other": return "minus.circle.fill"
        default: return "arrow.up.circle.fill"
        }
    }
} 