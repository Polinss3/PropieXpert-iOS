import SwiftUI

struct FlowView: View {
    var body: some View {
        VStack {
            Text("Flujo de Ingresos y Gastos")
                .font(.largeTitle)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

#Preview {
    FlowView()
} 