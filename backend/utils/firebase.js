const admin = require('firebase-admin');
const prisma = require('./prisma');
const path = require('path');

// Initialize Firebase Admin SDK
let firebaseInitialized = false;

const initializeFirebase = () => {
    if (firebaseInitialized) return;
    
    try {
        // Look for service account key file in config directory
        const serviceAccountPath = path.join(__dirname, '../config/myteluv2-firebase-adminsdk-fbsvc-c0a5189c6d.json');
        const serviceAccount = require(serviceAccountPath);
        
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

module.exports = {
    initializeFirebase,
    sendPushNotification,
    sendParkingNotification
};
