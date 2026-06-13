/**
 * Asynchronous Background Task Queue Utility
 * 
 * Manages CPU/network intensive background jobs (like batch anomaly analysis)
 * sequentially or with limited concurrency to avoid resource exhaustion.
 * Runs in-memory for zero external dependencies (no Redis requirement for testing).
 */
class TaskQueue {
  constructor(concurrency = 1) {
    this.concurrency = concurrency;
    this.queue = [];
    this.activeWorkers = 0;
    this.jobs = new Map(); // Store job status: id -> { status, result, error, progress }
  }

  /**
   * Add a new job to the queue
   * @param {string} jobId Unique identifier for the job
   * @param {Function} taskFn Asynchronous function that executes the task
   * @returns {Object} Job status details
   */
  addJob(jobId, taskFn) {
    const jobInfo = {
      id: jobId,
      status: 'QUEUED',
      progress: 0,
      createdAt: new Date().toISOString(),
      completedAt: null,
      error: null,
      result: null
    };
    
    this.jobs.set(jobId, jobInfo);
    this.queue.push({ id: jobId, fn: taskFn });
    
    console.log(`[TaskQueue] Job ${jobId} queued. Total queue size: ${this.queue.length}`);
    
    // Trigger worker execution asynchronously
    setImmediate(() => this.processNext());
    
    return jobInfo;
  }

  /**
   * Process the next job in the queue
   */
  async processNext() {
    if (this.activeWorkers >= this.concurrency || this.queue.length === 0) {
      return;
    }

    this.activeWorkers++;
    const { id, fn } = this.queue.shift();
    const jobInfo = this.jobs.get(id);
    
    if (jobInfo) {
      jobInfo.status = 'PROCESSING';
      jobInfo.progress = 20;
    }

    console.log(`[TaskQueue] Starting execution of job ${id}`);

    try {
      if (jobInfo) jobInfo.progress = 50;
      const result = await fn();
      
      if (jobInfo) {
        jobInfo.status = 'COMPLETED';
        jobInfo.progress = 100;
        jobInfo.result = result;
        jobInfo.completedAt = new Date().toISOString();
      }
      console.log(`[TaskQueue] Job ${id} completed successfully`);
    } catch (err) {
      if (jobInfo) {
        jobInfo.status = 'FAILED';
        jobInfo.progress = 100;
        jobInfo.error = err.message;
        jobInfo.completedAt = new Date().toISOString();
      }
      console.error(`[TaskQueue] Job ${id} failed:`, err.message);
    } finally {
      this.activeWorkers--;
      // Process next job
      setImmediate(() => this.processNext());
    }
  }

  /**
   * Get the status of a specific job
   * @param {string} jobId 
   * @returns {Object|null}
   */
  getJobStatus(jobId) {
    return this.jobs.get(jobId) || null;
  }

  /**
   * Clear completed and failed jobs to free memory
   */
  cleanup() {
    const now = Date.now();
    for (const [id, info] of this.jobs.entries()) {
      if (['COMPLETED', 'FAILED'].includes(info.status)) {
        const completedTime = new Date(info.completedAt).getTime();
        // Keep logs for 30 minutes
        if (now - completedTime > 30 * 60 * 1000) {
          this.jobs.delete(id);
        }
      }
    }
  }
}

// Export single global instance
const globalAnomalyQueue = new TaskQueue(1);

module.exports = {
  TaskQueue,
  globalAnomalyQueue
};
