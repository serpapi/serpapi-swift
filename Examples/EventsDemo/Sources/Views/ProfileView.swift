import SwiftUI
import SerpApi

#if os(macOS)
import AppKit
#endif

struct ProfileView: View {
    @AppStorage("serpapi_key") var apiKey: String = ""
    @State private var accountInfo: AccountInfo?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showAPIKey = false
    @State private var isEditingAPIKey = false
    @State private var draftAPIKey = ""
    @State private var didCopy = false
    @Environment(\.colorScheme) private var colorScheme

    struct AccountInfo {
        let email: String
        let plan: String
        let searchesLeft: Int
        let thisHourSearches: Int?
        let thisMonthUsage: Int?

        init?(dict: [String: Any]) {
            self.email = dict["account_email"] as? String ?? ""
            self.plan = dict["plan_name"] as? String ?? ""

            var left = dict["searches_per_month"] as? Int ?? 0
            if let planLeft = dict["plan_searches_left"] as? Int {
                left = planLeft
            }
            self.searchesLeft = left
            self.thisHourSearches = dict["this_hour_searches"] as? Int
            self.thisMonthUsage = dict["this_month_usage"] as? Int
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                apiKeyCard

                if !apiKey.isEmpty {
                    accountCard
                }

                if apiKey.isEmpty {
                    getAccessCard
                }

                Spacer(minLength: 0)
            }
            .padding(24)
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Profile")
        .onAppear {
            draftAPIKey = apiKey
            if !apiKey.isEmpty && accountInfo == nil {
                Task { await checkStatus() }
            }
        }
        .onChange(of: apiKey) { _ in
            accountInfo = nil
            errorMessage = nil
            if !isEditingAPIKey {
                draftAPIKey = apiKey
            }
            if !apiKey.isEmpty {
                Task { await checkStatus() }
            }
        }
    }

    // MARK: - Sections

    private var header: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(SerpApiTheme.heroGradient)
                Image(systemName: "person.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.white)
            }
            .frame(width: 64, height: 64)

            VStack(alignment: .leading, spacing: 4) {
                Text(accountInfo?.email.isEmpty == false ? accountInfo!.email : "Your SerpApi Account")
                    .font(.title2.weight(.semibold))
                    .lineLimit(1)
                Text(accountInfo?.plan.isEmpty == false ? accountInfo!.plan : (apiKey.isEmpty ? "No API key configured" : "Loading account…"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }

    private var apiKeyCard: some View {
        Card(title: "API Key", systemImage: "key.fill") {
            if apiKey.isEmpty || isEditingAPIKey {
                editor
            } else {
                savedView
            }

            if apiKey.isEmpty {
                Label("An API key is required to search.", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundColor(SerpApiTheme.amber)
                    .padding(.top, 4)
            }
        }
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 10) {
            SecureField("Paste your SerpApi key", text: $draftAPIKey)
                .textFieldStyle(.roundedBorder)
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
                    .buttonStyle(.bordered)
                }

                Spacer()
            }
        }
    }

    private var savedView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(showAPIKey ? apiKey : maskedAPIKey)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(
                        SerpApiTheme.accentBlue.opacity(colorScheme == .dark ? 0.18 : 0.10),
                        in: RoundedRectangle(cornerRadius: 8)
                    )

                Spacer()

                Button {
                    showAPIKey.toggle()
                } label: {
                    Image(systemName: showAPIKey ? "eye.slash.fill" : "eye.fill")
                }
                .buttonStyle(.borderless)
                .help(showAPIKey ? "Hide key" : "Reveal key")

                Button {
                    copyKey()
                } label: {
                    Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
                        .foregroundColor(didCopy ? SerpApiTheme.mint : .primary)
                }
                .buttonStyle(.borderless)
                .help("Copy key")
            }

            HStack {
                Button("Change Key") {
                    draftAPIKey = apiKey
                    isEditingAPIKey = true
                    showAPIKey = false
                }
                .buttonStyle(.bordered)

                Button(role: .destructive) {
                    apiKey = ""
                    draftAPIKey = ""
                    showAPIKey = false
                } label: {
                    Text("Remove")
                }
                .buttonStyle(.bordered)

                Spacer()
            }
        }
    }

    private var accountCard: some View {
        Card(title: "Account", systemImage: "person.crop.circle.badge.checkmark") {
            if isLoading && accountInfo == nil {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Checking account status…")
                        .foregroundColor(.secondary)
                }
            } else if let info = accountInfo {
                VStack(spacing: 10) {
                    infoRow(label: "Email", value: info.email.isEmpty ? "—" : info.email)
                    Divider()
                    infoRow(label: "Plan", value: info.plan.isEmpty ? "—" : info.plan)
                    Divider()
                    HStack {
                        Text("Searches Left")
                        Spacer()
                        Text("\(info.searchesLeft)")
                            .font(.body.monospacedDigit())
                            .foregroundColor(info.searchesLeft > 0 ? SerpApiTheme.mint : SerpApiTheme.danger)
                    }
                    if let month = info.thisMonthUsage {
                        Divider()
                        infoRow(label: "This Month", value: "\(month) searches")
                    }
                    if let hour = info.thisHourSearches {
                        Divider()
                        infoRow(label: "This Hour", value: "\(hour) searches")
                    }
                }
            } else {
                Button {
                    Task { await checkStatus() }
                } label: {
                    Label("Check Account Status", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
            }

            if let error = errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundColor(SerpApiTheme.danger)
                    .padding(.top, 4)
            }

            if accountInfo != nil {
                HStack {
                    Spacer()
                    Button {
                        Task { await checkStatus() }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
                    .disabled(isLoading)
                }
            }
        }
    }

    private var getAccessCard: some View {
        Card(title: "Get Access", systemImage: "sparkles") {
            Text("Don’t have a key yet? Create a free SerpApi account and grab yours.")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Link(destination: URL(string: "https://serpapi.com/users/sign_up")!) {
                Label("Sign Up for SerpApi", systemImage: "arrow.up.right.square")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
                .textSelection(.enabled)
        }
    }

    // MARK: - Helpers

    private var maskedAPIKey: String {
        guard !apiKey.isEmpty else { return "" }
        if apiKey.count <= 8 {
            return String(repeating: "•", count: max(apiKey.count, 6))
        }
        return "\(apiKey.prefix(4))••••••••\(apiKey.suffix(4))"
    }

    private func copyKey() {
        #if os(macOS)
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(apiKey, forType: .string)
        #else
        UIPasteboard.general.string = apiKey
        #endif
        didCopy = true
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await MainActor.run { didCopy = false }
        }
    }

    func checkStatus() async {
        guard !apiKey.isEmpty else { return }
        isLoading = true
        errorMessage = nil

        do {
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

// MARK: - Reusable Card

private struct Card<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: Content
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .foregroundStyle(SerpApiTheme.heroGradient)
                Text(title)
                    .font(.headline)
                Spacer()
            }
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(SerpApiTheme.cardBackground(for: colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(SerpApiTheme.cardBorder(for: colorScheme), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.06), radius: 12, y: 4)
    }
}
