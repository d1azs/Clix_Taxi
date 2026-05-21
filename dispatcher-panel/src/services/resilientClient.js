/**
 * services/resilientClient.js — WebSocket → REST Polling fallback + Exponential Backoff.
 *
 * Designed for mobile Flutter app integration (WebView or direct) and dispatcher panel.
 */

/**
 * Exponential Backoff retry for critical API calls (payments, orders).
 * @param {Function} fn - Async function to retry
 * @param {Object} opts - { maxRetries, baseDelay, maxDelay }
 */
export async function withRetry(fn, opts = {}) {
  const { maxRetries = 5, baseDelay = 500, maxDelay = 16000 } = opts;
  let attempt = 0;

  while (attempt <= maxRetries) {
    try {
      return await fn();
    } catch (err) {
      attempt++;
      if (attempt > maxRetries) throw err;

      // Exponential: 500ms → 1s → 2s → 4s → 8s (+ jitter)
      const delay = Math.min(baseDelay * Math.pow(2, attempt - 1), maxDelay);
      const jitter = delay * 0.2 * Math.random();
      await new Promise((r) => setTimeout(r, delay + jitter));

      console.warn(`Retry ${attempt}/${maxRetries} after ${delay}ms:`, err.message);
    }
  }
}

/**
 * Resilient transport that degrades from WebSocket to REST polling.
 */
export class ResilientTransport {
  constructor({ wsUrl, pollUrl, pollInterval = 5000, onMessage, getToken }) {
    this.wsUrl = wsUrl;
    this.pollUrl = pollUrl;
    this.pollInterval = pollInterval;
    this.onMessage = onMessage;
    this.getToken = getToken;

    this.ws = null;
    this.pollTimer = null;
    this.mode = 'ws'; // 'ws' | 'poll'
    this.wsRetryCount = 0;
    this.maxWsRetries = 5;
  }

  start() {
    this._connectWs();
  }

  stop() {
    if (this.ws) this.ws.close();
    if (this.pollTimer) clearInterval(this.pollTimer);
    this.ws = null;
    this.pollTimer = null;
  }

  _connectWs() {
    const token = this.getToken();
    if (!token) {
      this._fallbackToPoll();
      return;
    }

    try {
      this.ws = new WebSocket(`${this.wsUrl}?token=${token}`);
    } catch (e) {
      this._fallbackToPoll();
      return;
    }

    this.ws.onopen = () => {
      this.mode = 'ws';
      this.wsRetryCount = 0;
      // Stop polling if it was active
      if (this.pollTimer) {
        clearInterval(this.pollTimer);
        this.pollTimer = null;
      }
      console.info('[Transport] WebSocket connected');
    };

    this.ws.onmessage = (event) => {
      try {
        this.onMessage(JSON.parse(event.data));
      } catch (e) { /* ignore parse errors */ }
    };

    this.ws.onclose = () => {
      this.wsRetryCount++;
      if (this.wsRetryCount <= this.maxWsRetries) {
        // Exponential backoff reconnect
        const delay = Math.min(1000 * Math.pow(2, this.wsRetryCount - 1), 30000);
        console.warn(`[Transport] WS reconnect in ${delay}ms (attempt ${this.wsRetryCount})`);
        setTimeout(() => this._connectWs(), delay);
      } else {
        console.warn('[Transport] WS max retries reached, falling back to REST poll');
        this._fallbackToPoll();
      }
    };

    this.ws.onerror = () => this.ws.close();
  }

  _fallbackToPoll() {
    this.mode = 'poll';
    if (this.pollTimer) return; // Already polling

    console.info(`[Transport] Polling mode: ${this.pollUrl} every ${this.pollInterval}ms`);

    const poll = async () => {
      try {
        const token = this.getToken();
        const res = await fetch(this.pollUrl, {
          headers: { Authorization: `Bearer ${token}` },
        });
        if (res.ok) {
          const data = await res.json();
          this.onMessage({ type: 'poll_data', data });
        }
      } catch (e) {
        // Silent — will retry next interval
      }
    };

    poll(); // Immediate first poll
    this.pollTimer = setInterval(poll, this.pollInterval);

    // Periodically try to reconnect WS
    setTimeout(() => {
      if (this.mode === 'poll') {
        this.wsRetryCount = 0;
        this._connectWs();
      }
    }, 60000); // Try WS again after 1 min
  }
}
