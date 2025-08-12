import SwiftUI
import LocalAuthentication
import AuthenticationServices
import FirebaseAuth
import CryptoKit
import Firebase
import FirebaseCore
import GoogleSignIn

enum AuthenticationError: Error {
    case runtimeError(String)
}

struct WelcomeView: View {
    @EnvironmentObject var auth: AuthViewModel
    @EnvironmentObject var popRoot: PopToRoot
    @Environment(\.colorScheme) var colorScheme
    @State var selection = 0
    @Namespace var animation
    @State var toggleGlitch = false
    @State var resettingPassword = false
    @State var createLoading = false
    @State var username = ""
    @State var usernameError = ""
    @State var usernameLoading = false
    @State var showTerms = false
    @State var email = ""
    @State var storedEmail = ""
    @State var storedPass = ""
    @State var emailError = ""
    @State var emailLoading = false
    @State var passLoading = false
    @State var showPicker = false
    @State var selectedImage: UIImage?
    @State var newImage: Image?
    @State var password = ""
    @State var passwordError = ""
    @State var nonce: String?
    @State private var errorMessage: String = ""
    @State private var showAlert: Bool = false
    @State var appleLoading = false
    @State var appleCreating = false
    @State var googleLoading = false
    @State var googleCreating = false
    @FocusState var isEditing
    @FocusState var isPassEditing
    @FocusState var isUserEditing
    
    var body: some View {
        ZStack {
            GeometryReader { geo in
                Image("WealthBlur")
                    .resizable()
                    .frame(width: geo.size.width, height: geo.size.height)
            }
            .ignoresSafeArea()
                
            if selection == 0 {
                actionButtons()
            } else if selection == 1 {
                emailField()
                    .transition(.opacity).offset(y: -80)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            authenticate()
                        }
                    }
            } else if selection == 2 {
                passwordField(createAcc: false).transition(.opacity).offset(y: -80)
            } else if selection == 3 {
                passwordField(createAcc: true).transition(.opacity).offset(y: -80)
            } else if selection == 4 {
                createAccount().transition(.opacity).offset(y: -80)
            }

