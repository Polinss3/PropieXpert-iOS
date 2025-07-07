import SwiftUI

struct DashboardSummaryItem: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let value: String
    let subtitle: String
    let color: Color
}

struct DashboardView: View {
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
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    Text("Dashboard")
                        .font(.largeTitle).bold()
                        .padding(.top, 8)
                        .padding(.horizontal)
                    
                    // Resumen: Grid de tarjetas
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(summaryItems) { item in
                            DashboardSummaryCard(item: item)
                        }
                    }
                    .padding(.horizontal)
                    
                    // ROI
                    Text("Rentabilidad (ROI)")
                        .font(.headline)
                        .padding(.horizontal)
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(roiItems) { item in
                            DashboardSummaryCard(item: item)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Hipoteca
                    Text("Hipoteca")
                        .font(.headline)
                        .padding(.horizontal)
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(mortgageItems) { item in
                            DashboardSummaryCard(item: item)
                        }
                    }
                    .padding(.horizontal)
                    
                    // --- Aquí irán el resto de secciones ---
                    // Rendimiento de propiedades, Tablas, Calendario, Gráficas...
                    // ...
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
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

#Preview {
    DashboardView()
} 