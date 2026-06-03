const prisma = require('../utils/prisma');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { v4: uuidv4 } = require('uuid');
const asyncHandler = require('express-async-handler');
const { logAudit } = require('../utils/auditLogger');
const embeddingCache = require('../utils/embeddingCache');

exports.register = asyncHandler(async (req, res) => {
    const { nama, username, password, role, nim_nip } = req.body;

    // Only allow MAHASISWA and DOSEN roles for public registration
    // ADMIN role can only be assigned by existing admins
    const allowedRoles = ['MAHASISWA', 'DOSEN'];
    const userRole = allowedRoles.includes(role) ? role : 'MAHASISWA';

    const checkExisted = await prisma.user.findUnique({
        where: {
            username: username
        }
    });
    if (checkExisted) {
        return res.status(400).json({ status: "error", message: 'Username already exists' });
    }

    if (nim_nip) {
        const checkNimNip = await prisma.user.findFirst({
            where: {
                nim_nip: nim_nip,
                deletedAt: null
            }
        });
        if (checkNimNip) {
            return res.status(400).json({ status: "error", message: 'NIM/NIP already exists' });
        }
    }

    const hashedPassword = await bcrypt.hash(password, 10);
    const user = await prisma.user.create({
        data: {
            nama,
            username,
            password: hashedPassword,
            role: userRole,
            nim_nip: nim_nip || null
        }
    });
    if (user) {
        res.status(201).json({
            status: "success",
            message: 'User created successfully',
            data: {
                id: user.id_user,
                username: user.username,
                nama: user.nama,
                role: user.role
            }
        });
    } else {
        res.status(400).json({ status: "error", message: 'Invalid user data' });
        throw new Error('Invalid user data');
    }
});

exports.login = asyncHandler(async (req, res) => {
    const { username, password } = req.body;

    const user = await prisma.user.findUnique({
        where: {
            username: username,
            deletedAt: null // Exclude soft-deleted users
        }
    });
    if (!user) {
        return res.status(401).json({ status: "error", message: 'Invalid username or password' });
    }

    const isPasswordValid = await bcrypt.compare(password, user.password);
    if (!isPasswordValid) {
        return res.status(401).json({ status: "error", message: 'Invalid username or password' });
    }

    // Generate access token (1 hour)
    const token = jwt.sign({ id: user.id_user }, process.env.JWT_SECRET, { expiresIn: '1h' });
    
    // Generate refresh token (7 days)
    const refreshToken = uuidv4();
    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + 7); // 7 days

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
        message: 'Login successful',
        data: {
            id_user: user.id_user,
            token: token,
            refresh_token: refreshToken,
            username: user.username,
            nama: user.nama,
            role: user.role
        }
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
            message: 'Old password and new password are required'
        });
    }

    if (newPassword.length < 6) {
        return res.status(400).json({
            status: "error",
            message: 'New password must be at least 6 characters'
        });
    }

    // Get current user with password
    const user = await prisma.user.findUnique({
        where: { id_user: userId }
    });

    // Verify old password
    const isPasswordValid = await bcrypt.compare(oldPassword, user.password);
    if (!isPasswordValid) {
        return res.status(401).json({
            status: "error",
            message: 'Old password is incorrect'
        });
    }

    // Hash and save new password
    const hashedPassword = await bcrypt.hash(newPassword, 10);
    await prisma.user.update({
        where: { id_user: userId },
        data: { password: hashedPassword }
    });

    res.status(200).json({
        status: "success",
        message: 'Password changed successfully'
    });
});

// Admin reset password for any user
exports.adminResetPassword = asyncHandler(async (req, res) => {
    const { id_user, new_password } = req.body;

    if (!id_user || !new_password) {
        return res.status(400).json({
            status: "error",
            message: 'id_user and new_password are required'
        });
    }

    if (new_password.length < 6) {
        return res.status(400).json({
            status: "error",
            message: 'Password must be at least 6 characters'
        });
    }

    // Check if user exists
    const user = await prisma.user.findUnique({
        where: { id_user: parseInt(id_user) }
    });

    if (!user || user.deletedAt) {
        return res.status(404).json({
            status: "error",
            message: 'User not found'
        });
    }

    // Hash and save new password
    const hashedPassword = await bcrypt.hash(new_password, 10);
    await prisma.user.update({
        where: { id_user: parseInt(id_user) },
        data: { password: hashedPassword }
    });

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
        message: `Password for ${user.nama} has been reset successfully`
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
    
    await prisma.$transaction([
        // Reactivate user
        prisma.user.update({
            where: { id_user: parsedId },
            data: { deletedAt: null }
        }),
        // Reactivate associated biometrics
        prisma.dataBiometrik.updateMany({
            where: { id_user: parsedId },
            data: { deletedAt: null }
        })
    ]);
    
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
        res.status(500).json({
            status: "error",
            message: 'Failed to upload profile picture: ' + error.message
        });
    }
});

const { sendPasswordResetEmail } = require('../utils/mailer');

exports.requestPasswordReset = asyncHandler(async (req, res) => {
    const { username } = req.body;
    
    // Find user by username or email
    const user = await prisma.user.findFirst({
        where: {
            OR: [
                { username: username },
                { email: username } // Also check email if they enter email
            ],
            deletedAt: null
        }
    });

    if (!user) {
        // Return 200 anyway to prevent user enumeration attacks
        return res.status(200).json({
            status: "success",
            message: "If the username or email exists, a reset link has been sent."
        });
    }

    // Respond immediately to prevent timing attack / user enumeration
    res.status(200).json({
        status: "success",
        message: "If the username or email exists, a reset link has been sent."
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
            message: "Invalid or expired reset token"
        });
    }

    if (resetRecord.user.deletedAt) {
        return res.status(400).json({
            status: "error",
            message: "User account is deactivated"
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
        })
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
        message: "Password has been successfully reset"
    });
});