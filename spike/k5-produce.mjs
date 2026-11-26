// K-5: tries to produce to ev.spike.example as svc-spike and prints the outcome as one JSON line.
// The expected outcome is an authorization error from the broker.
import { readFileSync } from 'node:fs'
import { Producer, stringSerializers } from '@platformatic/kafka'

const producer = new Producer({
  clientId: 'k5-produce',
  bootstrapBrokers: ['kafka:9092'],
  sasl: { mechanism: 'SCRAM-SHA-512', username: 'svc-spike', password: readFileSync('/run/secrets/kafka-svc-spike', 'utf8') },
  serializers: stringSerializers,
  retries: 0
})
let out
try {
  await producer.send({ messages: [{ topic: 'ev.spike.example', key: 'k5-should-not-land', value: '{}' }] })
  out = { produced: true }
} catch (err) {
  // Keep the whole error tree: the broker's code sits on a nested error.
  const seen = []
  const walk = e => { if (!e || seen.length > 20) return; seen.push(`${e.code ?? e.name}: ${e.message}${e.apiId ? ` [${e.apiId}]` : ''}`); (e.errors || []).forEach(walk); if (e.cause) walk(e.cause) }
  walk(err)
  out = { produced: false, errors: seen }
}
console.log(JSON.stringify(out))
await producer.close(true)
