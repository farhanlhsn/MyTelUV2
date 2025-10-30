# MyTelUV2

Aplikasi MyTelU V2 - Backend (Node.js + Express + Prisma) dan Mobile (Flutter + GetX)

## 🎯 Quick Start

```bash
# Install dependencies
npm run install-all

# Run di platform pilihan Anda:
npm run start:macos      # macOS Desktop 
npm run start:windows    # Windows Desktop
npm run start:ios        # iOS Simulator/Device
npm run start:android    # Android Emulator/Device
npm start                # Chrome/Web (secure storage tidak work)
```

## 📋 Available Commands

| Command | Deskripsi |
|---------|-----------|
| `npm start` | Backend + Mobile di Chrome |
| `npm run start:macos` | Backend + Mobile di macOS |
| `npm run start:windows` | Backend + Mobile di Windows |
| `npm run start:ios` | Backend + Mobile di iOS |
| `npm run start:android` | Backend + Mobile di Android |
| `npm run start:all` | Backend + Mobile di semua device |
| `npm run backend` | Backend only |
| `npm run mobile:chrome` | Mobile di Chrome only |
| `npm run mobile:macos` | Mobile di macOS only |
| `npm run mobile:windows` | Mobile di Windows only |
| `npm run mobile:ios` | Mobile di iOS only |
| `npm run mobile:android` | Mobile di Android only |
| `npm run install-all` | Install semua dependencies |

## 🚀 Cara Menjalankan

### Opsi 1: Run di Chrome (Web) - Untuk Development Cepat
```bash
npm start
```
⚠️ **Catatan**: `flutter_secure_storage` tidak bekerja di web, jadi login akan error. Gunakan desktop atau mobile emulator untuk testing login.

### Opsi 2: Run di Desktop Platform 

**macOS (Mac/Linux):**
```bash
npm run start:macos
```

**Windows:**
```bash
npm run start:windows
```

✅ **Recommended**: Full features termasuk secure storage berfungsi dengan baik di desktop.

### Opsi 3: Run di Mobile Platform

**iOS (perlu Mac + Xcode + iOS Simulator/Device):**
```bash
npm run start:ios
```

**Android (perlu Android Studio + Emulator/Device):**
```bash
npm run start:android
```

### Opsi 4: Run di Semua Device
```bash
npm run start:all
```

### Run Backend atau Mobile Saja

**Backend only:**
```bash
npm run backend
```

**Mobile only:**
```bash
npm run mobile:chrome      # Chrome/Web
npm run mobile:macos       # macOS Desktop
npm run mobile:windows     # Windows Desktop
npm run mobile:ios         # iOS Simulator/Device
npm run mobile:android     # Android Emulator/Device
```

## 📦 Install Dependencies

```bash
npm run install-all
```

## 🔧 Setup

1. **Copy .env file** (di root project):
```env
DATABASE_URL="your_database_url"
JWT_SECRET="your_jwt_secret"
JWT_EXPIRES_IN="1d"
PORT=5050
```

2. **Setup Prisma**:
```bash
cd backend
npm run prisma:migrate
npm run prisma:generate
```

## 📱 Struktur Project

```
MyTelUV2/
├── backend/              # Node.js + Express + Prisma
│   ├── controllers/      # Business logic
│   ├── middlewares/      # Rate limiter, validation
│   ├── routes/          # API routes
│   ├── prisma/          # Database schema & migrations
│   └── utils/           # Helper functions
│
├── mobile/              # Flutter + GetX
│   └── lib/
│       ├── app/         # App config & routes
│       ├── bindings/    # Dependency injection
│       ├── controllers/ # State management
│       ├── models/      # Data models
│       ├── pages/       # UI screens
│       └── services/    # API calls
│
└── package.json         # Root scripts

```

## 🎯 API Endpoints

### Auth
- `POST /api/auth/register` - Register user baru
- `POST /api/auth/login` - Login user

### User Flow
```
Login → Register → Login → Home → Profile → Logout
```

## 🔐 Features

### Backend
- ✅ JWT Authentication
- ✅ Password Hashing (bcrypt)
- ✅ Rate Limiting
- ✅ Input Sanitization
- ✅ CORS Configuration
- ✅ Security Headers (Helmet)
- ✅ Prisma ORM

### Mobile
- ✅ GetX State Management
- ✅ Secure Storage (Token & User Data)
- ✅ Login/Register Flow
- ✅ Profile Page
- ✅ Logout with Confirmation
- ✅ Beautiful UI

## ⚠️ Important Notes

1. **Flutter Secure Storage**: 
   - ❌ **TIDAK WORK** di Chrome/Web
   - ✅ **WORK** di macOS, Windows, iOS, Android
   
2. **CORS**: Sudah dikonfigurasi untuk allow mobile apps dan localhost.

3. **Port**: Backend berjalan di port 5050 (bisa diubah di .env).

4. **Platform Requirements**:
   - **Windows**: Perlu Visual Studio 2022 dengan C++ Desktop Development
   - **macOS**: Perlu Xcode dan Command Line Tools
   - **iOS**: Perlu Mac + Xcode + iOS Simulator
   - **Android**: Perlu Android Studio + Android SDK + Emulator

## 🐛 Troubleshooting

### Error: More than one device connected
Gunakan script spesifik untuk platform yang Anda inginkan:
```bash
npm run start:macos      # untuk macOS
npm run start:windows    # untuk Windows
npm run start:ios        # untuk iOS
npm run start:android    # untuk Android
```

### Error: MissingPluginException flutter_secure_storage
Rebuild aplikasi (contoh untuk macOS):
```bash
cd mobile
flutter clean
flutter pub get
flutter run -d macos
```

Untuk platform lain, ganti `macos` dengan `windows`, `ios`, atau `android`.

### Error: No devices found
Pastikan:
- **macOS/Windows**: Desktop development sudah di-enable di Flutter
- **iOS**: Simulator sudah running atau device sudah connected
- **Android**: Emulator sudah running atau device sudah connected dan USB debugging aktif

Cek device dengan:
```bash
cd mobile
flutter devices
```
