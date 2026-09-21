import SwiftUI

/// Card view representing a single Xtream account with activation, synchronization, editing, and deletion controls.
public struct XtreamAccountRowView: View {
    let account: XtreamAccount
    @ObservedObject var accountStore = XtreamAccountStore.shared

    @State private var isShowingEditSheet: Bool = false
    @State private var isShowingDeleteAlert: Bool = false
    @State private var isSyncingThis: Bool = false

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Top Row: Name, Host badge and Active indicator
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(account.name)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.primary)

                        if account.isActive {
                            HStack(spacing: 4) {
                                Circle().fill(Color.green).frame(width: 6, height: 6)
                                Text("AKTİF")
                                    .font(.caption2.bold())
                                    .foregroundColor(.green)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.12))
                            .cornerRadius(6)
                        }
                    }

                    Text(account.hostDisplayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Context Menu for Quick Actions
                Menu {
                    if !account.isActive {
                        Button(action: {
                            accountStore.setActiveAccount(account: account)
                        }) {
                            Label("Aktif Hesap Yap", systemImage: "checkmark.circle.fill")
                        }
                    }

                    Button(action: syncAccount) {
                        Label("Sunucudan Yenile (Sync)", systemImage: "arrow.clockwise")
                    }

                    Button(action: {
                        isShowingEditSheet = true
                    }) {
                        Label("Hesap Bilgilerini Düzenle", systemImage: "pencil")
                    }

                    Divider()

                    Button(role: .destructive, action: {
                        isShowingDeleteAlert = true
                    }) {
                        Label("Hesabı Sil", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle.fill")
                        .font(.title3)
                        .foregroundColor(.secondary.opacity(0.8))
                        .padding(4)
                }
            }

            // Stats row: Channels, VOD, Expiry Date
            HStack(spacing: 12) {
                Label("\(account.channelCount) Kanal", systemImage: "tv")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Label("\(account.vodCount) VOD", systemImage: "film")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                if let exp = account.expirationDate {
                    Label(exp, systemImage: "calendar")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            Divider()

            // Bottom Action Bar
            HStack {
                if account.isActive {
                    Text("Şu anda canlı yayınlar bu hesaptan oynatılıyor.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else {
                    Button(action: {
                        accountStore.setActiveAccount(account: account)
                    }) {
                        Text("Bu Hesaba Geçiş Yap")
                            .font(.caption.bold())
                            .foregroundColor(.accentColor)
                    }
                }

                Spacer()

                // Sync button
                Button(action: syncAccount) {
                    HStack(spacing: 4) {
                        if isSyncingThis {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.caption)
                        }
                        Text(isSyncingThis ? "Yenileniyor..." : "Yenile")
                            .font(.caption.weight(.medium))
                    }
                    .foregroundColor(.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(UIColor.tertiarySystemFill))
                    .cornerRadius(8)
                }
                .disabled(isSyncingThis)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(account.isActive ? Color.green.opacity(0.4) : Color.clear, lineWidth: 1.5)
                )
        )
        .sheet(isPresented: $isShowingEditSheet) {
            EditXtreamAccountSheet(account: account)
        }
        .alert("Hesabı Sil", isPresented: $isShowingDeleteAlert) {
            Button("Vazgeç", role: .cancel) {}
            Button("Sil", role: .destructive) {
                accountStore.deleteAccount(account: account)
            }
        } message: {
            Text("'\(account.name)' hesabı, şifresi ve önbellekteki kanalları silinecektir. Emin misiniz?")
        }
    }

    private func syncAccount() {
        isSyncingThis = true
        Task {
            try? await accountStore.syncAccount(account: account)
            await MainActor.run {
                isSyncingThis = false
            }
        }
    }
}
