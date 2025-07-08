import SwiftUI
import Foundation

struct AddExpenseSheet: View {
    @AppStorage("auth_token") var authToken: String = ""
    @Environment(\.dismiss) var dismiss
    var onExpenseAdded: (() -> Void)?
    var initialData: PropieXpert.Expense? = nil
    var isEdit: Bool { initialData != nil }

    // Form fields
    @State private var properties: [PropertyName] = []
    @State private var propertyId: String = ""
    @State private var type: String = ""
    @State private var amount: String = ""
    @State private var date: String = ""
    @State private var description: String = ""
    @State private var isRecurring: Bool = false
    @State private var frequency: String = "monthly"
    @State private var recurrenceStartDate: String = ""
    @State private var recurrenceEndDate: String = ""
    @State private var dueDate: String = ""
    @State private var isPaid: Bool = false
    @State private var paymentDate: String = ""
    // UI State
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var showDeleteAlert = false
    @State private var isDeleting = false

    let expenseTypes = ["maintenance", "utilities", "taxes", "insurance", "mortgage", "repairs", "improvements", "management", "other"]
    let frequencyOptions = ["monthly", "quarterly", "yearly"]

    var body: some View {
        ZStack {
            NavigationView {
                Form {
                    Section(header: Text("Gasto")) {
                        Picker("Propiedad", selection: $propertyId) {
                            Text("Selecciona una propiedad").tag("")
                            ForEach(properties, id: \.id) { property in
                                Text(property.name).tag(property._id)
                            }
                        }
                        Picker("Tipo", selection: $type) {
                            Text("Selecciona un tipo").tag("")
                            ForEach(expenseTypes, id: \.self) { t in
                                Text(typeLabel(for: t)).tag(t)
                            }
                        }
                        TextField("Cantidad (€)", text: $amount)
                            .keyboardType(.decimalPad)
                        DatePicker("Fecha", selection: Binding(
                            get: { dateFromString(date) ?? Date() },
                            set: { date = stringFromDate($0) }
                        ), displayedComponents: .date)
                        TextField("Descripción", text: $description, axis: .vertical)
                    }
                    Section {
                        Toggle("¿Es recurrente?", isOn: $isRecurring)
                    }
                    if isRecurring {
                        Section(header: Text("Recurrencia")) {
                            Picker("Frecuencia", selection: $frequency) {
                                ForEach(frequencyOptions, id: \.self) { f in
                                    Text(frequencyLabel(for: f)).tag(f)
                                }
                            }
                            DatePicker("Fecha inicio", selection: Binding(
                                get: { dateFromString(recurrenceStartDate) ?? Date() },
                                set: { recurrenceStartDate = stringFromDate($0) }
                            ), displayedComponents: .date)
                            DatePicker("Fecha fin", selection: Binding(
                                get: { dateFromString(recurrenceEndDate) ?? Date() },
                                set: { recurrenceEndDate = stringFromDate($0) }
                            ), displayedComponents: .date)
                        }
                    }
                    Section(header: Text("Vencimiento y pago")) {
                        DatePicker("Fecha de vencimiento", selection: Binding(
                            get: { dateFromString(dueDate) ?? Date() },
                            set: { dueDate = stringFromDate($0) }
                        ), displayedComponents: .date)
                        Toggle("¿Pagado?", isOn: $isPaid)
                        if isPaid {
                            DatePicker("Fecha de pago", selection: Binding(
                                get: { dateFromString(paymentDate) ?? Date() },
                                set: { paymentDate = stringFromDate($0) }
                            ), displayedComponents: .date)
                        }
                    }
                    if let errorMessage = errorMessage {
                        Section {
                            Text(errorMessage).foregroundColor(.red)
                        }
                    }
                    if isEdit {
                        Section {
                            Button("Eliminar gasto", role: .destructive) {
                                showDeleteAlert = true
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationTitle(isEdit ? "Editar Gasto" : "Añadir Gasto")
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
                .onAppear(perform: loadInitialData)
                .alert("¿Eliminar gasto?", isPresented: $showDeleteAlert) {
                    Button("Eliminar", role: .destructive, action: deleteExpense)
                    Button("Cancelar", role: .cancel) {}
                } message: {
                    Text("Esta acción no se puede deshacer.")
                }
            }
        }
        .ignoresSafeArea(.container, edges: .all)
    }

    func loadInitialData() {
        fetchProperties()
        if let expense = initialData {
            propertyId = expense.property_id
            type = expense.type
            amount = String(format: "%.2f", expense.amount)
            date = String(expense.date.prefix(10))
            description = expense.description ?? ""
            isRecurring = expense.is_recurring ?? false
            frequency = expense.frequency ?? "monthly"
            recurrenceStartDate = expense.date.prefix(10).description
            recurrenceEndDate = ""
            dueDate = expense.due_date ?? ""
            isPaid = expense.is_paid ?? false
            paymentDate = expense.payment_date ?? ""
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

    func submit() {
        errorMessage = nil
        // Validación básica
        guard !propertyId.isEmpty else {
            errorMessage = "La propiedad es obligatoria."
            return
        }
        guard !type.isEmpty else {
            errorMessage = "El tipo es obligatorio."
            return
        }
        guard let amountValue = Double(amount), amountValue > 0 else {
            errorMessage = "Cantidad inválida."
            return
        }
        guard !date.isEmpty else {
            errorMessage = "La fecha es obligatoria."
            return
        }
        isLoading = true
        var payload: [String: Any] = [
            "property_id": propertyId,
            "type": type,
            "amount": amountValue,
            "date": date + "T00:00:00",
            "is_recurring": isRecurring
        ]
        if !description.isEmpty {
            payload["description"] = description
        }
        if isRecurring {
            payload["frequency"] = frequency
            payload["recurrence_start_date"] = recurrenceStartDate + "T00:00:00"
            if !recurrenceEndDate.isEmpty {
                payload["recurrence_end_date"] = recurrenceEndDate + "T00:00:00"
            }
        }
        if !dueDate.isEmpty {
            payload["due_date"] = dueDate + "T00:00:00"
        }
        payload["is_paid"] = isPaid
        if isPaid, !paymentDate.isEmpty {
            payload["payment_date"] = paymentDate + "T00:00:00"
        }
        let urlString: String
        let method: String
        if isEdit, let id = initialData?.id {
            urlString = "https://api.propiexpert.com/expenses/\(id)"
            method = "PUT"
        } else {
            urlString = "https://api.propiexpert.com/expenses/"
            method = "POST"
        }
        guard let url = URL(string: urlString) else { isLoading = false; return }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])
        } catch {
            errorMessage = "Error al preparar los datos."
            isLoading = false
            return
        }
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
                    onExpenseAdded?()
                    dismiss()
                } else {
                    if let data = data, let msg = String(data: data, encoding: .utf8) {
                        errorMessage = "Error: \(msg)"
                    } else {
                        errorMessage = "Error desconocido al guardar."
                    }
                }
            }
        }.resume()
    }

    func deleteExpense() {
        guard let id = initialData?.id else { return }
        isDeleting = true
        errorMessage = nil
        let urlString = "https://api.propiexpert.com/expenses/\(id)"
        guard let url = URL(string: urlString) else { isDeleting = false; return }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isDeleting = false
                if let error = error {
                    errorMessage = "Error al eliminar: \(error.localizedDescription)"
                    return
                }
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 else {
                    errorMessage = "Error desconocido al eliminar."
                    return
                }
                onExpenseAdded?()
                dismiss()
            }
        }.resume()
    }

    func dateFromString(_ str: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: str)
    }
    func stringFromDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
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
    func frequencyLabel(for freq: String) -> String {
        switch freq {
        case "monthly": return "Mensual"
        case "quarterly": return "Trimestral"
        case "yearly": return "Anual"
        default: return freq.capitalized
        }
    }
}

#Preview {
    AddExpenseSheet(onExpenseAdded: {})
} 