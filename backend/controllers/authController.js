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