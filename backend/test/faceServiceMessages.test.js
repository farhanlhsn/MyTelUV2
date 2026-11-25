/**
 * Unit Testing - Indonesian translation of the face service's English error strings
 * (utils/faceServiceMessages.js). The strings under test are the exact ones that
 * python-service/face_recognition/app.py and face_processor.py return.
 */

const {
    translateFaceServiceError,
    isFaceServiceInternalError,
    FACE_SERVICE_FALLBACK_MESSAGE,
    FACE_MATCH_FAILED_MESSAGE,
    FACE_SERVICE_FAILURE_MESSAGE,
} = require('../utils/faceServiceMessages');

describe('translateFaceServiceError', () => {
    test('no face detected', () => {
        const message = translateFaceServiceError('No face detected in image');
        expect(message).toMatch(/Wajah tidak terdeteksi/);
        expect(message).not.toMatch(/detected/i);
    });

    test('no faces detected (multi-face scan)', () => {
        expect(translateFaceServiceError('No faces detected in image')).toMatch(/Tidak ada wajah/);
    });

    test('several faces in a single-face photo, with the count the service adds', () => {
        const message = translateFaceServiceError(
            'Multiple faces detected (3). Please provide image with single face.',
        );
        expect(message).toMatch(/lebih dari satu wajah/);
        expect(message).not.toMatch(/Please|provide/);
    });

    test('missing file / empty filename', () => {
        expect(translateFaceServiceError('No image file provided')).toMatch(/Foto wajah wajib/);
        expect(translateFaceServiceError('No selected file')).toMatch(/Foto wajah wajib/);
    });

    test('unsupported file type', () => {
        const message = translateFaceServiceError('Invalid file type. Allowed: jpg, jpeg, png');
        expect(message).toMatch(/Format foto tidak didukung/);
        expect(message).toMatch(/JPG/);
    });

    test('unreadable image', () => {
        expect(translateFaceServiceError('Failed to decode image')).toMatch(/Foto tidak dapat dibaca/);
        expect(translateFaceServiceError('Failed to read image')).toMatch(/Foto tidak dapat dibaca/);
    });

    test('matching is case-insensitive and tolerates surrounding whitespace', () => {
        expect(translateFaceServiceError('  no face DETECTED in image ')).toMatch(/Wajah tidak terdeteksi/);
    });

    test('internal errors fall back to a generic Indonesian message without leaking details', () => {
        for (const raw of [
            'Error processing image: OpenCV(4.9) exception at /tmp/x.cpp',
            'Server error: division by zero',
            'Error comparing embeddings: shapes (512,) and (256,)',
            'Missing embedding1 or embedding2 in request',
            'Empty embeddings list',
        ]) {
            expect(translateFaceServiceError(raw)).toBe(FACE_SERVICE_FALLBACK_MESSAGE);
        }
    });

    test('empty or non-string input falls back to the generic message', () => {
        for (const raw of [undefined, null, '', '   ', 42, { error: 'x' }]) {
            expect(translateFaceServiceError(raw)).toBe(FACE_SERVICE_FALLBACK_MESSAGE);
        }
    });

    test('the fallback is Indonesian', () => {
        expect(FACE_SERVICE_FALLBACK_MESSAGE).toMatch(/Gagal/);
        expect(FACE_SERVICE_FALLBACK_MESSAGE).not.toMatch(/Failed|detected|error/i);
    });

    test('the match-failure and service-failure messages are Indonesian and distinct', () => {
        expect(FACE_MATCH_FAILED_MESSAGE).toBe('Gagal mencocokkan wajah. Silakan coba lagi.');
        expect(FACE_SERVICE_FAILURE_MESSAGE).toMatch(/^Layanan pengenalan wajah/);
        expect(new Set([FACE_SERVICE_FALLBACK_MESSAGE, FACE_MATCH_FAILED_MESSAGE, FACE_SERVICE_FAILURE_MESSAGE]).size).toBe(3);
    });
});

describe('isFaceServiceInternalError', () => {
    test('is true for the service-side wrappers around an unexpected exception', () => {
        for (const raw of [
            'Error processing image: OpenCV(4.9) exception at /tmp/x.cpp',
            'Server error: division by zero',
            'Error comparing embeddings: shapes (512,) and (256,)',
            'Error finding best match: shapes differ',
            '  error processing image: lower case, padded',
        ]) {
            expect(isFaceServiceInternalError(raw)).toBe(true);
        }
    });

    test('is false for problems with the user photo and for non-strings', () => {
        for (const raw of [
            'No face detected in image',
            'No faces detected in image',
            'Multiple faces detected (2). Please provide image with single face.',
            'Failed to decode image',
            'Invalid file type. Allowed: jpg, jpeg, png',
            undefined,
            null,
            '',
            42,
        ]) {
            expect(isFaceServiceInternalError(raw)).toBe(false);
        }
    });
});
