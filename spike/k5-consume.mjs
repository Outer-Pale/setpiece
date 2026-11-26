// K-5: reads ev.spike.example as svc-spike with @platformatic/kafka and prints the record whose
// key is argv[2] as one JSON line {key, value, headers}. Exits 1 if it isn't found in 30 s.
import { readFileSync } from 'node:fs'
import { Consumer, stringDeserializers } from '@platformatic/kafka'

const want = process.argv[2]
const consumer = new Consumer({
  clientId: 'k5-consume',
  groupId: `svc-spike-k5-${Date.now()}`,
  bootstrapBrokers: ['kafka:9092'],
  sasl: { mechanism: 'SCRAM-SHA-512', username: 'svc-spike', password: readFileSync('/run/secrets/kafka-svc-spike', 'utf8') },
  deserializers: stringDeserializers,
  autocommit: false
})
const timer = setTimeout(() => { console.log(JSON.stringify({ found: false })); process.exit(1) }, 30000)
try {
  const stream = await consumer.consume({ topics: ['ev.spike.example'], mode: 'earliest' })
  for await (const m of stream) {
    if (m.key !== want) continue
    console.log(JSON.stringify({ found: true, key: m.key, value: m.value, headers: Object.fromEntries(m.headers) }))
    clearTimeout(timer)
    break
  }
} catch (err) {
  console.log(JSON.stringify({ found: false, error: `${err.name}: ${err.message}` }))
  process.exitCode = 1
}
await consumer.close(true)
process.exit(process.exitCode ?? 0)
