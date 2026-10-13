const admin = require('firebase-admin');
const prisma = require('./prisma');
const { formatJakarta } = require('./timezone');
const path = require('path');
const fs = require('fs');

// Initialize Firebase Admin SDK
let firebaseInitialized = false;

const initializeFirebase = () => {
    if (firebaseInitialized) return;

    try {
        const configDir = path.join(__dirname, '../config');

        // Try exact file name first, then any adminsdk JSON in config dir
        const exactPath = path.join(configDir, 'myteluv2-firebase-adminsdk-fbsvc-c0a5189c6d.json');
        let serviceAccountPath = null;

        if (fs.existsSync(exactPath)) {
            serviceAccountPath = exactPath;
        } else {
            // Auto-discover any firebase adminsdk key file
            const files = fs.readdirSync(configDir).filter(f =>
                f.endsWith('.json') && f.includes('adminsdk')
            );
            if (files.length > 0) {
                serviceAccountPath = path.join(configDir, files[0]);
                console.log(`[Firebase] Using discovered key: ${files[0]}`);
            }
        }

        if (!serviceAccountPath) {
            console.warn('⚠️  Firebase service account key not found in backend/config/. Push notifications disabled.');
            return;
        }

        const serviceAccount = JSON.parse(fs.readFileSync(serviceAccountPath, 'utf8'));

        admin.initializeApp({
            credential: admin.credential.cert(serviceAccount)
        });

        firebaseInitialized = true;
        console.log('✅ Firebase Admin SDK initialized successfully');
    } catch (error) {
        console.error('❌ Firebase Admin SDK initialization failed:', error.message);
        console.log('📝 Make sure serviceAccountKey.json exists in backend/config/');
    }
};

// Initialize on module load
initializeFirebase();

// FCM error codes meaning the token will never work again (app uninstalled, token rotated, garbage)
const INVALID_TOKEN_ERRORS = new Set([
    'messaging/registration-token-not-registered',
    'messaging/invalid-registration-token'
]);

const isInvalidTokenError = (error) => Boolean(error && INVALID_TOKEN_ERRORS.has(error.code));

// What every helper needs to know about a recipient before sending
const PUSH_RECIPIENT_SELECT = { fcm_token: true, push_notifications_enabled: true, deletedAt: true };

/**
 * Whether a user (selected with PUSH_RECIPIENT_SELECT) gets push notifications: an active account
 * (deletedAt not set) that did not turn push off and has a device token.
 */
const canReceivePush = (user) => Boolean(
    user &&
    !user.deletedAt &&
    user.push_notifications_enabled !== false &&
    user.fcm_token &&
    user.fcm_token.trim().length > 0
);

/**
 * Remove FCM tokens that Firebase reported as invalid. Matched by token value, so a user who has
 * registered a new token since keeps it. Errors are logged, never thrown.
 * @param {string[]} tokens
 */
const clearInvalidTokens = async (tokens) => {
    if (!tokens || tokens.length === 0) return;
    try {
        const { count } = await prisma.user.updateMany({
            where: { fcm_token: { in: tokens } },
            data: { fcm_token: null }
        });
        console.log(`🗑️ Cleared ${count} invalid FCM token(s)`);
    } catch (error) {
        console.error('❌ Failed to clear invalid FCM tokens:', error.message);
    }
};

/**
 * Send push notification to a single device. Internal transport: it does not check the user's
 * preferences, every exported helper does that first (see sendUserNotification).
 * @param {string} token - FCM device token
 * @param {string} title - Notification title
 * @param {string} body - Notification body
 * @param {object} data - Additional data payload
 */
const sendPushNotification = async (token, title, body, data = {}) => {
    if (!firebaseInitialized) {
        console.warn('Firebase not initialized, skipping notification');
        return { success: false, error: 'Firebase not initialized' };
    }

    if (!token) {
        return { success: false, error: 'No FCM token provided' };
    }

    const message = {
        notification: {
            title,
            body
        },
        data: {
            ...data,
            click_action: 'FLUTTER_NOTIFICATION_CLICK'
        },
        android: {
            priority: 'high',
            notification: {
                sound: 'default',
                channelId: 'parking_notifications'
            }
        },
        apns: {
            payload: {
                aps: {
                    sound: 'default',
                    badge: 1
                }
            }
        },
        token
    };

    try {
        const response = await admin.messaging().send(message);
        console.log(`✅ Notification sent successfully: ${response}`);
        return { success: true, messageId: response };
    } catch (error) {
        console.error('❌ Error sending notification:', error.message);

        // The token is dead: remove it so it is not tried again
        if (isInvalidTokenError(error)) {
            await clearInvalidTokens([token]);
        }

        return { success: false, error: error.message };
    }
};

/**
 * Send a push notification to one user. Skipped (success: false) when the account is deactivated,
 * the user turned push notifications off (push_notifications_enabled = false) or has no FCM token.
 * @param {number} userId - User ID
 * @param {string} title - Notification title
 * @param {string} body - Notification body
 * @param {object} data - Additional data payload (string values)
 */
