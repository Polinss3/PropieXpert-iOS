import SwiftUI

struct PlaceholderView: View {
    var body: some View {
        ZStack {
            VStack {
                Text("Más próximamente")
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
    PlaceholderView()
} 