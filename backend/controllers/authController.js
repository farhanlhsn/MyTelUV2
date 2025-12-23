const prisma = require('../utils/prisma');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const asyncHandler = require('express-async-handler');

exports.register = asyncHandler(async (req, res) => {
    const { nama, username, password, role } = req.body;

    const checkExisted = await prisma.user.findUnique({
        where: {
            username: username
        }
    });
    if (checkExisted) {
        return res.status(400).json({ status: "error", message: 'Username already exists' });
    }

    const hashedPassword = await bcrypt.hash(password, 10);
    const user = await prisma.user.create({
        data: {
            nama,
            username,
            password: hashedPassword,
            role: role || 'MAHASISWA'
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
            username: username
        }
    });
    if (!user) {
        return res.status(401).json({ status: "error", message: 'Invalid username or password' });
    }

    const isPasswordValid = await bcrypt.compare(password, user.password);
    if (!isPasswordValid) {
        return res.status(401).json({ status: "error", message: 'Invalid username or password' });
    }

    const token = jwt.sign({ id: user.id_user }, process.env.JWT_SECRET, { expiresIn: process.env.JWT_EXPIRES_IN || '1d' });

    res.status(200).json({
        status: "success",
        message: 'Login successful',
        data: {
            id_user: user.id_user,
            token: token,
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
            role: user.role
        }
    });
});

exports.getAllUsers = asyncHandler(async (req, res) => {
    const {
        role,
        search,
        page = 1,
        limit = 10,
        sortBy = 'createdAt',
        order = 'desc'
    } = req.query;

    // Build filter object
    const where = {
        deletedAt: null // Exclude soft-deleted users
    };

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

    res.status(200).json({
        status: "success",
        message: `Password for ${user.nama} has been reset successfully`
    });
});