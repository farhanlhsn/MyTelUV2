const prisma = require('../utils/prisma');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { v4: uuidv4 } = require('uuid');
const asyncHandler = require('express-async-handler');
const { logAudit } = require('../utils/auditLogger');
const embeddingCache = require('../utils/embeddingCache');
const { GENERIC_SERVER_ERROR } = require('../utils/serverError');

// Picks the Indonesian 409 message for whichever unique field the existing row collides on.
const duplicateMessage = (existing, wanted) => {
    if (existing.username === wanted.username) return 'Username sudah digunakan';
    if (wanted.nim_nip && existing.nim_nip === wanted.nim_nip) return 'NIM/NIP sudah terdaftar';
    if (wanted.email && existing.email === wanted.email) return 'Email sudah terdaftar';
    return 'Username, NIM/NIP, atau email sudah terdaftar';
};

// Public registration can only ever create a MAHASISWA. DOSEN and ADMIN accounts are created by an
// admin through adminCreateUser; any `role` sent to /register is ignored (the Zod schema strips it,
// and register never reads it).
const PUBLIC_REGISTER_ROLE = 'MAHASISWA';

// Shared by register and adminCreateUser so both apply exactly the same duplicate rules.
// Resolves to { user } on success or { conflict: <Indonesian message> } for a 409.
const createUserAccount = async ({ nama, username, password, role, nim_nip, email: rawEmail }) => {
    const email = rawEmail ? rawEmail.trim().toLowerCase() : null;

    // The duplicate check deliberately includes soft-deleted users: the DB unique constraints on
    // username / nim_nip / email still cover them, so excluding them here turned a duplicate into a 500.
    const conflictFilters = [{ username }];
    if (nim_nip) conflictFilters.push({ nim_nip });
    if (email) conflictFilters.push({ email });

    const existing = await prisma.user.findFirst({
        where: { OR: conflictFilters },
        select: { username: true, nim_nip: true, email: true }
    });
    if (existing) {
        return { conflict: duplicateMessage(existing, { username, nim_nip, email }) };
    }

    const hashedPassword = await bcrypt.hash(password, 10);
    try {
        const user = await prisma.user.create({
            data: {
                nama,
                username,
                password: hashedPassword,
                role,
                nim_nip: nim_nip || null,
                email
            }
        });
        return { user };
    } catch (error) {
        // A concurrent registration won the race for the same unique value after our check.
        if (error?.code === 'P2002') {
            return { conflict: 'Username, NIM/NIP, atau email sudah terdaftar' };
        }
        throw error;
    }
};

exports.register = asyncHandler(async (req, res) => {
    const { nama, username, password, nim_nip, email } = req.body;

    const { user, conflict } = await createUserAccount({
        nama, username, password, nim_nip, email, role: PUBLIC_REGISTER_ROLE
    });
    if (conflict) {
        return res.status(409).json({ status: "error", message: conflict });
    }

    res.status(201).json({
        status: "success",
        message: 'Akun berhasil dibuat',
        data: {
            id: user.id_user,
            username: user.username,
            nama: user.nama,
            role: user.role
        }
    });
});

// ADMIN only (see authRoutes): creates an account with an explicit role, which is how DOSEN and
// ADMIN accounts come to exist now that public registration is MAHASISWA only.
exports.adminCreateUser = asyncHandler(async (req, res) => {
    const { nama, username, password, role, nim_nip, email } = req.body;

    const { user, conflict } = await createUserAccount({ nama, username, password, role, nim_nip, email });
    if (conflict) {
        return res.status(409).json({ status: "error", message: conflict });
    }

    logAudit({
        action: 'ADMIN_CREATE_USER',
        performedBy: req.user.id_user,
        targetUserId: user.id_user,
        details: `Admin ${req.user.nama} created ${user.role} account '${user.username}'`,
        ip: req.ip || req.headers['x-forwarded-for']
    });

    res.status(201).json({
        status: "success",
        message: 'Akun berhasil dibuat',
        data: {
            id: user.id_user,
            username: user.username,
            nama: user.nama,
            role: user.role,
            nim_nip: user.nim_nip,
            email: user.email
        }
    });
});

