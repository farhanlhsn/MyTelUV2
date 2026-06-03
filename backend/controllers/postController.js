const asyncHandler = require('express-async-handler');
const prisma = require('../utils/prisma');
const { uploadFile, deleteFile, fileExists } = require('../utils/r2FileHandler');
const { parsePagination, buildPaginationMeta } = require('../utils/paginationHelper');
const { moderateContent } = require('../utils/contentModerator');
const { sendSocialNotification } = require('../utils/firebase');

// ==================== POST CRUD ====================

// Get all posts (feed) with pagination
exports.getAllPosts = asyncHandler(async (req, res) => {
    const { page, limit, skip } = parsePagination(req.query);
    const userId = req.user.id_user;

    const [posts, total] = await prisma.$transaction([
        prisma.post.findMany({
            where: { deletedAt: null },
            skip,
            take: limit,
            include: {
                user: {
                    select: {
                        id_user: true,
                        nama: true,
                        username: true,
                        role: true
                    }
                },
                likes: {
                    where: { id_user: userId },
                    select: { id_user: true }
                },
                comments: {
                    where: { deletedAt: null },
                    select: { id_comment: true }
                },
                _count: {
                    select: {
                        likes: true,
                        comments: { where: { deletedAt: null } }
                    }
                }
            },
            orderBy: { createdAt: 'desc' }
        }),
        prisma.post.count({ where: { deletedAt: null } })
    ]);

    // Add isLiked field for current user
    const postsWithLikeStatus = posts.map(post => ({
        ...post,
        isLiked: post.likes.length > 0,
        likeCount: post._count.likes,
        commentCount: post._count.comments,
        likes: undefined,
        _count: undefined
    }));

    res.status(200).json({
        status: "success",
        data: postsWithLikeStatus,
        pagination: buildPaginationMeta(total, page, limit)
    });
});

// Get single post by ID
exports.getPostById = asyncHandler(async (req, res) => {
    const { id } = req.params;
    const userId = req.user.id_user;

    const post = await prisma.post.findFirst({
        where: {
            id_post: parseInt(id),
            deletedAt: null
        },
        include: {
            user: {
                select: {
                    id_user: true,
                    nama: true,
                    username: true,
                    role: true
                }
            },
            likes: {
                where: { id_user: userId },
                select: { id_user: true }
            },
            comments: {
                where: { deletedAt: null },
                include: {
                    user: {
                        select: {
                            id_user: true,
                            nama: true,
                            username: true
                        }
                    }
                },
                orderBy: { createdAt: 'asc' }
            },
            _count: {
                select: {
                    likes: true,
                    comments: { where: { deletedAt: null } }
                }
            }
        }
    });

    if (!post) {
        return res.status(404).json({
            status: "error",
            message: "Post not found"
        });
    }

    res.status(200).json({
        status: "success",
        data: {
            ...post,
            isLiked: post.likes.length > 0,
            likeCount: post._count.likes,
            commentCount: post._count.comments,
            likes: undefined,
            _count: undefined
        }
    });
});

// Create new post
exports.createPost = asyncHandler(async (req, res) => {
    const { content, latitude, longitude, location_name } = req.body;
    const userId = req.user.id_user;

    if (!content || content.trim() === '') {
        return res.status(400).json({
            status: "error",
            message: "Content is required"
        });
    }

    // OpenAI Moderation check
    const moderationResult = await moderateContent(content);
    if (moderationResult.flagged) {
        return res.status(400).json({
            status: "error",
            message: "Postingan melanggar panduan komunitas."
        });
    }

    // Handle media uploads
    let mediaUrls = [];
    if (req.files && req.files.media) {
        const mediaFiles = Array.isArray(req.files.media) ? req.files.media : [req.files.media];

        for (const file of mediaFiles) {
            try {
                const result = await uploadFile(
                    file.buffer,
                    file.originalname,
                    file.mimetype,
                    'posts'
                );
                mediaUrls.push(result.fileUrl);
            } catch (error) {
                return res.status(500).json({
                    status: "error",
                    message: `Failed to upload media: ${error.message}`
                });
            }
        }
    }

    const post = await prisma.post.create({
        data: {
            id_user: userId,
            content: content.trim(),
            media: mediaUrls,
            latitude: latitude ? parseFloat(latitude) : null,
            longitude: longitude ? parseFloat(longitude) : null,
            location_name: location_name || null
        },
        include: {
            user: {
                select: {
                    id_user: true,
                    nama: true,
                    username: true,
                    role: true
                }
            }
        }
    });

    res.status(201).json({
        status: "success",
        message: "Post created successfully",
        data: {
            ...post,
            isLiked: false,
            likeCount: 0,
            commentCount: 0
        }
    });
});

