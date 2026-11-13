# Music Player — iOS sürümü

Windows'taki WinForms `MusicPlayer.exe` uygulamasının iOS (SwiftUI) karşılığı.
Aynı `muzik.pak` formatını (`MUSPAK1_`) okur, aynı şarkıları aynı koyu temayla çalar.

> Not: Windows uygulaması doğrudan iOS'a "dönüştürülemez". Bu, aynı işi yapan
> sıfırdan yazılmış bir SwiftUI uygulamasıdır.

## Klasör yapısı

```
project.yml                         XcodeGen proje tanımı
MusicPlayer/Sources/
  MusicPlayerApp.swift              @main giriş
  Theme.swift                       renk paleti (Controls.cs ile aynı)
  PakLibrary.swift                  muzik.pak okuyucu/yazıcı (birebir format)
  PlayerModel.swift                 AVAudioPlayer tabanlı oynatma + içe aktarma
  ContentView.swift                 arayüz (arama, liste, now playing)
MusicPlayer/Resources/
  Assets.xcassets/                  uygulama ikonu + accent rengi
.github/workflows/build-ipa.yml     GitHub Actions ile imzasız IPA üretir
tools/restore-pak.ps1               muzik.pak'ı geri dönüşüm kutusundan çıkarır
tools/serve.ps1                     muzik.pak'ı Wi-Fi üzerinden telefona indirtir
```

## Gereksinimler

- Bir GitHub hesabı (public repo önerilir: macOS runner dakikaları ücretsizdir).
- İnternet. Mac gerekmez — IPA'yı GitHub'ın macOS runner'ı üretir.
- iPhone'da kurulum için **Sideloadly + Apple ID** (kısa bir kablo oturumu yeter;
  asıl 2 GB'lık müzik Wi-Fi ile taşınır).

## 1) GitHub'a yükle

Bu `ios` klasörünü bir repo kökü olarak yükle:

```powershell
cd C:\Users\Spook\Desktop\source\ios
git init
git add .
git commit -m "MusicPlayer iOS"
gh repo create musicplayer-ios --public --source=. --remote=origin --push
```

(`gh` kurulu ve giriş yapılmış olmalı. Değilse GitHub'da boş repo açıp
`git remote add origin ...` + `git push -u origin main` kullan.)

## 2) IPA'yı üret

- GitHub'da **Actions → Build unsigned IPA → Run workflow** (veya `main`'e push).
- Bittiğinde iş çalışmasının altındaki **MusicPlayer-ipa** artifact'ını indir.
- İçinden `MusicPlayer.ipa` çıkar (uygulama müziği içermediği için ~2 MB).

## 3) iPhone'a kur (Sideloadly)

1. Sideloadly'yi aç, iPhone'u kablo ile bağla.
2. `MusicPlayer.ipa` dosyasını seç, Apple ID'ni gir, **Start**.
3. iPhone'da: **Ayarlar → Genel → VPN ve Cihaz Yönetimi** → geliştirici profilini güven.
4. (iOS 16+) **Ayarlar → Gizlilik ve Güvenlik → Geliştirici Modu**'nu aç, telefonu yeniden başlat.

> Ücretsiz Apple ID imzası 7 gün geçerlidir; süre dolunca Sideloadly ile yeniden imzala.
> Kalıcı/kablosuz çözüm için SideStore veya ücretli imza servisi kullanılabilir.

## 4) Müziği telefona taşı (kablosuz)

Windows'ta:

```powershell
cd C:\Users\Spook\Desktop\source\ios\tools
powershell -ExecutionPolicy Bypass -File .\restore-pak.ps1   # muzik.pak'i geri dönüşüm kutusundan çıkarır
powershell -ExecutionPolicy Bypass -File .\serve.ps1          # Wi-Fi sunucusu + adresleri yazar
```

iPhone'da:

1. Telefon ve PC **aynı Wi-Fi**'de olsun.
2. **Safari**'de `serve.ps1`'in yazdığı `http://192.168.x.x:8000/muzik.pak` adresini aç.
3. İndir → **Dosyalar**'a kaydet (2.1 GB, biraz sürebilir).
4. **Music** uygulamasını aç → **+ → muzik.pak içe aktar** → indirdiğin dosyayı seç.
   (İçe aktarma sırasında ~2 GB ekstra boş alan gerekir.)
5. Hazır. `+ → MP3 ekle` ile tek tek şarkı da ekleyebilirsin.

## Format uyumu

`PakLibrary.swift`, `src/PakLibrary.cs` ile birebir aynı byte düzenini kullanır:

```
"MUSPAK1_" + 3 sıfır byte
tekrar (dosya sonuna kadar):
  int32 LE  isim uzunluğu (UTF-8 bayt)
  byte[]    isim, örn "Sanatçı\Sanatçı - Şarkı.mp3"
  int64 LE  veri uzunluğu
  byte[]    mp3 verisi
```

Bu yüzden Windows'ta üretilmiş `muzik.pak` olduğu gibi çalışır.
