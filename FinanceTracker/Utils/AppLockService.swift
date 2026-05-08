import Foundation
import Combine
import LocalAuthentication
import AppKit

/// Local-only app lock. Uses LocalAuthentication (Touch ID, Apple Watch,
/// or system password) to gate the UI on launch. No data is encrypted —
/// the SwiftData store remains the same plaintext sqlite. This is a
/// shoulder-surf protection, not a cryptographic safe.
@MainActor
final class AppLockGate: ObservableObject {
    @Published var isLocked: Bool

    init(initiallyLocked: Bool) {
        self.isLocked = initiallyLocked
    }

    /// Returns true when the device can prompt for authentication.
    static var available: Bool {
        let ctx = LAContext()
        var err: NSError?
        return ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &err)
    }

    /// Prompts for Touch ID / password. On success unlocks the gate. On
    /// failure leaves it locked; caller can retry. If the device cannot
    /// evaluate any policy (e.g. no Touch ID, no password set on a Mac
    /// signed in via auto-login), the gate fails open to avoid lockout.
    func authenticate(reason: String) async {
        let ctx = LAContext()
        ctx.localizedCancelTitle = "Cancel"
        var err: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &err) else {
            // No auth method available — don't lock the user out of their data.
            isLocked = false
            return
        }
        do {
            let ok = try await ctx.evaluatePolicy(.deviceOwnerAuthentication,
                                                  localizedReason: reason)
            if ok { isLocked = false }
        } catch {
            // Stay locked. User can retry via the Unlock button.
        }
    }
}
