import Firebase
import FirebaseAuth

struct UserService {
    let db = Firestore.firestore()
    
    func updateUseResiToUpdate(shouldUse: Bool){
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        if !uid.isEmpty {
            db.collection("users").document(uid).updateData(["useResiToUpdate": shouldUse]) { _ in }
        }
    }
    func updateDiscordInfo(username: String, discordUid: String){
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        if !uid.isEmpty {
            db.collection("users").document(uid)
                .updateData(["discordUsername": username,
                             "discordUID": discordUid
                            ]) { _ in }
        }
    }
    func updateSize(size: String, field: String){
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        if !uid.isEmpty {
            db.collection("users").document(uid).updateData([field: size]) { _ in }
        }
    }
    func updateSold(field: String){
        if !field.isEmpty {
            db.collection("toolSoldCount").document("count")
                .updateData([field: FieldValue.increment(Int64(1))]) { _ in }
        }
    }
    func getSoldQuantiites(completion: @escaping(SoldQuantities?) -> Void){
        db.collection("toolSoldCount")
            .document("count")
            .getDocument { snapshot, _ in
                guard let snapshot = snapshot else {
                    completion(nil)
                    return
                }
                guard let sold = try? snapshot.data(as: SoldQuantities.self) else {
                    completion(nil)
                    return
                }
                completion(sold)
            }
    }
    func getLeaderboardUsers(lowest: Double?, completion: @escaping([User]) -> Void) {
        var query = db.collection("users")
                        .order(by: "checkoutTotal", descending: true)
                        .limit(to: 45)
        
        if let lowest {
            query = db.collection("users")
                        .whereField("checkoutTotal", isLessThan: lowest)
                        .order(by: "checkoutTotal", descending: true)
                        .limit(to: 45)
        }
        
        query.getDocuments { snapshot, _ in
            guard let documents = snapshot?.documents else {
                completion([])
                return
            }
            let users = documents.compactMap({ try? $0.data(as: User.self)} )
            completion(users)
        }
    }
    func getRandomVal(completion: @escaping(String) -> Void){
        db.collection("Random")
            .document("Random")
            .getDocument { snapshot, _ in
                guard let snapshot = snapshot else {
                    completion("")
                    return
                }
                guard let randomVal = try? snapshot.data(as: RandomString.self) else {
                    completion("")
                    return
                }
                completion(randomVal.random)
            }
    }
    func BotInStock(completion: @escaping(Bool) -> Void){
        db.collection("InStock")
            .document("InStock")
            .getDocument { snapshot, _ in
                guard let snapshot = snapshot else {
                    completion(true)
                    return
                }
                guard let isInStock = try? snapshot.data(as: InStock.self) else {
                    completion(true)
                    return
                }
                completion(isInStock.InStock)
            }
    }
    func joinWaitlist(email: String) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        let data = ["email": email,
                    "uid": uid,
                    "timestamp": Timestamp(date: Date())] as [String : Any]
        