// Issues an access token (1 hour) plus a refresh token and its expiry (7 days). The caller stores the
// refresh token row, so login can do it standalone and changePassword can do it inside its transaction.
const issueSession = (userId) => {
    const token = jwt.sign({ id: userId }, process.env.JWT_SECRET, { expiresIn: '1h' });
    const refreshToken = uuidv4();
    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + 7); // 7 days
    return { token, refreshToken, expiresAt };
};

// The `data` object of a successful login. changePassword returns the same shape so the client can
// treat both responses identically.
const sessionPayload = (user, token, refreshToken) => ({
    id_user: user.id_user,
    token: token,
    refresh_token: refreshToken,
    username: user.username,
    nama: user.nama,
    role: user.role
});

exports.login = asyncHandler(async (req, res) => {
    const { username, password } = req.body;

    const user = await prisma.user.findFirst({
        where: {
            username: username,
            deletedAt: null // Exclude soft-deleted users
        }
    });
    if (!user) {
        return res.status(401).json({ status: "error", message: 'Username atau password salah' });
    }

    const isPasswordValid = await bcrypt.compare(password, user.password);
    if (!isPasswordValid) {
        return res.status(401).json({ status: "error", message: 'Username atau password salah' });
    }

    const { token, refreshToken, expiresAt } = issueSession(user.id_user);

    // Store refresh token in DB
    await prisma.refreshToken.create({
        data: {
            token: refreshToken,
            id_user: user.id_user,
            expiresAt
        }
    });

    res.status(200).json({
        status: "success",
        message: 'Login berhasil',
        data: sessionPayload(user, token, refreshToken)
    });
});

exports.getMe = asyncHandler(async (req, res) => {
    const user = req.user;
    res.status(200).json({
        status: "success",
        message: 'User data retrieved successfully',
        data: {
            id: user.id_user,
            username: user.username,
            nama: user.nama,
            role: user.role,
            nim_nip: user.nim_nip
        }
    });
});

exports.logout = asyncHandler(async (req, res) => {
    const userId = req.user.id_user;
    const { refresh_token } = req.body; // Optional: revoke specific refresh token

    // Clear FCM token on logout so user won't receive push notifications
    await prisma.user.update({
        where: { id_user: userId },
        data: { fcm_token: null }
    });

    // Revoke refresh token if provided
    if (refresh_token) {
        await prisma.refreshToken.deleteMany({
            where: {
                token: refresh_token,
                id_user: userId
            }
        });
    }

    res.status(200).json({
        status: "success",
        message: 'Logged out successfully'
    });
});

exports.refreshToken = asyncHandler(async (req, res) => {
    const { refresh_token } = req.body;

    if (!refresh_token) {
        return res.status(400).json({ status: "error", message: 'Refresh token is required' });
    }

    // Check if refresh token exists in DB
    const existingToken = await prisma.refreshToken.findUnique({
        where: { token: refresh_token },
        include: { user: true }
    });

    if (!existingToken) {
        return res.status(401).json({ status: "error", message: 'Invalid refresh token' });
    }

    // Check if expired
    if (new Date() > existingToken.expiresAt) {
        await prisma.refreshToken.delete({ where: { id: existingToken.id } });
        return res.status(401).json({ status: "error", message: 'Refresh token expired' });
    }

    // Check if user is still active (not soft deleted)
    if (existingToken.user.deletedAt) {
        return res.status(401).json({ status: "error", message: 'User account is deactivated' });
    }

    // Generate new access token (1 hour)
    const token = jwt.sign({ id: existingToken.user.id_user }, process.env.JWT_SECRET, { expiresIn: '1h' });

    // Rotate refresh token: generate new one, delete old one
    const newRefreshToken = uuidv4();
    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + 7); // 7 days

    await prisma.$transaction([
        prisma.refreshToken.delete({ where: { id: existingToken.id } }),
        prisma.refreshToken.create({
            data: {
                token: newRefreshToken,
                id_user: existingToken.user.id_user,
                expiresAt
            }
        })
    ]);

    res.status(200).json({
        status: "success",
        message: 'Token refreshed successfully',
        data: {
            token: token,
            refresh_token: newRefreshToken
        }
    });
});

