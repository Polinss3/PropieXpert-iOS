import SwiftUI

struct UserProfileView: View {
    @AppStorage("auth_token") var authToken: String = ""
    @State private var user: UserProfile?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showEditProfile = false
    @State private var showLogoutAlert = false
    
    // Extrae la URL de la foto del JWT
    var googlePictureURL: String? {
        let url = decodeJWT(token: authToken)
        print("[DEBUG] googlePictureURL - payload extraído del JWT:", url as Any)
        guard let payload = url,
              let picture = payload["picture"] as? String else { return nil }
        print("[DEBUG] googlePictureURL - picture extraído:", picture)
        return picture
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                VStack(spacing: 28) {
                    Spacer(minLength: 24)
                    // Avatar
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .accentColor))
                            .scaleEffect(2)
                            .padding(.top, 40)
                    } else if let errorMessage = errorMessage {
                        Text(errorMessage).foregroundColor(.red)
                    } else if let user = user {
                        VStack(spacing: 12) {
                            if let urlString = googlePictureURL, let url = URL(string: urlString) {
                                AsyncImage(url: url) { phase in
                                    if let image = phase.image {
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 110, height: 110)
                                            .clipShape(Circle())
                                            .shadow(radius: 8)
                                            .overlay(Circle().stroke(Color.accentColor, lineWidth: 3))
                                    } else if phase.error != nil {
                                        Image(systemName: "person.crop.circle.fill")
                                            .resizable()
                                            .foregroundColor(.gray.opacity(0.4))
                                            .frame(width: 110, height: 110)
                                    } else {
                                        ProgressView()
                                            .frame(width: 110, height: 110)
                                    }
                                }
                            } else {
                                Image(systemName: "person.crop.circle.fill")
                                    .resizable()
                                    .foregroundColor(.gray.opacity(0.4))
                                    .frame(width: 110, height: 110)
                                    .shadow(radius: 8)
                            }
                            Button(action: { showEditProfile = true }) {
                                Text("Editar perfil")
                                    .font(.caption)
                                    .foregroundColor(.accentColor)
                                    .padding(.top, 2)
                            }
                            .sheet(isPresented: $showEditProfile) {
                                EditProfilePlaceholderView(user: user)
                            }
                        }
                        // Nombre y email
                        VStack(spacing: 2) {
                            Text(user.name ?? "Sin nombre")
                                .font(.title).bold()
                                .multilineTextAlignment(.center)
                            Text(user.email)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                        }
                        // Tarjeta de plan
                        if let plan = user.plan {
                            VStack(spacing: 8) {
                                HStack(spacing: 8) {
                                    Image(systemName: "star.fill")
                                        .foregroundColor(.yellow)
                                    Text("Plan actual: \(plan.capitalized)")
                                        .font(.headline)
                                }
                                if let limit = user.property_limit {
                                    Text("Límite de propiedades: \(limit)")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                if user.plan_selected == false {
                                    Text("No has seleccionado un plan todavía.")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                                // Botón para gestionar suscripción
                                Button(action: {
                                    let urlString = "https://app.propiexpert.com/profile?token=\(authToken)"
                                    if let url = URL(string: urlString) {
                                        UIApplication.shared.open(url)
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: "arrow.up.right.square")
                                        Text("Gestionar suscripción")
                                    }
                                    .font(.body.bold())
                                    .padding(.vertical, 10)
                                    .frame(maxWidth: .infinity)
                                    .background(Color.blue.opacity(0.12))
                                    .foregroundColor(.blue)
                                    .cornerRadius(12)
                                }
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(16)
                        }
                        // Idioma
                        HStack(spacing: 8) {
                            Image(systemName: "globe")
                                .foregroundColor(.blue)
                            Text("Idioma: Español")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        // Botón cerrar sesión
                        Button(action: { showLogoutAlert = true }) {
                            Text("Cerrar sesión")
                                .font(.headline)
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red.opacity(0.08))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.red.opacity(0.2), lineWidth: 1)
                                )
                        }
                        .padding(.top, 8)
                        .padding(.horizontal, 32)
                        .alert("¿Seguro que quieres cerrar sesión?", isPresented: $showLogoutAlert) {
                            Button("Cerrar sesión", role: .destructive) { logout() }
                            Button("Cancelar", role: .cancel) {}
                        }
                        Spacer()
                    }
                }
                .padding(.horizontal, 24)
                .navigationTitle("Perfil")
                .navigationBarTitleDisplayMode(.large)
            }
        }
        .onAppear(perform: fetchUserProfile)
    }
    
    func fetchUserProfile() {
        print("[DEBUG] fetchUserProfile - authToken:", authToken)
        guard let url = URL(string: "https://api.propiexpert.com/auth/me") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let data = data {
                    print("[DEBUG] fetchUserProfile - respuesta cruda:", String(data: data, encoding: .utf8) ?? "<binario>")
                    do {
                        let decoded = try JSONDecoder().decode(UserProfile.self, from: data)
                        user = decoded
                        print("[DEBUG] fetchUserProfile - usuario decodificado:", decoded)
                    } catch {
                        print("[DEBUG] fetchUserProfile - error decodificando:", error)
                        errorMessage = "Error al decodificar usuario: \(error.localizedDescription)"
                    }
                } else if let error = error {
                    errorMessage = "Error de red: \(error.localizedDescription)"
                } else {
                    errorMessage = "No se recibieron datos del servidor."
                }
            }
        }.resume()
    }
    
    func logout() {
        authToken = ""
        // Aquí podrías limpiar más datos si es necesario
    }
    
    // Decodifica el payload del JWT y lo devuelve como diccionario
    func decodeJWT(token: String) -> [String: Any]? {
        print("[DEBUG] decodeJWT - token recibido:", token)
        let segments = token.split(separator: ".")
        guard segments.count == 3 else {
            print("[DEBUG] decodeJWT - token no tiene 3 partes")
            return nil
        }
        let payloadSegment = segments[1]
        var base64 = String(payloadSegment)
        // Añadir padding si es necesario
        let requiredLength = 4 * ((base64.count + 3) / 4)
        let paddingLength = requiredLength - base64.count
        if paddingLength > 0 {
            base64 += String(repeating: "=", count: paddingLength)
        }
        guard let data = Data(base64Encoded: base64) else {
            print("[DEBUG] decodeJWT - base64 inválido")
            return nil
        }
        let json = try? JSONSerialization.jsonObject(with: data, options: [])
        print("[DEBUG] decodeJWT - payload decodificado:", json as Any)
        return json as? [String: Any]
    }
}

// Vista placeholder para editar perfil
struct EditProfilePlaceholderView: View {
    let user: UserProfile
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "person.crop.circle.badge.pencil")
                .resizable()
                .frame(width: 80, height: 80)
                .foregroundColor(.accentColor)
            Text("Edición de perfil (próximamente)")
                .font(.title2).bold()
            Text("Aquí podrás editar tu nombre, foto y otros datos personales.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding()
    }
} 