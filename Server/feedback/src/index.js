// feedback.hereaboutsapp.com: takes a note from the app's Send feedback page and emails it to support.
// Nothing is stored. FEEDBACK_TO (a secret, never in this repo) is the verified Email Routing address support@ forwards to.
import { EmailMessage } from 'cloudflare:email';
import { readNote, mime } from './feedback.js';

const FROM = 'feedback@hereaboutsapp.com';
// A note is at most a few kilobytes, even in emoji. Anything far bigger isn't from the app.
const MAX_BYTES = 256 * 1024;
const reply = (status, headers) => new Response(null, { status, headers });

async function readLimited(request) {
  if (Number(request.headers.get('content-length') ?? 0) > MAX_BYTES) return null;
  const reader = request.body?.getReader();
  if (!reader) return '';
  const chunks = [];
  let size = 0;
  for (;;) {
    const { done, value } = await reader.read();
    if (done) break;
    size += value.byteLength;
    if (size > MAX_BYTES) { await reader.cancel(); return null; }
    chunks.push(value);
  }
  const bytes = new Uint8Array(size);
  let offset = 0;
  for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.byteLength; }
  return new TextDecoder().decode(bytes);
}

export default {
  async fetch(request, env) {
    if (request.method !== 'POST') return reply(405, { Allow: 'POST' });
    if (!(request.headers.get('content-type') ?? '').startsWith('application/json')) return reply(415);
    // A few notes a minute from one address is plenty for a person; more is someone else.
    if (env.LIMIT) {
      const { success } = await env.LIMIT.limit({ key: request.headers.get('cf-connecting-ip') ?? 'unknown' });
      if (!success) return reply(429);
    }
    const text = await readLimited(request);
    if (text === null) return reply(413);
    let json;
    try { json = JSON.parse(text); } catch { return reply(400); }
    const note = readNote(json);
    if (!note) return reply(400);
    if (!env.FEEDBACK_TO) return reply(503);
    try {
      await env.EMAIL.send(new EmailMessage(FROM, env.FEEDBACK_TO, mime(note, { from: FROM, to: env.FEEDBACK_TO })));
    } catch {
      return reply(502);
    }
    return reply(204);
  },
};
