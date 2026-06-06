# addEvents integration patterns

The `addEvents` endpoint is capable (scales to 100s of TB/day) but it is **not**
fire-and-forget. Direct integrations must handle sessions, concurrency limits,
and fault tolerance explicitly — these are the things a real pipeline has to
get right.

If you can drop in the SentinelOne Collector (formerly Scalyr Agent) instead,
do — it already implements everything below, plus checkpointing, rotation,
and sampling. Roll your own only when the Collector doesn't fit (serverless,
custom sources, volume >10 GB/day where `uploadLogs` breaks down).

## Sessions

- Generate a single session UUID at process start and store it in a global. **Do not create a new session per request.** A session is an identifier for the upload process, not a log batch.
- Only **one request can be in-flight per session at a time.** The server queues per session; parallel requests on the same session serialise, defeating the point of parallelism.
- Keep each session near **2.5 MB/sec**. Hard cap is 10 MB/sec. If you have more throughput than one session supports, create additional sessions and shard events across them.
- Account-wide cap: **50K sessions per 5-minute window.** Burst-creating sessions (e.g. a new one per request) will trip this fast.
- Events in the same session with identical `ts` are ordered by receive order.
- **Multi-line parsers** (stack traces, multi-line syslog) require all lines of a single record in the same session — don't split a record across sessions.

## Session/sessionInfo/logs

- `session` (string, required) — the UUID above.
- `sessionInfo` (object, optional) — fields describing the upload process (`serverHost`, `serverType`, `region`, `logfile`, `parser`). **Must be consistent across every request with the same session.** Changing it partway is undefined.
- `logs` (array, optional) — constant metadata that every event in a batch references. Useful for Kubernetes/Docker where every event shares `pod`, `container`, `namespace`, `node`. Each event sets `"log": "<logId>"` and SDL joins back the `attrs` at read time. Saves bytes and improves throughput.

Example:

```json
{
  "session": "149d8290-7871-11e1-b0c4-0800200c9a66",
  "sessionInfo": {"serverHost": "syslog-01", "parser": "pa-dns01"},
  "logs": [
    {"id": "dns1", "attrs": {"source": "win-dns"}}
  ],
  "threads": [{"id": "1", "name": "request handler"}],
  "events": [
    {"thread": "1", "ts": "1667443947000000000", "sev": 3, "log": "dns1",
     "attrs": {"message": "03/15 02:54:59 PM PACKET UDP Snd 174.56.114.70 ..."}}
  ]
}
```

## Structured vs unstructured events

**Unstructured** — one `message` field only. Good for upstream parsing:

```json
"attrs": { "message": "17/Jan/2023:23:18:11 invoked app server: request=x984313696, timeMs=311, status=failure" }
```

**Structured** — key/value pairs, no parser needed:

```json
"attrs": {
  "message": "invoked app server",
  "request": "x984313696",
  "timeMs": 311,
  "status": "failure"
}
```

Charging: unstructured events are charged for bytes in `message` + 1 byte per extra field. Structured events are charged per field and value. Omitting `message` disables full-text search on that event.

Severity scale for `sev` (default 3): 0 finest / 1 finer/trace / 2 fine/debug / 3 info/notice / 4 warn / 5 error / 6 fatal/critical.

`ts` must be a **string** of nanoseconds since epoch. JSON numbers lose precision at that magnitude. `SDLClient.now_ns()` returns it correctly.

## Fault tolerance — binary truncated exponential backoff

The official SentinelOne guidance for a robust ingest loop:

```text
MAX_ERROR_WAIT_TIME   = 30.0
MAX_SUCCESS_WAIT_TIME = 5.0
SUCCESS_INCREASE      = 0.6
ERROR_BACKOFF         = 1.5
MAX_REQUEST_SIZE      = 5_900_000  # bytes (safety margin under 6 MB)

session_id = random_uuid()
current_wait = 0

while running:
    sleep(current_wait)
    payload = new_request(session_id)
    while has_pending_events() and payload.size < MAX_REQUEST_SIZE:
        payload.add_event(next_event())

    response = send(payload)
    while response.status_code != 200 or response.status != "success":
        if "discardBuffer" in response.status:
            break                               # permanent — drop the batch
        current_wait = max(current_wait * ERROR_BACKOFF, MIN_ERROR_WAIT_TIME)
        current_wait = min(current_wait, MAX_ERROR_WAIT_TIME)
        sleep(current_wait)
        response = send(payload)                # SAME payload, SAME session

    current_wait = min(current_wait * SUCCESS_INCREASE, MAX_SUCCESS_WAIT_TIME)
```

Key properties:
- On error, multiply wait by 1.5 up to 30s. This protects the queue server while it recovers.
- On success, *decrease* wait by ×0.6 (don't reset to 0) — avoids flapping if the backend is still tender.
- On `status` containing `discardBuffer`, stop retrying and throw away the payload — the server has said "don't send this again".
- Retries reuse the same session + same payload. Don't generate a new session on retry.

The `SDLClient.add_events()` retry policy is correct for casual use (one-off
scripts, moderate volumes). For a real ingest pipeline, disable its retries
(pass `retries=0` through to `_request`) and wrap the call in the loop above.

## Batching

- Upper bound: 5.9 MB per payload (leaves headroom under the 6 MB hard cap).
- Upper bound: a few seconds of buffered data per server — beyond that, memory and restart-loss start to hurt.
- If you generate many events per second, group them into batches. One batch per session per iteration.

## When not to use `addEvents`

- Low/medium unstructured throughput → `uploadLogs` is simpler and scope-limited to 10 GB/day.
- OS log files → use the SentinelOne Collector.
- Syslog → use the Syslog Collector or Syslog Plugin.
- Whole files (tar.gz/json/txt) → `uploadLogs`.
- Third-party data with an existing sink/connector → check for an official collector first.