// Update post
exports.updatePost = asyncHandler(async (req, res) => {
    const { id } = req.params;
    const { content, latitude, longitude, location_name, remove_media } = req.body;
    const userId = req.user.id_user;

    const post = await prisma.post.findFirst({
        where: {
            id_post: parseInt(id),
            deletedAt: null
        }
    });

    if (!post) {
        return res.status(404).json({
            status: "error",
            message: "Post not found"
        });
    }

    if (post.id_user !== userId) {
        return res.status(403).json({
            status: "error",
            message: "You can only edit your own posts"
        });
    }

    // OpenAI Moderation check if content is provided
    if (content && content.trim() !== '') {
        const moderationResult = await moderateContent(content);
        if (moderationResult.flagged) {
            return res.status(400).json({
                status: "error",
                message: "Postingan melanggar panduan komunitas."
            });
        }
    }

    // Handle media updates (removal of selected files)
    let finalMedia = [...post.media];
    let shouldUpdateMedia = false;

    if (remove_media) {
        shouldUpdateMedia = true;
        let filesToRemove = [];
        if (Array.isArray(remove_media)) {
            filesToRemove = remove_media;
        } else {
            try {
                filesToRemove = JSON.parse(remove_media);
                if (!Array.isArray(filesToRemove)) {
                    filesToRemove = [filesToRemove];
                }
            } catch (e) {
                filesToRemove = [remove_media];
            }
        }

        for (const url of filesToRemove) {
            if (post.media.includes(url)) {
                try {
                    if (await fileExists(url)) {
                        await deleteFile(url);
                    }
                } catch (err) {
                    console.error(`Failed to delete file from R2: ${url}`, err.message);
                }
            }
        }
        finalMedia = finalMedia.filter(url => !filesToRemove.includes(url));
    }

    // Handle media updates (upload new files)
    if (req.files && req.files.media) {
        shouldUpdateMedia = true;
        const mediaFiles = Array.isArray(req.files.media) ? req.files.media : [req.files.media];

        for (const file of mediaFiles) {
            try {
                const result = await uploadFile(
                    file.buffer,
                    file.originalname,
                    file.mimetype,
                    'posts'
                );
                finalMedia.push(result.fileUrl);
            } catch (error) {
                return res.status(500).json({
                    status: "error",
                    message: `Failed to upload media: ${error.message}`
                });
            }
        }
    }

    const updatedPost = await prisma.post.update({
        where: { id_post: parseInt(id) },
        data: {
            content: content ? content.trim() : undefined,
            latitude: latitude !== undefined ? parseFloat(latitude) : undefined,
            longitude: longitude !== undefined ? parseFloat(longitude) : undefined,
            location_name: location_name !== undefined ? location_name : undefined,
            media: shouldUpdateMedia ? finalMedia : undefined
        },
        include: {
            user: {
                select: {
                    id_user: true,
                    nama: true,
                    username: true,
                    role: true
                }
            }
        }
    });

    res.status(200).json({
        status: "success",
        message: "Post updated successfully",
        data: updatedPost
    });
});

// Delete post (soft delete)
exports.deletePost = asyncHandler(async (req, res) => {
    const { id } = req.params;
    const userId = req.user.id_user;
    const userRole = req.user.role;

    const post = await prisma.post.findFirst({
        where: {
            id_post: parseInt(id),
            deletedAt: null
        }
    });

    if (!post) {
        return res.status(404).json({
            status: "error",
            message: "Post not found"
        });
    }

    // Allow owner or admin to delete
    if (post.id_user !== userId && userRole !== 'ADMIN') {
        return res.status(403).json({
            status: "error",
            message: "You can only delete your own posts"
        });
    }

    // Delete associated media files
    if (post.media && post.media.length > 0) {
        for (const mediaUrl of post.media) {
            if (await fileExists(mediaUrl)) {
                await deleteFile(mediaUrl);
            }
        }
    }

    await prisma.post.update({
        where: { id_post: parseInt(id) },
        data: { deletedAt: new Date() }
    });

    res.status(200).json({
        status: "success",
        message: "Post deleted successfully"
    });
});

// ==================== LIKES ====================

// Toggle like on post
exports.toggleLike = asyncHandler(async (req, res) => {
    const { id } = req.params;
    const userId = req.user.id_user;

    const post = await prisma.post.findFirst({
        where: {
            id_post: parseInt(id),
            deletedAt: null
        }
    });

    if (!post) {
        return res.status(404).json({
            status: "error",
            message: "Post not found"
        });
    }

    // Check if already liked
    const existingLike = await prisma.postLike.findUnique({
        where: {
            id_post_id_user: {
                id_post: parseInt(id),
                id_user: userId
            }
        }
    });

    let isLiked;
    if (existingLike) {
        // Unlike
        await prisma.postLike.delete({
            where: { id_like: existingLike.id_like }
        });
        isLiked = false;
    } else {
        // Like
        await prisma.postLike.create({
            data: {
                id_post: parseInt(id),
                id_user: userId
            }
        });
        isLiked = true;

        // Trigger notification
        if (post.id_user !== userId) {
            // Get current user's name
            prisma.user.findUnique({ where: { id_user: userId }, select: { nama: true } })
                .then(user => {
                    if (user) {
                        sendSocialNotification(post.id_user, 'LIKE', user.nama, post.content)
                            .catch(err => console.error('Error triggering like notification:', err.message));
                    }
                })
                .catch(err => console.error('Error fetching user for like notification:', err.message));
        }
    }

    // Get updated like count
    const likeCount = await prisma.postLike.count({
        where: { id_post: parseInt(id) }
    });

    res.status(200).json({
        status: "success",
        message: isLiked ? "Post liked" : "Post unliked",
        data: {
            isLiked,
            likeCount
        }
    });
});

