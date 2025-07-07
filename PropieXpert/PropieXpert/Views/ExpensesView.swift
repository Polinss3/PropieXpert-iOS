import SwiftUI
import Foundation
// Los modelos Income y Expense vienen de Models.swift
// Importa Models.swift si es necesario (en Xcode suele estar disponible automáticamente)

struct ExpensesView: View {
    @AppStorage("auth_token") var authToken: String = ""
    @State private var expenses: [Expense] = []
    @State private var properties: [PropertyName] = []
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var showAddExpenseSheet = false
    @State private var editingExpense: Expense? = nil
    
    var body: some View {
        ZStack {
            NavigationView {
                VStack {
                    if isLoading {
                        ProgressView("Cargando gastos...")
                    } else if let errorMessage = errorMessage {
                        Text(errorMessage).foregroundColor(.red)
                    } else if expenses.isEmpty {
                        VStack(spacing: 12) {
                            Text("No tienes gastos registrados.")
                                .foregroundColor(.gray)
                            Text("Pulsa el botón '+' para añadir un gasto.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(expenses) { expense in
                                    ExpenseCard(expense: expense, propertyName: getPropertyName(for: expense.property_id))
                                        .padding(.horizontal)
                                        .onTapGesture {
                                            editingExpense = expense
                                            showAddExpenseSheet = true
                                        }
                                }
                            }
                            .padding(.top)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationTitle("Gastos")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            editingExpense = nil
                            showAddExpenseSheet = true
                        }) {
                            Image(systemName: "plus")
                        }
                    }
                }
                .onAppear(perform: fetchAll)
                .sheet(isPresented: $showAddExpenseSheet) {
                    AddExpenseSheet(
                        onExpenseAdded: {
                            fetchAll()
                            showAddExpenseSheet = false
                        },
                        initialData: editingExpense
                    )
                }
            }
        }
        .ignoresSafeArea(.container, edges: .all)
    }
    
    func fetchAll() {
        fetchProperties {
            fetchExpenses()
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
    
    func fetchExpenses() {
        isLoading = true
        errorMessage = nil
        guard let url = URL(string: "https://api.propiexpert.com/expenses/") else { isLoading = false; return }
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
                    let decoded = try JSONDecoder().decode([Expense].self, from: data)
                    expenses = decoded
                } catch {
                    errorMessage = "Error al decodificar gastos: \(error.localizedDescription)"
                }
            }
        }.resume()
    }
    
    func getPropertyName(for propertyId: String) -> String {
        properties.first(where: { $0._id == propertyId })?.name ?? "Propiedad desconocida"
    }
}

struct ExpenseCard: View {
    let expense: Expense
    let propertyName: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(propertyName)
                    .font(.headline)
                Spacer()
                Text(typeLabel(for: expense.type))
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.red.opacity(0.15))
                    .foregroundColor(.red)
                    .cornerRadius(10)
            }
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Cantidad")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatCurrency(expense.amount))
                        .font(.title3).bold()
                        .foregroundColor(.red)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Fecha")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatDate(expense.date))
                        .font(.body)
                }
            }
            if let due = expense.due_date, !due.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Vencimiento")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatDate(due))
                        .font(.body)
                }
            }
            if let desc = expense.description, !desc.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Descripción")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(desc)
                        .font(.body)
                }
            }
            HStack(spacing: 12) {
                if let isPaid = expense.is_paid {
                    Label(isPaid ? "Pagado" : "Pendiente", systemImage: isPaid ? "checkmark.circle.fill" : "clock.fill")
                        .font(.caption)
                        .foregroundColor(isPaid ? .green : .orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background((isPaid ? Color.green : Color.orange).opacity(0.12))
                        .cornerRadius(8)
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
}

#Preview {
    ExpensesView()
} 