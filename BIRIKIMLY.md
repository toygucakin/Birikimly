# Birikimly - Kişisel Finans ve Tasarruf Uygulaması 🚀

Birikimly, kullanıcıların gelir ve giderlerini en hızlı şekilde yönetmesi, harcama alışkanlıklarını analiz etmesi ve finansal özgürlüğe ulaşması için tasarlanmış modern bir mobil uygulamadır.

## 🎯 Proje Kapsamı ve Vizyonu

Birikimly'nin temel amacı, karmaşık finans takip süreçlerini basitleştirerek herkesin bütçesini kontrol altına almasını sağlamaktır.
- **Hız:** Tek dokunuşla harcama ekleme.
- **Bilinç:** Detaylı kategori raporları ile paranın nereye gittiğini anlama.
- **Güven ve Senkronizasyon:** Çok cihazlı erişim ve bulut yedekleme.
- **Offline-First:** İnternet olmasa dahi kesintisiz kullanım.

### Gelecek Vizyonu 🌟
- **Kişiselleştirilebilir Profil İkonları:** Kullanıcıların kendi profilleri için özel simgeler (hayvan, çiçek ve manzara çizimleri/ikonları) seçebilmesi sağlanacaktır. Bu tasarımlar temel düzeyde siyah-beyaz (monochrome/vektörel) olarak çizilecektir; bu sayede projedeki dinamik tema değişikliklerine (arka plan rengi ve birincil renk tonuna) anında ve kusursuz şekilde uyum sağlayarak görsel bütünlük daima korunacaktır.
- **Yapay Zeka Destekli Analizler:** Kullanıcıya "Bu ay kahveye çok harcadın, dikkat!" gibi akıllı uyarılar.
- **Fatura Hatırlatıcılar:** Otomatik ödeme günleri için bildirimler.
- **Gelişmiş Grafikler:** Yıllık ve aylık trendlerin interaktif görsellerle sunulması.
- **Taksitli İşlem Desteği:** Harcamaların aylara bölünerek taksitli şekilde girilebilmesi.
- **Geçmiş Aylarla Karşılaştırma:** Mevcut harcamaların bir önceki ay veya geçen yılın aynı ayı ile kıyaslanması.
- **Uygulama İçi Rehber (Tutorial):** Yeni kullanıcıların uygulamayı daha kolay öğrenebilmesi amacıyla interaktif bir "Nasıl Kullanılır?" rehberi/turunun eklenmesi sağlanacaktır.
- **Widget Küçük Ekran Arayüz İyileştirmesi:** Butonların iç dolguları (`paddingStart/End`) ve dış boşlukları (`margin`) daraltılarak yatayda alan kazanılacak; yazı boyutları başlıklar için `9.5sp`, bakiyeler için `11sp` olarak optimize edilecektir. Ayrıca `singleLine="true"` ve `ellipsize="end"` özellikleri kullanılarak küçük/dar boyutlu (2x2 veya 2x1) widget'larda bakiye tutarlarının alt satıra sarkıp sıkışması sorunu giderilecektir.
- **Ay Sonunda ve Düzenli İşlemlerde Bildirim Gönderimi:** Ay sonlarında bütçe durumu özeti ve düzenli işlemler arka planda gerçekleştiğinde kullanıcıya anlık bildirim (push notification) gönderilmesi sağlanacaktır.

---

## 📝 Değişiklik Günlüğü (Change Log)

