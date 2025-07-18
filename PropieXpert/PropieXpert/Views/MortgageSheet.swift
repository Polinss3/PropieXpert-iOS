import SwiftUI
import Foundation

struct MortgageSheet: View {
    let propertyId: String
    var mortgage: Mortgage? = nil
    var onSave: (() -> Void)?
    var onDelete: (() -> Void)?
    @Environment(\.dismiss) var dismiss
    @AppStorage("auth_token") var authToken: String = ""

    // Form fields
    @State private var type: String = "fixed"
    @State private var initialAmount: String = ""
    @State private var years: String = ""
    @State private var interestFixed: String = ""
    @State private var interestVariable: String = ""
    @State private var startDate: String = ""
    @State private var startDateObj: Date = Date()
    @State private var bankName: String = ""
    @State private var accountNumber: String = ""
    @State private var paymentDay: String = ""
    @State private var fixedRatePeriod: String = ""
    @State private var referenceNumber: String = ""
    @State private var desc: String = ""
    @State private var isAutomatic: Bool = false

    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var showDeleteAlert = false

    var isEdit: Bool { mortgage != nil }

    var body: some View {
        ZStack {
            NavigationView {
                Form {
                    Section {
                        Text("Los campos marcados con * son obligatorios")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Section(header: Text("Hipoteca")) {
                        Picker("Tipo de hipoteca *", selection: $type) {
                            Text("Fija").tag("fixed")
                            Text("Variable").tag("variable")
                            Text("Mixta").tag("mixed")
                        }
                        TextField("Importe inicial (€) *", text: $initialAmount)
                            .keyboardType(.decimalPad)
                        TextField("Años *", text: $years)
                            .keyboardType(.numberPad)
                        if type == "fixed" || type == "mixed" {
                            TextField("Interés fijo (%)", text: $interestFixed)
                                .keyboardType(.decimalPad)
                        }
                        if type == "variable" || type == "mixed" {
                            TextField("Interés variable (%)", text: $interestVariable)
                                .keyboardType(.decimalPad)
                        }
                        DatePicker("Fecha inicio *", selection: $startDateObj, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .environment(\.locale, Locale(identifier: "es_ES"))
                            .onChange(of: startDateObj) { newDate in
                                let formatter = DateFormatter()
                                formatter.dateFormat = "dd-MM-yyyy"
                                formatter.locale = Locale(identifier: "es_ES")
                                startDate = formatter.string(from: newDate)
                            }
                        // Muestra la fecha seleccionada en formato español
                        Text("Seleccionada: \(startDate)")
                            .font(.caption)
                            .foregroundColor(.gray)
                        TextField("Banco *", text: $bankName)
                        TextField("Nº de cuenta *", text: $accountNumber)
                        Toggle("Pago automático", isOn: $isAutomatic)
                        TextField("Día de pago", text: $paymentDay)
                            .keyboardType(.numberPad)
                        TextField("Años tipo fijo", text: $fixedRatePeriod)
                            .keyboardType(.numberPad)
                        TextField("Referencia", text: $referenceNumber)
                        TextField("Descripción", text: $desc, axis: .vertical)
                    }
                    Section(header: Text("Cálculos automáticos")) {
                        HStack {
                            Text("Cuota mensual")
                            Spacer()
                            Text("\(calculatedMonthlyPayment) €")
                                .foregroundColor(.blue)
                        }
                        HStack {
                            Text("Total a pagar")
                            Spacer()
                            Text("\(calculatedTotalToPay) €")
                                .foregroundColor(.blue)
                        }
                    }
                    if let errorMessage = errorMessage {
                        Section {
                            Text(errorMessage).foregroundColor(.red)
                        }
                    }
                    if isEdit {
                        Section {
                            Button("Eliminar hipoteca", role: .destructive) {
                                showDeleteAlert = true
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationTitle(isEdit ? "Editar Hipoteca" : "Añadir Hipoteca")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancelar") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        if isLoading {
                            ProgressView()
                        } else {
                            Button("Guardar", action: submit)
                        }
                    }
                }
                .alert("¿Eliminar hipoteca?", isPresented: $showDeleteAlert) {
                    Button("Eliminar", role: .destructive) { deleteMortgage() }
                    Button("Cancelar", role: .cancel) {}
                } message: {
                    Text("Esta acción no se puede deshacer.")
                }
                .onAppear {
                    if let m = mortgage {
                        type = m.type
                        initialAmount = String(format: "%.2f", m.initial_amount)
                        years = String(m.years)
                        interestFixed = m.interest_rate_fixed != nil ? String(m.interest_rate_fixed!) : ""
                        interestVariable = m.interest_rate_variable != nil ? String(m.interest_rate_variable!) : ""
                        if let s = m.start_date, let d = isoDate(from: s) {
                            startDateObj = d
                            let formatter = DateFormatter()
                            formatter.dateFormat = "dd-MM-yyyy"
                            formatter.locale = Locale(identifier: "es_ES")
                            startDate = formatter.string(from: d)
                        } else {
                            startDate = ""
                        }
                        bankName = m.bank_name ?? ""
                        accountNumber = m.account_number ?? ""
                        paymentDay = m.payment_day != nil ? String(m.payment_day!) : ""
                        fixedRatePeriod = m.fixed_rate_period != nil ? String(m.fixed_rate_period!) : ""
                        referenceNumber = m.reference_number ?? ""
                        desc = m.description ?? ""
                        isAutomatic = m.is_automatic_payment ?? false
                    }
                    if mortgage == nil {
                        let formatter = DateFormatter()
                        formatter.dateFormat = "dd-MM-yyyy"
                        formatter.locale = Locale(identifier: "es_ES")
                        startDate = formatter.string(from: startDateObj)
                    }
                }
            }
        }
        .ignoresSafeArea(.container, edges: .all)
    }

    // Helper para parsear Double con ',' o '.'
    func parseDouble(_ string: String) -> Double? {
        let normalized = string.replacingOccurrences(of: ",", with: ".")
        return Double(normalized)
    }

    var calculatedMonthlyPayment: String {
        guard let P = parseDouble(initialAmount), let n = Int(years), n > 0 else { return "0.00" }
        let months = n * 12
        var r = 0.0
        if type == "fixed" {
            r = (parseDouble(interestFixed) ?? 0) / 100 / 12
        } else if type == "variable" {
            r = (parseDouble(interestVariable) ?? 0) / 100 / 12
        } else if type == "mixed" {
            r = (parseDouble(interestFixed) ?? 0) / 100 / 12
        }
        if P > 0 && r > 0 && months > 0 {
            let cuota = (P * (r * pow(1 + r, Double(months)))) / (pow(1 + r, Double(months)) - 1)
            if cuota.isNaN || cuota.isInfinite {
                return "0.00"
            }
            return String(format: "%.2f", cuota)
        }
        return "0.00"
    }
    var calculatedTotalToPay: String {
        guard let cuota = parseDouble(calculatedMonthlyPayment), let n = Int(years), n > 0 else { return "0.00" }
        let total = cuota * Double(n) * 12
        if total.isNaN || total.isInfinite {
            return "0.00"
        }
        return String(format: "%.2f", total)
    }

    func submit() {
        errorMessage = nil
        guard let initialAmountValue = parseDouble(initialAmount), initialAmountValue > 0 else {
            errorMessage = "Importe inicial inválido."
            return
        }
        guard let yearsValue = Int(years), yearsValue > 0 else {
            errorMessage = "Años inválidos."
            return
        }
        let interestFixedValue = parseDouble(interestFixed) ?? 0
        let interestVariableValue = parseDouble(interestVariable) ?? 0
        let cuota = parseDouble(calculatedMonthlyPayment) ?? 0
        let totalToPay = parseDouble(calculatedTotalToPay) ?? 0
        // Calcula end_date automáticamente
        var endDate: String? = nil
        // Convierte la fecha seleccionada (español) a ISO para el backend
        let isoFormatter = DateFormatter()
        isoFormatter.dateFormat = "yyyy-MM-dd"
        isoFormatter.locale = Locale(identifier: "en_US_POSIX")
        let isoStartDate = isoFormatter.string(from: startDateObj)
        if let start = startDateObj as Date? {
            var d = start
            d.addTimeInterval(Double(yearsValue) * 365.25 * 24 * 60 * 60)
            endDate = isoFormatter.string(from: d)
        }
        var payload: [String: Any] = [
            "property_id": propertyId,
            "type": type,
            "initial_amount": initialAmountValue,
            "years": yearsValue,
            "interest_rate_fixed": (type == "fixed" || type == "mixed") ? interestFixedValue : 0,
            "interest_rate_variable": (type == "variable" || type == "mixed") ? interestVariableValue : 0,
            "interest_rate": 0,
            "monthly_payment": cuota,
            "start_date": isoStartDate, // <-- siempre string
            "end_date": endDate ?? "",
            "bank_name": bankName,
            "account_number": accountNumber,
            "total_to_pay": totalToPay,
            "payment_day": Int(paymentDay) ?? nil,
            "fixed_rate_period": Int(fixedRatePeriod) ?? nil,
            "reference_number": referenceNumber.isEmpty ? nil : referenceNumber,
            "description": desc.isEmpty ? nil : desc,
            "is_automatic_payment": isAutomatic
        ]
        payload = payload.filter { !($0.value is NSNull) }
        isLoading = true
        
        let createMortgage: () -> Void = {
            let urlString = "https://api.propiexpert.com/mortgages/"
            guard let url = URL(string: urlString) else { self.isLoading = false; return }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])
            } catch {
                self.errorMessage = "Error al preparar los datos."
                self.isLoading = false
                return
            }
            URLSession.shared.dataTask(with: request) { data, response, error in
                DispatchQueue.main.async {
                    self.isLoading = false
                    if let error = error {
                        self.errorMessage = "Error de red: \(error.localizedDescription)"
                        return
                    }
                    guard let httpResponse = response as? HTTPURLResponse else {
                        self.errorMessage = "Respuesta inválida del servidor."
                        return
                    }
                    if httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
                        self.onSave?()
                        self.dismiss()
                    } else {
                        if let data = data, let msg = String(data: data, encoding: .utf8) {
                            self.errorMessage = "Error: \(msg)"
                        } else {
                            self.errorMessage = "Error desconocido al guardar."
                        }
                    }
                }
            }.resume()
        }

