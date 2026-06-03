const CircuitBreaker = require('../utils/CircuitBreaker');

describe('Circuit Breaker Unit Tests', () => {
  let breaker;
  
  beforeEach(() => {
    // 3 failures to open, 500ms recovery time, 2 successes to close
    breaker = new CircuitBreaker('TestService', {
      failureThreshold: 3,
      recoveryTimeout: 500,
      successThreshold: 2
    });
  });

  test('should start in CLOSED state', () => {
    expect(breaker.state).toBe('CLOSED');
    expect(breaker.failureCount).toBe(0);
  });

  test('should pass through successful calls', async () => {
    const action = jest.fn().mockResolvedValue('success-data');
    const result = await breaker.fire(action);
    
    expect(result).toBe('success-data');
    expect(action).toHaveBeenCalledTimes(1);
    expect(breaker.state).toBe('CLOSED');
  });

  test('should transition to OPEN after reaching failure threshold', async () => {
    const error = new Error('API Error');
    const action = jest.fn().mockRejectedValue(error);

    // Call 1
    await expect(breaker.fire(action)).rejects.toThrow('API Error');
    expect(breaker.state).toBe('CLOSED');
    expect(breaker.failureCount).toBe(1);

    // Call 2
    await expect(breaker.fire(action)).rejects.toThrow('API Error');
    expect(breaker.state).toBe('CLOSED');
    expect(breaker.failureCount).toBe(2);

    // Call 3 (triggers trip to OPEN)
    await expect(breaker.fire(action)).rejects.toThrow('API Error');
    expect(breaker.state).toBe('OPEN');
    expect(breaker.failureCount).toBe(3);
  });

  test('should fail fast (circuit-tripped) when state is OPEN', async () => {
    breaker.forceState('OPEN');
    
    const action = jest.fn().mockResolvedValue('should-not-run');
    
    await expect(breaker.fire(action)).rejects.toThrow(
      /sedang offline secara protektif/
    );
    expect(action).not.toHaveBeenCalled();
  });

  test('should transition to HALF-OPEN after recovery timeout and recover on successes', async () => {
    const error = new Error('API Error');
    const failedAction = jest.fn().mockRejectedValue(error);
    const successAction = jest.fn().mockResolvedValue('recovered');

    // 1. Trip circuit to OPEN
    await expect(breaker.fire(failedAction)).rejects.toThrow();
    await expect(breaker.fire(failedAction)).rejects.toThrow();
    await expect(breaker.fire(failedAction)).rejects.toThrow();
    expect(breaker.state).toBe('OPEN');

    // 2. Wait for recovery timeout
    await new Promise((resolve) => setTimeout(resolve, 600));

    // 3. Fire success action (transitions to HALF-OPEN internally first)
    const result1 = await breaker.fire(successAction);
    expect(result1).toBe('recovered');
    expect(breaker.state).toBe('HALF-OPEN');
    expect(breaker.successCount).toBe(1);

    // 4. Second success closes circuit
    const result2 = await breaker.fire(successAction);
    expect(result2).toBe('recovered');
    expect(breaker.state).toBe('CLOSED');
    expect(breaker.successCount).toBe(0);
    expect(breaker.failureCount).toBe(0);
  });

  test('should revert to OPEN immediately if a failure occurs in HALF-OPEN', async () => {
    breaker.forceState('OPEN');
    
    // Wait for recovery timeout
    await new Promise((resolve) => setTimeout(resolve, 600));

    const failedAction = jest.fn().mockRejectedValue(new Error('API Error'));
    
    // Failure in HALF-OPEN trips circuit back to OPEN instantly
    await expect(breaker.fire(failedAction)).rejects.toThrow();
    expect(breaker.state).toBe('OPEN');
  });
});
