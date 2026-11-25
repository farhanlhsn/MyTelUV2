/**
 * Unit Testing - TaskQueue cleanup is scheduled hourly so finished anomaly jobs do not pile up in memory
 */

jest.mock('node-cron', () => ({ schedule: jest.fn() }));
jest.mock('../utils/prisma', () => ({
    sesiAbsensi: { findMany: jest.fn().mockResolvedValue([]), updateMany: jest.fn() }
}));

const { TaskQueue, globalAnomalyQueue } = require('../utils/TaskQueue');
const { initScheduler } = require('../utils/scheduler');

const HOUR = 60 * 60 * 1000;

describe('TaskQueue cleanup timer', () => {
    afterEach(() => {
        jest.useRealTimers();
        jest.restoreAllMocks();
        globalAnomalyQueue.stopCleanupTimer();
    });

    test('runs cleanup() every hour', () => {
        jest.useFakeTimers();
        const queue = new TaskQueue(1);
        const cleanupSpy = jest.spyOn(queue, 'cleanup');

        queue.startCleanupTimer();
        jest.advanceTimersByTime(HOUR - 1);
        expect(cleanupSpy).not.toHaveBeenCalled();
        jest.advanceTimersByTime(1);
        expect(cleanupSpy).toHaveBeenCalledTimes(1);
        jest.advanceTimersByTime(HOUR);
        expect(cleanupSpy).toHaveBeenCalledTimes(2);

        queue.stopCleanupTimer();
        jest.advanceTimersByTime(HOUR);
        expect(cleanupSpy).toHaveBeenCalledTimes(2);
    });

    test('the timer is unref()ed (never keeps the process alive) and started only once', () => {
        const queue = new TaskQueue(1);

        const timer = queue.startCleanupTimer();
        try {
            expect(timer.hasRef()).toBe(false);
            expect(queue.startCleanupTimer()).toBe(timer);
        } finally {
            queue.stopCleanupTimer();
        }
    });

    test('cleanup() drops jobs finished more than 30 minutes ago', () => {
        const queue = new TaskQueue(1);
        const old = new Date(Date.now() - 31 * 60 * 1000).toISOString();
        const recent = new Date().toISOString();
        queue.jobs.set('old', { id: 'old', status: 'COMPLETED', completedAt: old });
        queue.jobs.set('failed-old', { id: 'failed-old', status: 'FAILED', completedAt: old });
        queue.jobs.set('recent', { id: 'recent', status: 'COMPLETED', completedAt: recent });
        queue.jobs.set('running', { id: 'running', status: 'PROCESSING', completedAt: null });

        queue.cleanup();

        expect([...queue.jobs.keys()]).toEqual(['recent', 'running']);
    });

    test('initScheduler starts the hourly cleanup of the anomaly job queue', () => {
        jest.spyOn(console, 'log').mockImplementation(() => {});
        const startSpy = jest.spyOn(globalAnomalyQueue, 'startCleanupTimer');

        initScheduler();

        expect(startSpy).toHaveBeenCalledTimes(1);
    });
});