### [29.06.2026] - Güvenlik Sıkılaştırma, iOS Deep Link Desteği, Güvenli Çıkış (Purge), App Store Uyumlu Hesap Silme ve Göç (Migration) Optimizasyonları
- **Supabase Oturum Şifreleme (Güvenlik):** İstemci tarafında Supabase oturum bilgilerinin (access ve refresh token'lar) şifresiz saklanması sorunu giderildi. `flutter_secure_storage` entegrasyonu ve özel `SecureLocalStorage` sınıfı ile bu bilgiler **Android KeyStore** ve **iOS Keychain** üzerinde donanım destekli şifrelendi.
- **iOS Deep Link Desteği (Bug Düzeltme):** iOS widget'ındaki butonlardan gelen `birikimly://add_expense` / `add_income` tetiklemelerinin çalışabilmesi için `ios/Runner/Info.plist` dosyasına `birikimly` URL şeması başarıyla tanımlandı.
- **Güvenli Çıkış & Veri Temizleme (Purge):** Kullanıcı hesaptan çıkış yaptığında veya misafir modundan ayrıldığında yerel SQLite (`db.sqlite`) veritabanındaki verilerin cihazda kalmaya devam etmesi engellendi. Veritabanındaki tüm tabloları temizleyen `clearAllData()` metodu entegre edildi.
- **Hesabımı Kalıcı Olarak Sil (Yasal Uyum & Güvenlik):** Apple App Store yayın kuralları (Guideline 5.1.1(v)) gereğince profil sayfasına hesap silme desteği eklendi. Yetkisiz hesap silme isteklerini önlemek adına işlem öncesinde e-posta ve şifreli doğrulama (re-authentication) zorunluluğu getirildi. Doğrulama başarılı olursa Supabase tarafında hazırlanan güvenli `delete_user_account` RPC (Stored Procedure) fonksiyonu çağrılarak kullanıcının buluttaki verileri, yetkilendirmesi ve yerel SQLite veritabanı tamamen silinmektedir.
- **Senkronizasyon Performansı (Darboğaz Giderilmesi):** Ağ bağlantısı değiştikçe ve açılışta tetiklenen kategori normalleştirme adımında tüm işlemlerin taranıp RAM'e çekilmesi önlendi. Yalnızca normalleştirme gerektiren verileri filtreleyen `getTransactionsNeedingNormalization()` veritabanı sorgusuyla açılış hızı optimize edildi.
- **Veritabanı Göç (Migration) ve Geç Açılma Hatalarının Düzeltilmesi:** Uygulama yükseltmelerinde ve yeni kurulumlarda yaşanan `duplicate column name: frequency` SQLite hatası, versiyon 12'den sonraki kolon ekleme (`addColumn`) mantığı koşula bağlanarak düzeltildi. Uygulamanın dönen animasyonda asılı kalıp kilitlenmesi sorunu giderildi.
- **Bellek Sızıntısı (Memory Leak) Engeli:** `syncServiceProvider` Riverpod provider'ına `ref.onDispose` eklenerek aboneliklerin arka planda açık kalarak kaynak sızdırması önlendi. Ayrıca `app_links` paketi bağımlılık karmaşasını önlemek adına transitiflikten çıkarılıp `pubspec.yaml`'a doğrudan eklendi.
- **İşlem Sihirbazı Taşma (Pixel Overflow) & Yapısal İyileştirmeler:** Gelir/gider ekleme sihirbazında (`TransactionWizard`) yaşanan dikey/yatay taşma hataları tamamen çözüldü. Klavye açıldığında diyalog yüksekliğinin dinamik olarak sınırlanması ve `_buildAmountStep` adımının dikeyde `SingleChildScrollView` ile sarmalanması sayesinde orta form alanı kendi içinde kaydırılabilir hale getirildi; bu sayede 'Devam Et' (navigasyon) butonu en altta her zaman sabit (sticky footer) ve görünür tutularak klavye açıkken de butonun kaybolması/kırpılması önlendi.
- **Düzenli Ödemeler Gerçekleşme ve Takip Sistemi (Gelen/Gelmeyen Analizi):** Kullanıcı girmeden gerçekleşen otomatik düzenli ödemelerin bildirimi akıllı hale getirildi. Diyalog penceresi sadece yeni otomatik işlem gerçekleştiğinde açılacak şekilde koşullandırıldı; gerçekleşen ödemeler ile önümüzdeki **7 gün içinde** gerçekleşecek aktif **"Bekleyen Planlar"** (kalan gün sayısı ve tarihleriyle) bu diyaloğa dahil edildi. Ayrıca `Düzenli İşlemler` ekranı iki sekmeli (Planlar / İşlem Geçmişi) Tab yapısına kavuşturularak otomatik tamamlanan işlemlerin kalıcı olarak takip edilebilmesi sağlandı.
- **Yatay Taşma (Right Overflow) Giderilmesi & Etiket Güncellemesi:** Düzenli işlem giriş alanındaki "Miktarı Girin" başlığı ile "Geçerlilik Süresi (Taksit) / Tahmini Bitiş" alanlarının dar ekranlarda sağa doğru piksel taşmasına sebep olması, `Expanded`/`Flexible` ve `ellipsis` metin kesme özellikleri entegre edilerek çözüldü. Kullanıcının düzenli ödeme planlamasının ne anlama geldiğini net anlaması için eski `Tahmini Süre` başlığı `Düzenli Tekrar Miktarı` olarak güncellendi.





### [24.06.2026] - Ekran Kilidi, Düzenli İşlem Bildirim Pop-up'ı, Tutar Limit Doğrulamaları ve Çoklu Kategori Filtresi
- **Ekran Yönü Sabitleme:** Uygulama hem Android hem de iOS platformlarında sadece dikey (portrait) modda çalışacak şekilde kilitlendi.
- **Düzenli İşlem Detaylı Pop-up Gösterimi:** Uygulama açılışında otomatik işlenen düzenli (tekrarlayan) işlemlerin sadece bir SnackBar yerine şık bir pop-up diyalog penceresinde detaylı şekilde listelenmesi sağlandı.
- **Tutar Sınırı ve Kırmızı Uyarı Düzeltmesi:** Sayı formatlayıcısının (`ThousandsFormatter`) dahili limiti `999.999.999.999.999 ₺` düzeyine çekilerek kullanıcının miktar alanına limitin üzerinde giriş yapabilmesi sağlandı. Böylece `9.999.999.999 ₺` sınırını aşan değerlerde `'En fazla 9.999.999.999 ₺ girilebilir.'` kırmızı uyarı mesajının görüntülenmeme sorunu çözüldü.
- **Diyalog Boyut Stabilizasyonu:** Yeni işlem ekleme penceresinde uyarı mesajı çıktığında "Devam Et" butonunun aşağı kaymasını engellemek amacıyla adım yüksekliği `150.0` olarak sabitlendi ve içerik kaydırma fizikliği `ClampingScrollPhysics` olarak düzenlendi.
- **Düzenli İşlemleri Düzenleme Desteği:** Düzenli İşlemler ekranındaki miktar düzenleme penceresi de `ThousandsFormatter` formatlayıcı, `9.999.999.999 ₺` limit aşımı kontrolü, kırmızı uyarı mesajı ve butonu pasifleştirme akışıyla donatılarak diğer formlarla tamamen tutarlı hale getirildi.
- **Raporlarda Çoklu Kategori Seçimi:** Aylık Detay Raporu altındaki "Ay İçerisindeki İşlemler" paneline çoklu kategori filtreleme özelliği eklenerek kullanıcıların aynı anda birden fazla kategori seçebilmesi sağlandı. Seçim penceresine checkmark görsel geri bildirimi, **"Temizle"** ve **"Uygula"** butonları eklendi. Çip başlığı seçim sayısına göre dinamik hale getirildi.


### [23.06.2026] - Limit İyileştirmeleri, Düzenli İşlemler ve Katlanabilir Arayüz Güncellemeleri
- **Limitsiz Kategori Harcamalarının Dashboard Gösterimi:** Limit belirlenmeyen harcama kategorilerinin o ay harcaması varsa Dashboard bütçe listesinde gösterilmesi sağlandı. Limitsiz kategoriler için "/ Limit Yok" ve %0 doluluk oranı yansıtıldı, aşım kontrolü kapatıldı.
- **Kategori Bütçeleri Daraltılabilir Arayüzü:** Kategori Bütçeleri bölümü ana ekranda açılır-kapanır (collapsible) hale getirilerek `AnimatedSize` ile akıcı geçiş sağlandı.
- **Yaklaşan Ödemeler Boş Durum Gösterimi:** Bulunulan ay için başka planlanmış ödeme kalmadığında veya olmadığında, gizlenmek yerine yeşil bir onay işaretiyle "Bu ay için planlanmış başka bir ödemeniz bulunmuyor." bilgi kutusu gösterilmesi sağlandı.
- **Limit Barında Ay Sonu Kalan Gün Sayacı:** Ana ekrandaki genel limit barının sağ altına kalan gün sayısını gösteren sayaç yerleştirildi.
- **Düzenli İşlem Saat Standardizasyonu & Bugün Başlangıç Tarihi:** Otomatik işlenen düzenli işlemlerin sonraki çalıştırma saatleri 12:00 olarak standartlaştırıldı. Başlangıç tarihi bugün olan düzenli işlemler için ilk işlem anında anlık saatle normal işlem olarak oluşturuldu, sonraki tekrarları 12:00'ye planlandı.
- **Açılış Bildirimi İyileştirmesi:** Uygulama açılışında tek bir düzenli işlem otomatik işlendiğinde, kullanıcıya işlemin kategorisi, açıklaması ve miktarı detaylı SnackBar olarak gösterildi.

### [22.06.2026] - Yaklaşan Güncellemeler & Yol Haritası Planı
- **Detaylı Kategori Seçiminde Çoklu Seçim Özelliği (Gelecek Vizyonu):**
  - Kategori seçim ekranında çoklu seçim desteği eklenecektir.
- **Kategori Bütçeleri & Limit İyileştirmeleri:**
  - Kategori limit aşım uyarısının ekranın daha üst kısmına taşınması ve daha kompakt (isteğe göre küçültülebilir/kapatılabilir) hale getirilmesi sağlanacaktır.

### [21.06.2026] - Widget Navigasyon Düzeltmeleri, Canlı Limit Formatlama, Misafir/Kullanıcı Önbellek İzolasyonu & Rapor İyileştirmeleri
- **Widget Derin Link Navigasyonu (Widget Deep Link Navigation) Düzeltmesi:**
  - Widget üzerinden gelir/gider ekleme butonuyla uygulamaya dönüldüğünde, uygulamanın arka planda açık veya birikmiş pencereleri olması durumunda sihirbazın açılmayıp ana ekranda takılı kalması sorunu çözüldü.
  - `main.dart` altında deep link yakalandığında global `navigatorKey` üzerinden `popUntil((route) => route.isFirst)` çağrılarak arka plandaki tüm dialog ve sayfalar temizlendi, ardından `TransactionWizard` dialog penceresinin sorunsuz ve mükerrer olmadan açılması sağlandı.
- **Canlı Binlik Ayracı Formatı (ThousandsFormatter):**
  - Profil sayfasında aylık genel limit ve kategori bazlı limit giriş alanlarına sayı yazılırken canlı binlik ayracı desteği eklendi (Örn: `3200` yazarken `3.200` olarak biçimlendirilmesi).
  - Kayıt esnasında sayıların veritabanı veya ayarlara kaydedilebilmesi için binlik noktalarının temizlenmesi (`.replaceAll('.', '')`) ve `double.tryParse` ile güvenli şekilde ayrıştırılması sağlandı.
- **Misafir (Guest) ve Hesap Sahibi (Authenticated) Önbellek İzolasyonu:**
  - Misafir hesabı aktifken yapılan limit veya isim değişikliklerinin, çıkış yapıp normal kullanıcı hesabı ile giriş yapıldığında ya da tam tersi durumda birbirine yansıması/sızması sorunu giderildi.
  - `preferences_provider.dart` dosyasındaki `SharedPreferences` anahtarları, aktif kullanıcı kimliğine (guest veya kullanıcı ID'si) göre dinamik olarak (`userName_${user.id}` / `userName_guest`, `monthlyLimit_${user.id}` / `monthlyLimit_guest`) ayrıştırıldı. Böylece misafir bütçesi ile gerçek hesap verileri tamamen birbirinden bağımsız hale getirildi.
- **İşlem Listesi ve Rapor Ekranı Filtrelemeleri:**
  - Aylık İşlem Raporu ekranında dinamik kategori filtreleme çipleri (chips) ve gelişmiş filtreleme mantığı eklendi.
  - Dashboard'daki işlem başlığı "Bu Ayki İşlemler" ifadesinden "Son İşlemler" olarak güncellendi.
- **Tema İsim Güncellemeleri:**
  - "Kızıl Gece" koyu temasının ismi **"Kadife Gül"** (Crimson Noir), "Kızıl Işık" açık temasının ismi ise **"Mermer Alevi"** (Scarlet Light) olarak güncellenerek görsel anlatım zenginleştirildi.
- **Widget Görsel ve Deneyim İyileştirmeleri:**
  - Ana ekran widget boyutu 1x2 ızgara olacak şekilde revize edildi ve ekran alanını optimize etmek amacıyla yeniden boyutlandırılamaz (non-resizable) hale getirildi.
  - Widget içerisindeki "Aylık Net Durum" ve net bakiye bilgisi modern ve temiz bir görünüm için yatayda tam ortalandı (gravity/center hizalama).
  - Aylık harcama/gider miktarının, belirlenen aylık limite oranını yansıtan ve temayla uyumlu (#FFCDD2) canlı, akıllı bir **ilerleme çubuğu (Progress Bar)** widget'a eklendi. Aylık limit kaldırıldığında veya girilmediğinde çubuğun kendini gizlemesi (`View.GONE`) ve tasarımı bozmaması sağlandı.

### [20.06.2026] - Widget Entegrasyonu, Arka Plan İyileştirmeleri & Dashboard Limit Düzeltmeleri
- **Widget Üzerinden Açılış ve Mükerrer Pencere Sorunlarının Giderilmesi:**
  - Widget üzerindeki butonlara tıklandığında uygulamanın arka planda açık veya kapalı olmasından bağımsız olarak doğrudan gelir/gider ekleme penceresinin açılması sağlandı.
  - Uygulama arka planda açıkken widget'a üst üste tıklandığında dialog pencerelerinin katlanarak (üst üste 2, 3, 4 veya daha fazla) birikmesi sorunu tamamen çözüldü.
  - Android tarafında `MainActivity.kt` üzerinde `onNewIntent` metodunda `setIntent(intent)` çağrılarak intent güncellemesi sağlandı.
  - Flutter tarafında dialog durum kontrolü (`_isWizardOpen`) `static` yapılarak state re-creation durumlarında durumun kaybolması önlendi.
  - Simültane ve hızlı tıklamalarda oluşabilecek mükerrer tetiklemeleri engellemek için 1.5 saniyelik zaman damgası tabanlı bir deduplication (mükerrer önleme) yapısı entegre edildi.
- **Dashboard Veri ve Bütçe Limitlerinin Düzeltilmesi:**
  - Ana sayfada (Dashboard) aylık harcama limitleri ve bütçe hesaplamalarının eksik yapılmasına yol açan son 20 işlem limiti kaldırıldı.
  - `recentTransactionsProvider` yerine tüm işlemleri çeken `transactionStreamProvider` kullanımına geçildi.
  - İşlemler ana ekranda ay bazlı olarak dinamik şekilde filtrelendi. Böylece aylık gider/gelir toplamları ve kategori bütçe dolulukları o ayın *tüm* işlemlerini doğru yansıtacak şekilde düzeltildi.
  - Ana sayfadaki "Son İşlemler" başlığı "Bu Ayki İşlemler" olarak güncellendi.

### [15.06.2026] - Tarih Yerelleştirmesi, Kapatma Hızları & Animasyon Optimizasyonları
- **Tarihlerin ve DatePicker'ın Türkçeleştirilmesi:** 
  - Gelir ve gider ekleme sihirbazındaki tarih formatları ile işlem listelerindeki tarih kartları tamamen Türkçe (Örn: *14 June 2026* yerine *14 Haziran 2026*) olarak güncellendi.
  - Tarih seçim takvim penceresinin (DatePicker) İngilizce açılması sorunu `flutter_localizations` entegrasyonu ve `MaterialApp` yerelleştirme delegelerinin tanımlanmasıyla çözüldü. Takvim arayüzü tamamen Türkçe yapıldı.
- **Tema Seçim Paneli Kapanış Animasyonu Yavaşlatılması:**
  - Profil ekranındaki görünüm teması seçim alt panelinin (Bottom Sheet) kapanış hızı yavaşlatıldı. Açılış süresi `400ms`, kapanış süresi `900ms` olarak ayarlanarak geçişin çok daha akıcı, yumuşak ve premium hissedilmesi sağlandı.

### [14.06.2026] - Çoklu Tema (Multi-Theme) Sistemi & Premium Arayüz
- **12 Premium Renk Paleti**: Kullanıcıların uygulamayı tamamen kişiselleştirebilmesi için 12 adet premium renk paleti tanımlandı ve entegre edildi.
  - *Koyu Temalar (Üstte):* Gece Yarısı (Midnight Sky), Zümrüt Ormanı (Emerald Forest), Kehribar Sarısı (Cyberpunk Amber), Ametist Lavanta (Royal Amethyst), Kızıl Günbatımı (Crimson Sunset), Safir Mavi (Sapphire Blue), Kadife Gül (Crimson Noir).
  - *Açık Temalar (Altta):* Krem Mavi (Cream Blue - Nike Air Max 1 ilhamlı), Klasik Aydınlık (Classic Light), Okyanus Mavisi (Ocean Blue), Sakura Pembe (Sakura Pink), Mermer Alevi (Scarlet Light).
- **Dinamik Renk Bağlantıları**: `AppColors` sınıfı dinamik getter'lar ile yeniden kurgulandı, böylece projedeki 170'ten fazla statik renk referansı kod değişikliği gerektirmeden seçilen tema paletini anında uygulamaya başladı.
- **Durum Yönetimi ve Kalıcılık**: Seçilen temanın `SharedPreferences` ile cihaz hafızasında tutulması ve uygulama yeniden başlatıldığında otomatik yüklenmesi Riverpod ile sağlandı.
- **Arayüz Taşma (Overflow) ve Panel UX Geliştirmeleri**:
  - Profil ekranındaki tema seçim alt panelinde (Bottom Sheet) oluşan 1.7 piksellik taşma uyarısı (`BOTTOM OVERFLOWED BY 1.7 PIXELS`), `SafeArea`, `useSafeArea: true` kullanımı ve scroll dolgularının `SingleChildScrollView` içine taşınmasıyla kalıcı olarak çözüldü.
  - Sürüklemeyi engelleyen scroll yapısı düzeltilerek başlık alanı dışarı taşındı ve **aşağı sürükleyerek kapatma (drag-to-dismiss)** aktif hale getirildi. Ayrıca sağ üst köşeye şık bir **kapatma/çarpı butonu (`Icons.close`)** eklendi.
  - Kategori bütçelerindeki kartlara basınca açılan alt menünün kapanış animasyonu yavaşlatılarak akıcı hale getirildi, menü kapanırken yaşanan arka plan simsiyah kalma ve çökme sorunları giderildi.
- **İşlem Sihirbazı (Wizard) İyileştirmeleri**: Haftalık, aylık ve yıllık düzenli gelir/gider ekleme özellikleri zenginleştirildi, ekran aşağı kayarken oluşan taşma şeridi hataları giderildi.


### [14.06.2026] - Gelişmiş Bütçe ve Limit Yönetimi (Smart Budget Tracking)
- **Aylık ve Kategorik Limitler:** Kullanıcıların profil ekranından genel aylık harcama limitleri ve spesifik gider kategorileri için özel limitler (Örn: Mutfak için 5.000 ₺) belirleyebilmesi sağlandı.
- **Akıllı Uyarı Sistemi:** Limit belirleme sırasında matematiksel tutarsızlıkları (kategori limitleri toplamının genel limiti aşması gibi) yakalayan ve eşitleme önerisi sunan akıllı diyaloglar eklendi.
- **Ana Ekran (Dashboard) Entegrasyonu:**
  - Ana ekrana limitleri doluluk oranlarına (veya parasal aşım miktarlarına) göre akıllıca sıralayan yatay (horizontal) **"Kategori Bütçeleri"** kartları eklendi.
  - Limit aşımlarında ana ekranda beliren, birleştirilmiş (konsolide) ve tıklandığında detayı için alt menü (Bottom Sheet) açan dinamik kırmızı uyarı afişleri kurgulandı.
- **Kullanıcı Deneyimi (UX) İyileştirmeleri:** Limit sayılarının daha okunaklı olması için binlik ayracı (Örn: 17.001 ₺) formatlamasına geçildi.

### [22.04.2026] - Büyük Güvenlik ve Auth Güncellemesi
- **Supabase Auth Entegrasyonu:** Kullanıcıların e-posta ile giriş yapabilmesi sağlandı.
- **OTP (Tek Kullanımlık Kod) Akışı:** Kayıt ve giriş süreçleri e-posta doğrulama kodu ile daha güvenli hale getirildi.
- **Özel Şifre Belirleme:** Kod doğrulandıktan sonra kullanıcının kendi şifresini belirlediği akış (`UpdatePasswordScreen`) oluşturuldu.
- **Offline-First Yetkilendirme:** Veritabanına `userId` alanı eklenerek her kullanıcının sadece kendi verisini görmesi sağlandı (Drift Schema v2).
- **GitHub Hazırlığı (.env):** Hassas Supabase API anahtarları `.env` dosyasına taşındı ve kaynak kodun güvenliği sağlandı.
- **UI İyileştirmeleri:** Şifre gizleme/gösterme (göz ikonu) ve giriş ekranındaki ekran taşma (overflow) hataları giderildi.

---
*Bu dosya projenin hafızasıdır ve gitignore edilerek yerelde saklanmaktadır.*
