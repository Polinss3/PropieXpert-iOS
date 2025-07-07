import SwiftUI

struct DashboardView: View {
    var body: some View {
        ZStack {
            VStack {
                Text("Dashboard")
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
    DashboardView()
} 