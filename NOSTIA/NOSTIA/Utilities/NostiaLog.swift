import Foundation

/// Diagnostic logging that cannot reach a shipped build (security audit D12.5:
/// "no tokens or photo data in device logs; verbose logging disabled in release
/// builds"). Bare `print` was the previous pattern and it survives into release,
/// where anyone with a cable and Console.app reads it — the Stripe PaymentSheet
/// path in particular used to dump a whole `NSError.userInfo`, which carries
/// payment-intent identifiers and server messages.
///
/// The message is an `@autoclosure`, so in a release build the interpolation is
/// never even evaluated: no string is built, nothing is emitted. Anything that
/// genuinely needs to be visible in production belongs in a server-side log
/// with an actor and a timestamp (D14.1), not here.
nonisolated enum NostiaLog {
    static func debug(_ category: String, _ message: @autoclosure () -> String) {
        #if DEBUG
        print("[\(category)] \(message())")
        #endif
    }

    /// Same guarantee as `debug`; a separate name so grepping for real failure
    /// sites stays possible.
    static func error(_ category: String, _ message: @autoclosure () -> String) {
        #if DEBUG
        print("[\(category)] ERROR \(message())")
        #endif
    }
}
