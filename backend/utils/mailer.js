const nodemailer = require('nodemailer');

const transporter = nodemailer.createTransport({
    host: process.env.SMTP_HOST || 'smtp.gmail.com',
    port: process.env.SMTP_PORT || 587,
    secure: process.env.SMTP_SECURE === 'true', // true for 465, false for other ports
    auth: {
        user: process.env.SMTP_USER,
        pass: process.env.SMTP_PASS
    }
});

exports.sendPasswordResetEmail = async (to, resetUrl) => {
    try {
        const mailOptions = {
            from: `"MyTelUV2" <${process.env.SMTP_USER}>`,
            to: to,
            subject: 'Password Reset Request',
            html: `
                <p>You requested a password reset for your MyTelUV2 account.</p>
                <p>Please click the link below to reset your password. This link will expire in 30 minutes.</p>
                <a href="${resetUrl}">${resetUrl}</a>
                <p>If you did not request this, please ignore this email.</p>
            `
        };

        const info = await transporter.sendMail(mailOptions);
        console.log(`Password reset email sent to ${to}: ${info.messageId}`);
        return true;
    } catch (error) {
        console.error('Error sending password reset email:', error);
        return false;
    }
};
