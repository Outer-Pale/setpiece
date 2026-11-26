// A stub edge-auth for build step 1 (E03 spec F-2). Not the real service: it accepts fixed
// test tokens, and it records every body it receives so spike-check k1 can read them back.
//   Bearer good…  200 with the three x-chassis-* headers
//   Bearer slow…  the same, after 3 s (Kong's 2 s timeout gives the client 503)
//   anything else 401 Problem
import { createServer } from 'node:http';
import { randomUUID } from 'node:crypto';

const received = [];

const send = (res, status, headers = {}, body = '') => {
  res.writeHead(status, headers);
  res.end(body);
};

const authorize = (body) => {
  const auth = typeof body?.authorization === 'string' ? body.authorization : '';
  if (!/^Bearer (good|slow)/.test(auth)) return null;
  return {
    'x-chassis-internal-token': `stub-${randomUUID()}`,
    'x-chassis-correlation-id': randomUUID(),
    'x-chassis-budget-ms': '1500',
  };
};

createServer((req, res) => {
  if (req.method === 'GET' && req.url === '/healthz') return send(res, 200);
  if (req.method === 'GET' && req.url === '/_stub/received') {
    return send(res, 200, { 'content-type': 'application/json' }, JSON.stringify(received));
  }
  if (req.method !== 'POST' || req.url !== '/v1/authorize') return send(res, 404);

  let raw = '';
  req.on('data', (chunk) => { raw += chunk; });
  req.on('end', () => {
    let body = null;
    try { body = JSON.parse(raw); } catch { /* recorded as null */ }
    const issued = authorize(body);
    received.push({ body, issued });
    if (received.length > 1000) received.shift();
    if (!issued) {
      return send(res, 401, { 'content-type': 'application/problem+json' },
        JSON.stringify({ type: 'about:blank', title: 'Unauthorized', status: 401 }));
    }
    const delay = body.authorization.startsWith('Bearer slow') ? 3000 : 0;
    setTimeout(() => send(res, 200, issued), delay);
  });
}).listen(8080);
