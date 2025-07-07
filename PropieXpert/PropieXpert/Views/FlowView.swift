import SwiftUI

struct FlowView: View {
    var body: some View {
        ZStack {
            VStack {
                Text("Flujo de Ingresos y Gastos")
                    .font(.largeTitle)
                    .padding(.top, 32)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color(.systemBackground))
        }
        .ignoresSafeArea(.container, edges: .all)
    }
}

#Preview {
    FlowView()
} 