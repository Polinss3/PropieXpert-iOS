import SwiftUI
import GoogleSignIn
import GoogleSignInSwift

struct LoginView: View {
    @State private var isLoading = false
    @State private var errorMessage: String?
    @AppStorage("auth_token") var authToken: String = ""
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Inicia sesión con Google")
                .font(.title)
                .bold()
            GoogleSignInButton(action: handleSignIn)
                .frame(height: 50)
            if isLoading {
                ProgressView()
            }
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
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
            isLoading = false
            if let error = error {
                errorMessage = "Error de Google: \(error.localizedDescription)"
                print("[Login] Error de Google: \(error)")
                return
            }
            guard let idToken = result?.user.idToken?.tokenString else {
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
                    errorMessage = "Error de red: \(error.localizedDescription)"
                    print("[Login] Error de red: \(error)")
                    return
                }
                if let httpResponse = response as? HTTPURLResponse {
                    print("[Login] Código de respuesta HTTP: \(httpResponse.statusCode)")
                }
                guard let data = data else {
                    errorMessage = "No se recibió respuesta del servidor"
                    print("[Login] No se recibió respuesta del servidor")
                    return
                }
                if let responseString = String(data: data, encoding: .utf8) {
                    print("[Login] Respuesta del backend: \(responseString)")
                }
                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    errorMessage = "Respuesta inválida del servidor"
                    print("[Login] Respuesta inválida del servidor")
                    return
                }
                if let token = json["token"] as? String {
                    authToken = token
                    print("[Login] Login exitoso, token guardado.")
                } else if let detail = json["detail"] as? String {
                    errorMessage = "Error del backend: \(detail)"
                    print("[Login] Error del backend: \(detail)")
                } else {
                    errorMessage = "Respuesta inesperada del backend"
                    print("[Login] Respuesta inesperada del backend: \(json)")
                }
            }
        }
        task.resume()
    }
}

#Preview {
    LoginView()
} 