            topLogo()
        }
        .onOpenURL { url in
            GIDSignIn.sharedInstance.handle(url)
        }
        .ignoresSafeArea(.keyboard)
        .alert(errorMessage, isPresented: $showAlert) {  }
        .onChange(of: selection, initial: true, { _, newValue in
            if selection == 0 {
                glitchTogg()
            }
        })
        .sheet(isPresented: $showPicker, onDismiss: loadImage){
            ImagePicker(selectedImage: $selectedImage)
        }
        .sheet(isPresented: $showTerms) {
            termsView().presentationDetents([.large])
        }
    }
    @MainActor
    func googleOauth() async throws {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            showError("Cannot process your request. Code 1a")
            return
        }

        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene
        guard let rootViewController = scene?.windows.first?.rootViewController else {
            showError("Cannot process your request. Code 1b")
            return
        }
        
        let result = try await GIDSignIn.sharedInstance.signIn(
            withPresenting: rootViewController
        )
        let user = result.user
        
        guard let idToken = user.idToken?.tokenString else {
            showError("Cannot process your request. Code 1c")
            return
        }
        
        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken, accessToken: user.accessToken.tokenString
        )
        
        withAnimation(.easeInOut(duration: 0.2)){
            self.googleCreating = true
        }

        Auth.auth().signIn(with: credential) { result, _ in
            guard let user = result?.user else {
                showError("Cannot process your request. Code 1d")
                return
            }
            withAnimation(.easeInOut(duration: 0.2)){
                self.googleLoading = false
                self.googleCreating = false
                self.auth.userSession = user
            }
            self.auth.CreateUserOrFetch()
        }
    }
    func loadImage() {
        guard let selectedImage = selectedImage else { return }
        newImage = Image(uiImage: selectedImage)
    }
    func glitchTogg() {
        Task { toggleGlitch.toggle() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if selection == 0 {
                glitchTogg()
            }
        }
    }
    @ViewBuilder
    func createAccount() -> some View {
        VStack(spacing: 15){
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showPicker = true
            } label: {
                if let newImage {
                    newImage
                        .resizable()
                        .scaledToFill()
                        .frame(width: 120, height: 120)
                        .clipShape(Circle()).contentShape(Circle()).shadow(color: .gray, radius: 2)
                } else {
                    Image("AppIcon")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 120, height: 120)
                        .clipShape(Circle()).contentShape(Circle()).shadow(color: .gray, radius: 2)
                        .blur(radius: 12)
                        .overlay {
                            Image(systemName: "plus")
                                .font(.largeTitle)
                                .foregroundStyle(.white)
                        }
                }
            }.frame(height: 80).padding(.bottom)
            
            TextField("", text: $username)
                .lineLimit(1).autocorrectionDisabled()
                .focused($isUserEditing)
                .frame(height: 57)
                .padding(.top, 8)
                .overlay(alignment: .leading, content: {
                    Text("Pick a Username").font(.system(size: 18)).fontWeight(.light)
                        .foregroundStyle(colorScheme == .dark ? Color.white : Color.black)
                        .opacity(isUserEditing ? 0.8 : 0.5)
                        .offset(y: username.isEmpty && !isUserEditing ? 0.0 : -21.0)
                        .scaleEffect(username.isEmpty && !isUserEditing ? 1.0 : 0.8, anchor: .leading)
                        .animation(.easeInOut(duration: 0.2), value: isUserEditing)
                        .onTapGesture {
                            isUserEditing = true
                        }
                })
                .padding(.horizontal)
                .background {
                    TransparentBlurView(removeAllFilters: true)
                        .blur(radius: 10, opaque: true)
                        .background(colorScheme == .dark ? .black.opacity(0.5) : .white.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .overlay(content: {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(colorScheme == .dark ? Color.white : Color.black ,lineWidth: 1)
                        .opacity(isUserEditing ? 0.8 : 0.5)
                })
                .padding(.horizontal)
                .onChange(of: username) { _, _ in
                    usernameError = inputChecker().myInputChecker(withString: username, withLowerSize: 1, withUpperSize: 14, needsLower: true)
                    
                    if username == "WealthStaff" {
                        usernameError = "Username cannot be 'WealthStaff'"
                    } else if username.hasPrefix("@") {
                        usernameError = "Username cannot start with '@'"
                    }
                }
            
            let status = !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && usernameError.isEmpty && selectedImage != nil
            
            Button {
                if status && !createLoading {
                    withAnimation(.easeInOut(duration: 0.2)){
                        createLoading = true
                    }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    
                    if let selectedImage {
                        auth.uploadImage(image: selectedImage, location: "userPhotos", compression: 0.25) { im, _ in
                            UserService().editImageUsername(newURL: im, username: "@\(username)")
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                auth.registerHelper {
                                    withAnimation(.easeInOut(duration: 0.2)){
                                        createLoading = false
                                    }
                                }
                            }
                        }
                    }
                }
            } label: {
                ZStack {
                    Capsule()
                        .foregroundStyle(.clear)
                        .frame(height: 55)
                        .background {
                            TransparentBlurView(removeAllFilters: true)
                                .blur(radius: 10, opaque: true)
                                .background(.blue.opacity(0.8))
                                .clipShape(Capsule())
                        }
                        .shadow(color: .gray, radius: 5)

                    if createLoading {
                        LottieView(loopMode: .loop, name: "loading")
                            .frame(width: 45, height: 45).scaleEffect(0.3)
                    } else {
                        Text(usernameError.isEmpty ? "Done" : usernameError)
                            .font(.title3).bold()
                            .brightness(!usernameError.isEmpty ? -0.3 : 0.0)
                            .foregroundStyle(!usernameError.isEmpty ? .red : colorScheme == .dark ? .white : .black)
                    }
                }.opacity(status ? 1.0 : 0.7)
            }.padding(.horizontal)
        }
    }
    @ViewBuilder
    func emailField() -> some View {
        VStack(spacing: 15){
            TextField("", text: $email)
                .lineLimit(1).autocorrectionDisabled()
                .focused($isEditing)
                .frame(height: 57)
                .padding(.top, 8)
                .overlay(alignment: .leading, content: {
                    Text("Email").font(.system(size: 18)).fontWeight(.light)
                        .foregroundStyle(colorScheme == .dark ? Color.white : Color.black)
                        .opacity(isEditing ? 0.8 : 0.5)
                        .offset(y: email.isEmpty && !isEditing ? 0.0 : -21.0)
                        .scaleEffect(email.isEmpty && !isEditing ? 1.0 : 0.8, anchor: .leading)
                        .animation(.easeInOut(duration: 0.2), value: isEditing)
                        .onTapGesture {
                            isEditing = true
                        }
                })
                .padding(.horizontal)
                .background {
                    TransparentBlurView(removeAllFilters: true)
                        .blur(radius: 10, opaque: true)
                        .background(colorScheme == .dark ? .black.opacity(0.5) : .white.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .overlay(content: {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(colorScheme == .dark ? Color.white : Color.black ,lineWidth: 1)
                        .opacity(isEditing ? 0.8 : 0.5)
                })
                .padding(.horizontal)
                .onChange(of: email) { _, _ in
                    if !inputChecker().isValidEmail(email) {
                        emailError = "Enter a valid email"
                    } else {
                        emailError = ""
                    }
                }
            
            let status = !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && emailError.isEmpty
            
            Button {
                if !emailLoading && status {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.easeInOut(duration: 0.2)){
                        emailLoading = true
                    }
                    UserService().emailExists(email: email) { exists in
                        withAnimation(.easeInOut(duration: 0.2)){
                            emailLoading = false
                        }
                        if exists {
                            withAnimation(.easeInOut(duration: 0.2)){
                                selection = 2
                            }
                        } else {
                            withAnimation(.easeInOut(duration: 0.2)){
                                selection = 3
                            }
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            isPassEditing = true
                        }
                    }
                }
            } label: {
                ZStack {
                    Capsule()
                        .foregroundStyle(.clear)
                        .frame(height: 55)
                        .background {
                            TransparentBlurView(removeAllFilters: true)
                                .blur(radius: 10, opaque: true)
                                .background(.blue.opacity(0.8))
                                .clipShape(Capsule())
                        }
                        .shadow(color: .gray, radius: 5)
                    
                    if emailLoading {
                        LottieView(loopMode: .loop, name: "loading")
                            .frame(width: 45, height: 45).scaleEffect(0.3)
                    } else {
                        Text(emailError.isEmpty ? "Continue" : emailError)
                            .font(.title3).bold()
                            .brightness(!emailError.isEmpty ? -0.3 : 0.0)
                            .foregroundStyle(!emailError.isEmpty ? .red : colorScheme == .dark ? .white : .black)
                    }
                }.opacity(status ? 1.0 : 0.7)
            }.padding(.horizontal)
        }
    }
    @ViewBuilder
    func passwordField(createAcc: Bool) -> some View {
        VStack(spacing: 15){
            
            if !createAcc {
                HStack {
                    Spacer()
                    Button {
                        if !resettingPassword {
                            resettingPassword = true
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            auth.resetPassword(email: email) { success in
                                if success {
                                    popRoot.presentAlert(image: "checkmark", text: "Check you email!")
                                } else {
                                    popRoot.presentAlert(image: "exclamationmark.shield", text: auth.resetError)
                                }
                                resettingPassword = false
                            }
                        }
                    } label: {
                        Text("Forgot Password?")
                            .font(.subheadline)
                            .foregroundStyle(colorScheme == .dark ? .white : .black)
                    }
                }.padding(.horizontal)
            }
            
            SecureField("", text: $password)
                .lineLimit(1).autocorrectionDisabled()
                .focused($isPassEditing)
                .frame(height: 57)
                .padding(.top, 8)
                .overlay(alignment: .leading, content: {
                    Text(createAcc ? "Choose Password" : "Password").font(.system(size: 18)).fontWeight(.light)
                        .foregroundStyle(colorScheme == .dark ? Color.white : Color.black)
                        .opacity(isPassEditing ? 0.8 : 0.5)
                        .offset(y: password.isEmpty && !isPassEditing ? 0.0 : -21.0)
                        .scaleEffect(password.isEmpty && !isPassEditing ? 1.0 : 0.8, anchor: .leading)
                        .animation(.easeInOut(duration: 0.2), value: isPassEditing)
                        .onTapGesture {
                            isPassEditing = true
                        }
                })
                .padding(.horizontal)
                .background {
                    TransparentBlurView(removeAllFilters: true)
                        .blur(radius: 10, opaque: true)
                        .background(colorScheme == .dark ? .black.opacity(0.5) : .white.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .overlay(content: {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(colorScheme == .dark ? Color.white : Color.black ,lineWidth: 1)
                        .opacity(isPassEditing ? 0.8 : 0.5)
                })
                .padding(.horizontal)
                .onChange(of: password) { _, _ in
                    let pass = password.trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    if pass.isEmpty {
                        passwordError = ""
                    } else if pass.count < 8 {
                        passwordError = "Too short"
                    } else {
                        passwordError = ""
                    }
                }
            
            let status = !password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && passwordError.isEmpty
            
            Button {
                if !passLoading && status {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()

                    if createAcc {
                        showTerms = true
                    } else {
                        withAnimation(.easeInOut(duration: 0.2)){
                            passLoading = true
                        }
                        
                        auth.login(withEmail: email, password: password) { error in
                            if error.isEmpty {
                                if storedEmail != email || storedPass != password {
                                    self.save(email: email.lowercased(), password: password)
                                }
                                popRoot.presentAlert(image: "hand.wave", text: "Welcome back!")
                            } else {
                                popRoot.presentAlert(image: "exclamationmark.shield", text: error)
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                withAnimation(.easeInOut(duration: 0.2)){
                                    passLoading = false
                                }
                            }
                        }
                    }
                }
            } label: {
                ZStack {
                    Capsule()
                        .foregroundStyle(.clear)
                        .frame(height: 55)
                        .background {
                            TransparentBlurView(removeAllFilters: true)
                                .blur(radius: 10, opaque: true)
                                .background(.blue.opacity(0.8))
                                .clipShape(Capsule())
                        }
                        .shadow(color: .gray, radius: 5)
                    
                    if passLoading {
                        LottieView(loopMode: .loop, name: "loading")
                            .frame(width: 45, height: 45).scaleEffect(0.3)
                    } else {
                        Text(passwordError.isEmpty ? (createAcc ? "View terms" : "Login") : passwordError)
                            .font(.title3).bold()
                            .brightness(!passwordError.isEmpty ? -0.3 : 0.0)
                            .foregroundStyle(!passwordError.isEmpty ? .red : colorScheme == .dark ? .white : .black)
                    }
                }.opacity(status ? 1.0 : 0.7)
            }.padding(.horizontal)
        }
    }
    @ViewBuilder
    func actionButtons() -> some View {
        VStack(spacing: 15){
            Spacer()
            
            SignInWithAppleButton(.signIn) { request in
                let nonce = randomNonceString()
                self.nonce = nonce
                request.requestedScopes = [.email, .fullName]
                if let nonce {
                    request.nonce = sha256(nonce)
                }
            } onCompletion: { result in
                switch result {
                case .success(let authorization):
                    loginWithFirebase(authorization)
                case .failure(_):
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                }
            }
            .frame(height: 60).clipShape(Capsule())
            .overlay {
                ZStack {
                    Capsule()
                        .foregroundStyle(colorScheme == .dark ? .white : .black)
                        .frame(height: 60).shadow(color: .gray, radius: 6)
  
                    HStack(spacing: 7){
                        if appleLoading || appleCreating {
                            ProgressView().transition(.scale)
                        } else {
                            Image(systemName: "apple.logo")
                                .font(.title3)
                                .foregroundStyle(colorScheme == .dark ? .black : .white)
                                .transition(.scale)
                        }
                        
                        Text("Continue with Apple")
                            .font(.title3).bold()
                            .foregroundStyle(colorScheme == .dark ? .black : .white)
                    }
                }.allowsHitTesting(false)
            }
            .offset(x: googleLoading ? -400.0 : 0.0)

            Button {
                withAnimation(.easeInOut(duration: 0.3)){
                    googleLoading = true
                }
                Task {
                    defer {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            googleLoading = false
                        }
                    }
                    do {
                        try await googleOauth()
                        withAnimation(.easeInOut(duration: 0.3)){
                            googleLoading = false
                        }
                    } catch AuthenticationError.runtimeError(let errorMessage) {
                        showError(errorMessage)
                    }
                }
            } label: {
                ZStack {
                    Capsule()
                        .foregroundStyle(Color(red: 0.55, green: 0.75, blue: 1.0))
                        .frame(height: 60).shadow(color: .gray, radius: 8)
                    
                    HStack(spacing: 7){
                        if googleLoading || googleCreating {
                            ProgressView().transition(.scale).frame(width: 22, height: 22)
                        } else {
                            Image(colorScheme == .dark ? "gWhite" : "gBlack")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 22, height: 22)
                        }
                        
                        Text("Continue with Google")
                            .font(.title3).bold()
                            .foregroundStyle(colorScheme == .dark ? .white : .black)
                    }
                }
            }.offset(y: appleLoading ? 400.0 : 0.0)
            
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.easeInOut(duration: 0.2)){
                    selection = 1
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isEditing = true
                }
            } label: {
                ZStack {
                    Capsule()
                        .foregroundStyle(.clear)
                        .frame(height: 55)
                        .background {
                            TransparentBlurView(removeAllFilters: true)
                                .blur(radius: 10, opaque: true)
                                .background(colorScheme == .dark ? .black.opacity(0.5) : .white.opacity(0.5))
                                .clipShape(Capsule())
                        }
                        .shadow(color: .gray, radius: 5)
                    
                    Text("Email Login")
                        .font(.title3).bold()
                        .foregroundStyle(colorScheme == .dark ? .white : .black)
                }
            }
            .offset(y: appleLoading ? 400.0 : 0.0)
            .offset(x: googleLoading ? 400.0 : 0.0)
        }
        .transition(.move(edge: .bottom))
        .padding(.horizontal, 30)
    }
    func showError(_ message: String) {
        withAnimation(.easeInOut(duration: 0.3)){
            appleLoading = false
            googleLoading = false
        }
        errorMessage = message
        showAlert.toggle()
    }
    func loginWithFirebase(_ authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            withAnimation(.easeInOut(duration: 0.3)){
                appleLoading = true
            }
            
            guard let nonce else {
                showError("Cannot process your request. Code 2")
                return
            }
            guard let appleIDToken = appleIDCredential.identityToken else {
                showError("Cannot process your request. Code 3")
                return
            }
            guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                showError("Cannot process your request. Code 4")
                return
            }

            let credential = OAuthProvider.appleCredential(withIDToken: idTokenString,
                                                           rawNonce: nonce,
                                                           fullName: appleIDCredential.fullName)
            
            withAnimation(.easeInOut(duration: 0.2)){
                appleCreating = true
            }
            
            Auth.auth().signIn(with: credential) { (authResult, error) in
                if error != nil {
                    showError("Cannot process your request. Code 5 \(error?.localizedDescription ?? "")")
                } else if let user = authResult?.user {
                    withAnimation(.easeInOut(duration: 0.2)){
                        self.auth.userSession = user
                    }
                    self.auth.CreateUserOrFetch()
                }

                withAnimation(.easeInOut(duration: 0.2)){
                    appleLoading = false
                    appleCreating = false
                }
            }
        }
    }
    private func randomNonceString(length: Int = 32) -> String? {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            showError("Cannot process your request. Code 1")
            return nil
        }
        
        let charset: [Character] =
        Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        
        let nonce = randomBytes.map { byte in
            charset[Int(byte) % charset.count]
        }
        
        return String(nonce)
    }
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        
        return hashString
    }
    @ViewBuilder
    func topLogo() -> some View {
        VStack(spacing: 0){
            if selection == 0 {
                Spacer()
            }
            
            let size = (selection == 0) ? 200.0 : 100
            
            ZStack {
                HStack {
                    if (selection == 1 && !emailLoading) || (selection == 2 && !passLoading) || (selection == 3 && !passLoading){
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            
                            if selection == 1 {
                                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                isPassEditing = false
                            }
                            
                            if selection == 1 || selection == 2 {
                                withAnimation(.easeInOut(duration: 0.2)){
                                    selection -= 1
                                }
                            } else {
                                withAnimation(.easeInOut(duration: 0.2)){
                                    selection = 1
                                }
                            }
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.title3).fontWeight(.semibold)
                                .foregroundStyle(colorScheme == .dark ? .white : .black)
                                .padding(14)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }.transition(.scale)
                    }
                    Spacer()
                }.padding(.leading)
                
                Image("wealthLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
            }
            
            if selection == 0 {
                GlitchEffect(trigger: $toggleGlitch, text: "Wealth")
                    .font(.largeTitle).bold()
                    .foregroundStyle(.black)
                    .offset(y: -5).transition(.move(edge: .top).combined(with: .opacity))
            }
            
            Spacer()
        }
        .padding(.bottom, selection == 0 ? 160.0 : 0.0)
    }
    func save(email: String, password: String) {
        let passwordData = password.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "https://WealthAIO.com",
            kSecAttrAccount as String: email,
            kSecValueData as String: passwordData
        ]
        let saveStatus = SecItemAdd(query as CFDictionary, nil)
        if saveStatus == errSecDuplicateItem {
            update(email: email, password: password)
        }
    }
    func update(email: String, password: String) {
        if let result = read(service: "https://WealthAIO.com"){
            if result.0 == email {
                let query: [String: Any] = [
                    kSecClass as String: kSecClassGenericPassword,
                    kSecAttrService as String: "https://WealthAIO.com",
                    kSecAttrAccount as String: email
                ]
                let passwordData = password.data(using: .utf8)!
                let updatedData: [String: Any] = [
                    kSecValueData as String: passwordData
                ]
                
                SecItemUpdate(query as CFDictionary, updatedData as CFDictionary)
            } else {
                delete(email: result.0)
                save(email: email, password: password)
            }
        }
    }
    func delete(email: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "https://WealthAIO.com",
            kSecAttrAccount as String: email
        ]
        SecItemDelete(query as CFDictionary)
    }
    func read(service: String) -> (String, String)? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnAttributes as String: true,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess, let item = result as? [String: Any] {
            if let account = item[kSecAttrAccount as String] as? String,
               let passwordData = item[kSecValueData as String] as? Data,
               let password = String(data: passwordData, encoding: .utf8) {
               return (account, password)
            }
        }
        return nil
    }
    func authenticate() {
        let context = LAContext()
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            let reason = "Secure Authentication."

            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, authenticationError in
                DispatchQueue.main.async {
                    if success {
                        if let loginInfo = self.read(service: "https://WealthAIO.com") {
                            let (email, password) = loginInfo
                            self.email = email
                            self.password = password
                            self.storedEmail = email
                            self.storedPass = password
                        }
                    }
                }
            }
        }
    }
    @ViewBuilder
    func termsView() -> some View {
        VStack(alignment: .leading){
            Text("Review and Agree to Terms").font(.title).bold()
            ScrollView {
                VStack {
                    Text("We are committed to maintaining a safe and respectful community for all users. We have a zero-tolerance policy for objectionable content and abusive behavior. Any content or actions that promote hate speech, harassment, discrimination, or any form of harm towards others will not be tolerated. Violation of these guidelines may result in the immediate suspension or termination of your account.").bold().padding(2).background(.yellow.opacity(0.2))
                    
                    Text("\nBy registering a Wealth account or utilizing the platform and our products, you implicitly consent to abide by these terms and conditions. ARBITRATION NOTICE: By agreeing to our Terms of Use and Privacy Policy, you recognize that any disputes between you and our organization will be settled exclusively through individual arbitration. Furthermore, you relinquish your entitlement to initiate a collective legal action or participate in arbitration on behalf of a collective.")
                    
                    HStack {
                        Text("About Our Service:").bold().font(.system(size: 19))
                        Spacer()
                    }.padding(.top, 8)
                    
                    Text("\nTo ensure the efficient operation of our Service, it is crucial for us to store, transfer, and manage data across our global systems. Our Privacy Policy offers detailed information on how you can maintain control over your data. The words “we,” “us,” and “our” refer to HUSTLER INC LLC. Your utilization and engagement with the Services or any Content entail risks that you assume responsibility for. You acknowledge and consent that the Services are made accessible to you in their present state (“AS IS”) and availability, without any warranties or guarantees.")
                }
                VStack {
                    HStack {
                        Text("Your Commitments:\n").bold().font(.system(size: 19))
                        Spacer()
                    }.padding(.top, 8)
                    
                    Text("By using any of our services you acknowledge the following commitments you make to us.\n\n1. Your account must not have been previously disabled and/or deleted by us due to infringements of the law or our policy.\n\n2. Wealth strictly prohibits certain actions, including assuming false identities, supplying inaccurate information, or establishing an account on behalf of another individual without their explicit consent. While revealing your identity is not obligatory to fulfill your obligations to us, it is essential to note that impersonating someone or misrepresenting your true identity is strictly forbidden.\n\n3. Participating in unlawful or unauthorized activities is strictly forbidden. This encompasses any violation of our Terms and policies. If you come across explicit or illegal content, please reach out to us.\n\n4. Engaging in actions that interfere with or disrupt the proper operation of the Wealth platform is strictly prohibited. This includes any form of misuse of our designated services, such as submitting fraudulent or unsubstantiated claims through our contact page.\n\n5. Engaging in unauthorized methods to establish accounts, access, or gather information is strictly prohibited. This encompasses the automated generation of accounts. You are granted permission to view, share, and engage with the content presented to you. However, the deliberate collection of data displayed on our service is strictly forbidden.\n\n6. Participating in the sale, licensing, or acquisition of any accounts or data sourced from us or our Service is strictly prohibited. This includes all attempts to engage in buying, selling, or transferring any portion of your account, as well as soliciting or collecting login credentials or Tools from fellow users. Additionally, requesting or gathering Wealth usernames or passwords is strictly forbidden.\n\n7. Sharing private or confidential information of others without permission or engaging in activities that infringe upon someone else’s rights, including intellectual property rights, is strictly prohibited. However, you may make use of someone else’s works within the exceptions or limitations to copyright and related rights as outlined by applicable law. By sharing content, you confirm that you either own the content or have obtained all the requisite rights to publish or distribute it.\n\n8. By using our platform’s content uploading feature, you hereby acknowledge and consent to refrain from posting any material that contains nudity, pornography, profanity, or any content contravening the stipulations outlined within these terms of service.")
                    
                    HStack {
                        Text("Permissions You Give to Wealth:\n").bold().font(.system(size: 19))
                        Spacer()
                    }.padding(.top, 8)
                    
                    Text("Although we do not assert ownership of the content you publish on our Service, we do require a license from you to utilize it. Your rights to your content remain intact and unaffected. You possess the liberty to share your content with anyone, anywhere, as we do not lay claim to its ownership. Nevertheless, to deliver the Service, we necessitate specific legal permissions from you, commonly known as a “license.”\n\nWhen you share, post, or upload intellectual property-protected content on or via our Service, you provide us with a worldwide license that is non-exclusive, royalty-free, transferable, and sub-licensable. This license empowers us to store, utilize, distribute, modify, delete, copy, display, translate, and share your content, all while upholding your privacy. However, once your content is deleted from our systems, this license will no longer remain in effect.\n\nAdditionally, you consent to the installation of updates to our Service on your device. In specific situations, we reserve the right to modify your selected username or identifier for your account if we deem it necessary. This action may be taken, for instance, if it violates someone’s intellectual property rights, impersonates another user, or contains explicit content.\n\nEngaging in the act of altering, generating imitative works from, decompiling, or extracting source code from our platform and products is strictly prohibited.")
                    
                    HStack {
                        Text("Additional Provisions:\n").bold().font(.system(size: 19))
                        Spacer()
                    }.padding(.top, 8)
                    
                    Text("In the event that we ascertain that the content or information you contribute to the Service violates our Terms of Use or policies, or if we are legally authorized or obligated to take action, we maintain the prerogative to eliminate said content or information. Additionally, we possess the right to refuse the provision or suspend any part or the entirety of the Service to you indefinitely. It is your responsibility to ensure the security of your account by employing a robust password and restricting its usage solely to this particular account. Any loss or damage resulting from your failure to adhere to the aforementioned guidelines is beyond our liability and we cannot be held accountable for it. In light of the fact that our platform incorporates the display of YouTube videos, it is imperative that you concomitantly provide your consent to be bound by the Terms of Service and Privacy Policy of YouTube. Our platform provides a service to view asset price data and information, and such data may be incorrect or delayed. Do not use our asset price data to influence your asset management; always visit a trusted data provider to get an up-to-date overview of your assets. We hold no responsibility of incorrect asset data displayed to you through our service as our platform is distributed “As Is.”")
                    
                    HStack {
                        Text("Misuse of Services:\n").bold().font(.system(size: 19))
                        Spacer()
                    }.padding(.top, 8)
                    
                    Text("Our Tools and Services are designed to facilitate the purchase of products from various online retailers. In utilizing these tools and services, users are required to adhere strictly to the rules, regulations, and policies set forth by the retailers. Compliance with these stipulations is mandatory, and any deviation or violation of these retailer policies by any user will result in the immediate termination of their account and associated services. Additionally, all active subscriptions will be rendered null and void, and no refunds will be issued under these circumstances. Furthermore, it is important to note that certain products may be governed by specific rules and provisions imposed by the retailers. Users bear the sole responsibility for conducting thorough research and acquiring a comprehensive understanding of all applicable rules and policies prior to using our service. This proactive approach ensures adherence to all regulatory requirements and facilitates a seamless transactional experience.")
                }
                
                VStack {
                    HStack {
                        Text("How Disputes are Handled:\n").bold().font(.system(size: 19))
                        Spacer()
                    }.padding(.top, 8)
                    
                    Text("By making use of our services or products, you acknowledge and accept that any legal claim or dispute arising from or related to these Terms must be resolved exclusively through individual arbitration. Group actions and collective arbitrations are explicitly prohibited. Should you choose to delete your account, it will result in the termination of these terms and agreements between us.")
                    
                    HStack {
                        Text("Changing our Terms and Policies:\n").bold().font(.system(size: 19))
                        Spacer()
                    }.padding(.top, 8)
                    
                    Text("We maintain the authority to alter our Service and regulations, as it may become essential for us to adjust these Terms in accordance with our progressing Service and regulations. Prior to implementing any modifications to these Terms, we will furnish you with advanced notification. You will be given the chance to assess the revised Terms before they take effect. By choosing to continue utilizing the Service thereafter, you signify your consent to the updated Terms. Nevertheless, if you do not desire to consent to these modified Terms, you have the alternative to delete your account.")
                    
                    HStack {
                        Text("Terms and conditions of purchase:\n").bold().font(.system(size: 19))
                        Spacer()
                    }.padding(.top, 8)
                    Text("Please be advised that you bear full responsibility for all fees, charges, and expenses related to the utilization of the Services and Content provided by Hustler Inc LLC. In this regard, you hereby grant explicit authorization to Hustler Inc LLC to charge your card for any and all charges and fees accrued in connection with the aforementioned Services or Content. Furthermore, you hereby consent to the retention of your credit card information by Hustler Inc LLC for the duration necessary to fulfill all your payment obligations. It is essential to note that payments pertaining to Wealth Tools are non-refundable and non-reversible. In the event that you opt to promote posts through our platform, it is imperative that any associated promoted content adheres strictly to our Terms of Service and refrains from infringing upon the rights of any individual or entity. Should such promoted content be found in violation of our terms or the rights of any party, Hustler Inc LLC reserves the right to promptly delete said content without any entitlement to a refund. By making a purchase on our platform, you explicitly acknowledge your acceptance and agreement to abide by our Purchasers Terms, thereby binding yourself to the stated terms and conditions.").padding(.bottom, 50)
                }
            }.font(.system(size: 16)).scrollIndicators(.hidden)
            Button {
                showTerms = false
                
                withAnimation(.easeInOut(duration: 0.2)){
                    passLoading = true
                }
                
                auth.register(withEmail: email, password: password) { success in
                    if success {
                        save(email: email.lowercased(), password: password)
                        withAnimation(.easeInOut(duration: 0.2)){
                            selection = 4
                        }
                    } else {
                        popRoot.presentAlert(image: "exclamationmark.shield", text: auth.registerError)
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        withAnimation(.easeInOut(duration: 0.2)){
                            passLoading = false
                        }
                    }
                }
            } label: {
                ZStack {
                    Rectangle().fill(.blue.gradient)
                    Text("Agree to Terms").bold().font(.system(size: 18)).foregroundStyle(.white)
                }
            }.padding(.horizontal).frame(height: 40)
        }.padding()
    }
}
