const admin = require('firebase-admin');
const prisma = require('./prisma');
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
 * Send push notification to all students in a class when attendance is opened
 * @param {number} classId - Class ID
 * @param {string} className - Class name (e.g. IF-45-01)
 * @param {string} matakuliahName - Subject name (e.g. Alpro)
 */
const sendAbsensiNotification = async (classId, className, matakuliahName) => {
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

        const title = '📝 Sesi Absensi Dibuka!';
        const body = `Sesi absensi untuk kelas ${className} (${matakuliahName}) telah dibuka. Silakan lakukan presensi.`;

        const data = {
            type: 'ABSENSI_NOTIFICATION',
            id_kelas: String(classId),
            timestamp: new Date().toISOString()
        };

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
                    channelId: 'absensi_notifications'
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
        console.log(`✅ Absensi notification sent. Success count: ${response.successCount}, Failure count: ${response.failureCount}`);
        return { success: true, response };

    } catch (error) {
        console.error('❌ Error in sendAbsensiNotification:', error.message);
        return { success: false, error: error.message };
    }
};

module.exports = {
    initializeFirebase,
    sendPushNotification,
    sendParkingNotification,
    sendSocialNotification,
    sendAbsensiNotification
};
