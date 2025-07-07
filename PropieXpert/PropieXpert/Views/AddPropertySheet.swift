import SwiftUI

struct AddPropertySheet: View {
    @AppStorage("auth_token") var authToken: String = ""
    @Environment(\.dismiss) var dismiss
    var onPropertyAdded: (() -> Void)?

    // Form fields
    @State private var name = ""
    @State private var address = ""
    @State private var purchaseDate = ""
    @State private var purchasePrice = ""
    @State private var currentValue = ""
    @State private var propertyType = "apartment"
    @State private var bedrooms = ""
    @State private var bathrooms = ""
    @State private var squareMeters = ""
    @State private var description = ""
    @State private var amenities = ""
    @State private var isRented = false
    @State private var rentalPrice = ""
    @State private var lastRenovation = ""
    @State private var notes = ""

    // Mortgage fields
    @State private var addMortgage = false
    @State private var mortgageType = "fixed"
    @State private var mortgageInitialAmount = ""
    @State private var mortgageYears = ""
    @State private var mortgageInterestFixed = ""
    @State private var mortgageInterestVariable = ""
    @State private var mortgageStartDate = ""
    @State private var mortgageBankName = ""
    @State private var mortgageAccountNumber = ""
    @State private var mortgagePaymentDay = ""
    @State private var mortgageFixedRatePeriod = ""
    @State private var mortgageReferenceNumber = ""
    @State private var mortgageDescription = ""
    @State private var mortgageIsAutomatic = false

    // UI State
    @State private var isLoading = false
    @State private var errorMessage: String? = nil

