/**
 * Premium In-Memory Circuit Breaker Class
 * 
 * Protects the main Express application from cascade failures or thread starvation
 * due to slow or offline external AI microservices.
 */
class CircuitBreaker {
  /**
   * @param {string} serviceName Name of the service being monitored (e.g. "FaceAPI")
   * @param {Object} options Configuration options
   * @param {number} options.failureThreshold Consecutive failures before opening the circuit (default: 5)
   * @param {number} options.recoveryTimeout Time in ms before trying to heal (default: 30000 / 30s)
   * @param {number} options.successThreshold Consecutive successes in HALF-OPEN to close the circuit (default: 2)
   */
  constructor(serviceName, options = {}) {
    this.serviceName = serviceName;
    this.failureThreshold = options.failureThreshold || 5;
    this.recoveryTimeout = options.recoveryTimeout || 30000;
    this.successThreshold = options.successThreshold || 2;

    this.state = 'CLOSED'; // CLOSED, OPEN, HALF-OPEN
    this.failureCount = 0;
    this.successCount = 0;
    this.lastStateChanged = Date.now();
  }

  /**
   * Transition to a new state
   * @param {string} newState 
   */
  setState(newState) {
    if (this.state !== newState) {
      console.warn(`[CircuitBreaker - ${this.serviceName}] State change: ${this.state} -> ${newState}`);
      this.state = newState;
      this.lastStateChanged = Date.now();
      
      // Reset counters on state transition
      if (newState === 'CLOSED') {
        this.failureCount = 0;
        this.successCount = 0;
      } else if (newState === 'OPEN') {
        this.successCount = 0;
      } else if (newState === 'HALF-OPEN') {
        this.successCount = 0;
        this.failureCount = 0;
      }
    }
  }

  /**
   * Execute an asynchronous operation protected by the circuit breaker
   * @param {Function} action Asynchronous function to execute
   * @returns {Promise<any>}
   */
  async fire(action) {
    // 1. Check if the circuit is open and if it's time to try healing
    if (this.state === 'OPEN') {
      const now = Date.now();
      if (now - this.lastStateChanged >= this.recoveryTimeout) {
        this.setState('HALF-OPEN');
      } else {
        const secondsRemaining = Math.ceil((this.recoveryTimeout - (now - this.lastStateChanged)) / 1000);
        throw new Error(
          `Layanan ${this.serviceName} sedang offline secara protektif. Silakan coba kembali dalam ${secondsRemaining} detik.`
        );
      }
    }

    // 2. Execute action
    try {
      const result = await action();
      
      // Handle success
      if (this.state === 'HALF-OPEN') {
        this.successCount++;
        console.log(`[CircuitBreaker - ${this.serviceName}] Successful request in HALF-OPEN state (${this.successCount}/${this.successThreshold})`);
        
        if (this.successCount >= this.successThreshold) {
          this.setState('CLOSED');
        }
      }
      
      return result;
    } catch (error) {
      // Handle failure
      this.handleFailure(error);
      throw error;
    }
  }

  /**
   * Process a failure during execution
   * @param {Error} error 
   */
  handleFailure(error) {
    if (this.state === 'CLOSED') {
      this.failureCount++;
      console.error(`[CircuitBreaker - ${this.serviceName}] Failed request in CLOSED state (${this.failureCount}/${this.failureThreshold}): ${error.message}`);
      
      if (this.failureCount >= this.failureThreshold) {
        this.setState('OPEN');
      }
    } else if (this.state === 'HALF-OPEN') {
      console.error(`[CircuitBreaker - ${this.serviceName}] Failed request in HALF-OPEN state. Re-opening circuit immediately: ${error.message}`);
      this.setState('OPEN');
    }
  }

  /**
   * Force open/close for testing or administrative purposes
   * @param {string} state 
   */
  forceState(state) {
    if (['CLOSED', 'OPEN', 'HALF-OPEN'].includes(state)) {
      this.setState(state);
    }
  }

  /**
   * Get current metrics for monitoring
   */
  getMetrics() {
    return {
      service: this.serviceName,
      state: this.state,
      failureCount: this.failureCount,
      successCount: this.successCount,
      lastStateChanged: new Date(this.lastStateChanged).toISOString(),
    };
  }
}

module.exports = CircuitBreaker;