exports.getAllUsers = asyncHandler(async (req, res) => {
    const {
        role,
        status = 'active', // active, inactive, all
        search,
        page = 1,
        limit = 10,
        sortBy = 'createdAt',
        order = 'desc'
    } = req.query;

    // Build filter object
    const where = {};

    if (status === 'active') {
        where.deletedAt = null;
    } else if (status === 'inactive') {
        where.deletedAt = { not: null };
    }

    // Filter by role if provided
    if (role && ['MAHASISWA', 'DOSEN', 'ADMIN'].includes(role)) {
        where.role = role;
    }

    // Search by name or username
    if (search) {
        where.OR = [
            { nama: { contains: search, mode: 'insensitive' } },
            { username: { contains: search, mode: 'insensitive' } }
        ];
    }

    // Validate sortBy field
    const validSortFields = ['createdAt', 'updatedAt', 'nama', 'username', 'role'];
    const orderByField = validSortFields.includes(sortBy) ? sortBy : 'createdAt';
    const orderByDirection = order === 'asc' ? 'asc' : 'desc';

    // Calculate pagination
    const pageNum = Math.max(1, parseInt(page));
    const limitNum = Math.min(100, Math.max(1, parseInt(limit))); // Max 100 per page
    const skip = (pageNum - 1) * limitNum;

    // Get total count for pagination
    const totalUsers = await prisma.user.count({ where });

    // Fetch users with filters
    const users = await prisma.user.findMany({
        where,
        select: {
            id_user: true,
            nama: true,
            username: true,
            role: true,
            createdAt: true,
            updatedAt: true,
            deletedAt: true,
            dataBiometrik: {
                select: {
                    id_biometrik: true,
                    photo_url: true,
                    deletedAt: true
                }
            }
            // Exclude password
        },
        orderBy: {
            [orderByField]: orderByDirection
        },
        skip,
        take: limitNum
    });

    // Transform to include biometric status
    const usersWithBioStatus = users.map(user => ({
        ...user,
        has_biometric: user.dataBiometrik && !user.dataBiometrik.deletedAt,
        biometric_photo: user.dataBiometrik?.photo_url || null,
        dataBiometrik: undefined // Remove nested object
    }));

    // Calculate pagination metadata
    const totalPages = Math.ceil(totalUsers / limitNum);

    res.status(200).json({
        status: "success",
        message: 'Users retrieved successfully',
        data: {
            users: usersWithBioStatus,
            pagination: {
                currentPage: pageNum,
                totalPages,
                totalUsers,
                limit: limitNum,
                hasNextPage: pageNum < totalPages,
                hasPrevPage: pageNum > 1
            }
        }
    });
});

exports.updateProfile = asyncHandler(async (req, res) => {
    const { nama } = req.body;
    const userId = req.user.id_user;

    if (!nama || nama.trim() === '') {
        return res.status(400).json({
            status: "error",
            message: 'Nama is required'
        });
    }

    const updatedUser = await prisma.user.update({
        where: { id_user: userId },
        data: { nama: nama.trim() },
        select: {
            id_user: true,
            username: true,
            nama: true,
            role: true
        }
    });

    res.status(200).json({
        status: "success",
        message: 'Profile updated successfully',
        data: updatedUser
    });
});

