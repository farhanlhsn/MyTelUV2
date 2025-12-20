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
            // Exclude password
        },
        orderBy: {
            [orderByField]: orderByDirection
        },
        skip,
        take: limitNum
    });

    // Calculate pagination metadata
    const totalPages = Math.ceil(totalUsers / limitNum);

    res.status(200).json({
        status: "success",
        message: 'Users retrieved successfully',
        data: {
            users,
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