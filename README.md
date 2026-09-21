# CarPlayTV - iOS IPTV & CarPlay Video Oynatıcı

CarPlayTV; iPhone, iPad ve **Apple CarPlay** üzerinde canlı IPTV akışlarını (M3U, M3U8 ve Xtream Codes API) yüksek performans ve düşük gecikme ile oynatmak üzere tasarlanmış modern, yerel (native Swift & SwiftUI) bir iOS uygulamasıdır.

---

## 🚗 CarPlay Video Oynatma Stratejileri

Apple'ın sürüş güvenliği kuralları ve teknik altyapısı doğrultusunda uygulama **3 farklı CarPlay modu** sunar:

### 1. Resmi Apple CarPlay Video & AirPlay Modu (App Store / Developer Uyumlu)
- Apple'ın resmi `com.apple.developer.carplay-video` ve `com.apple.developer.carplay-audio` yetkilerini (entitlements) kullanır.
- **Araç Park Halindeyken:** AirPlay video projeksiyonu ile CarPlay ekranında tam ekran video oynatımı sağlar.
- **Araç Hareket Halindeyken:** Sürüş güvenliği gereği otomatik olarak kesintisiz araç hoparlörü ses moduna geçer.

### 2. Doğrudan Harici Pencere Modu (Sideload / TrollStore / AltStore / CarBridge)
- CarPlay ekranı harici bir `UIScreen` / `UIWindowScene` olarak algılandığında, CarPlay şablonlarının üzerine doğrudan bağımsız bir `UIWindow` ve `AVPlayerLayer` açar.
- Hareket kısıtlamalarına takılmadan doğrudan araç ekranına video kareleri çizer.
- Kişisel kullanım ve sideloading için idealdir.

### 3. Çift Ekran (Companion) Modu
- iPhone ön göğüste (tutacakta) canlı TV videosunu oynatır.
- CarPlay ekranı ise direksiyon kumandaları, kategori listesi, favoriler ve Now Playing kontrolleri ile ses sistemini yönetir.

---

## 🚀 Özellikler

- **Gelişmiş IPTV Akış Motoru:** HLS (`.m3u8`), TS ve MP4 canlı akışları için donanımsal hızlandırmalı `AVPlayer`.
- **M3U / M3U8 Ayrıştırıcı:** `tvg-id`, `tvg-name`, `tvg-logo`, `group-title` ve özel HTTP User-Agent desteği.
- **Xtream Codes API Entegrasyonu:** Canlı TV kanallarını kategorileriyle birlikte otomatik çekme.
- **CarPlay Şablonları:**
  - `CPTabBarTemplate`: Favoriler, Kategoriler, Son İzlenenler sekmeleri.
  - `CPNowPlayingTemplate`: Çalan kanal adı, logosu, oynat/durdur ve sonraki/önceki kanal butonları.
  - Direksiyon multimedya tuşları desteği (`MPRemoteCommandCenter`).
- **Modern iOS Arayüzü:** Karanlık mod, cam efekti (glassmorphism), kaydırma hareketleri, kanal arama ve Resim içinde Resim (PiP).

---

## 🛠️ Kurulum ve Derleme (Xcode)

### Gereksinimler
- macOS (Xcode 15.0 veya üzeri)
- iOS 16.0+ hedef sürüm
- Apple Developer Hesabı (Ücretsiz veya Ücretli)

### Adımlar
1. Proje klasörünü Mac bilgisayarınıza kopyalayın.
2. `CarPlayTV.xcodeproj` dosyasını Xcode ile açın.
3. Xcode'da sol menüden `CarPlayTV` hedefini (target) seçin ve **Signing & Capabilities** sekmesine gidin.
4. Kendi **Apple Developer Team** hesabınızı seçin ve `Bundle Identifier` alanını gerekirse güncelleyin.
5. `CarPlayTV` şemasını seçip **Run** (⌘ + R) butonuna basın.

---

## 📺 Xcode CarPlay Simülatörü ile Test Etme

Uygulamanın CarPlay entegrasyonunu gerçek bir araca bağlamadan Xcode Simülatöründe test edebilirsiniz:

1. Xcode'dan bir iPhone Simülatörü (örneğin *iPhone 15 Pro*) başlatın.
2. Simülatör penceresi açıkken üst menüden:
   **`I/O` > `External Displays` > `CarPlay`** seçeneğini işaretleyin.
3. Ekranda bağımsız bir **CarPlay Ekranı** açılacaktır.
4. CarPlay ana ekranında **CarPlayTV** simgesine tıklayın; kategoriler, favoriler ve oynatıcı şablonları anında görüntülenecektir.

---

## 📦 Sideloading (TrollStore / AltStore / Sideloadly) Kurulumu

CarPlay ekranında hareket halindeyken doğrudan video izlemek istiyorsanız:

1. Xcode'da projeyi **Any iOS Device (arm64)** hedefiyle **Product > Archive** edin veya `.ipa` çıktısı alın.
2. IPA dosyasını TrollStore, AltStore veya Sideloadly ile iPhone'unuza yükleyin.
3. Uygulamayı açıp **CarPlay & Ayarlar** sekmesinden:
   - Video Modu: **"Doğrudan Harici Pencere (Sideload/TrollStore)"** olarak seçin.
4. iPhone'u aracınızın CarPlay portuna bağladığınızda video doğrudan CarPlay ekranında akacaktır.

---

## 📁 Proje Dosya Yapısı

```
CarPlayTV/
├── CarPlayTV.xcodeproj/            # Xcode proje ve şema dosyaları
├── CarPlayTV/
│   ├── App/
│   │   ├── CarPlayTVApp.swift      # SwiftUI @main giriş noktası
│   │   ├── AppDelegate.swift       # CarPlay ve UI sahne yapılandırması
│   │   └── SceneDelegate.swift     # iPhone pencere yaşam döngüsü
│   ├── Models/
│   │   ├── Channel.swift           # Kanal, kategori ve çalma listesi modelleri
│   │   └── XtreamModels.swift      # Xtream Codes JSON veri modelleri
│   ├── Services/
│   │   ├── PlaybackManager.swift   # AVPlayer, AirPlay, harici ekran ve ses yöneticisi
│   │   ├── PlaylistStore.swift     # Kanallar, favoriler ve son izlenenler deposu
│   │   ├── M3UParser.swift         # M3U / M3U8 regex ve akış ayrıştırıcı
│   │   └── XtreamCodesClient.swift # Xtream Codes v2 API istemcisi
│   ├── CarPlay/
│   │   ├── CarPlaySceneDelegate.swift          # CPTemplateApplicationSceneDelegate
│   │   ├── CarPlayInterfaceManager.swift       # CarPlay menü ve NowPlaying şablonları
│   │   └── CarPlayVideoWindowController.swift  # Harici ekrana doğrudan video çizim penceresi
│   ├── Views/
│   │   ├── MainTabView.swift                   # Ana sekme çubuğu
│   │   ├── Channels/                           # Kanal listesi, arama ve filtreleme
│   │   ├── Player/                             # SwiftUI tam ekran ve mini video oynatıcı
│   │   ├── Playlist/                           # M3U ve Xtream ekleme ekranları
│   │   └── Settings/                           # CarPlay modları ve tanılama ayarları
│   ├── Info.plist                  # CarPlay sahne rolleri ve arka plan izinleri
│   ├── CarPlayTV.entitlements      # CarPlay ses ve video izinleri
│   └── Assets.xcassets/            # Renk ve ikon katalogları
└── README.md
```
