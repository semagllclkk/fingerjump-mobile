# 🖐 Finger Jump

Sonsuz tırmanma oyunu. Parmağınla yönlendir, boss'ları yen, rekoru kır.

## Oynanış

Oyuncu otomatik zıplar — senin işin **yatay hareketi** kontrol etmek:

| Kontrol Modu | Nasıl Çalışır |
|---|---|
| **Jiroskop** | Telefonu sağa/sola eğ |
| **Kamera** | Ön kamera — parmak X pozisyonu oyuncuyu yönlendirir |
| **Ateş** | Gyro: ekrana dokun · Kamera: yumruk yap |

## Platformlar

| Renk | Tür | Davranış |
|---|---|---|
| 🟢 Yeşil | Normal | Sınırsız kullanım |
| 🟠 Turuncu | Kırılgan | 1 zıplamadan sonra kaybolur |
| 🟡 Altın | Boost | 2× yüksekliğe fırlatır |

## Boss Sistemi

Her **15 metre**de bir boss çıkar. Boss yalnızca X ekseninde hareket eder.  
Skor arttıkça boss daha büyük, daha hızlı ve daha fazla can puanına sahip olur.  
Boss'u yenmek için ekrana dokun (veya yumruk yap) → mermi fırlat.

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
│   │   ├── boss_component.dart      # X-eksen hareketi, HP bar
│   │   └── projectile_component.dart
│   └── systems/
│       └── input_controller.dart
└── services/
    ├── camera_hand_service.dart # Kamera başlatma, frame gönderme, olay alma
    └── gyroscope_service.dart   # İvmeölçer → EMA smooth → normalizedX
```

## Lisans

MIT
