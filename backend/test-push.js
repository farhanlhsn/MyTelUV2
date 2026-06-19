const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '../.env') });
const { PrismaClient } = require('./generated/prisma');
const prisma = new PrismaClient();
const admin = require('firebase-admin');
const fs = require('fs');

const serviceAccountPath = path.join(__dirname, '../myteluv2-firebase-adminsdk-fbsvc-80ecfc899c.json');

if (!fs.existsSync(serviceAccountPath)) {
    console.error('❌ Error: backend/config/serviceAccountKey.json not found!');
    console.error('Make sure you have placed your Firebase service account JSON file there.');
    process.exit(1);
}

const serviceAccount = require(serviceAccountPath);
admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

async function main() {
    console.log('🔍 Fetching user FCM tokens from database...');
    const users = await prisma.user.findMany({
        where: {
            fcm_token: { not: null },
            deletedAt: null
        },
        orderBy: { updatedAt: 'desc' },
        take: 5
    });

    let targetToken = null;
    let category = 'general';
    let userName = 'User Test';

    // Parse arguments
    const arg1 = process.argv[2];
    const arg2 = process.argv[3];

    if (arg1) {
        if (arg1.length > 50) {
            targetToken = arg1;
            category = arg2 || 'general';
        } else {
            category = arg1;
        }
    }

    if (!targetToken) {
        if (users.length === 0) {
            console.warn('⚠️ No users with FCM tokens found in the database.');
            console.log('Usage: node test-push.js [FCM_TOKEN] [category]');
            console.log('Categories: kendaraan_masuk_keluar, verifikasi_kendaraan, postingan, absensi, general');
            process.exit(1);
        }
        const targetUser = users[0];
        targetToken = targetUser.fcm_token;
        userName = targetUser.nama;
        console.log(`Found ${users.length} users in DB. Target: ${targetUser.nama} (${targetUser.username})`);
    } else {
        console.log(`Using manual token: ${targetToken.substring(0, 15)}...`);
    }

    let title = '🔔 Test Notifikasi Berhasil!';
    let body = `Halo ${userName}, ini adalah test notifikasi untuk memverifikasi Firebase Anda.`;
    let type = 'GENERAL_TEST';

    switch (category.toLowerCase()) {
        case 'kendaraan_masuk_keluar':
            title = '🚗 Kendaraan Masuk/Keluar';
            body = `Halo ${userName}, kendaraan Anda dengan plat D 1234 ABC telah masuk area parkir FIT.`;
            type = 'KENDARAAN_IN_OUT';
            break;
        case 'verifikasi_kendaraan':
            title = '✅ Verifikasi Kendaraan Disetujui';
            body = `Halo ${userName}, pengajuan pendaftaran kendaraan Honda Vario Anda telah disetujui oleh Admin.`;
            type = 'KENDARAAN_VERIFICATION';
            break;
        case 'postingan':
            title = '💬 Postingan Baru';
            body = `Budi menyukai postingan Anda: "Info parkir hari ini cukup padat..."`;
            type = 'SOCIAL_NOTIFICATION';
            break;
        case 'absensi':
            title = '📝 Peringatan Absensi';
            body = `Halo ${userName}, persentase kehadiran Anda pada kelas Rekayasa Perangkat Lunak mendekati batas minimal.`;
            type = 'ABSENSI_NOTIFICATION';
            break;
    }

    console.log(`Sending Category: [${category.toUpperCase()}] (FCM data.type: "${type}")`);
    await sendPush(targetToken, title, body, type);
}

async function sendPush(token, title, body, type) {
    const message = {
        notification: {
            title: title,
            body: body
        },
        data: {
            type: type,
            timestamp: new Date().toISOString(),
            click_action: 'FLUTTER_NOTIFICATION_CLICK'
        },
        android: {
            priority: 'high',
            notification: {
                sound: 'default'
            }
        },
        token: token
    };

    try {
        console.log('Sending...');
        const response = await admin.messaging().send(message);
        console.log('✅ Push notification sent successfully!');
        console.log('Response:', response);
    } catch (error) {
        console.error('❌ Failed to send push notification:', error.message);
    } finally {
        await prisma.$disconnect();
    }
}

main().catch(err => {
    console.error('Fatal error:', err);
    prisma.$disconnect();
});
