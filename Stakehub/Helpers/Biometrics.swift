import LocalAuthentication

enum Biometrics {
    static func authenticate(
        reason: String = "Unlock Stakehub",
        completion: @escaping (Bool) -> Void
    ) {
        let ctx = LAContext()
        ctx.localizedCancelTitle = "Cancel"
        var error: NSError?

        if ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            ctx.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { ok, err in
                DispatchQueue.main.async {
                    if ok {
                        completion(true)
                    } else {
                        // If Face ID is temporarily locked or the system canceled,
                        // fall back to passcode to re-enable biometry.
                        if let laErr = err as? LAError,
                           laErr.code == .biometryLockout || laErr.code == .appCancel || laErr.code == .systemCancel {
                            fallbackToPasscode(reason: reason, completion: completion)
                        } else {
                            fallbackToPasscode(reason: reason, completion: completion)
                        }
                    }
                }
            }
            return
        }

        fallbackToPasscode(reason: reason, completion: completion)
    }


    private static func fallbackToPasscode(reason: String, completion: @escaping (Bool) -> Void) {
        let ctx = LAContext()
        var e: NSError?

        // ✅ check .deviceOwnerAuthentication (not the biometrics variant)
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &e) else {
            DispatchQueue.main.async { completion(false) }
            return
        }
        ctx.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { ok, _ in
            DispatchQueue.main.async { completion(ok) }
        }
    }
}
