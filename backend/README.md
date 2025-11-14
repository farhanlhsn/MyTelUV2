# MyTelU Backend API

Backend API untuk sistem MyTelU - Platform manajemen akademik dan parkir kampus.

## 📋 Table of Contents

- [Features](#features)
- [Tech Stack](#tech-stack)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Database Setup](#database-setup)
- [Running the Application](#running-the-application)
- [API Documentation](#api-documentation)
- [Testing](#testing)
- [Project Structure](#project-structure)

---

## ✨ Features

### 1. Authentication & Authorization
- JWT-based authentication
- Role-based access control (RBAC)
- Support untuk 3 role: ADMIN, DOSEN, MAHASISWA
- Secure password hashing dengan bcrypt

### 2. Sistem Akademik
- **Matakuliah**: CRUD mata kuliah
- **Kelas**: Manajemen kelas dengan jadwal
- **Peserta Kelas**: KRS (Kartu Rencana Studi) untuk mahasiswa
- **Absensi**: Sistem absensi dengan tracking lokasi GPS
- Schedule conflict detection
- Soft delete untuk data integrity

### 3. Manajemen Kendaraan
- Registrasi kendaraan dengan foto
- Upload foto kendaraan dan STNK ke Cloudflare R2
- Verifikasi kendaraan oleh admin
- Tracking status verifikasi

### 4. Sistem Parkir (Schema ready)
- Log parkir kendaraan
- Tracking kapasitas parkiran real-time
- Location-based dengan PostGIS

### 5. Security Features
- Rate limiting (brute force protection)
- Input sanitization
- Helmet.js security headers
- CORS configuration
- File upload validation

---

## 🛠 Tech Stack

- **Runtime**: Node.js
- **Framework**: Express.js
- **Database**: PostgreSQL with PostGIS extension
- **ORM**: Prisma
- **Authentication**: JWT (jsonwebtoken)
- **File Storage**: Cloudflare R2 (S3-compatible)
- **Security**: Helmet, bcrypt, express-rate-limit
- **File Upload**: Multer

---

## 📦 Prerequisites

Pastikan sudah terinstall:

- Node.js >= 16.x
- PostgreSQL >= 13.x dengan PostGIS extension
- npm atau yarn
- Cloudflare R2 account (untuk file storage)

---

## 🚀 Installation

### 1. Clone Repository

```bash
git clone <repository-url>
cd MyTelUV2/backend
```

### 2. Install Dependencies

```bash
npm install
```

### 3. Environment Variables

Buat file `.env` di root folder (bukan di folder backend):

```bash
# Database
DATABASE_URL="postgresql://username:password@localhost:5432/mytelu_db?schema=public"

# JWT Secret
JWT_SECRET="your-super-secret-jwt-key-change-this-in-production"

# Server
PORT=5050
NODE_ENV=development

# Cloudflare R2
R2_ACCOUNT_ID="your-r2-account-id"
R2_ACCESS_KEY_ID="your-r2-access-key"
R2_SECRET_ACCESS_KEY="your-r2-secret-key"
R2_BUCKET_NAME="mytelu-bucket"
R2_PUBLIC_URL="https://your-bucket.r2.cloudflarestorage.com"
```

> **Note**: File `.env` ada di root folder project, bukan di folder backend

---

## 🗄 Database Setup

### 1. Create Database

```bash
# Login ke PostgreSQL
psql -U postgres

# Create database
CREATE DATABASE mytelu_db;

# Connect to database
\c mytelu_db

# Enable PostGIS extension
CREATE EXTENSION IF NOT EXISTS postgis;

# Exit
\q
```

### 2. Run Prisma Migrations

```bash
cd backend
npx prisma migrate dev
```

### 3. Generate Prisma Client

```bash
npx prisma generate
```

### 4. (Optional) Seed Sample Data

Generate dummy data untuk testing:

```bash
node utils/akademikSeeder.js
```

Seeder akan membuat:
- 1 Admin user
- 5 Dosen users
- 20 Mahasiswa users
- 8 Matakuliah
- ~12 Kelas dengan jadwal berbeda
- Random enrollments (KRS)
- Sample absensi data untuk 5 hari terakhir

**Test Credentials:**
- Admin: `admin` / `password123`
- Dosen: `john.doe` / `password123`
- Mahasiswa: `mahasiswa1` / `password123`

---

## ▶️ Running the Application

### Development Mode

```bash
cd backend
node server.js
```

Server akan running di `http://localhost:5050`

### Production Mode

```bash
NODE_ENV=production node server.js
```

---

## 📚 API Documentation

### Base URL

```
http://localhost:5050/api
```

### Available Endpoints

#### Authentication (`/api/auth`)
- `POST /register` - Register user baru
- `POST /login` - Login dan dapatkan JWT token
- `GET /me` - Get current user info (protected)

#### Akademik (`/api/akademik`)
- **Matakuliah**
  - `POST /matakuliah` - Create matakuliah (Admin)
  - `GET /matakuliah` - Get all matakuliah
  - `GET /matakuliah/:id` - Get matakuliah by ID
  - `PUT /matakuliah/:id` - Update matakuliah (Admin)
  - `DELETE /matakuliah/:id` - Delete matakuliah (Admin)

- **Kelas**
  - `POST /kelas` - Create kelas (Admin/Dosen)
  - `GET /kelas` - Get all kelas
  - `GET /kelas/dosen` - Get kelas by dosen (Dosen)
  - `GET /kelas/:id` - Get kelas by ID
  - `PUT /kelas/:id` - Update kelas (Admin/Dosen)
  - `DELETE /kelas/:id` - Delete kelas (Admin/Dosen)

- **Peserta Kelas**
  - `POST /kelas/daftar` - Daftar kelas/KRS (Mahasiswa)
  - `DELETE /kelas/:id/drop` - Drop kelas (Mahasiswa)
  - `GET /kelas/ku` - Get my enrolled kelas (Mahasiswa)
  - `GET /kelas/:id/peserta` - Get peserta list (Dosen/Admin)

- **Absensi**
  - `POST /absensi` - Create absensi (Mahasiswa/Dosen)
  - `GET /absensi/ku` - Get my absensi history
  - `GET /absensi/kelas/:id` - Get kelas absensi list (Dosen/Admin)
  - `GET /absensi/kelas/:id/stats` - Get absensi statistics (Dosen/Admin)

#### Kendaraan (`/api/kendaraan`)
- `POST /register` - Register kendaraan with photos
- `GET /` - Get my kendaraan
- `DELETE /:id` - Delete kendaraan
- `POST /verify` - Verify kendaraan (Admin)
- `GET /all-unverified` - Get unverified kendaraan (Admin)
- `GET /all-kendaraan` - Get all kendaraan (Admin)

**Detailed API Documentation**: [AKADEMIK_API.md](./docs/AKADEMIK_API.md)

---

## 🧪 Testing

### Using cURL

**Login:**
```bash
curl -X POST http://localhost:5050/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "username": "admin",
    "password": "password123"
  }'
```

**Get Matakuliah:**
```bash
curl -X GET http://localhost:5050/api/akademik/matakuliah \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

**Create Matakuliah:**
```bash
curl -X POST http://localhost:5050/api/akademik/matakuliah \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "nama_matakuliah": "Pemrograman Web",
    "kode_matakuliah": "IF301"
  }'
```

**Mahasiswa Daftar Kelas:**
```bash
curl -X POST http://localhost:5050/api/akademik/kelas/daftar \
  -H "Authorization: Bearer MAHASISWA_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "id_kelas": 1
  }'
```

**Create Absensi:**
```bash
curl -X POST http://localhost:5050/api/akademik/absensi \
  -H "Authorization: Bearer MAHASISWA_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "id_kelas": 1,
    "type_absensi": "LOKAL_ABSENSI",
    "latitude": -6.2088,
    "longitude": 106.8456
  }'
```

### Using Postman/Thunder Client

1. Import collection dari `docs/postman_collection.json` (jika ada)
2. Set environment variable `base_url` = `http://localhost:5050`
3. Login untuk get JWT token
4. Set token di Authorization header untuk protected routes

---

## 📁 Project Structure

```
backend/
├── config/
│   └── r2Config.js           # Cloudflare R2 configuration
├── controllers/
│   ├── authController.js      # Auth logic
│   ├── akademikController.js  # Akademik CRUD logic
│   └── kendaraanController.js # Kendaraan management
├── middlewares/
│   ├── authMiddleware.js      # JWT & RBAC middleware
│   ├── multerMiddleware.js    # File upload handling
│   ├── rateLimiterMiddleware.js  # Rate limiting
│   └── validationMiddleware.js   # Input validation
├── routes/
│   ├── authRoutes.js          # Auth endpoints
│   ├── akademikRoutes.js      # Akademik endpoints
│   └── kendaraanRoutes.js     # Kendaraan endpoints
├── utils/
│   ├── prisma.js              # Prisma client instance
│   ├── r2FileHandler.js       # R2 upload/delete helpers
│   └── akademikSeeder.js      # Database seeder
├── prisma/
│   ├── schema.prisma          # Database schema
│   └── migrations/            # Migration files
├── docs/
│   └── AKADEMIK_API.md        # API documentation
├── server.js                  # Express app entry point
├── package.json
└── README.md
```

---

## 🔒 Security Best Practices

1. **Never commit `.env` file** - Sudah ada di `.gitignore`
2. **Change JWT_SECRET** - Gunakan random string yang kuat
3. **Use HTTPS in production** - Deploy dengan SSL/TLS
4. **Rate limiting enabled** - Protection dari brute force
5. **Input sanitization** - Semua input di-sanitize
6. **SQL Injection protection** - Menggunakan Prisma ORM
7. **File upload validation** - Size & type validation

---

## 🐛 Common Issues

### Issue: Prisma Client Error
```
Error: @prisma/client did not initialize yet
```
**Solution:**
```bash
cd backend
npx prisma generate
```

### Issue: PostGIS Extension Error
```
ERROR: type "point" does not exist
```
**Solution:**
```bash
psql -U postgres -d mytelu_db -c "CREATE EXTENSION IF NOT EXISTS postgis;"
```

### Issue: R2 Upload Failed
**Solution:**
- Check R2 credentials di `.env`
- Pastikan bucket sudah dibuat
- Verify R2 access key memiliki permission yang cukup

### Issue: Port Already in Use
```
Error: listen EADDRINUSE: address already in use :::5050
```
**Solution:**
```bash
# Kill process on port 5050
lsof -ti:5050 | xargs kill -9

# Or change PORT in .env
```

---

## 📝 Development Notes

### Soft Delete Pattern
Semua model menggunakan soft delete dengan field `deletedAt`:
```javascript
// Soft delete
await prisma.kelas.update({
  where: { id_kelas: 1 },
  data: { deletedAt: new Date() }
});

// Filter active records
await prisma.kelas.findMany({
  where: { deletedAt: null }
});
```

### PostGIS Time Fields
Field `jam_mulai` dan `jam_berakhir` menggunakan PostgreSQL TIME type:
```javascript
// Use raw query for time fields
await prisma.$executeRaw`
  INSERT INTO kelas (jam_mulai, jam_berakhir, ...)
  VALUES ('08:00:00'::time, '10:00:00'::time, ...)
`;
```

### Composite Primary Key
`PesertaKelas` menggunakan composite PK:
```javascript
where: {
  id_mahasiswa_id_kelas: {
    id_mahasiswa: 1,
    id_kelas: 2
  }
}
```

---

## 🤝 Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

## 📄 License

This project is private and confidential.

---

## 📞 Support

Untuk pertanyaan atau issue:
- Create issue di repository
- Contact: [your-email@example.com]

---

## 🎯 Roadmap

- [ ] WebSocket untuk real-time absensi
- [ ] Face recognition integration
- [ ] Email notification system
- [ ] Mobile app API optimization
- [ ] Report generation (PDF/Excel)
- [ ] Dashboard analytics
- [ ] Anomaly detection system
- [ ] Parking management implementation

---

**Happy Coding! 🚀**


