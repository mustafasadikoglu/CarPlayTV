import SwiftUI

public struct CarPlaySettingsView: View {
    @ObservedObject var playback = PlaybackManager.shared

    public var body: some View {
        NavigationStack {
            Form {
                // CarPlay Durumu
                Section(header: Text("CarPlay Bağlantı Durumu")) {
                    HStack {
                        Image(systemName: playback.isCarPlayConnected ? "checkmark.circle.fill" : "xmark.circle")
                            .foregroundColor(playback.isCarPlayConnected ? .green : .gray)
                        Text(playback.isCarPlayConnected ? "CarPlay Bağlandı" : "CarPlay Bağlı Değil")
                            .font(.headline)
                        Spacer()
                        if playback.isCarPlayConnected {
                            Text("Aktif")
                                .font(.caption.bold())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.green.opacity(0.2))
                                .foregroundColor(.green)
                                .cornerRadius(6)
                        }
                    }

                    HStack {
                        Text("Harici Video Çıkışı")
                        Spacer()
                        Text(playback.isExternalVideoActive ? "Yayında" : "Devre Dışı")
                            .foregroundColor(playback.isExternalVideoActive ? .green : .secondary)
                    }

                    HStack {
                        Text("Algılanan Ekran Sayısı")
                        Spacer()
                        Text("\(UIScreen.screens.count)")
                            .foregroundColor(.secondary)
                    }
                }

                // Video Oynatma Modu
                Section(
                    header: Text("CarPlay Video Oynatma Modu"),
                    footer: Text(videoModeDescription(for: playback.carPlayVideoMode))
                ) {
                    Picker("Video Modu", selection: Binding(
                        get: { playback.carPlayVideoMode },
                        set: { playback.setCarPlayVideoMode($0) }
                    )) {
                        ForEach(CarPlayVideoMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                }

                // Görüntü Oranı
                Section("Görüntü Ayarları") {
                    Picker("En-Boy Oranı", selection: $playback.aspectRatio) {
                        ForEach(VideoAspectRatio.allCases, id: \.self) { ratio in
                            Text(ratio.rawValue).tag(ratio)
                        }
                    }
                }

                // Apple Güvenlik ve Geliştirici Notu
                Section("Teknik Bilgi & Güvenlik") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "shield.lefthalf.filled")
                                .foregroundColor(.accentColor)
                            Text("Apple CarPlay Video Kılavuzu")
                                .font(.subheadline.bold())
                        }
                        Text("• Apple, sürüş sırasında dikkat dağılmasını engellemek için App Store onaylı uygulamalarda araç hareket halindeyken CarPlay ekranında videoyu kısıtlar.\n• Araç park halindeyken 'AirPlay / Park Halinde Video' modu tam ekran video akışı sağlar.\n• TrollStore, AltStore veya Jailbreak ortamında doğrudan CarPlay ekranına görüntü vermek için 'Doğrudan Harici Pencere' modunu seçebilirsiniz.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                // Uygulama Hakkında
                Section("Hakkında") {
                    HStack {
                        Text("Uygulama")
                        Spacer()
                        Text("CarPlayTV iOS")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Sürüm")
                        Spacer()
                        Text("1.0.0 (Build 1)")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("CarPlay & Ayarlar")
        }
    }

    private func videoModeDescription(for mode: CarPlayVideoMode) -> String {
        switch mode {
        case .autoParkAirPlay:
            return "Resmi Apple CarPlay video standardı. Araç park halindeyken CarPlay ekranında AirPlay video akışı sağlar, araç hareket ettiğinde ses moduna geçer."
        case .forceExternalWindow:
            return "Sideload / TrollStore / Kurumsal sertifikalı kurulumlar için. CarPlay ekranına bağımsız bir UIWindow açarak doğrudan tam ekran video kareleri çizer."
        case .companionAudioOnly:
            return "Video telefon ekranında oynatılır, araç hoparlörlerine yüksek kaliteli ses ve CarPlay ekranına kanal değiştirme menüleri iletilir."
        }
    }
}
