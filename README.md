# 💬 MQTT Mesajlaşma Uygulaması (Flutter)

Bu proje, iki farklı cihaz arasında **gerçek zamanlı mesajlaşma** imkânı sunan bir Flutter uygulamasıdır. MQTT protokolü ile çalışır ve cihazlar arası hızlı, düşük gecikmeli iletişim sağlar.

---

## ⚙️ Özellikler

- 🌐 MQTT (HiveMQ) protokolü ile bağlantı
- 💬 Gerçek zamanlı mesaj gönderme ve alma
- 🆔 Cihazları ayırmak için benzersiz clientID kullanımı
- 📝 Gönderilen ve alınan mesajları listeleme
- 🖼️ Hafif mavimsi arka plan

---

## 🔧 Kurulum

### 1. Projeyi Klonla
```bash
git clone https://github.com/sebahattinn/MqttMessageApp.git
cd MqttMessageApp
flutter pub get
flutter run