const sendUserNotification = async (userId, title, body, data = {}) => {
    try {
        const user = await prisma.user.findUnique({
            where: { id_user: userId },
            select: PUSH_RECIPIENT_SELECT
        });

        if (!canReceivePush(user)) {
            console.log(`User ${userId} has no active push recipient (deactivated, push disabled or no FCM token), skipping notification`);
            return { success: false, skipped: true, error: 'Push notification not delivered to this user' };
        }

        return await sendPushNotification(user.fcm_token, title, body, data);
    } catch (error) {
        console.error('❌ Error in sendUserNotification:', error.message);
        return { success: false, error: error.message };
    }
};

/**
 * Send parking notification to a user
 * @param {number} userId - User ID
 * @param {string} parkingType - 'MASUK' or 'KELUAR'
 * @param {object} vehicleInfo - { plat_nomor, nama_kendaraan }
 * @param {string} parkiranName - Parking location name
 */
const sendParkingNotification = async (userId, parkingType, vehicleInfo, parkiranName) => {
    try {
        const title = parkingType === 'MASUK' 
            ? '🚗 Kendaraan Masuk Parkiran' 
            : '🚗 Kendaraan Keluar Parkiran';

        const body = parkingType === 'MASUK'
            ? `${vehicleInfo.nama_kendaraan} (${vehicleInfo.plat_nomor}) masuk ke ${parkiranName}`
            : `${vehicleInfo.nama_kendaraan} (${vehicleInfo.plat_nomor}) keluar dari ${parkiranName}`;

        const data = {
            type: 'PARKING_NOTIFICATION',
            parking_type: parkingType,
            plat_nomor: vehicleInfo.plat_nomor,
            nama_kendaraan: vehicleInfo.nama_kendaraan || '',
            parkiran_name: parkiranName,
            timestamp: new Date().toISOString()
        };

        return await sendUserNotification(userId, title, body, data);

    } catch (error) {
        console.error('❌ Error in sendParkingNotification:', error.message);
        return { success: false, error: error.message };
    }
};

/**
 * Send push notification for social interactions (like, comment)
 * @param {number} userId - ID of the post owner receiving the notification
 * @param {string} type - 'LIKE' or 'COMMENT'
 * @param {string} actorName - Name of the user performing the action
 * @param {string} postPreview - Preview of the post content
 * @param {number} [postId] - ID of the post, sent as data.id_post for the app's deep link
 */
const sendSocialNotification = async (userId, type, actorName, postPreview, postId) => {
    try {
        const title = type === 'LIKE'
            ? `❤️ ${actorName} menyukai postingan Anda`
            : `💬 ${actorName} mengomentari postingan Anda`;

        const truncatedPreview = postPreview.length > 50 
            ? postPreview.substring(0, 50) + '...'
            : postPreview;

        const body = truncatedPreview;

        const data = {
            type: 'SOCIAL_NOTIFICATION',
            social_type: type,
            actor_name: actorName,
            ...(postId !== undefined && postId !== null ? { id_post: String(postId) } : {}),
            timestamp: new Date().toISOString()
        };

        return await sendUserNotification(userId, title, body, data);
    } catch (error) {
        console.error('❌ Error in sendSocialNotification:', error.message);
        return { success: false, error: error.message };
    }
};

/**
 * Send a push notification to every student enrolled in a class (multicast).
 * Shared by the class-wide notifications (absensi opened, jadwal pengganti). Students whose account is
 * deactivated or who turned push notifications off are left out; tokens FCM reports as invalid are cleared.
 * @param {number} classId - Class ID
 * @param {object} notification
 * @param {string} notification.title
 * @param {string} notification.body
 * @param {object} notification.data - string values only (FCM data payload)
 * @param {string} [notification.channelId='absensi_notifications'] - Android channel
 * @param {string} [notification.label='Kelas'] - name used in the log lines
 */