exports.changePassword = asyncHandler(async (req, res) => {
    const { oldPassword, newPassword } = req.body;
    const userId = req.user.id_user;

    if (!oldPassword || !newPassword) {
        return res.status(400).json({
            status: "error",
            message: 'Password lama dan password baru wajib diisi'
        });
    }

    if (newPassword.length < 8) {
        return res.status(400).json({
            status: "error",
            message: 'Password minimal 8 karakter'
        });
    }

    // Get current user with password
    const user = await prisma.user.findUnique({
        where: { id_user: userId }
    });

    // Verify old password. A wrong current password is a validation failure (400), not 401: the caller
    // is authenticated, and clients treat 401 as "session expired" (refresh, then log out).
    const isPasswordValid = await bcrypt.compare(oldPassword, user.password);
    if (!isPasswordValid) {
        return res.status(400).json({
            status: "error",
            message: 'Password lama salah'
        });
    }

    // Hash and save the new password. Every refresh token of the user is revoked in the same
    // transaction so a stolen session cannot outlive the password change; the caller's own session is
    // replaced by a fresh pair (created after the delete, in the same transaction) so this device
    // stays logged in.
    const hashedPassword = await bcrypt.hash(newPassword, 10);
    const { token, refreshToken, expiresAt } = issueSession(userId);
    await prisma.$transaction([
        prisma.user.update({
            where: { id_user: userId },
            data: { password: hashedPassword }
        }),
        prisma.refreshToken.deleteMany({ where: { id_user: userId } }),
        prisma.refreshToken.create({
            data: { token: refreshToken, id_user: userId, expiresAt }
        })
    ]);

    res.status(200).json({
        status: "success",
        message: 'Password berhasil diubah',
        data: sessionPayload(user, token, refreshToken)
    });
});

// Admin reset password for any user
exports.adminResetPassword = asyncHandler(async (req, res) => {
    const { id_user, new_password } = req.body;

    if (!id_user || !new_password) {
        return res.status(400).json({
            status: "error",
            message: 'id_user dan new_password wajib diisi'
        });
    }

    if (new_password.length < 8) {
        return res.status(400).json({
            status: "error",
            message: 'Password minimal 8 karakter'
        });
    }

    // Check if user exists
    const user = await prisma.user.findUnique({
        where: { id_user: parseInt(id_user) }
    });

    if (!user || user.deletedAt) {
        return res.status(404).json({
            status: "error",
            message: 'User tidak ditemukan'
        });
    }

    // Hash and save new password; revoke the target user's refresh tokens in the same transaction.
    const hashedPassword = await bcrypt.hash(new_password, 10);
    await prisma.$transaction([
        prisma.user.update({
            where: { id_user: parseInt(id_user) },
            data: { password: hashedPassword }
        }),
        prisma.refreshToken.deleteMany({ where: { id_user: parseInt(id_user) } })
    ]);

    // Audit log for sensitive action
    logAudit({
        action: 'ADMIN_RESET_PASSWORD',
        performedBy: req.user.id_user,
        targetUserId: parseInt(id_user),
        details: `Admin ${req.user.nama} reset password for user ${user.nama}`,
        ip: req.ip || req.headers['x-forwarded-for']
    });

    res.status(200).json({
        status: "success",
        message: `Password untuk ${user.nama} berhasil direset`
    });
});

