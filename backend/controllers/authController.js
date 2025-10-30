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
            token: token,
            username: user.username,
            nama: user.nama,
            role: user.role
        } 
    });
});

exports.getMe = asyncHandler(async (req, res) => {
    const token = req.headers.authorization?.split(' ')[1];
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
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