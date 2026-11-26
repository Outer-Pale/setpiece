// A K-2 upstream target (E03 spec K-2, §2a). Answers with its name. The check flips it:
//   POST /_spike/ready/0|1  makes /readyz fail or pass (Kong's active check)
//   POST /_spike/fail/0|1   makes every other request answer 500 (Kong's passive check)
import { createServer } from 'node:http';

let ready = true;
let failing = false;

createServer((req, res) => {
  const flip = req.method === 'POST' && req.url.match(/^\/_spike\/(ready|fail)\/([01])$/);
  if (flip) {
    if (flip[1] === 'ready') ready = flip[2] === '1';
    else failing = flip[2] === '1';
    res.writeHead(204);
    return res.end();
  }
  if (req.url === '/readyz') {
    res.writeHead(ready ? 200 : 503);
    return res.end();
  }
  res.writeHead(failing ? 500 : 200, { 'content-type': 'text/plain' });
  res.end(process.env.TARGET_NAME);
}).listen(8080);