        if isEdit, let mortgage = mortgage {
            // Primero elimina la hipoteca existente
            let mortgageId = mortgage.id
            guard let url = URL(string: "https://api.propiexpert.com/mortgages/\(mortgageId)") else { self.isLoading = false; return }
            var request = URLRequest(url: url)
            request.httpMethod = "DELETE"
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
            URLSession.shared.dataTask(with: request) { data, response, error in
                DispatchQueue.main.async {
                    // Ignora errores de borrado (por si no existe)
                    // Ahora crea la nueva hipoteca
                    createMortgage()
                }
            }.resume()
        } else {
            // Si es nueva, solo crea
            createMortgage()
        }
    }

    func deleteMortgage() {
        guard let mortgage = mortgage else { return }
        isLoading = true
        errorMessage = nil
        guard let url = URL(string: "https://api.propiexpert.com/mortgages/\(mortgage.id)") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
                if let error = error {
                    errorMessage = "Error de red: \(error.localizedDescription)"
                    return
                }
                guard let httpResponse = response as? HTTPURLResponse else {
                    errorMessage = "Respuesta inválida del servidor."
                    return
                }
                if httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
                    onDelete?()
                    dismiss()
                } else {
                    if let data = data, let msg = String(data: data, encoding: .utf8) {
                        errorMessage = "Error: \(msg)"
                    } else {
                        errorMessage = "Error desconocido al eliminar."
                    }
                }
            }
        }.resume()
    }

    // Helpers
    func isoDate(from string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.date(from: string)
    }
    func isoString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: date)
    }
}

#Preview {
    MortgageSheet(propertyId: "123", mortgage: nil)
} 