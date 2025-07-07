import SwiftUI
import Foundation
// Importa Models.swift si es necesario (en Xcode suele estar disponible automáticamente)

struct Income: Identifiable, Decodable {
    let id: String
    let property_id: String
    let type: String
    let amount: Double
    let date: String
    let description: String?
    let is_recurring: Bool?
    let frequency: String?
    // Puedes añadir más campos si los necesitas
}

struct IncomeView: View {
    @AppStorage("auth_token") var authToken: String = ""
    @State private var incomes: [Income] = []
    @State private var properties: [PropertyName] = []
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var showAddIncomeSheet = false
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("Cargando ingresos...")
                } else if let errorMessage = errorMessage {
                    Text(errorMessage).foregroundColor(.red)
                } else if incomes.isEmpty {
                    VStack(spacing: 12) {
                        Text("No tienes ingresos registrados.")
                            .foregroundColor(.gray)
                        Text("Pulsa el botón '+' para añadir un ingreso.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(incomes) { income in
                                IncomeCard(income: income, propertyName: getPropertyName(for: income.property_id))
                                    .padding(.horizontal)
                            }
                        }
                        .padding(.top)
                    }
                }
            }
            .navigationTitle("Ingresos")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showAddIncomeSheet = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .onAppear(perform: fetchAll)
            .sheet(isPresented: $showAddIncomeSheet) {
                AddIncomeSheet(onIncomeAdded: {
                    fetchAll()
                    showAddIncomeSheet = false
                })
            }
        }
    }
    
    func fetchAll() {
        fetchProperties {
            fetchIncomes()
        }
    }
    
    func fetchProperties(completion: @escaping () -> Void) {
        guard let url = URL(string: "https://api.propiexpert.com/properties/") else { completion(); return }
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
                completion()
            }
        }.resume()
    }
    
    func fetchIncomes() {
        isLoading = true
        errorMessage = nil
        guard let url = URL(string: "https://api.propiexpert.com/incomes/") else { isLoading = false; return }
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
                    let decoded = try JSONDecoder().decode([Income].self, from: data)
                    incomes = decoded
                } catch {
                    errorMessage = "Error al decodificar ingresos: \(error.localizedDescription)"
                }
            }
        }.resume()
    }
    
    func getPropertyName(for propertyId: String) -> String {
        properties.first(where: { $0._id == propertyId })?.name ?? "Propiedad desconocida"
    }
}

struct IncomeCard: View {
    let income: Income
    let propertyName: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(propertyName)
                    .font(.headline)
                Spacer()
                Text(typeLabel(for: income.type))
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.15))
                    .foregroundColor(.green)
                    .cornerRadius(10)
            }
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Cantidad")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatCurrency(income.amount))
                        .font(.title3).bold()
                        .foregroundColor(.green)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Fecha")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatDate(income.date))
                        .font(.body)
                }
            }
            if let desc = income.description, !desc.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Descripción")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(desc)
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
    
    func formatDate(_ dateString: String) -> String {
        // Intenta parsear con DateFormatter flexible
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
}

#Preview {
    IncomeView()
} 