import SwiftUI
import UniformTypeIdentifiers
// El modelo Income viene de Models.swift

struct AddIncomeSheet: View {
    @AppStorage("auth_token") var authToken: String = ""
    @Environment(\.dismiss) var dismiss
    var onIncomeAdded: (() -> Void)?
    var initialData: Income? = nil
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
    // Document upload
    @State private var fileUrl: URL? = nil
    @State private var fileCategory: String = ""
    @State private var fileDescription: String = ""
    @State private var isUploadingFile = false
    @State private var fileUploadError: String? = nil
    @State private var fileUploadSuccess: String? = nil
    // UI State
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var showDeleteAlert = false
    @State private var isDeleting = false

    let incomeTypes = ["rent", "deposit", "sale", "interest", "dividends", "other"]
    let frequencyOptions = ["monthly", "quarterly", "yearly"]
    let categoryOptions = ["nota_simple", "certificado_energia", "factura", "contrato", "recibo", "otro"]

    var body: some View {
        ZStack {
            NavigationView {
                Form {
                    Section {
                        Text("Los campos marcados con * son obligatorios")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Section(header: Text("Ingreso")) {
                        Picker("Propiedad *", selection: $propertyId) {
                            Text("Selecciona una propiedad").tag("")
                            ForEach(properties, id: \._id) { property in
                                Text(property.name).tag(property._id)
                            }
                        }
                        Picker("Tipo *", selection: $type) {
                            Text("Selecciona un tipo").tag("")
                            ForEach(incomeTypes, id: \.self) { t in
                                Text(typeLabel(for: t)).tag(t)
                            }
                        }
                        TextField("Cantidad (€) *", text: $amount)
                            .keyboardType(.decimalPad)
                        DatePicker("Fecha *", selection: Binding(
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
                    Section(header: Text("Documento (opcional)")) {
                        FilePickerButton(fileUrl: $fileUrl)
                        Picker("Categoría", selection: $fileCategory) {
                            Text("-").tag("")
                            ForEach(categoryOptions, id: \.self) { c in
                                Text(categoryLabel(for: c)).tag(c)
                            }
                        }
                        TextField("Descripción del archivo", text: $fileDescription)
                        if isUploadingFile {
                            ProgressView("Subiendo archivo...")
                        }
                        if let fileUploadError = fileUploadError {
                            Text(fileUploadError).foregroundColor(.red)
                        }
                        if let fileUploadSuccess = fileUploadSuccess {
                            Text(fileUploadSuccess).foregroundColor(.green)
                        }
                    }
                    if let errorMessage = errorMessage {
                        Section {
                            Text(errorMessage).foregroundColor(.red)
                        }
                    }
                    if isEdit {
                        Section {
                            Button("Eliminar ingreso", role: .destructive) {
                                showDeleteAlert = true
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationTitle(isEdit ? "Editar Ingreso" : "Añadir Ingreso")
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
                .alert("¿Eliminar ingreso?", isPresented: $showDeleteAlert) {
                    Button("Eliminar", role: .destructive, action: deleteIncome)
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
        if let income = initialData {
            propertyId = income.property_id
            type = income.type
            amount = String(format: "%.2f", income.amount)
            date = String(income.date.prefix(10))
            description = income.description ?? ""
            // Recurrencia
            isRecurring = income.is_recurring ?? false
            frequency = income.frequency ?? "monthly"
            recurrenceStartDate = income.date.prefix(10).description
            recurrenceEndDate = ""
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
        let urlString: String
        let method: String
        if isEdit, let id = initialData?.id {
            urlString = "https://api.propiexpert.com/incomes/\(id)"
            method = "PUT"
        } else {
            urlString = "https://api.propiexpert.com/incomes/"
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
                    // Subir archivo si hay
                    if let fileUrl = fileUrl {
                        uploadFile(incomeId: extractIncomeId(from: data))
                    } else {
                        onIncomeAdded?()
                        dismiss()
                    }
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

    func uploadFile(incomeId: String?) {
        guard let fileUrl = fileUrl, let incomeId = incomeId else { return }
        isUploadingFile = true
        fileUploadError = nil
        fileUploadSuccess = nil
        let boundary = UUID().uuidString
        var request = URLRequest(url: URL(string: "https://api.propiexpert.com/documents/income/\(incomeId)/files")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        var body = Data()
        // File
        if let fileData = try? Data(contentsOf: fileUrl) {
            let filename = fileUrl.lastPathComponent
            let mimetype = mimeType(for: fileUrl)
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: \(mimetype)\r\n\r\n".data(using: .utf8)!)
            body.append(fileData)
            body.append("\r\n".data(using: .utf8)!)
        }
        // Category
        if !fileCategory.isEmpty {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"category\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(fileCategory)\r\n".data(using: .utf8)!)
        }
        // Description
        if !fileDescription.isEmpty {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"description\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(fileDescription)\r\n".data(using: .utf8)!)
        }
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body
        URLSession.shared.uploadTask(with: request, from: body) { data, response, error in
            DispatchQueue.main.async {
                isUploadingFile = false
                if let error = error {
                    fileUploadError = "Error al subir archivo: \(error.localizedDescription)"
                    return
                }
                fileUploadSuccess = "Archivo subido correctamente."
                onIncomeAdded?()
                dismiss()
            }
        }.resume()
    }

    func extractIncomeId(from data: Data?) -> String? {
        guard let data = data else { return nil }
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return (json["id"] as? String) ?? (json["_id"] as? String)
        }
        return nil
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
    func mimeType(for url: URL) -> String {
        let ext = url.pathExtension
        if let uti = UTType(filenameExtension: ext), let mime = uti.preferredMIMEType {
            return mime
        }
        return "application/octet-stream"
    }
    func typeLabel(for type: String) -> String {
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
    func frequencyLabel(for freq: String) -> String {
        switch freq {
        case "monthly": return "Mensual"
        case "quarterly": return "Trimestral"
        case "yearly": return "Anual"
        default: return freq.capitalized
        }
    }
    func categoryLabel(for cat: String) -> String {
        switch cat {
        case "nota_simple": return "Nota simple"
        case "certificado_energia": return "Certificado energético"
        case "factura": return "Factura"
        case "contrato": return "Contrato"
        case "recibo": return "Recibo"
        case "otro": return "Otro"
        default: return cat.capitalized
        }
    }
    func deleteIncome() {
        guard let id = initialData?.id else { return }
        isDeleting = true
        errorMessage = nil
        let urlString = "https://api.propiexpert.com/incomes/\(id)"
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
                onIncomeAdded?()
                dismiss()
            }
        }.resume()
    }
}

// FilePickerButton: Botón para seleccionar archivo
struct FilePickerButton: View {
    @Binding var fileUrl: URL?
    @State private var showPicker = false
    var body: some View {
        Button(action: { showPicker = true }) {
            HStack {
                Image(systemName: "paperclip")
                Text(fileUrl == nil ? "Seleccionar archivo" : fileUrl!.lastPathComponent)
            }
        }
        .fileImporter(isPresented: $showPicker, allowedContentTypes: [.data], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                fileUrl = urls.first
            case .failure:
                fileUrl = nil
            }
        }
    }
}

#Preview {
    AddIncomeSheet(onIncomeAdded: {})
} 