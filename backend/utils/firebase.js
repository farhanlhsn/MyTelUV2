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

/**
 * Send push notification to a single device
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
        
        // Handle invalid token - remove from database
        if (error.code === 'messaging/registration-token-not-registered' ||
            error.code === 'messaging/invalid-registration-token') {
            console.log('🗑️ Invalid FCM token, consider removing from database');
        }
        
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
        // Get user's FCM token
        const user = await prisma.user.findUnique({
            where: { id_user: userId },
            select: { fcm_token: true, nama: true }
        });

        if (!user?.fcm_token) {
            console.log(`No FCM token for user ${userId}, skipping notification`);
            return { success: false, error: 'No FCM token' };
        }

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

        return await sendPushNotification(user.fcm_token, title, body, data);

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
 */
const sendSocialNotification = async (userId, type, actorName, postPreview) => {
    try {
        const user = await prisma.user.findUnique({
            where: { id_user: userId },
            select: { fcm_token: true }
        });

        if (!user?.fcm_token) {
            console.log(`No FCM token for user ${userId}, skipping social notification`);
            return { success: false, error: 'No FCM token' };
        }

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
            timestamp: new Date().toISOString()
        };

        return await sendPushNotification(user.fcm_token, title, body, data);
    } catch (error) {
        console.error('❌ Error in sendSocialNotification:', error.message);
        return { success: false, error: error.message };
    }
};

/**
 * Send a push notification to every student enrolled in a class (multicast).
 * Shared by the class-wide notifications (absensi opened, jadwal pengganti).
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
        // Fetch all students enrolled in the class with FCM tokens
        const peserta = await prisma.pesertaKelas.findMany({
            where: { id_kelas: classId, deletedAt: null },
            include: {
                mahasiswa: {
                    select: { fcm_token: true }
                }
            }
        });

        const tokens = peserta
            .map(p => p.mahasiswa?.fcm_token)
            .filter(t => t && t.trim().length > 0);

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

module.exports = {
    initializeFirebase,
    sendPushNotification,
    sendParkingNotification,
    sendSocialNotification,
    sendKelasNotification,
    sendAbsensiNotification,
    jadwalPenggantiMessage,
    sendJadwalPenggantiNotification
};
