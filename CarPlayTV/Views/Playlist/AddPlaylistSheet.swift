import SwiftUI

public struct AddPlaylistSheet: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var store = PlaylistStore.shared
    @ObservedObject var accountStore = XtreamAccountStore.shared

    @State private var selectedTab: Int = 0

    // M3U fields
    @State private var m3uName: String = ""
    @State private var m3uUrlString: String = ""

    // Xtream fields
    @State private var xtreamName: String = ""
    @State private var xtreamServer: String = ""
    @State private var xtreamUser: String = ""
    @State private var xtreamPass: String = ""

    public var body: some View {
        NavigationStack {
            Form {
                Picker("Tip Seçin", selection: $selectedTab) {
                    Text("M3U / M3U8 Link").tag(0)
                    Text("Xtream Codes API").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())

                if selectedTab == 0 {
                    Section("M3U Çalma Listesi Bilgileri") {
                        TextField("Liste Adı (Örn: Ev IPTV)", text: $m3uName)
                        TextField("M3U URL (http://...)", text: $m3uUrlString)
                            .keyboardType(.URL)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }

                    Section(footer: Text("URL'nin doğrudan .m3u veya .m3u8 çıktısı veren geçerli bir IPTV bağlantısı olduğundan emin olun.")) {
                        Button(action: saveM3U) {
                            if store.isLoading {
                                HStack {
                                    Spacer()
                                    ProgressView()
                                    Spacer()
                                }
                            } else {
                                Text("M3U Listesini Ekle")
                                    .frame(maxWidth: .infinity)
                                    .bold()
                            }
                        }
                        .disabled(m3uName.isEmpty || m3uUrlString.isEmpty || store.isLoading)
                    }
                } else {
                    Section("Xtream Sunucu Bilgileri") {
                        TextField("Bağlantı Adı (Örn: Premium IPTV)", text: $xtreamName)
                        TextField("Sunucu URL (http://dns.com:8080)", text: $xtreamServer)
                            .keyboardType(.URL)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        TextField("Kullanıcı Adı", text: $xtreamUser)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        SecureField("Şifre", text: $xtreamPass)
                    }

                    Section(footer: Text("Xtream Codes API canlı TV kanalları otomatik olarak kategorileriyle çekilecektir.")) {
                        Button(action: saveXtream) {
                            if accountStore.isSyncing {
                                HStack {
                                    Spacer()
                                    ProgressView()
                                        .padding(.trailing, 8)
                                    Text(accountStore.syncProgressText ?? "Bağlanılıyor...")
                                    Spacer()
                                }
                            } else {
                                Text("Xtream Hesabını Bağla")
                                    .frame(maxWidth: .infinity)
                                    .bold()
                            }
                        }
                        .disabled(xtreamName.isEmpty || xtreamServer.isEmpty || xtreamUser.isEmpty || xtreamPass.isEmpty || accountStore.isSyncing)
                    }
                }

                if let error = accountStore.errorMessage ?? store.errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Çalma Listesi Ekle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func saveM3U() {
        guard let url = URL(string: m3uUrlString.trimmingCharacters(in: .whitespacesAndNewlines)) else { return }
        Task {
            await store.addM3UPlaylist(name: m3uName, url: url)
            if store.errorMessage == nil {
                dismiss()
            }
        }
    }

    private func saveXtream() {
        Task {
            do {
                _ = try await XtreamAccountStore.shared.addAccount(
                    name: xtreamName,
                    server: xtreamServer,
                    user: xtreamUser,
                    pass: xtreamPass
                )
                await MainActor.run {
                    dismiss()
                }
            } catch {
                // Error is displayed via accountStore.errorMessage
            }
        }
    }
}
