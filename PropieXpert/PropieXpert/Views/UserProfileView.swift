import SwiftUI

struct UserProfileView: View {
    @AppStorage("auth_token") var authToken: String = ""
    @State private var user: UserProfile?
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                if isLoading {
                    ProgressView("Cargando perfil...")
                } else if let errorMessage = errorMessage {
                    Text(errorMessage).foregroundColor(.red)
                } else if let user = user {
                    VStack(spacing: 16) {
                        // Avatar
                        if let picture = user.picture, let url = URL(string: picture) {
                            AsyncImage(url: url) { image in
                                image.resizable()
                            } placeholder: {
                                ProgressView()
                            }
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                        } else {
                            Image(systemName: "person.crop.circle.fill")
                                .resizable()
                                .frame(width: 100, height: 100)
                                .foregroundColor(.gray)
                        }
                        // Nombre y email
                        Text(user.name ?? "Usuario")
                            .font(.title).bold()
                        Text(user.email)
                            .foregroundColor(.secondary)
                        // Plan
                        if let plan = user.plan {
                            Text("Plan actual: \(plan.capitalized)")
                                .font(.headline)
                            Text("Límite: \(user.property_limit.map { "\($0) propiedades" } ?? "Sin límite")")
                                .font(.subheadline)
                        }
                        // Botón de logout
                        Button("Cerrar sesión") {
                            authToken = ""
                        }
                        .foregroundColor(.red)
                        .padding(.top, 16)
                    }
                }
            }
            .padding()
            .navigationTitle("Perfil")
            .onAppear(perform: fetchUserProfile)
        }
    }
    
    func fetchUserProfile() {
        isLoading = true
        errorMessage = nil
        guard let url = URL(string: "https://api.propiexpert.com/auth/me") else { return }
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
                    let decoded = try JSONDecoder().decode(UserProfile.self, from: data)
                    user = decoded
                } catch {
                    errorMessage = "Error al decodificar usuario: \(error.localizedDescription)"
                }
            }
        }.resume()
    }
} 