import SwiftUI
import GoogleSignIn

struct LoginView: View {
    @State private var isLoading = false
    @State private var errorMessage: String?
    @EnvironmentObject private var authSession: AuthSession
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.04, green: 0.08, blue: 0.16), Color(red: 0.02, green: 0.02, blue: 0.06)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color.blue.opacity(0.28))
                .frame(width: 260, height: 260)
                .blur(radius: 70)
                .offset(x: -130, y: -260)

            Circle()
                .fill(Color.cyan.opacity(0.18))
                .frame(width: 320, height: 320)
                .blur(radius: 90)
                .offset(x: 150, y: 280)

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    Spacer(minLength: 44)

                    VStack(alignment: .leading, spacing: 18) {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(.white.opacity(0.12))
                                Image(systemName: "building.2.crop.circle.fill")
                                    .font(.system(size: 28, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                            .frame(width: 58, height: 58)

                            Text("PropieXpert")
                                .font(.system(size: 22, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Gestiona tus propiedades sin fricción")
                                .font(.system(size: 42, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .lineSpacing(-2)

                            Text("Ingresos, gastos, hipotecas y rentabilidad en un panel privado y seguro.")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundStyle(.white.opacity(0.72))
                                .lineSpacing(3)
                        }
                    }

                    VStack(spacing: 18) {
                        HStack(spacing: 10) {
                            LoginPill(icon: "lock.shield.fill", text: "Seguro")
                            LoginPill(icon: "chart.line.uptrend.xyaxis", text: "ROI")
                            LoginPill(icon: "house.fill", text: "Activos")
                        }

                        Button(action: handleSignIn) {
                            HStack(spacing: 14) {
                                ZStack {
                                    Circle()
                                        .fill(.white)
                                    Text("G")
                                        .font(.system(size: 22, weight: .bold, design: .rounded))
                                        .foregroundStyle(Color(red: 0.26, green: 0.52, blue: 0.96))
                                }
                                .frame(width: 34, height: 34)

                                Text(isLoading ? "Conectando..." : "Continuar con Google")
                                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white)

                                Spacer()

                                if isLoading {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: "arrow.right")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(.white.opacity(0.9))
                                }
                            }
                            .padding(.horizontal, 18)
                            .frame(height: 62)
                            .background(
                                LinearGradient(
                                    colors: [Color(red: 0.10, green: 0.45, blue: 0.95), Color(red: 0.00, green: 0.72, blue: 0.88)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                            .shadow(color: Color.cyan.opacity(0.30), radius: 24, x: 0, y: 12)
                        }
                        .disabled(isLoading)
                        .opacity(isLoading ? 0.82 : 1)

                        if let errorMessage = errorMessage {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(Color.orange)
                                    .padding(.top, 2)
                                Text(errorMessage)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.88))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(.white.opacity(0.10), lineWidth: 1)
                            )
                        }

                        Text("Al continuar aceptas acceder con tu cuenta de Google. Tus datos se usan únicamente para autenticarte en PropieXpert.")
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.48))
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)
                    }
                    .padding(20)
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 30, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .stroke(.white.opacity(0.12), lineWidth: 1)
                    )

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 24)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
        }
    }
    
    func handleSignIn() {
        guard let rootViewController = UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.keyWindow })
            .first?.rootViewController else {
            errorMessage = "No se pudo obtener la ventana principal."
            print("[Login] No se pudo obtener la ventana principal.")
            return
        }
        isLoading = true
        errorMessage = nil
        print("[Login] Iniciando Google Sign-In...")
        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { result, error in
            if let error = error {
                isLoading = false
                errorMessage = "Error de Google: \(error.localizedDescription)"
                print("[Login] Error de Google: \(error)")
                return
            }
            guard let idToken = result?.user.idToken?.tokenString else {
                isLoading = false
                errorMessage = "No se pudo obtener el idToken de Google"
                print("[Login] No se pudo obtener el idToken de Google")
                return
            }
            print("[Login] idToken obtenido, llamando al backend...")
            loginWithBackend(idToken: idToken)
        }
    }
    
    func loginWithBackend(idToken: String) {
        guard let url = URL(string: "https://api.propiexpert.com/auth/google-login") else {
            errorMessage = "URL del backend inválida"
            print("[Login] URL del backend inválida")
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ["credential": idToken]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        print("[Login] Enviando petición al backend...")
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    isLoading = false
                    errorMessage = "Error de red: \(error.localizedDescription)"
                    print("[Login] Error de red: \(error)")
                    return
                }
                if let httpResponse = response as? HTTPURLResponse {
                    print("[Login] Código de respuesta HTTP: \(httpResponse.statusCode)")
                }
                guard let data = data else {
                    isLoading = false
                    errorMessage = "No se recibió respuesta del servidor"
                    print("[Login] No se recibió respuesta del servidor")
                    return
                }
                if let responseString = String(data: data, encoding: .utf8) {
                    print("[Login] Respuesta del backend: \(responseString.prefix(300))")
                }
                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    isLoading = false
                    errorMessage = "Respuesta inválida del servidor"
                    print("[Login] Respuesta inválida del servidor")
                    return
                }
                if let token = json["token"] as? String {
                    isLoading = false
                    authSession.login(token: token)
                    print("[Login] Login exitoso, token guardado.")
                } else if let detail = json["detail"] as? String {
                    isLoading = false
                    errorMessage = userFriendlyBackendMessage(detail: detail, statusCode: (response as? HTTPURLResponse)?.statusCode)
                    print("[Login] Error del backend: \(detail)")
                } else {
                    isLoading = false
                    errorMessage = "Respuesta inesperada del backend"
                    print("[Login] Respuesta inesperada del backend: \(json)")
                }
            }
        }
        task.resume()
    }

    func userFriendlyBackendMessage(detail: String, statusCode: Int?) -> String {
        if statusCode == 503 || detail.localizedCaseInsensitiveContains("database") || detail.localizedCaseInsensitiveContains("mongodb") || detail.localizedCaseInsensitiveContains("ssl") {
            return "No podemos completar el inicio de sesión ahora mismo. Estamos teniendo problemas de conexión con el servidor. Inténtalo de nuevo en unos minutos."
        }

        if statusCode == 401 || statusCode == 403 {
            return "No hemos podido validar tu cuenta de Google. Inténtalo de nuevo."
        }

        return "No hemos podido iniciar sesión. Inténtalo de nuevo en unos minutos."
    }
}

private struct LoginPill: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
            Text(text)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(.white.opacity(0.86))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.white.opacity(0.10), in: Capsule())
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthSession())
} 
