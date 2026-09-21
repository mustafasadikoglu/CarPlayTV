import SwiftUI

/// Sheet for editing and re-authenticating an existing Xtream Codes account.
public struct EditXtreamAccountSheet: View {
    let account: XtreamAccount
    @ObservedObject var accountStore = XtreamAccountStore.shared
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var server: String
    @State private var username: String
    @State private var password: String

    @State private var isTesting: Bool = false
    @State private var errorMessage: String?
    @State private var showingError: Bool = false

    public init(account: XtreamAccount) {
        self.account = account
        _name = State(initialValue: account.name)
        _server = State(initialValue: account.server)
        _username = State(initialValue: account.username)
        _password = State(initialValue: account.securePassword ?? "")
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section("Hesap & Sunucu Bilgileri") {
                    TextField("Hesap Adı (Örn: Ev IPTV)", text: $name)

                    TextField("Sunucu URL (http://...)", text: $server)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)

                    TextField("Kullanıcı Adı", text: $username)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)

                    SecureField("Şifre", text: $password)
                }

                Section("Hesap Durumu") {
                    HStack {
                        Text("Son Senkronizasyon")
                        Spacer()
                        Text(account.formattedLastSynced)
                            .foregroundColor(.secondary)
                    }

                    if let exp = account.expirationDate {
                        HStack {
                            Text("Bitiş Tarihi")
                            Spacer()
                            Text(exp)
                                .foregroundColor(.secondary)
                        }
                    }

                    HStack {
                        Text("Mevcut Kanal / Film")
                        Spacer()
                        Text("\(account.channelCount) Kanal • \(account.vodCount) VOD")
                            .foregroundColor(.secondary)
                    }
                }

                Section(footer: Text("Kaydettiğinizde sunucuya bağlanılarak hesap bilgileri test edilecek ve şifre iOS Keychain'de güvenle güncellenecektir.")) {
                    Button(action: saveAndTest) {
                        if isTesting {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .padding(.trailing, 8)
                                Text("Doğrulanıyor...")
                                Spacer()
                            }
                        } else {
                            Text("Değişiklikleri Test Et & Kaydet")
                                .frame(maxWidth: .infinity)
                                .bold()
                        }
                    }
                    .disabled(name.isEmpty || server.isEmpty || username.isEmpty || password.isEmpty || isTesting)
                }
            }
            .navigationTitle("Hesabı Düzenle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Vazgeç") {
                        dismiss()
                    }
                }
            }
            .alert("Güncelleme Hatası", isPresented: $showingError) {
                Button("Tamam", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "Bilinmeyen bir hata oluştu.")
            }
        }
    }

    private func saveAndTest() {
        isTesting = true
        errorMessage = nil

        Task {
            do {
                try await accountStore.updateAccount(
                    id: account.id,
                    name: name,
                    server: server,
                    user: username,
                    pass: password
                )
                await MainActor.run {
                    isTesting = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isTesting = false
                    let safe = URLSanitizer.sanitize(error.localizedDescription)
                    errorMessage = "Sunucu bağlantısı başarısız: \(safe)"
                    showingError = true
                }
            }
        }
    }
}
