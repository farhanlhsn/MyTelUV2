/**
 * Upload middleware errors are client errors: a wrong field, a wrong file type, an oversize or missing file
 * must reach the global error handler with statusCode 400 and an Indonesian message, never as a 500.
 */
const express = require('express');
const request = require('supertest');
const {
    uploadSingle,
    uploadFields,
    validateFileSize,
    requireFile
} = require('../middlewares/multerMiddleware');

const app = express();
app.post('/upload',
    uploadFields([{ name: 'fotoKendaraan', maxCount: 3 }, { name: 'fotoSTNK', maxCount: 1 }]),
    validateFileSize,
    requireFile,
    (req, res) => res.status(201).json({ status: 'success' })
);
app.post('/single', uploadSingle('foto'), (req, res) => res.status(201).json({ status: 'success' }));
// Mirrors server.js: the status of the error decides the response status, 5xx is generic.
app.use((err, req, res, next) => {
    const status = [err.statusCode, err.status].find((s) => Number.isInteger(s) && s >= 400 && s < 600) || 500;
    res.status(status).json({ status: 'error', message: status >= 500 ? 'Terjadi kesalahan pada server' : err.message });
});

const png = Buffer.from('89504e470d0a1a0a', 'hex');

describe('multerMiddleware errors', () => {
    test('an upload field that is not allowed is a 400 with an Indonesian message', async () => {
        const res = await request(app).post('/single').attach('foto', png, { filename: 'a.png', contentType: 'image/png' });

        expect(res.status).toBe(400);
        expect(res.body).toEqual({
            status: 'error',
            message: 'Field upload tidak valid: foto. Yang diizinkan: fotoKendaraan, fotoSTNK'
        });
    });

    test('a wrong file type is a 400 with an Indonesian message', async () => {
        const res = await request(app).post('/upload').attach('fotoKendaraan', Buffer.from('GIF89a'), 'a.gif');

        expect(res.status).toBe(400);
        expect(res.body).toEqual({
            status: 'error',
            message: 'Jenis file tidak valid untuk fotoKendaraan. Yang diizinkan: .jpg, .jpeg, .png, .webp'
        });
    });

    test('a valid image passes through', async () => {
        const res = await request(app).post('/upload')
            .attach('fotoKendaraan', png, { filename: 'a.png', contentType: 'image/png' });

        expect(res.status).toBe(201);
    });

    test('a request without any file is a 400 with an Indonesian message', async () => {
        const res = await request(app).post('/upload').field('plat_nomor', 'B1234XYZ');

        expect(res.status).toBe(400);
        expect(res.body).toEqual({ status: 'error', message: 'Tidak ada file yang diunggah' });
    });

    test('validateFileSize hands an oversize file to the error handler as a 400 in Indonesian', () => {
        const next = jest.fn();
        const file = { size: 6 * 1024 * 1024, maxSize: 5 * 1024 * 1024, uploadType: 'fotoSTNK' };

        validateFileSize({ files: { fotoSTNK: [file] } }, {}, next);

        const err = next.mock.calls[0][0];
        expect(err.statusCode).toBe(400);
        expect(err.message).toBe('Ukuran file melebihi batas 5MB untuk fotoSTNK');
    });
});