const sendKelasNotification = async (classId, { title, body, data, channelId = 'absensi_notifications', label = 'Kelas' }) => {
    try {
        // Fetch all students enrolled in the class with what decides whether they get push
        const peserta = await prisma.pesertaKelas.findMany({
            where: { id_kelas: classId, deletedAt: null },
            include: {
                mahasiswa: {
                    select: PUSH_RECIPIENT_SELECT
                }
            }
        });

        const tokens = peserta
            .map(p => p.mahasiswa)
            .filter(canReceivePush)
            .map(m => m.fcm_token);

        // If no tokens, skip
        const uniqueTokens = [...new Set(tokens)];
        if (uniqueTokens.length === 0) {
            console.log(`No student FCM tokens found for class ${classId}, skipping notification.`);
            return { success: false, error: 'No FCM tokens' };
        }

        if (!firebaseInitialized) {
            console.warn('Firebase not initialized, skipping notification');
            return { success: false, error: 'Firebase not initialized' };
        }

        // Send to each token using multicast
        const message = {
            notification: { title, body },
            data: {
                ...data,
                click_action: 'FLUTTER_NOTIFICATION_CLICK'
            },
            android: {
                priority: 'high',
                notification: {
                    sound: 'default',
                    channelId
                }
            },
            apns: {
                payload: {
                    aps: {
                        sound: 'default',
                        badge: 1
                    }
                }
            },
            tokens: uniqueTokens
        };

        const response = await admin.messaging().sendEachForMulticast(message);
        console.log(`✅ ${label} notification sent. Success count: ${response.successCount}, Failure count: ${response.failureCount}`);

        // responses[i] belongs to uniqueTokens[i]
        const invalidTokens = (response.responses || [])
            .map((r, i) => (!r.success && isInvalidTokenError(r.error) ? uniqueTokens[i] : null))
            .filter(Boolean);
        await clearInvalidTokens(invalidTokens);

        return { success: true, response };

    } catch (error) {
        console.error(`❌ Error in ${label} notification:`, error.message);
        return { success: false, error: error.message };
    }
};

/**
 * Send push notification to all students in a class when attendance is opened
 * @param {number} classId - Class ID
 * @param {string} className - Class name (e.g. IF-45-01)
 * @param {string} matakuliahName - Subject name (e.g. Alpro)
 */
const sendAbsensiNotification = async (classId, className, matakuliahName) => sendKelasNotification(classId, {
    title: '📝 Sesi Absensi Dibuka!',
    body: `Sesi absensi untuk kelas ${className} (${matakuliahName}) telah dibuka. Silakan lakukan presensi.`,
    data: {
        type: 'ABSENSI_NOTIFICATION',
        id_kelas: String(classId),
        timestamp: new Date().toISOString()
    },
    label: 'Absensi'
});

/**
 * Text of the jadwal pengganti notification (dates and times in WIB).
 * @param {object} jadwal - see sendJadwalPenggantiNotification
 * @returns {{title: string, body: string}}
 */
const jadwalPenggantiMessage = ({ namaKelas, namaMatakuliah, status, tanggalAsli, tanggalGanti, jamMulaiGanti, jamBerakhirGanti, ruanganGanti, alasan }) => {
    const kelas = `${namaKelas} (${namaMatakuliah})`;
    const tanggal = formatJakarta(tanggalAsli);

    if (status === 'LIBUR') {
        return {
            title: '📅 Kelas Diliburkan',
            body: `Kelas ${kelas} pada ${tanggal} diliburkan. Alasan: ${alasan}`
        };
    }

    const jam = jamMulaiGanti && jamBerakhirGanti
        ? ` pukul ${jamMulaiGanti.slice(0, 5)}-${jamBerakhirGanti.slice(0, 5)} WIB`
        : '';
    const ruangan = ruanganGanti ? ` di ruang ${ruanganGanti}` : '';
    return {
        title: '📅 Jadwal Kelas Diganti',
        body: `Kelas ${kelas} pada ${tanggal} dipindah ke ${formatJakarta(tanggalGanti)}${jam}${ruangan}. Alasan: ${alasan}`
    };
};

/**
 * Notify the students of a class about a jadwal pengganti (class cancelled or moved).
 * @param {number} classId - Class ID
 * @param {object} jadwal
 * @param {number} jadwal.idJadwalPengganti
 * @param {string} jadwal.namaKelas
 * @param {string} jadwal.namaMatakuliah
 * @param {'LIBUR'|'GANTI_JADWAL'} jadwal.status
 * @param {Date} jadwal.tanggalAsli
 * @param {Date|null} [jadwal.tanggalGanti]
 * @param {string|null} [jadwal.jamMulaiGanti] - "HH:MM:SS"
 * @param {string|null} [jadwal.jamBerakhirGanti] - "HH:MM:SS"
 * @param {string|null} [jadwal.ruanganGanti]
 * @param {string} jadwal.alasan
 */
// async: a message that cannot be built (e.g. invalid date) rejects instead of throwing synchronously
const sendJadwalPenggantiNotification = async (classId, jadwal) => sendKelasNotification(classId, {
    ...jadwalPenggantiMessage(jadwal),
    data: {
        type: 'JADWAL_PENGGANTI_NOTIFICATION',
        id_kelas: String(classId),
        id_jadwal_pengganti: String(jadwal.idJadwalPengganti),
        status: jadwal.status,
        timestamp: new Date().toISOString()
    },
    label: 'Jadwal pengganti'
});

// sendPushNotification (send to a raw token) is deliberately not exported: every exported helper checks
// the recipient's push preference and account status first.
module.exports = {
    initializeFirebase,
    sendUserNotification,
    sendParkingNotification,
    sendSocialNotification,
    sendKelasNotification,
    sendAbsensiNotification,
    jadwalPenggantiMessage,
    sendJadwalPenggantiNotification
};