// ==================== COMMENTS ====================

// Get comments for a post
exports.getComments = asyncHandler(async (req, res) => {
    const { id } = req.params;
    const { page = 1, limit = 20 } = req.query;
    const skip = (parseInt(page) - 1) * parseInt(limit);

    const post = await prisma.post.findFirst({
        where: {
            id_post: parseInt(id),
            deletedAt: null
        }
    });

    if (!post) {
        return res.status(404).json({
            status: "error",
            message: "Post not found"
        });
    }

    const [comments, total] = await prisma.$transaction([
        prisma.postComment.findMany({
            where: {
                id_post: parseInt(id),
                deletedAt: null
            },
            skip,
            take: parseInt(limit),
            include: {
                user: {
                    select: {
                        id_user: true,
                        nama: true,
                        username: true
                    }
                }
            },
            orderBy: { createdAt: 'asc' }
        }),
        prisma.postComment.count({
            where: {
                id_post: parseInt(id),
                deletedAt: null
            }
        })
    ]);

    res.status(200).json({
        status: "success",
        data: comments,
        pagination: {
            total,
            page: parseInt(page),
            limit: parseInt(limit),
            totalPages: Math.ceil(total / parseInt(limit))
        }
    });
});

// Add comment to post
exports.addComment = asyncHandler(async (req, res) => {
    const { id } = req.params;
    const { content } = req.body;
    const userId = req.user.id_user;

    if (!content || content.trim() === '') {
        return res.status(400).json({
            status: "error",
            message: "Comment content is required"
        });
    }

    // OpenAI Moderation check
    const moderationResult = await moderateContent(content);
    if (moderationResult.flagged) {
        return res.status(400).json({
            status: "error",
            message: "Postingan melanggar panduan komunitas."
        });
    }

    const post = await prisma.post.findFirst({
        where: {
            id_post: parseInt(id),
            deletedAt: null
        }
    });

    if (!post) {
        return res.status(404).json({
            status: "error",
            message: "Post not found"
        });
    }

    const comment = await prisma.postComment.create({
        data: {
            id_post: parseInt(id),
            id_user: userId,
            content: content.trim()
        },
        include: {
            user: {
                select: {
                    id_user: true,
                    nama: true,
                    username: true
                }
            }
        }
    });

    // Trigger notification
    if (post.id_user !== userId) {
        sendSocialNotification(post.id_user, 'COMMENT', comment.user.nama, post.content)
            .catch(err => console.error('Error triggering comment notification:', err.message));
    }

    res.status(201).json({
        status: "success",
        message: "Comment added successfully",
        data: comment
    });
});

// Delete comment
exports.deleteComment = asyncHandler(async (req, res) => {
    const { id, commentId } = req.params;
    const userId = req.user.id_user;
    const userRole = req.user.role;

    const comment = await prisma.postComment.findFirst({
        where: {
            id_comment: parseInt(commentId),
            id_post: parseInt(id),
            deletedAt: null
        }
    });

    if (!comment) {
        return res.status(404).json({
            status: "error",
            message: "Comment not found"
        });
    }

    // Allow owner or admin to delete
    if (comment.id_user !== userId && userRole !== 'ADMIN') {
        return res.status(403).json({
            status: "error",
            message: "You can only delete your own comments"
        });
    }

    await prisma.postComment.update({
        where: { id_comment: parseInt(commentId) },
        data: { deletedAt: new Date() }
    });

    res.status(200).json({
        status: "success",
        message: "Comment deleted successfully"
    });
});

// Get my posts
exports.getMyPosts = asyncHandler(async (req, res) => {
    const userId = req.user.id_user;
    const { page = 1, limit = 10 } = req.query;
    const skip = (parseInt(page) - 1) * parseInt(limit);

    const [posts, total] = await prisma.$transaction([
        prisma.post.findMany({
            where: {
                id_user: userId,
                deletedAt: null
            },
            skip,
            take: parseInt(limit),
            include: {
                user: {
                    select: {
                        id_user: true,
                        nama: true,
                        username: true,
                        role: true
                    }
                },
                _count: {
                    select: {
                        likes: true,
                        comments: { where: { deletedAt: null } }
                    }
                }
            },
            orderBy: { createdAt: 'desc' }
        }),
        prisma.post.count({
            where: {
                id_user: userId,
                deletedAt: null
            }
        })
    ]);

    const postsWithCounts = posts.map(post => ({
        ...post,
        likeCount: post._count.likes,
        commentCount: post._count.comments,
        _count: undefined
    }));

    res.status(200).json({
        status: "success",
        data: postsWithCounts,
        pagination: {
            total,
            page: parseInt(page),
            limit: parseInt(limit),
            totalPages: Math.ceil(total / parseInt(limit))
        }
    });
});
