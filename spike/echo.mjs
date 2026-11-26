// The upstream for Kong's K-1 test routes (E03 spec §2a): answers with the request it received.
import { createServer } from 'node:http';

createServer((req, res) => {
  res.writeHead(200, { 'content-type': 'application/json' });
  res.end(JSON.stringify({ method: req.method, url: req.url, headers: req.headers }));
}).listen(8080);
