import SwiftUI
import SerpApi

struct ProfileView: View {
    @AppStorage("serpapi_key") var apiKey: String = ""
    @State private var accountInfo: AccountInfo?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showAPIKey = false
    @State private var isEditingAPIKey = false
    @State private var draftAPIKey = ""
    
    struct AccountInfo: Codable {
        let email: String
        let plan: String
        let searches_left: Int
        
        init?(dict: [String: Any]) {
            self.email = dict["account_email"] as? String ?? ""
            self.plan = dict["plan_name"] as? String ?? ""
            
            var left = dict["searches_per_month"] as? Int ?? 0
            if let planLeft = dict["plan_searches_left"] as? Int {
                left = planLeft
            }
            self.searches_left = left
        }
    }
    
    var body: some View {
        Form {
            Section(header: Text("API Key")) {
                if apiKey.isEmpty || isEditingAPIKey {
                    SecureField("Enter your SerpApi Key", text: $draftAPIKey)
                        #if os(iOS)
                        .autocapitalization(.none)
                        .textContentType(.password)
                        #endif

                    HStack {
                        Button(apiKey.isEmpty ? "Save Key" : "Update Key") {
                            apiKey = draftAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
                            isEditingAPIKey = false
                            showAPIKey = false
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(draftAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                        if !apiKey.isEmpty {
                            Button("Cancel") {
                                isEditingAPIKey = false
                                draftAPIKey = apiKey
                            }
                        }
                    }
                } else {
                    HStack {
                        Text("Saved Key")
                        Spacer()
                        Text(showAPIKey ? apiKey : maskedAPIKey)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Button(showAPIKey ? "Hide" : "Reveal") {
                            showAPIKey.toggle()
                        }
                        Button("Change Key") {
                            draftAPIKey = apiKey
                            isEditingAPIKey = true
                            showAPIKey = false
                        }
                    }
                }
                
                if apiKey.isEmpty {
                    Text("An API key is required to search.")
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
            
            Section(header: Text("Get Access")) {
                Link(destination: URL(string: "https://serpapi.com/users/sign_up")!) {
                    Label("Sign Up for SerpApi", systemImage: "person.badge.plus")
                }
                .foregroundColor(.blue)
            }
            
            if !apiKey.isEmpty {
                Section(header: Text("Account Status")) {
                    if isLoading {
                        ProgressView()
                    } else if let info = accountInfo {
                        HStack {
                            Text("Email")
                            Spacer()
                            Text(info.email)
                                .foregroundColor(.secondary)
                        }
                        HStack {
                            Text("Plan")
                            Spacer()
                            Text(info.plan)
                                .foregroundColor(.secondary)
                        }
                        HStack {
                            Text("Searches Left")
                            Spacer()
                            Text("\(info.searches_left)")
                                .foregroundColor(info.searches_left > 0 ? .green : .red)
                        }
                    } else {
                        Button("Check Account Status") {
                            Task {
                                await checkStatus()
                            }
                        }
                    }
                    if let error = errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
        }
        .navigationTitle("Profile")
        .onAppear {
            draftAPIKey = apiKey
        }
        .onChange(of: apiKey) { _ in
            accountInfo = nil
            errorMessage = nil
            if !isEditingAPIKey {
                draftAPIKey = apiKey
            }
        }
        #if os(macOS)
        .frame(maxWidth: 640)
        .frame(maxWidth: .infinity, alignment: .center)
        #endif
    }

    private var maskedAPIKey: String {
        guard !apiKey.isEmpty else { return "" }
        if apiKey.count <= 8 {
            return "********"
        }
        return "\(apiKey.prefix(4))****\(apiKey.suffix(4))"
    }
    
    func checkStatus() async {
        guard !apiKey.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        
        // Simple manual request or use shared client logic if easily accessible
        // Using manual request for simplicity in view to avoid dependency loops if ViewModel is not passed
        // But better to use `SerpApiClient`
        
        // We need to import SerpApi module
        // But we can't easily import `SerpApiClient` from here unless we import the module
        // Assuming `import SerpApi` works (it does, locally)
        
        do {
            // Re-create client with current key
            let client = SerpApiClient(params: ["api_key": apiKey])
            let result = try await client.account()
            
            if let info = AccountInfo(dict: result) {
                self.accountInfo = info
            } else {
                self.errorMessage = "Could not parse account info."
            }
        } catch {
            self.errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
}
