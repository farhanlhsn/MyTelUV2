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
    user: { findUnique: jest.fn() },
    $transaction: jest.fn(),
}));

jest.mock('../utils/r2FileHandler', () => ({
    uploadFile: jest.fn(),
    deleteFile: jest.fn(),
    fileExists: jest.fn(),
}));

jest.mock('../utils/firebase', () => ({
    sendSocialNotification: jest.fn().mockResolvedValue({ success: true }),
}));

// Import modules
const prisma = require('../utils/prisma');
const { uploadFile, deleteFile, fileExists } = require('../utils/r2FileHandler');
const { sendSocialNotification } = require('../utils/firebase');
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

        test('the feed does not load the comment rows (only the comment count)', async () => {
            prisma.$transaction.mockResolvedValue([[], 0]);

            await postController.getAllPosts(createMockReq({}, { id_user: 1 }, {}, {}), createMockRes());

            const [findArgs] = prisma.post.findMany.mock.calls[0];
            expect(findArgs.include).not.toHaveProperty('comments');
            expect(findArgs.include._count.select.comments).toEqual({ where: { deletedAt: null } });
        });

        test('limit is clamped to 1..100', async () => {
            prisma.$transaction.mockResolvedValue([[], 0]);

            await postController.getAllPosts(createMockReq({}, { id_user: 1 }, {}, { limit: '100000' }), createMockRes());

            expect(prisma.post.findMany.mock.calls[0][0].take).toBe(100);
        });
    });

    /**
     * LIMIT CLAMPING (comments, my posts)
     */
    describe('limit clamping', () => {
        test.each([
            ['100000', 100],
            ['-5', 1],
            ['abc', 20]
        ])('getComments limit=%s -> take %i (default 20)', async (limit, take) => {
            prisma.post.findFirst.mockResolvedValue({ id_post: 1 });
            prisma.$transaction.mockResolvedValue([[], 0]);
            const res = createMockRes();

            await postController.getComments(createMockReq({}, { id_user: 1 }, { id: '1' }, { page: '2', limit }), res);

            expect(prisma.postComment.findMany).toHaveBeenCalledWith(expect.objectContaining({ take, skip: take }));
            expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
                pagination: expect.objectContaining({ page: 2, limit: take })
            }));
        });

        test.each([
            ['100000', 100],
            ['0', 10],
            [undefined, 10]
        ])('getMyPosts limit=%s -> take %i (default 10)', async (limit, take) => {
            prisma.$transaction.mockResolvedValue([[], 0]);
            const res = createMockRes();

            await postController.getMyPosts(createMockReq({}, { id_user: 1 }, {}, { page: '-3', limit }), res);

            expect(prisma.post.findMany).toHaveBeenCalledWith(expect.objectContaining({ take, skip: 0 }));
            expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
                pagination: expect.objectContaining({ page: 1, limit: take })
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

        test('a media upload failure returns a generic 500 and never leaks error.message', async () => {
            const errorSpy = jest.spyOn(console, 'error').mockImplementation(() => {});
            const req = createMockReq(
                { content: 'Hello' },
                { id_user: 1 },
                {}, {},
                { media: [{ buffer: 'buf', originalname: 'a.jpg', mimetype: 'image/jpeg' }] }
            );
            const res = createMockRes();
            uploadFile.mockRejectedValueOnce(new Error('connect ECONNREFUSED r2.internal.example:9000 password=hunter2'));

            try {
                await postController.createPost(req, res);

                expect(res.status).toHaveBeenCalledWith(500);
                expect(res.json).toHaveBeenCalledWith({
                    status: 'error',
                    message: 'Terjadi kesalahan pada server'
                });
                expect(JSON.stringify(res.json.mock.calls)).not.toMatch(/ECONNREFUSED|hunter2/);
                expect(errorSpy).toHaveBeenCalled(); // the real error is logged, not returned
            } finally {
                errorSpy.mockRestore();
            }
        });
    });

    /**
     * UPDATE POST
     */
    describe('updatePost', () => {
        test('a media upload failure returns a generic 500 and never leaks error.message', async () => {
            const errorSpy = jest.spyOn(console, 'error').mockImplementation(() => {});
            const req = createMockReq(
                { content: 'Edited' },
                { id_user: 1 },
                { id: 1 }, {},
                { media: [{ buffer: 'buf', originalname: 'a.jpg', mimetype: 'image/jpeg' }] }
            );
            const res = createMockRes();
            prisma.post.findFirst.mockResolvedValueOnce({ id_post: 1, id_user: 1, content: 'Hello', media: [] });
            uploadFile.mockRejectedValueOnce(new Error('connect ECONNREFUSED r2.internal.example:9000 password=hunter2'));

            try {
                await postController.updatePost(req, res);

                expect(res.status).toHaveBeenCalledWith(500);
                expect(res.json).toHaveBeenCalledWith({
                    status: 'error',
                    message: 'Terjadi kesalahan pada server'
                });
                expect(JSON.stringify(res.json.mock.calls)).not.toMatch(/ECONNREFUSED|hunter2/);
                expect(errorSpy).toHaveBeenCalled(); // the real error is logged, not returned
            } finally {
                errorSpy.mockRestore();
            }
        });
    });

    /**
     * TOGGLE LIKE
     */
    describe('toggleLike', () => {
        test('should like if not already liked', async () => {
            const req = createMockReq({}, { id_user: 1 }, { id: 1 });
            const res = createMockRes();

            prisma.post.findFirst.mockResolvedValue({ id_post: 1, id_user: 2, content: 'Hello' });
            prisma.postLike.findUnique.mockResolvedValue(null); // Not liked yet
            prisma.postLike.create.mockResolvedValue({});
            prisma.postLike.count.mockResolvedValue(1);
            prisma.user.findUnique.mockResolvedValue({ nama: 'Alice' });

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

        test('a like that loses the race to a parallel like (P2002) is treated as already liked: 200', async () => {
            const req = createMockReq({}, { id_user: 1 }, { id: 1 });
            const res = createMockRes();

            prisma.post.findFirst.mockResolvedValue({ id_post: 1, id_user: 2, content: 'Hello' });
            prisma.postLike.findUnique.mockResolvedValue(null); // both requests saw "not liked"
            prisma.postLike.create.mockRejectedValueOnce(Object.assign(new Error('Unique constraint failed'), { code: 'P2002' }));
            prisma.postLike.count.mockResolvedValue(1);
            prisma.user.findUnique.mockResolvedValue({ nama: 'Alice' });

            await postController.toggleLike(req, res);

            expect(res.status).toHaveBeenCalledWith(200);
            expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
                status: 'success',
                data: { isLiked: true, likeCount: 1 }
            }));
            // the winning request already notified the owner
            expect(prisma.user.findUnique).not.toHaveBeenCalled();
            expect(sendSocialNotification).not.toHaveBeenCalled();
        });

        test('an unlike that loses the race to a parallel unlike (P2025) is treated as not liked: 200', async () => {
            const req = createMockReq({}, { id_user: 1 }, { id: 1 });
            const res = createMockRes();

            prisma.post.findFirst.mockResolvedValue({ id_post: 1, id_user: 2, content: 'Hello' });
            prisma.postLike.findUnique.mockResolvedValue({ id_like: 100 });
            prisma.postLike.delete.mockRejectedValueOnce(Object.assign(new Error('Record to delete does not exist'), { code: 'P2025' }));
            prisma.postLike.count.mockResolvedValue(0);

            await postController.toggleLike(req, res);

            expect(res.status).toHaveBeenCalledWith(200);
            expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
                data: { isLiked: false, likeCount: 0 }
            }));
        });

        test('any other error while liking still fails', async () => {
            const req = createMockReq({}, { id_user: 1 }, { id: 1 });
            const res = createMockRes();

            prisma.post.findFirst.mockResolvedValue({ id_post: 1, id_user: 2, content: 'Hello' });
            prisma.postLike.findUnique.mockResolvedValue(null);
            prisma.postLike.create.mockRejectedValueOnce(new Error('connection lost'));

            await expect(postController.toggleLike(req, res)).rejects.toThrow('connection lost');
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

            prisma.post.findFirst.mockResolvedValue({ id_post: 1, id_user: 2, content: 'Hello' });
            prisma.postComment.create.mockResolvedValue({ id_comment: 1, content: 'Nice', user: { nama: 'Alice' } });

            await postController.addComment(req, res);

            expect(prisma.postComment.create).toHaveBeenCalled();
            expect(res.status).toHaveBeenCalledWith(201);
        });
    });
});
