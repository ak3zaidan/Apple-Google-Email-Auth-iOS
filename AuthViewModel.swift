import SwiftUI
import GoogleSignIn
import FirebaseAuth
import FirebaseStorage
import FirebaseFirestore
import LocalAuthentication
import AuthenticationServices

class AuthViewModel: ObservableObject {
    private let service = UserService()
    private var tempUserSession: FirebaseAuth.User?
    @Published var userSession: FirebaseAuth.User?
    @Published var currentUser: User?
    @Published var resetError: String = ""
    @Published var registerError: String = ""
    @Published var possibleInstances = [String]()
    var verifierUserNames: [String] = []
    var subbedToInfoTopic: Bool = false
    
    init(){
        self.userSession = Auth.auth().currentUser
        self.fetchUser { }
    }
    
    func login(withEmail email: String, password: String, completion: @escaping(String) -> Void){
        if !email.isEmpty && !password.isEmpty {
            Auth.auth().signIn(withEmail: email, password: password){ result, error in
                if let error = error {
                    if error.localizedDescription.contains("The email address is badly formatted") {
                        completion("The email address is badly formatted")
                    } else if error.localizedDescription.contains("password is invalid") {
                        completion("incorrect password or email")
                    } else if error.localizedDescription.contains("no user record corresponding") {
                        completion("We could not find your account")
                    } else {
                        completion("An error occured")
                    }
                    return
                }
                guard let user = result?.user else {
                    completion("An error occured")
                    return
                }
                completion("")
                withAnimation(.easeInOut(duration: 0.2)){
                    self.userSession = user
                }
                self.fetchUser { }
            }
        } else {
            completion("incorrect password or email")
        }
    }
    func register(withEmail email: String, password: String, completion: @escaping(Bool) -> Void){
        self.registerError = ""
        Auth.auth().createUser(withEmail: email.lowercased(), password: password){ result, error in
            if let error = error {
                if error.localizedDescription.contains("email address is already in use") {
                    self.registerError = "email address is already in use"
                } else {
                    self.registerError = "An error occured, try again later"
                }
                completion(false)
                return
            }
            
            guard let user = result?.user else {
                self.registerError = "An error occured, try again later"
                completion(false)
                return
            }
            self.tempUserSession = user
            
            let arr = [String]()
            
            let data = ["email": email.lowercased(),
                        "username": "@user\(UUID().uuidString.prefix(6))",
                        "userSince": Timestamp(date: Date()),
                        "profileImageUrl": "",
                        "checkoutCount": 0,
                        "checkoutTotal": 0.0,
                        "botKey": UUID().uuidString,
                        "connectedServerIP": "",
                        "connectedMobileIP": "",
                        "hasBotAccess": false,
                        "hasInfoAccess": false,
                        "unlockedTools": arr] as [String : Any]
            
            Firestore.firestore().collection("users")
                .document(user.uid)
                .setData(data){ error in
                    if error != nil {
                        self.service.verifyUser(withUid: user.uid) { bool in
                            if bool {
                                completion(true)
                            } else {
                                Firestore.firestore().collection("users").document(user.uid)
                                    .setData(data){ error in
                                        if error != nil {
                                            completion(false)
                                            self.registerError = "An error occured, try again later"
                                        } else {
                                            completion(true)
                                        }
                                    }
                                
                            }
                        }
                    } else {
                        completion(true)
                    }
                }
        }
    }
    func registerHelper(completion: @escaping() -> Void){
        withAnimation(.easeInOut(duration: 0.2)){
            self.userSession = self.tempUserSession
        }
        self.fetchUser {
            completion()
        }
    }
    func signOut(){
        DispatchQueue.main.async {
            self.currentUser = nil
            self.userSession = nil
            GIDSignIn.sharedInstance.signOut()
            try? Auth.auth().signOut()
        }
    }
    func CreateUserOrFetch() {
        if let email = self.userSession?.email, !email.isEmpty {
            service.emailExists(email: email) { exists in
                if exists {
                    self.fetchUser { }
                } else if let uid = self.userSession?.uid {
                    let arr = [String]()
                    
                    let data = ["email": email,
                                "username": "@user\(UUID().uuidString.prefix(6))",
                                "userSince": Timestamp(date: Date()),
                                "profileImageUrl": "",
                                "checkoutCount": 0,
                                "checkoutTotal": 0.0,
                                "botKey": UUID().uuidString,
                                "connectedServerIP": "",
                                "connectedMobileIP": "",
                                "hasBotAccess": false,
                                "hasInfoAccess": false,
                                "unlockedTools": arr] as [String : Any]

                    Firestore.firestore().collection("users")
                        .document(uid)
                        .setData(data){ error in
                            if error != nil {
                                self.service.verifyUser(withUid: uid) { bool in
                                    if !bool {
                                        Firestore.firestore().collection("users").document(uid).setData(data){ err in
                                            if error == nil {
                                                self.fetchUser { }
                                            }
                                        }
                                    } else {
                                        self.fetchUser { }
                                    }
                                }
                            } else {
                                self.fetchUser { }
                            }
                        }
                }
            }
        }
    }
    func fetchUser(completion: @escaping() -> Void){
        guard let uid = self.userSession?.uid else { return }
        service.fetchUserWithRedo(withUid: uid) { user in
            if let user {
                self.currentUser = user
                completion()
            } else {
                self.service.fetchSafeUser(withUid: uid) { optional_user in
                    if let optional_user {
                        self.currentUser = optional_user
                        completion()
                    }
                }
            }
        }
    }
    func resetPassword(email: String, completion: @escaping(Bool) -> Void){
        Auth.auth().sendPasswordReset(withEmail: email) { error in
            if let error = error {
                if error.localizedDescription.contains("The email address is badly formatted") {
                    self.resetError = "The email address is badly formatted"
                } else if error.localizedDescription.contains("no user record corresponding") {
                    self.resetError = "We could not find your account"
                } else {
                    self.resetError = "An error occured, try again later"
                }
                completion(false)
            } else {
                completion(true)
            }
        }
    }
    func checkUserNameInUse(username: String, completion: @escaping(Bool) -> Void){
        if verifierUserNames.contains(username){
            completion(true)
        } else {
            Firestore.firestore().collection("users")
                .whereField("username", isEqualTo: username.lowercased()).limit(to: 1)
                .getDocuments { snapshot, _ in
                    guard let documents = snapshot?.documents else { return }
                    if documents.isEmpty {
                        self.verifierUserNames.append(username.lowercased())
                        completion(true)
                    } else {
                        completion(false)
                    }
                }
        }
    }
    func uploadImage(image: UIImage, location: String, compression: Double, completion: @escaping(String, Bool) -> Void){
        guard let imageData = image.jpegData(compressionQuality: compression) else {
            completion("", false)
            return
        }
        
        let filename = NSUUID().uuidString
        let ref = Storage.storage().reference(withPath: "/\("userImages")/\(location)/\(filename)")
    
        ref.putData(imageData, metadata: nil) { _, error in
            if error != nil {
                completion("", false)
                return
            }
            ref.downloadURL { imageUrl, _ in
                guard let imageUrl = imageUrl?.absoluteString else {
                    completion("", false)
                    return
                }
                completion(imageUrl, true)
            }
        }
    }
}
