# 🖐 Finger Jump

Sonsuz tırmanma oyunu. Parmağınla yönlendir, boss'ları yen, rekoru kır.

## Oynanış

Oyuncu otomatik zıplar — senin işin **yatay hareketi** kontrol etmek:

| Kontrol Modu | Nasıl Çalışır |
|---|---|
| **Jiroskop** | Telefonu sağa/sola eğ |
| **Kamera** | Ön kamera — parmak X pozisyonu oyuncuyu yönlendirir |
| **Ateş** | Gyro: ekrana dokun · Kamera: yumruk yap |

## Kediler

Oyun başında 5 kediden biri seçilir; her birinin küçük bir yeteneği var:

| Kedi | Yetenek |
|---|---|
| Sarman | Çevik Pati — %15 daha hızlı koşar |
| Tekir | Mıknatıs Bıyık — yakındaki coin'leri çeker |
| Kara | Dokuzuncu Can — bir kez düşüşten / boss'tan kurtulur |
| Pamuk (Van) | Van Zıplayışı — %8 daha yükseğe zıplar |
| Üç Renkli | Uğurlu Pati — her coin 2 sayılır |

## Platformlar

Portfolyodaki çiftlik sahnesinin beceri kartlarından esinlenen, sarmaşıklı çiçekli piksel kartlar:

| Kart | Davranış |
|---|---|
| Pembe çiçekli | Normal — sınırsız kullanım |
| Kuru sarmaşık, çatlak | Kırılgan — 1 zıplamadan sonra düşer |
| Altın çiçekli | Boost — 2× yüksekliğe fırlatır |

Kartların üstünde dönen piksel coin'ler var; toplam coin ve rekor kaydedilir.

## Boss Sistemi

Her **15 metre**de bir **Karga Reis** çıkar. Yalnızca X ekseninde hareket eder.
Skor arttıkça daha büyük, hızlı ve dayanıklı olur.
Ekrana dokun (veya yumruk yap) → yün yumağı fırlat.

## Teknoloji Stack'i

- **Flutter** + **Flame** (oyun motoru)
- **MediaPipe Hand Landmarker** — el/parmak tespiti (Kotlin native kanal)
- **Camera** paketi — YUV420 frame akışı → native
- **sensors_plus** — ivmeölçer (jiroskop modu)
- **shared_preferences** — yüksek skor kalıcılığı

## Kurulum

```bash
# Bağımlılıkları yükle
flutter pub get

# MediaPipe modelini indir ve yerleştir:
# assets/models/hand_landmarker.task
# (repoya dahil değil — model dosyası büyük)

# Android cihaza deploy et
flutter run
```

### MediaPipe Modeli

`hand_landmarker.task` modeli Git LFS ile yönetilmez; `.gitignore`'a eklenmiştir.  
Modeli [MediaPipe Solutions](https://developers.google.com/mediapipe/solutions/vision/hand_landmarker) sayfasından indir ve `assets/models/` klasörüne koy.

## Mimari

```
lib/
├── main.dart                    # Ekranlar, navigasyon, kamera overlay
├── game/
│   ├── finger_jump_game.dart    # Flame FlameGame — oyun döngüsü, boss, platform üretimi
│   ├── components/
│   │   ├── player_component.dart    # Fizik, çarpışma (sweep collision)
│   │   ├── platform_component.dart  # Normal / kırılgan / boost
│   │   ├── boss_component.dart      # Karga Reis, X-eksen hareketi, HP bar
│   │   ├── coin_component.dart      # Dönen piksel coin
│   │   ├── sky_backdrop.dart        # Yükseldikçe değişen gökyüzü, bulutlar, zemin
│   │   └── projectile_component.dart # Yün yumağı
│   └── systems/
│       └── input_controller.dart
└── services/
    ├── camera_hand_service.dart # Kamera başlatma, frame gönderme, olay alma
    └── gyroscope_service.dart   # İvmeölçer → EMA smooth → normalizedX
```

## Lisans

MIT