exports.deactivateUser = asyncHandler(async (req, res) => {
    const { id_user } = req.params;
    const parsedId = parseInt(id_user);
    
    const user = await prisma.user.findUnique({ where: { id_user: parsedId } });
    if (!user || user.deletedAt) {
        return res.status(404).json({ status: "error", message: "User not found or already deactivated" });
    }
    
    // Prevent deactivating self
    if (parsedId === req.user.id_user) {
        return res.status(400).json({ status: "error", message: "Cannot deactivate yourself" });
    }
    
    await prisma.$transaction([
        // Soft-delete user
        prisma.user.update({
            where: { id_user: parsedId },
            data: { deletedAt: new Date(), fcm_token: null }
        }),
        // Soft-delete associated biometrics (use updateMany to avoid error if no biometrics exists)
        prisma.dataBiometrik.updateMany({
            where: { id_user: parsedId },
            data: { deletedAt: new Date() }
        }),
        // Revoke all refresh tokens
        prisma.refreshToken.deleteMany({ where: { id_user: parsedId } })
    ]);
    
    // Invalidate embeddings cache
    embeddingCache.invalidateCache();
    
    logAudit({
        action: 'ADMIN_DEACTIVATE_USER',
        performedBy: req.user.id_user,
        targetUserId: parsedId,
        details: `Admin ${req.user.nama} deactivated user ${user.nama}`,
        ip: req.ip || req.headers['x-forwarded-for']
    });
    
    res.status(200).json({
        status: "success",
        message: `User ${user.nama} has been deactivated`
    });
});

exports.reactivateUser = asyncHandler(async (req, res) => {
    const { id_user } = req.params;
    const parsedId = parseInt(id_user);
    
    const user = await prisma.user.findUnique({ where: { id_user: parsedId } });
    if (!user || !user.deletedAt) {
        return res.status(404).json({ status: "error", message: "User not found or already active" });
    }
    
    // Only the account is reactivated. Biometric data that was soft-deleted (on purpose, or when the
    // account was deactivated) is NOT restored: the admin re-enrolls the face if it is still needed.
    await prisma.user.update({
        where: { id_user: parsedId },
        data: { deletedAt: null }
    });

    // Invalidate embeddings cache
    embeddingCache.invalidateCache();

    logAudit({
        action: 'ADMIN_REACTIVATE_USER',
        performedBy: req.user.id_user,
        targetUserId: parsedId,
        details: `Admin ${req.user.nama} reactivated user ${user.nama}`,
        ip: req.ip || req.headers['x-forwarded-for']
    });
    
    res.status(200).json({
        status: "success",
        message: `User ${user.nama} has been reactivated`
    });
});

// Register/Update FCM token for push notifications
exports.registerFcmToken = asyncHandler(async (req, res) => {
    const { fcm_token } = req.body;
    const userId = req.user.id_user;

    if (!fcm_token || fcm_token.trim() === '') {
        return res.status(400).json({
            status: "error",
            message: 'FCM token is required'
        });
    }

    await prisma.user.update({
        where: { id_user: userId },
        data: { fcm_token: fcm_token.trim() }
    });

    res.status(200).json({
        status: "success",
        message: 'FCM token registered successfully'
    });
});

exports.updatePreferences = asyncHandler(async (req, res) => {
    const { push_notifications_enabled } = req.body;
    const userId = req.user.id_user;

    if (push_notifications_enabled === undefined) {
        return res.status(400).json({
            status: "error",
            message: 'push_notifications_enabled is required'
        });
    }

    const user = await prisma.user.update({
        where: { id_user: userId },
        data: { push_notifications_enabled: Boolean(push_notifications_enabled) },
        select: { id_user: true, push_notifications_enabled: true }
    });

    res.status(200).json({
        status: "success",
        message: 'Preferences updated successfully',
        data: user
    });
});

const { uploadFile } = require('../utils/r2FileHandler');

exports.uploadProfilePicture = asyncHandler(async (req, res) => {
    const userId = req.user.id_user;
    const file = req.file;

    if (!file) {
        return res.status(400).json({
            status: "error",
            message: 'Profile picture image is required'
        });
    }

    try {
        const uploadResult = await uploadFile(
            file.buffer,
            file.originalname,
            file.mimetype,
            'profiles'
        );

        const updatedUser = await prisma.user.update({
            where: { id_user: userId },
            data: { profile_picture: uploadResult.fileUrl },
            select: { id_user: true, profile_picture: true }
        });

        res.status(200).json({
            status: "success",
            message: 'Profile picture uploaded successfully',
            data: updatedUser
        });
    } catch (error) {
        console.error('Failed to upload profile picture:', error.message);
        res.status(500).json({
            status: "error",
            message: GENERIC_SERVER_ERROR
        });
    }
});

