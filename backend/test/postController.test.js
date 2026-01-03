/**
 * Unit Testing - Post Controller
 * 
 * @author MyTelUV2 Team
 * @date 2026-01-04
 */

// Mock dependencies
jest.mock('../utils/prisma', () => ({
    post: { findMany: jest.fn(), count: jest.fn(), findFirst: jest.fn(), create: jest.fn(), update: jest.fn() },
    postLike: { findUnique: jest.fn(), create: jest.fn(), delete: jest.fn(), count: jest.fn() },
    postComment: { findMany: jest.fn(), count: jest.fn(), create: jest.fn(), findFirst: jest.fn(), update: jest.fn() },
    $transaction: jest.fn(),
}));

jest.mock('../utils/r2FileHandler', () => ({
    uploadFile: jest.fn(),
    deleteFile: jest.fn(),
    fileExists: jest.fn(),
}));

// Import modules
const prisma = require('../utils/prisma');
const { uploadFile, deleteFile, fileExists } = require('../utils/r2FileHandler');
const postController = require('../controllers/postController');

// Helper functions
const createMockReq = (body = {}, user = { id_user: 1, role: 'MAHASISWA' }, params = {}, query = {}, files = {}) => ({
    body,
    user,
    params,
    query,
    files
});

const createMockRes = () => {
    const res = {};
    res.status = jest.fn().mockReturnValue(res);
    res.json = jest.fn().mockReturnValue(res);
    return res;
};

describe('Post Controller Tests', () => {

    beforeEach(() => {
        jest.clearAllMocks();
    });

    /**
     * GET ALL POSTS
     */
    describe('getAllPosts', () => {
        test('should return posts with pagination and like status', async () => {
            const mockPosts = [
                { id_post: 1, user: { id_user: 1 }, likes: [{ id_user: 1 }], _count: { likes: 5, comments: 2 } },
                { id_post: 2, user: { id_user: 2 }, likes: [], _count: { likes: 0, comments: 0 } }
            ];
            const mockTotal = 2;

            prisma.$transaction.mockResolvedValue([mockPosts, mockTotal]);

            const req = createMockReq({}, { id_user: 1 }, {}, { page: 1, limit: 10 });
            const res = createMockRes();

            await postController.getAllPosts(req, res);

            expect(prisma.$transaction).toHaveBeenCalled();
            expect(res.status).toHaveBeenCalledWith(200);
            expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
                data: expect.arrayContaining([
                    expect.objectContaining({ id_post: 1, isLiked: true, likeCount: 5 }),
                    expect.objectContaining({ id_post: 2, isLiked: false, likeCount: 0 })
                ])
            }));
        });
    });

    /**
     * CREATE POST
     */
    describe('createPost', () => {
        test('should create post successfully with media', async () => {
            const req = createMockReq(
                { content: 'Hello' },
                { id_user: 1 },
                {}, {},
                { media: [{ buffer: 'buf', originalname: 'a.jpg', mimetype: 'image/jpeg' }] }
            );
            const res = createMockRes();

            uploadFile.mockResolvedValue({ fileUrl: 'url1' });
            prisma.post.create.mockResolvedValue({ id_post: 1, content: 'Hello', media: ['url1'] });

            await postController.createPost(req, res);

            expect(uploadFile).toHaveBeenCalled();
            expect(prisma.post.create).toHaveBeenCalledWith(expect.objectContaining({
                data: expect.objectContaining({ media: ['url1'] })
            }));
            expect(res.status).toHaveBeenCalledWith(201);
        });

        test('should fail if content is empty', async () => {
            const req = createMockReq({ content: '' });
            const res = createMockRes();
            await postController.createPost(req, res);
            expect(res.status).toHaveBeenCalledWith(400);
        });
    });

    /**
     * TOGGLE LIKE
     */
    describe('toggleLike', () => {
        test('should like if not already liked', async () => {
            const req = createMockReq({}, { id_user: 1 }, { id: 1 });
            const res = createMockRes();

            prisma.post.findFirst.mockResolvedValue({ id_post: 1 });
            prisma.postLike.findUnique.mockResolvedValue(null); // Not liked yet
            prisma.postLike.create.mockResolvedValue({});
            prisma.postLike.count.mockResolvedValue(1);

            await postController.toggleLike(req, res);

            expect(prisma.postLike.create).toHaveBeenCalled();
            expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
                data: expect.objectContaining({ isLiked: true, likeCount: 1 })
            }));
        });

        test('should unlike if already liked', async () => {
            const req = createMockReq({}, { id_user: 1 }, { id: 1 });
            const res = createMockRes();

            prisma.post.findFirst.mockResolvedValue({ id_post: 1 });
            prisma.postLike.findUnique.mockResolvedValue({ id_like: 100 }); // Already liked
            prisma.postLike.delete.mockResolvedValue({});
            prisma.postLike.count.mockResolvedValue(0);

            await postController.toggleLike(req, res);

            expect(prisma.postLike.delete).toHaveBeenCalled();
            expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
                data: expect.objectContaining({ isLiked: false, likeCount: 0 })
            }));
        });
    });

    /**
     * DELETE POST
     */
    describe('deletePost', () => {
        test('should delete post and files if owner', async () => {
            const req = createMockReq({}, { id_user: 1, role: 'MAHASISWA' }, { id: 1 });
            const res = createMockRes();

            prisma.post.findFirst.mockResolvedValue({
                id_post: 1,
                id_user: 1,
                media: ['url1']
            });
            fileExists.mockResolvedValue(true);

            await postController.deletePost(req, res);

            expect(deleteFile).toHaveBeenCalledWith('url1');
            expect(prisma.post.update).toHaveBeenCalledWith({
                where: { id_post: 1 },
                data: { deletedAt: expect.anything() }
            });
            expect(res.status).toHaveBeenCalledWith(200);
        });

        test('should fail if not owner and not admin', async () => {
            const req = createMockReq({}, { id_user: 2, role: 'MAHASISWA' }, { id: 1 });
            const res = createMockRes();

            prisma.post.findFirst.mockResolvedValue({ id_post: 1, id_user: 1 });

            await postController.deletePost(req, res);

            expect(res.status).toHaveBeenCalledWith(403);
        });
    });

    /**
     * ADD COMMENT
     */
    describe('addComment', () => {
        test('should add comment successfully', async () => {
            const req = createMockReq({ content: 'Nice' }, { id_user: 1 }, { id: 1 });
            const res = createMockRes();

            prisma.post.findFirst.mockResolvedValue({ id_post: 1 });
            prisma.postComment.create.mockResolvedValue({ id_comment: 1, content: 'Nice' });

            await postController.addComment(req, res);

            expect(prisma.postComment.create).toHaveBeenCalled();
            expect(res.status).toHaveBeenCalledWith(201);
        });
    });
});
