// What the app's Send feedback page posts, and the plain-text email support gets for it (owner, 13 Nov).
// Kept apart from the Worker's entry point so it runs under `node --test` too.

/** The longest message and name the app lets through, counted in characters as Swift counts them. */
export const MAX_MESSAGE = 4000;
export const MAX_NAME = 100;
const FIELDS = new Set(['name', 'message', 'email', 'version', 'system', 'language']);
// Letters, digits and dots around one @, with no spaces or line breaks (so nothing can be added to the headers).
const EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
// The app's version, iOS version and language: short, printable ASCII only.
const TAG = /^[\x20-\x7E]{1,40}$/;
const segmenter = new Intl.Segmenter(undefined, { granularity: 'grapheme' });
const characters = (text) => { let count = 0; for (const _ of segmenter.segment(text)) count++; return count; };

/** The note as the app sent it, trimmed, or null when anything about it is wrong. */
export function readNote(json) {
  if (!json || typeof json !== 'object' || Array.isArray(json)) return null;
  if (Object.keys(json).some((key) => !FIELDS.has(key))) return null;
  const { name, message, email, version, system, language } = json;
  if (typeof name !== 'string' || typeof message !== 'string') return null;
  const who = name.trim();
  const text = message.trim();
  if (!who || characters(who) > MAX_NAME || /[\r\n]/.test(who)) return null;
  if (!text || characters(text) > MAX_MESSAGE) return null;
  if (email !== undefined && (typeof email !== 'string' || email.length > 254 || !EMAIL.test(email))) return null;
  if (![version, system, language].every((tag) => typeof tag === 'string' && TAG.test(tag))) return null;
  return { name: who, message: text, email, version, system, language };
}

function base64(text) {
  const bytes = new TextEncoder().encode(text);
  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary);
}

/** The raw email for a note: from the site's feedback address to support, with Reply-To set when they gave an email. */
export function mime(note, { from, to, date = new Date(), id = crypto.randomUUID() }) {
  const body = [
    note.message,
    '',
    '--',
    `From: ${note.name}`,
    `Reply to: ${note.email ?? 'no email given'}`,
    `Hereabouts ${note.version}, ${note.system}, ${note.language}`,
    '',
  ].join('\n');
  const headers = [
    `From: Hereabouts feedback <${from}>`,
    `To: ${to}`,
    ...(note.email ? [`Reply-To: ${note.email}`] : []),
    `Subject: Hereabouts feedback, version ${note.version}`,
    `Date: ${date.toUTCString()}`,
    `Message-ID: <${id}@hereaboutsapp.com>`,
    'MIME-Version: 1.0',
    'Content-Type: text/plain; charset=utf-8',
    'Content-Transfer-Encoding: base64',
  ];
  const lines = base64(body).match(/.{1,76}/g) ?? [];
  return `${headers.join('\r\n')}\r\n\r\n${lines.join('\r\n')}\r\n`;
}