const { sendPasswordResetEmail } = require('../utils/mailer');

// Same answer whether or not the account exists (prevents user enumeration)
const PASSWORD_RESET_REQUESTED_MESSAGE = 'Jika username atau email terdaftar, tautan reset password telah dikirim.';

exports.requestPasswordReset = asyncHandler(async (req, res) => {
    const { username } = req.body;
    
    // Find user by username or email. Emails are stored lowercased by register, but older rows may not
    // be, so the email match is case-insensitive.
    const user = await prisma.user.findFirst({
        where: {
            OR: [
                { username: username },
                { email: { equals: username, mode: 'insensitive' } } // Also check email if they enter email
            ],
            deletedAt: null
        }
    });

    if (!user) {
        // Return 200 anyway to prevent user enumeration attacks
        return res.status(200).json({
            status: "success",
            message: PASSWORD_RESET_REQUESTED_MESSAGE
        });
    }

    // Respond immediately to prevent timing attack / user enumeration
    res.status(200).json({
        status: "success",
        message: PASSWORD_RESET_REQUESTED_MESSAGE
    });

    // Handle token creation and email sending asynchronously in the background
    setImmediate(async () => {
        try {
            // Jika user tidak punya email terdaftar, batalkan pengiriman
            // (email bersifat opsional di sistem ini — user tanpa email hubungi admin)
            if (!user.email) {
                console.warn(`[PasswordReset] User '${user.username}' tidak memiliki email. Reset link tidak dikirim.`);
                return;
            }
            const targetEmail = user.email;
            const resetToken = uuidv4();
            const expiresAt = new Date();
            expiresAt.setMinutes(expiresAt.getMinutes() + 30); // 30 mins validity

            await prisma.passwordResetToken.create({
                data: {
                    token: resetToken,
                    id_user: user.id_user,
                    expiresAt: expiresAt
                }
            });

            const resetUrl = `${process.env.FRONTEND_URL || 'http://localhost:3000'}/reset-password?token=${resetToken}`;
            
            // Send email
            sendPasswordResetEmail(targetEmail, resetUrl);
        } catch (error) {
            console.error('Background password reset error:', error);
        }
    });
});

exports.resetPasswordWithToken = asyncHandler(async (req, res) => {
    const { token, newPassword } = req.body;

    const resetRecord = await prisma.passwordResetToken.findUnique({
        where: { token: token },
        include: { user: true }
    });

    if (!resetRecord || resetRecord.usedAt || new Date() > resetRecord.expiresAt) {
        return res.status(400).json({
            status: "error",
            message: "Token reset tidak valid atau sudah kedaluwarsa"
        });
    }

    if (resetRecord.user.deletedAt) {
        return res.status(400).json({
            status: "error",
            message: "Akun pengguna sudah dinonaktifkan"
        });
    }

    const hashedPassword = await bcrypt.hash(newPassword, 10);

    await prisma.$transaction([
        prisma.user.update({
            where: { id_user: resetRecord.id_user },
            data: { password: hashedPassword }
        }),
        prisma.passwordResetToken.update({
            where: { id: resetRecord.id },
            data: { usedAt: new Date() }
        }),
        // Revoke every existing session: whoever knew the old password must log in again
        prisma.refreshToken.deleteMany({ where: { id_user: resetRecord.id_user } })
    ]);

    logAudit({
        action: 'USER_RESET_PASSWORD',
        performedBy: resetRecord.id_user,
        targetUserId: resetRecord.id_user,
        details: `User ${resetRecord.user.nama} reset their password via email link`,
        ip: req.ip || req.headers['x-forwarded-for']
    });

    res.status(200).json({
        status: "success",
        message: "Password berhasil direset"
    });
});