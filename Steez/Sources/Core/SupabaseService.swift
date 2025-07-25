import Foundation
import Supabase

class SupabaseService {
    static let shared = SupabaseService()

    let client: SupabaseClient

    private init() {
        guard let supabaseURLString = ProcessInfo.processInfo.environment["SUPABASE_URL"],
              let supabaseAnonKey = ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"],
              let supabaseURL = URL(string: supabaseURLString) else {
            fatalError("Could not load Supabase credentials. Make sure SUPABASE_URL and SUPABASE_ANON_KEY environment variables are set in your Xcode scheme.")
        }
        
        self.client = SupabaseClient(supabaseURL: supabaseURL, supabaseKey: supabaseAnonKey)
    }

    func signUp(email: String, password: String) async throws {
        try await client.auth.signUp(
            email: email, 
            password: password,
            redirectTo: URL(string: "steez://auth-callback")
        )
    }

    func signIn(email: String, password: String) async throws {
        try await client.auth.signIn(email: email, password: password)
    }

    func signOut() async throws {
        try await client.auth.signOut()
    }
    
    func session() async throws -> Session {
        return try await client.auth.session
    }
    
    func listenToAuthEvents() -> AsyncStream<(event: AuthChangeEvent, session: Session?)> {
        return client.auth.authStateChanges
    }

    // MARK: - Social Logins
    
    func signInWithApple(idToken: String, nonce: String) async throws {
        try await client.auth.signInWithIdToken(
            credentials: .init(
                provider: .apple,
                idToken: idToken,
                nonce: nonce
            )
        )
    }
    
    func signInWithGoogle(idToken: String) async throws {
        try await client.auth.signInWithIdToken(
            credentials: .init(
                provider: .google,
                idToken: idToken,
                nonce: nil // Nonce is not typically required for Google Sign-In with Supabase
            )
        )
    }

    // MARK: - Password Recovery
    
    func sendPasswordReset(for email: String) async throws {
        try await client.auth.resetPasswordForEmail(
            email,
            redirectTo: URL(string: "steez://auth-callback?type=recovery")
        )
    }
    
    func deleteUser() async throws {
        // Ensure we have a current session (throws if none)
        let _ = try await client.auth.session // force evaluation; we don't actually need the object here

        let supabaseURLString = ProcessInfo.processInfo.environment["SUPABASE_URL"] ?? "https://owbkldgydzokcdjhmvju.supabase.co"
        print("🔍 About to call: \(supabaseURLString)/functions/v1/delete-account")
        
        // Call Supabase Edge Function named "delete-account" to remove all user data server-side
        _ = try await client.functions.invoke("delete-account")

        // After backend deletion, sign out locally.
        try await client.auth.signOut()
    }
} 
 
