// cd Server/feedback && npm test
// What the feedback Worker accepts from the app, and the email it writes to support (owner, 13 Nov).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readNote, mime, MAX_MESSAGE } from '../src/feedback.js';

const good = { name: 'Sam Lee', message: 'Lent out is my favourite tab.', email: 'sam@example.com', version: '1.0 (6)', system: 'iOS 27.0', language: 'en-CA' };

test('a note from the app is read as it was sent, with the message trimmed', () => {
  assert.deepEqual(readNote({ ...good, name: ' Sam Lee ', message: '  Hi there \n' }), { ...good, message: 'Hi there' });
  assert.equal(readNote({ ...good, name: 'Zoë Ödegård' }).name, 'Zoë Ödegård');
  assert.deepEqual(readNote({ ...good, email: undefined }), { ...good, email: undefined }, 'the email is optional');
  const { email, ...withoutEmail } = good;
  assert.equal(readNote(withoutEmail).email, undefined);
});

test('anything else is refused', () => {
  const bad = [
    null, [], 'Hi', 42,
    { ...good, message: '' }, { ...good, message: '  \n ' }, { ...good, message: 7 },
    { ...good, message: 'a'.repeat(MAX_MESSAGE + 1) },
    { ...good, email: 'sam' }, { ...good, email: 'sam@example' }, { ...good, email: 'sam@exa mple.com' },
    { ...good, email: 'sam@example.com\r\nBcc: someone@example.com' }, { ...good, email: `${'a'.repeat(250)}@example.com` },
    { ...good, version: '1.0\r\nBcc: someone@example.com' }, { ...good, system: undefined }, { ...good, language: 'x'.repeat(41) },
    { ...good, version: '1.0 (6) ✓' },
    { ...good, name: '' }, { ...good, name: '   ' }, { ...good, name: undefined }, { ...good, name: 'a'.repeat(101) },
    { ...good, name: 'Sam\r\nBcc: someone@example.com' },
    { ...good, extra: 'notebook' },
  ];
  for (const body of bad) assert.equal(readNote(body), null, JSON.stringify(body));
  assert.ok(readNote({ ...good, message: 'a'.repeat(MAX_MESSAGE) }), 'the longest message the app allows');
  assert.ok(readNote({ ...good, message: '👍🏽'.repeat(MAX_MESSAGE) }), 'counted in characters, as the app counts them');
  assert.equal(readNote({ ...good, message: '👍🏽'.repeat(MAX_MESSAGE + 1) }), null);
});

test('the email to support has the name, the message, who to reply to, and the versions', () => {
  const raw = mime(readNote({ ...good, message: 'Ça marche très bien.' }), { from: 'feedback@hereaboutsapp.com', to: 'owner@example.com', date: new Date(Date.UTC(2026, 10, 13, 22, 5)), id: 'abc' });
  const [head, body] = raw.split('\r\n\r\n');
  const headers = head.split('\r\n');
  assert.ok(headers.includes('From: Hereabouts feedback <feedback@hereaboutsapp.com>'));
  assert.ok(headers.includes('To: owner@example.com'));
  assert.ok(headers.includes('Reply-To: sam@example.com'));
  assert.ok(headers.includes('Subject: Hereabouts feedback, version 1.0 (6)'));
  assert.ok(headers.includes('Message-ID: <abc@hereaboutsapp.com>'));
  assert.ok(headers.includes('Date: Fri, 13 Nov 2026 22:05:00 GMT'));
  assert.ok(headers.includes('Content-Type: text/plain; charset=utf-8'));
  assert.ok(headers.includes('Content-Transfer-Encoding: base64'));
  assert.ok(body.split('\r\n').every((line) => line.length <= 76), 'base64 lines are 76 characters at most');
  const text = Buffer.from(body.replace(/\r\n/g, ''), 'base64').toString('utf8');
  assert.equal(text, 'Ça marche très bien.\n\n--\nFrom: Sam Lee\nReply to: sam@example.com\nHereabouts 1.0 (6), iOS 27.0, en-CA\n');
});

test('with no email there is no Reply-To, and the email says so', () => {
  const raw = mime(readNote({ ...good, email: undefined }), { from: 'feedback@hereaboutsapp.com', to: 'owner@example.com' });
  const [head, body] = raw.split('\r\n\r\n');
  assert.ok(!head.includes('Reply-To'));
  assert.match(head, /Message-ID: <[0-9a-f-]{36}@hereaboutsapp\.com>/);
  assert.match(Buffer.from(body.replace(/\r\n/g, ''), 'base64').toString('utf8'), /Reply to: no email given/);
});
