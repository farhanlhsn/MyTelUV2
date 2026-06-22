module.exports = {
  openapi: '3.0.0',
  info: {
    title: 'MyTelUV2 API Documentation',
    version: '1.0.0',
    description: 'OpenAPI documentation for the MyTelUV2 backend services.',
  },
  servers: [
    {
      url: 'http://localhost:5050/api/v1',
      description: 'Development server (v1 prefix)',
    },
    {
      url: 'http://localhost:5050/api',
      description: 'Development server (legacy prefix)',
    },
  ],
  tags: [
    { name: 'System', description: 'Health and utility endpoints' },
    { name: 'Auth', description: 'Authentication and profile endpoints' },
    { name: 'Biometrik', description: 'Face verification and attendance' },
    { name: 'Kendaraan', description: 'Vehicle registration and approval' },
    { name: 'Akademik', description: 'Courses, classes, attendance, and reports' },
    { name: 'Parkir', description: 'Parking flow and edge device integration' },
    { name: 'Anomali', description: 'Attendance anomaly analysis' },
    { name: 'Posts', description: 'Campus social feed and comments' },
  ],
  components: {
    securitySchemes: {
      bearerAuth: {
        type: 'http',
        scheme: 'bearer',
        bearerFormat: 'JWT',
      },
      edgeSecretAuth: {
        type: 'apiKey',
        in: 'header',
        name: 'X-Edge-Secret',
      },
    },
    schemas: {
      ErrorResponse: {
        type: 'object',
        properties: {
          message: { type: 'string' },
        },
      },
      AuthLoginRequest: {
        type: 'object',
        required: ['username', 'password'],
        properties: {
          username: { type: 'string', example: 'john.doe' },
          password: { type: 'string', example: 'secret123' },
        },
      },
      AuthRegisterRequest: {
        type: 'object',
        required: ['nama', 'username', 'password'],
        properties: {
          nama: { type: 'string', example: 'John Doe' },
          username: { type: 'string', example: 'john.doe' },
          password: { type: 'string', example: 'secret123' },
          role: { type: 'string', enum: ['MAHASISWA', 'DOSEN'] },
          nim_nip: { type: 'string', example: '12345678901' },
        },
      },
      VehicleVerifyRequest: {
        type: 'object',
        required: ['id_kendaraan', 'id_user'],
        properties: {
          id_kendaraan: { oneOf: [{ type: 'number' }, { type: 'string' }] },
          id_user: { oneOf: [{ type: 'number' }, { type: 'string' }] },
        },
      },
      VehicleRejectRequest: {
        type: 'object',
        required: ['id_kendaraan', 'id_user', 'feedback'],
        properties: {
          id_kendaraan: { oneOf: [{ type: 'number' }, { type: 'string' }] },
          id_user: { oneOf: [{ type: 'number' }, { type: 'string' }] },
          feedback: { type: 'string' },
        },
      },
      MatakuliahRequest: {
        type: 'object',
        required: ['nama_matakuliah', 'kode_matakuliah'],
        properties: {
          nama_matakuliah: { type: 'string' },
          kode_matakuliah: { type: 'string' },
        },
      },
      KelasRequest: {
        type: 'object',
        required: ['id_matakuliah', 'id_dosen', 'jam_mulai', 'jam_berakhir', 'nama_kelas', 'ruangan'],
        properties: {
          id_matakuliah: { oneOf: [{ type: 'number' }, { type: 'string' }] },
          id_dosen: { oneOf: [{ type: 'number' }, { type: 'string' }] },
          jam_mulai: { type: 'string', example: '08:00:00' },
          jam_berakhir: { type: 'string', example: '09:40:00' },
          nama_kelas: { type: 'string' },
          ruangan: { type: 'string' },
          hari: { oneOf: [{ type: 'number' }, { type: 'string' }] },
        },
      },
      OpenAbsensiRequest: {
        type: 'object',
        required: ['id_kelas', 'mulai', 'selesai'],
        properties: {
          id_kelas: { oneOf: [{ type: 'number' }, { type: 'string' }] },
          mulai: { type: 'string' },
          selesai: { type: 'string' },
          latitude: { oneOf: [{ type: 'number' }, { type: 'string' }] },
          longitude: { oneOf: [{ type: 'number' }, { type: 'string' }] },
          radius_meter: { oneOf: [{ type: 'number' }, { type: 'string' }] },
          require_face: { oneOf: [{ type: 'boolean' }, { type: 'string' }] },
        },
      },
      CreateAbsensiRequest: {
        type: 'object',
        required: ['id_kelas', 'id_sesi_absensi', 'latitude', 'longitude'],
        properties: {
          id_kelas: { oneOf: [{ type: 'number' }, { type: 'string' }] },
          id_sesi_absensi: { oneOf: [{ type: 'number' }, { type: 'string' }] },
          latitude: { oneOf: [{ type: 'number' }, { type: 'string' }] },
          longitude: { oneOf: [{ type: 'number' }, { type: 'string' }] },
        },
      },
    },
  },
  security: [
    {
      bearerAuth: [],
    },
  ],
  paths: {
    '/health': {
      get: {
        tags: ['System'],
        summary: 'Health check',
        security: [],
        responses: {
          200: { description: 'Service is healthy' },
        },
      },
    },
    '/auth/register': {
      post: {
        tags: ['Auth'],
        summary: 'Register a new user',
        security: [],
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: { $ref: '#/components/schemas/AuthRegisterRequest' },
            },
          },
        },
        responses: { 201: { description: 'User created' } },
      },
    },
    '/auth/login': {
      post: {
        tags: ['Auth'],
        summary: 'Login user',
        security: [],
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: { $ref: '#/components/schemas/AuthLoginRequest' },
            },
          },
        },
        responses: { 200: { description: 'Login successful' } },
      },
    },
    '/auth/me': {
      get: {
        tags: ['Auth'],
        summary: 'Get current user profile',
        responses: { 200: { description: 'Current user data' } },
      },
    },
    '/auth/profile': {
      put: {
        tags: ['Auth'],
        summary: 'Update current profile',
        responses: { 200: { description: 'Profile updated' } },
      },
    },
    '/biometrik/request-liveness-token': {
      post: {
        tags: ['Biometrik'],
        summary: 'Request liveness token',
        responses: { 200: { description: 'Liveness token generated' } },
      },
    },
    '/biometrik/absen': {
      post: {
        tags: ['Biometrik'],
        summary: 'Submit biometric attendance',
        responses: { 201: { description: 'Attendance submitted' } },
      },
    },
    '/kendaraan/register': {
      post: {
        tags: ['Kendaraan'],
        summary: 'Register a vehicle',
        responses: { 201: { description: 'Vehicle registered' } },
      },
    },
    '/kendaraan/verify': {
      post: {
        tags: ['Kendaraan'],
        summary: 'Verify a vehicle request',
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: { $ref: '#/components/schemas/VehicleVerifyRequest' },
            },
          },
        },
        responses: { 200: { description: 'Vehicle verified' } },
      },
    },
    '/akademik/matakuliah': {
      get: {
        tags: ['Akademik'],
        summary: 'List matakuliah',
        responses: { 200: { description: 'Matakuliah list' } },
      },
      post: {
        tags: ['Akademik'],
        summary: 'Create matakuliah',
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: { $ref: '#/components/schemas/MatakuliahRequest' },
            },
          },
        },
        responses: { 201: { description: 'Matakuliah created' } },
      },
    },
    '/akademik/kelas': {
      get: {
        tags: ['Akademik'],
        summary: 'List kelas',
        responses: { 200: { description: 'Kelas list' } },
      },
      post: {
        tags: ['Akademik'],
        summary: 'Create kelas',
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: { $ref: '#/components/schemas/KelasRequest' },
            },
          },
        },
        responses: { 201: { description: 'Kelas created' } },
      },
    },
    '/akademik/open-absensi': {
      post: {
        tags: ['Akademik'],
        summary: 'Open attendance session',
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: { $ref: '#/components/schemas/OpenAbsensiRequest' },
            },
          },
        },
        responses: { 201: { description: 'Attendance session opened' } },
      },
    },
    '/akademik/absensi': {
      post: {
        tags: ['Akademik'],
        summary: 'Submit attendance',
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: { $ref: '#/components/schemas/CreateAbsensiRequest' },
            },
          },
        },
        responses: { 201: { description: 'Attendance saved' } },
      },
    },
    '/parkir/edge-entry': {
      post: {
        tags: ['Parkir'],
        summary: 'Process edge parking entry',
        security: [
          {
            edgeSecretAuth: [],
          },
        ],
        responses: { 200: { description: 'Edge entry processed' } },
      },
    },
    '/parkir/all': {
      get: {
        tags: ['Parkir'],
        summary: 'Get parking data',
        responses: { 200: { description: 'Parking list' } },
      },
    },
    '/anomali/analyze/{id_kelas}': {
      post: {
        tags: ['Anomali'],
        summary: 'Analyze class attendance anomaly',
        parameters: [
          { name: 'id_kelas', in: 'path', required: true, schema: { type: 'string' } },
        ],
        responses: { 201: { description: 'Analysis started' } },
      },
    },
    '/posts/': {
      get: {
        tags: ['Posts'],
        summary: 'List posts',
        responses: { 200: { description: 'Post list' } },
      },
      post: {
        tags: ['Posts'],
        summary: 'Create a post',
        responses: { 201: { description: 'Post created' } },
      },
    },
  },
};
