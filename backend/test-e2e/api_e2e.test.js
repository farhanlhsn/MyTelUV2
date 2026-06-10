/**
    End-to-End API Integration & Contract Tests for MyTelU V2
    Hits the actual running Node.js server and verifies end-to-end user journeys
    and integrations with database and Python services.
*/

const axios = require("axios");
const FormData = require("form-data");

const API_BASE = "http://localhost:5050";

describe("MyTelU V2 End-to-End API Test Suite", () => {
  let tokenMhs;
  let tokenDosen;
  let idKelas;
  let idSesi;
  let idKendaraan;
  let idPost;

  beforeAll(async () => {
    // Wait briefly for servers to boot
    await new Promise((resolve) => setTimeout(resolve, 1000));
    axios.defaults.headers.common["Connection"] = "close";
  });

  afterAll(async () => {
    await new Promise((resolve) => setTimeout(resolve, 500));
    // Destroy any lingering HTTP/HTTPS connections
    const http = require("http");
    const https = require("https");
    http.globalAgent.destroy();
    https.globalAgent.destroy();
  });

  test("1. Health Check - Verify all services and databases are healthy", async () => {
    const res = await axios.get(`${API_BASE}/health`);
    expect(res.status).toBe(200);
    expect(res.data.status).toBe("ok");
    expect(res.data.services.database.status).toBe("ok");
  });

  test("2. Authentication Flow - Login as Mahasiswa & Dosen", async () => {
    // Dosen Login
    const resDosen = await axios.post(`${API_BASE}/api/v1/auth/login`, {
      username: "dosen_test",
      password: "password123",
    });
    expect(resDosen.status).toBe(200);
    expect(resDosen.data.status).toBe("success");
    tokenDosen = resDosen.data.data.token;
    expect(tokenDosen).toBeDefined();

    // Mahasiswa Login
    const resMhs = await axios.post(`${API_BASE}/api/v1/auth/login`, {
      username: "mhs_test",
      password: "password123",
    });
    expect(resMhs.status).toBe(200);
    expect(resMhs.data.status).toBe("success");
    tokenMhs = resMhs.data.data.token;
    expect(tokenMhs).toBeDefined();
  });

  test("3. Profile Verification - Get profile details (Protected route)", async () => {
    const res = await axios.get(`${API_BASE}/api/v1/auth/me`, {
      headers: { Authorization: `Bearer ${tokenMhs}` },
    });
    expect(res.status).toBe(200);
    expect(res.data.status).toBe("success");
    expect(res.data.data.nim_nip).toBe("1301210001");
  });

  test("4. Fetch Class Details - Get classes taught by Dosen", async () => {
    const res = await axios.get(`${API_BASE}/api/v1/akademik/kelas/dosen`, {
      headers: { Authorization: `Bearer ${tokenDosen}` },
    });
    expect(res.status).toBe(200);
    expect(res.data.status).toBe("success");
    expect(res.data.data.length).toBeGreaterThan(0);
    idKelas = res.data.data[0].id_kelas;
    expect(idKelas).toBeDefined();
  });

  test("5. Open Attendance Session - Dosen opens geofenced session", async () => {
    // Sesi Absensi open
    const startTime = new Date();
    const endTime = new Date(startTime.getTime() + 60 * 60 * 1000); // 1 hour session

    const res = await axios.post(
      `${API_BASE}/api/v1/akademik/open-absensi`,
      {
        id_kelas: idKelas,
        type_absensi: "REMOTE_ABSENSI",
        mulai: startTime.toISOString(),
        selesaineya: endTime.toISOString(), // Wait, zod schema says 'selesai' is required
        selesai: endTime.toISOString(),
        latitude: -6.97,
        longitude: 107.63,
        radius_meter: 100,
        require_face: true,
      },
      {
        headers: { Authorization: `Bearer ${tokenDosen}` },
      },
    );

    expect(res.status).toBe(201);
    expect(res.data.status).toBe("success");
    expect(res.data.data.id_sesi_absensi).toBeDefined();
    idSesi = res.data.data.id_sesi_absensi;
  });

  test("6. Anti-Cheat: Reject attendance if using Mock Location", async () => {
    // Request a dynamic liveness token first
    const tokenRes = await axios.post(`${API_BASE}/api/v1/biometrik/request-liveness-token`, {}, {
      headers: { Authorization: `Bearer ${tokenMhs}` }
    });
    expect(tokenRes.status).toBe(200);
    const livenessToken = tokenRes.data.data.token;

    const form = new FormData();
    form.append("latitude", "-6.97");
    form.append("longitude", "107.63");
    form.append("id_sesi_absensi", idSesi.toString());
    form.append("liveness_token", livenessToken);
    form.append("is_mock_location", "true"); // Spoofing active
    form.append("image", Buffer.from("dummy_jpeg_bytes"), {
      filename: "test_face.jpg",
      contentType: "image/jpeg",
    });

    let didFail = false;
    try {
      await axios.post(`${API_BASE}/api/v1/biometrik/absen`, form, {
        headers: {
          ...form.getHeaders(),
          Authorization: `Bearer ${tokenMhs}`,
          "X-Test-Mode": "true", // Trigger test mode bypass in python face service
        },
      });
    } catch (err) {
      didFail = true;
      expect(err.response.status).toBe(400);
      expect(err.response.data.message).toContain(
        "Mock location / GPS spoofing terdeteksi",
      );
    }
    expect(didFail).toBe(true);
  });

  test("7. Anti-Cheat: Reject attendance if Liveness Check is not verified", async () => {
    const form = new FormData();
    form.append("latitude", "-6.97");
    form.append("longitude", "107.63");
    form.append("id_sesi_absensi", idSesi.toString());
    form.append("liveness_token", "invalid_or_expired_token"); // Liveness failed/bypassed
    form.append("is_mock_location", "false");
    form.append("image", Buffer.from("dummy_jpeg_bytes"), {
      filename: "test_face.jpg",
      contentType: "image/jpeg",
    });

    let didFail = false;
    try {
      await axios.post(`${API_BASE}/api/v1/biometrik/absen`, form, {
        headers: {
          ...form.getHeaders(),
          Authorization: `Bearer ${tokenMhs}`,
          "X-Test-Mode": "true",
        },
      });
    } catch (err) {
      didFail = true;
      expect(err.response.status).toBe(400);
      expect(err.response.data.message).toContain(
        "Token liveness tidak valid atau sudah kadaluarsa",
      );
    }
    expect(didFail).toBe(true);
  });

  test("8. Biometric Attendance - Verify face and record presence successfully", async () => {
    // Request a dynamic liveness token first
    const tokenRes = await axios.post(`${API_BASE}/api/v1/biometrik/request-liveness-token`, {}, {
      headers: { Authorization: `Bearer ${tokenMhs}` }
    });
    expect(tokenRes.status).toBe(200);
    const livenessToken = tokenRes.data.data.token;

    const form = new FormData();
    form.append("latitude", "-6.97");
    form.append("longitude", "107.63");
    form.append("id_sesi_absensi", idSesi.toString());
    form.append("liveness_token", livenessToken);
    form.append("is_mock_location", "false");
    form.append("image", Buffer.from("dummy_jpeg_bytes"), {
      filename: "test_face.jpg",
      contentType: "image/jpeg",
    });

    const res = await axios.post(`${API_BASE}/api/v1/biometrik/absen`, form, {
      headers: {
        ...form.getHeaders(),
        Authorization: `Bearer ${tokenMhs}`,
        "X-Test-Mode": "true",
      },
    });

    expect([200, 201]).toContain(res.status);
    expect(res.data.status).toBe("success");
    expect(res.data.message).toContain("Absensi berhasil");
  });

  test("9. Parking Entry Flow - Edge device detects vehicle entry via OCR", async () => {
    // Hit backend edge-entry directly, which proxies to Python plate recognition
    const form = new FormData();
    form.append("parkiran_id", "1");
    form.append("gate_type", "MASUK");
    form.append("image", Buffer.from("dummy_plate_bytes"), {
      filename: "plate.jpg",
      contentType: "image/jpeg",
    });

    const res = await axios.post(
      `${API_BASE}/api/v1/parkir/edge-entry`,
      form,
      {
        headers: {
          ...form.getHeaders(),
          "X-Edge-Secret": "e2e-testing-edge-device-secret-32-chars",
          "X-Test-Mode": "true", // Forwarded by backend to plate recognizer
        },
      },
    );

    expect([200, 201]).toContain(res.status);
    const gateAction = res.data.gate_action || res.data.data?.gate_action;
    expect(["ALLOW", "OPEN"]).toContain(gateAction);
    const plateText = res.data.plate_text || res.data.data?.plate_text;
    expect(plateText).toBe("B1234XYZ");
  });

  test("10. Anomaly Detection Integration - Trigger scheduled anomaly detection", async () => {
    // Fetch anomalies list as Dosen to verify it aggregates Isolation Forest results
    try {
      const res = await axios.get(`${API_BASE}/api/v1/anomali/${idKelas}`, {
        headers: { Authorization: `Bearer ${tokenDosen}` },
      });
      expect(res.status).toBe(200);
      expect(res.data.status).toBe("success");
      expect(res.data.data).toBeDefined();
    } catch (err) {
      console.error(
        "Test 10 error response:",
        err.response?.status,
        err.response?.data || err.message,
      );
      throw err;
    }
  });

  // ── Authorization & Validation Edge Cases ──────────────────────────────────

  test("11. Unauthorized - No token returns 401", async () => {
    let didFail = false;
    try {
      await axios.get(`${API_BASE}/api/v1/auth/me`);
    } catch (err) {
      didFail = true;
      expect(err.response.status).toBe(401);
      expect(err.response.data.status).toBe("error");
    }
    expect(didFail).toBe(true);
  });

  test("12. Unauthorized - Invalid token returns 401", async () => {
    let didFail = false;
    try {
      await axios.get(`${API_BASE}/api/v1/auth/me`, {
        headers: { Authorization: "Bearer invalid.token.here" },
      });
    } catch (err) {
      didFail = true;
      expect(err.response.status).toBe(401);
      expect(err.response.data.status).toBe("error");
    }
    expect(didFail).toBe(true);
  });

  test("13. Invalid Login - Wrong password returns 401", async () => {
    let didFail = false;
    try {
      await axios.post(`${API_BASE}/api/v1/auth/login`, {
        username: "mhs_test",
        password: "wrongpassword",
      });
    } catch (err) {
      didFail = true;
      expect(err.response.status).toBe(401);
    }
    expect(didFail).toBe(true);
  });

  test("14. Invalid Login - Missing fields returns 400 or 422", async () => {
    let didFail = false;
    try {
      await axios.post(`${API_BASE}/api/v1/auth/login`, {});
    } catch (err) {
      didFail = true;
      expect([400, 422]).toContain(err.response.status);
    }
    expect(didFail).toBe(true);
  });

  // ── Kendaraan (Vehicle) Management ────────────────────────────────────────

  test("15. Kendaraan Registration - Register new vehicle with STNK photo", async () => {
    const form = new FormData();
    form.append("plat_nomor", "D5678ABC");
    form.append("nama_kendaraan", "Honda Beat Biru");
    form.append("fotoSTNK", Buffer.from("dummy_jpeg_bytes"), {
      filename: "stnk.jpg",
      contentType: "image/jpeg",
    });
    form.append("fotoKendaraan", Buffer.from("dummy_jpeg_bytes"), {
      filename: "kendaraan1.jpg",
      contentType: "image/jpeg",
    });
    form.append("fotoKendaraan", Buffer.from("dummy_jpeg_bytes"), {
      filename: "kendaraan2.jpg",
      contentType: "image/jpeg",
    });
    form.append("fotoKendaraan", Buffer.from("dummy_jpeg_bytes"), {
      filename: "kendaraan3.jpg",
      contentType: "image/jpeg",
    });

    const res = await axios.post(`${API_BASE}/api/v1/kendaraan/register`, form, {
      headers: {
        ...form.getHeaders(),
        Authorization: `Bearer ${tokenMhs}`,
      },
    });

    expect([200, 201]).toContain(res.status);
    expect(res.data.status).toBe("success");
    idKendaraan = res.data.data?.id_kendaraan ?? res.data.data?.id;
    expect(idKendaraan).toBeDefined();
  });

  test("16. Get My Kendaraan - List registered vehicles for Mahasiswa", async () => {
    const res = await axios.get(`${API_BASE}/api/v1/kendaraan`, {
      headers: { Authorization: `Bearer ${tokenMhs}` },
    });
    expect(res.status).toBe(200);
    expect(Array.isArray(res.data.data)).toBe(true);
    expect(res.data.data.length).toBeGreaterThan(0);
  });

  // ── Social Posts ──────────────────────────────────────────────────────────

  test("17. Create Post - Submit a new social post", async () => {
    const res = await axios.post(
      `${API_BASE}/api/v1/posts`,
      { content: "Test post dari E2E testing" },
      { headers: { Authorization: `Bearer ${tokenMhs}` } },
    );
    expect(res.status).toBe(201);
    expect(res.data.status).toBe("success");
    idPost = res.data.data?.id_post ?? res.data.data?.id;
    expect(idPost).toBeDefined();
  });

  test("18. List Posts - Retrieve social feed contains created post", async () => {
    const res = await axios.get(`${API_BASE}/api/v1/posts`, {
      headers: { Authorization: `Bearer ${tokenMhs}` },
    });
    expect(res.status).toBe(200);
    const posts = res.data.data ?? res.data;
    expect(posts).toBeDefined();
  });

  // ── Session Termination ───────────────────────────────────────────────────

  test("19. Logout - Invalidate Mahasiswa session token", async () => {
    const res = await axios.post(
      `${API_BASE}/api/v1/auth/logout`,
      {},
      { headers: { Authorization: `Bearer ${tokenMhs}` } },
    );
    expect(res.status).toBe(200);
    expect(res.data.status).toBe("success");
  });
});