    var body: some View {
        ZStack {
            NavigationView {
                Form {
                    Section(header: Text("Propiedad")) {
                        TextField("Nombre", text: $name)
                        TextField("Dirección", text: $address)
                        Picker("Tipo", selection: $propertyType) {
                            Text("Apartamento").tag("apartment")
                            Text("Casa").tag("house")
                            Text("Comercial").tag("commercial")
                            Text("Terreno").tag("land")
                            Text("Otro").tag("other")
                        }
                        TextField("Precio de compra (€)", text: $purchasePrice)
                            .keyboardType(.decimalPad)
                        TextField("Valor actual (€)", text: $currentValue)
                            .keyboardType(.decimalPad)
                        TextField("Dormitorios", text: $bedrooms)
                            .keyboardType(.numberPad)
                        TextField("Baños", text: $bathrooms)
                            .keyboardType(.numberPad)
                        TextField("Metros cuadrados", text: $squareMeters)
                            .keyboardType(.decimalPad)
                        TextField("Descripción", text: $description, axis: .vertical)
                        TextField("Comodidades (separadas por coma)", text: $amenities)
                        Toggle("¿Está alquilada?", isOn: $isRented)
                        if isRented {
                            TextField("Precio de alquiler (€)", text: $rentalPrice)
                                .keyboardType(.decimalPad)
                        }
                        TextField("Última reforma (opcional)", text: $lastRenovation)
                            .keyboardType(.numbersAndPunctuation)
                        TextField("Notas", text: $notes, axis: .vertical)
                    }
                    Section {
                        Toggle("¿Añadir hipoteca?", isOn: $addMortgage)
                    }
                    if addMortgage {
                        Section(header: Text("Hipoteca")) {
                            Picker("Tipo de hipoteca", selection: $mortgageType) {
                                Text("Fija").tag("fixed")
                                Text("Variable").tag("variable")
                                Text("Mixta").tag("mixed")
                            }
                            TextField("Importe inicial (€)", text: $mortgageInitialAmount)
                                .keyboardType(.decimalPad)
                            TextField("Años", text: $mortgageYears)
                                .keyboardType(.numberPad)
                            if mortgageType == "fixed" || mortgageType == "mixed" {
                                TextField("Interés fijo (%)", text: $mortgageInterestFixed)
                                    .keyboardType(.decimalPad)
                            }
                            if mortgageType == "variable" || mortgageType == "mixed" {
                                TextField("Interés variable (%)", text: $mortgageInterestVariable)
                                    .keyboardType(.decimalPad)
                            }
                            TextField("Fecha inicio (YYYY-MM-DD)", text: $mortgageStartDate)
                            TextField("Banco", text: $mortgageBankName)
                            TextField("Nº de cuenta", text: $mortgageAccountNumber)
                            Toggle("Pago automático", isOn: $mortgageIsAutomatic)
                            TextField("Día de pago", text: $mortgagePaymentDay)
                                .keyboardType(.numberPad)
                            TextField("Años tipo fijo", text: $mortgageFixedRatePeriod)
                                .keyboardType(.numberPad)
                            TextField("Referencia", text: $mortgageReferenceNumber)
                            TextField("Descripción", text: $mortgageDescription, axis: .vertical)
                        }
                    }
                    if let errorMessage = errorMessage {
                        Section {
                            Text(errorMessage).foregroundColor(.red)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationTitle("Añadir Propiedad")
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
            }
        }
        .ignoresSafeArea(.container, edges: .all)
    }

    func submit() {
        errorMessage = nil
        // Validación básica
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "El nombre es obligatorio."
            return
        }
        guard !address.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "La dirección es obligatoria."
            return
        }
        guard let purchasePriceValue = Double(purchasePrice), purchasePriceValue > 0 else {
            errorMessage = "Precio de compra inválido."
            return
        }
        guard let currentValueValue = Double(currentValue), currentValueValue > 0 else {
            errorMessage = "Valor actual inválido."
            return
        }
        let bedroomsValue = Int(bedrooms) ?? 0
        let bathroomsValue = Int(bathrooms) ?? 0
        let squareMetersValue = Double(squareMeters) ?? 0
        let rentalPriceValue = Double(rentalPrice)
        // Mortgage validation
        var mortgage: [String: Any]? = nil
        if addMortgage {
            guard let initialAmount = Double(mortgageInitialAmount), initialAmount > 0 else {
                errorMessage = "Importe inicial de hipoteca inválido."
                return
            }
            guard let years = Int(mortgageYears), years > 0 else {
                errorMessage = "Años de hipoteca inválidos."
                return
            }
            let interestFixed = Double(mortgageInterestFixed) ?? 0
            let interestVariable = Double(mortgageInterestVariable) ?? 0
            // Cálculo de cuota mensual
            let n = years * 12
            var r = 0.0
            if mortgageType == "fixed" {
                r = interestFixed / 100 / 12
            } else if mortgageType == "variable" {
                r = interestVariable / 100 / 12
            } else if mortgageType == "mixed" {
                r = interestFixed / 100 / 12
            }
            var cuota = 0.0
            if initialAmount > 0 && r > 0 && n > 0 {
                cuota = (initialAmount * (r * pow(1 + r, Double(n)))) / (pow(1 + r, Double(n)) - 1)
            }
            let totalToPay = cuota * Double(years) * 12
            // Calcula end_date automáticamente
            var endDate: String? = nil
            if !mortgageStartDate.isEmpty, let start = isoDate(from: mortgageStartDate) {
                var d = start
                d.addTimeInterval(Double(years) * 365.25 * 24 * 60 * 60)
                endDate = isoString(from: d)
            }
            mortgage = [
                "type": mortgageType,
                "initial_amount": initialAmount,
                "years": years,
                "interest_rate_fixed": (mortgageType == "fixed" || mortgageType == "mixed") ? interestFixed : 0,
                "interest_rate_variable": (mortgageType == "variable" || mortgageType == "mixed") ? interestVariable : 0,
                "interest_rate": 0, // deprecated
                "monthly_payment": cuota,
                "start_date": mortgageStartDate.isEmpty ? nil : mortgageStartDate,
                "end_date": endDate,
                "bank_name": mortgageBankName,
                "account_number": mortgageAccountNumber,
                "total_to_pay": totalToPay,
                "payment_day": Int(mortgagePaymentDay) ?? nil,
                "fixed_rate_period": Int(mortgageFixedRatePeriod) ?? nil,
                "reference_number": mortgageReferenceNumber.isEmpty ? nil : mortgageReferenceNumber,
                "description": mortgageDescription.isEmpty ? nil : mortgageDescription,
                "is_automatic_payment": mortgageIsAutomatic
            ]
        }
        // Construir payload
        var payload: [String: Any] = [
            "name": name,
            "address": address,
            "property_type": propertyType,
            "purchase_price": purchasePriceValue,
            "current_value": currentValueValue,
            "bedrooms": bedroomsValue,
            "bathrooms": bathroomsValue,
            "square_meters": squareMetersValue,
            "description": description.isEmpty ? nil : description,
            "amenities": amenities.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty },
            "is_rented": isRented,
            "rental_price": isRented ? rentalPriceValue : nil,
            "last_renovation": lastRenovation.isEmpty ? nil : lastRenovation,
            "notes": notes.isEmpty ? nil : notes
        ]
        if let mortgage = mortgage {
            payload["mortgage"] = mortgage
        }
        // Limpiar nils
        payload = payload.filter { !($0.value is NSNull) }
        isLoading = true
        errorMessage = nil
        // Llamada a la API
        guard let url = URL(string: "https://api.propiexpert.com/properties/") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
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
                    onPropertyAdded?()
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
    AddPropertySheet(onPropertyAdded: {})
} 