        db.collection("Waitlist").document().setData(data) { _ in }
    }
    func addToolAccess(tool: String){
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        if !uid.isEmpty {
            db.collection("users").document(uid)
                .updateData(["unlockedTools": FieldValue.arrayUnion([tool])]) { _ in }
        }
    }
    func resetKey(completion: @escaping(String?) -> Void){
        guard let uid = Auth.auth().currentUser?.uid else {
            completion(nil)
            return
        }
        
        if !uid.isEmpty {
            let newKey = UUID().uuidString
            
            db.collection("users").document(uid)
                .updateData(["botKey": newKey]) { error in
                    if error != nil {
                        completion(nil)
                    } else {
                        completion(newKey)
                        
                        let data = ["newToken": newKey] as [String : Any]
                        
                        db.collection("users").document(uid).collection("events")
                            .document("token\(UUID().uuidString)").setData(data) { _ in }
                    }
                }

        } else {
            completion(nil)
        }
    }
    func editAutoPush(value: Bool){
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        if !uid.isEmpty {
            db.collection("users").document(uid).updateData(["disableAutoPush": !value]) { _ in }
        }
    }
    func resetPhoneIP(){
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        if !uid.isEmpty {
            db.collection("users").document(uid).updateData(["connectedMobileIP": ""]) { _ in }
        }
    }
    func setPhoneIP(id: String){
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        if !uid.isEmpty {
            db.collection("users").document(uid).updateData(["connectedMobileIP": id]) { _ in }
        }
    }
    func resetServerIP(hasScale: Bool){
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        if !uid.isEmpty {
            if hasScale {
                db.collection("users").document(uid).updateData([
                    "connectedServerIP": "",
                    "connectedServerIPExtra": [String]()
                ]) { _ in }
            } else {
                db.collection("users").document(uid).updateData(["connectedServerIP": ""]) { _ in }
            }

            db.collection("users").document(uid).collection("events")
                .document("session\(UUID().uuidString)").setData([:]) { _ in }
        }
    }
    func verifyPurchase(email: String, itemBought: String) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        let data = ["itemBought": itemBought,
                    "emailVerified": email,
                    "uid": uid,
                    "timestamp": Timestamp(date: Date())] as [String : Any]
        
        db.collection("Paid").document().setData(data) { _ in }
    }
    func uploadPurchase(email: String, itemBought: String) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        let data = ["itemBought": itemBought,
                    "email": email,
                    "uid": uid,
                    "timestamp": Timestamp(date: Date())] as [String : Any]
        
        db.collection("Paid").document().setData(data) { _ in }
    }
    func newestAlertSeen(date: Timestamp){
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        if !uid.isEmpty {
            db.collection("users").document(uid).updateData(["newestAlert": date]) { _ in }
        }
    }
    func newestCheckoutSeen(date: Timestamp){
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        if !uid.isEmpty {
            db.collection("users").document(uid).updateData(["newestCheckout": date]) { _ in }
        }
    }
    func uploadQuestion(email: String, reason: String, desc: String) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        let data = ["reason": reason,
                    "description": desc,
                    "email": email,
                    "uid": uid,
                    "timestamp": Timestamp(date: Date())] as [String : Any]
        
        db.collection("Help").document().setData(data) { _ in }
    }
    func editInfoStatus(hasAccess: Bool){
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        if !uid.isEmpty {
            db.collection("users").document(uid).updateData(["hasInfoAccess": hasAccess]) { _ in }
        }
    }
    func editUserToken(token: String){
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        if !uid.isEmpty {
            db.collection("users").document(uid).updateData(["notificationToken": token]) { _ in }
        }
    }
    func editImageUsername(newURL: String, username: String){
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        if !uid.isEmpty {
            db.collection("users").document(uid)
                .updateData(["profileImageUrl": newURL,
                             "username": username
                            ]) { _ in }
        }
    }
    func editUsername(username: String){
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        if !uid.isEmpty {
            db.collection("users").document(uid).updateData(["username": username]) { _ in }
        }
    }
    func editImage(newURL: String){
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        if !uid.isEmpty {
            db.collection("users").document(uid).updateData(["profileImageUrl": newURL]) { _ in }
        }
    }
    func emailExists(email: String, completion: @escaping(Bool) -> Void){
        if !email.isEmpty {
            let lower_email = email.lowercased()
            
            db.collection("users")
                .whereField("email", isEqualTo: lower_email).limit(to: 1)
                .getDocuments { snapshot, _ in
                    guard let documents = snapshot?.documents else {
                        completion(false)
                        return
                    }
                    let user = documents.compactMap({ try? $0.data(as: User.self)} ).first
                    
                    if user == nil {
                        completion(false)
                    } else {
                        completion(true)
                    }
                }
        } else {
            completion(false)
        }
    }
    func fetchSafeUser(withUid uid: String, completion: @escaping(User?) -> Void){
        if !uid.isEmpty {
            db.collection("users")
                .document(uid)
                .getDocument { snapshot, _ in
                    guard let snapshot = snapshot else {
                        completion(nil)
                        return
                    }
                    guard let user = try? snapshot.data(as: User.self) else {
                        completion(nil)
                        return
                    }
                    completion(user)
                }
        } else {
            completion(nil)
        }
    }
    func verifyUser(withUid uid: String, completion: @escaping(Bool) -> Void){
        if !uid.isEmpty {
            db.collection("users").document(uid)
                .getDocument { snapshot, _ in
                    guard snapshot != nil else {
                        completion(false)
                        return
                    }
                    completion(true)
                }
        } else {
            completion(false)
        }
    }
    func fetchUserWithRedo(withUid uid: String, completion: @escaping(User?) -> Void){
        if !uid.isEmpty {
            db.collection("users")
                .document(uid)
                .getDocument { snapshot, _ in
                    if let snapshot = snapshot, let user = try? snapshot.data(as: User.self) {
                        completion(user)
                    } else {
                        db.collection("users")
                            .document(uid)
                            .getDocument { snapshot, _ in
                                guard let snapshot = snapshot else {
                                    completion(nil)
                                    return
                                }
                                guard let user = try? snapshot.data(as: User.self) else {
                                    completion(nil)
                                    return
                                }
                                completion(user)
                            }
                        
                    }
                }
        } else {
            completion(nil)
        }
    }
}
