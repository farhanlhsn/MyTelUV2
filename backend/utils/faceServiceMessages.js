// Translates the English error strings of the face recognition service (python-service/face_recognition)
// into Indonesian user-facing messages. Unknown or internal strings (stack-trace-like text such as
// "Error processing image: ...") fall back to a generic message and are never forwarded to the user.
const FACE_SERVICE_FALLBACK_MESSAGE = 'Gagal mendeteksi wajah. Coba ambil foto ulang.';

// Order matters: the first matching rule wins. Patterns follow the exact strings returned by
// app.py and face_processor.py.
const RULES = [
    {
        pattern: /^no faces detected/i,
        message: 'Tidak ada wajah yang terdeteksi pada foto.',
    },
    {
        pattern: /^no face detected/i,
        message: 'Wajah tidak terdeteksi pada foto. Pastikan wajah terlihat jelas dan pencahayaan cukup.',
    },
    {
        pattern: /^multiple faces detected/i,
        message: 'Terdeteksi lebih dari satu wajah. Gunakan foto yang hanya berisi satu wajah.',
    },
    {
        pattern: /^no (image file provided|selected file)/i,
        message: 'Foto wajah wajib diunggah.',
    },
    {
        pattern: /^invalid file type/i,
        message: 'Format foto tidak didukung. Gunakan JPG, JPEG, atau PNG.',
    },
    {
        pattern: /^failed to (decode|read) image/i,
        message: 'Foto tidak dapat dibaca. Silakan ambil foto ulang.',
    },
];

/**
 * @param {unknown} rawMessage `error` field of a face service response
 * @returns {string} Indonesian message, safe to show to the user
 */
const translateFaceServiceError = (rawMessage) => {
    if (typeof rawMessage !== 'string') return FACE_SERVICE_FALLBACK_MESSAGE;
    const text = rawMessage.trim();
    const rule = RULES.find(({ pattern }) => pattern.test(text));
    return rule ? rule.message : FACE_SERVICE_FALLBACK_MESSAGE;
};

module.exports = { translateFaceServiceError, FACE_SERVICE_FALLBACK_MESSAGE };
