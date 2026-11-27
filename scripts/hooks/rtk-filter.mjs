#!/usr/bin/env node
/**
 * rtk output filter - the single implementation.
 *
 * WHAT THIS DOES
 * --------------
 * `rtk` (Rust Token Killer) compresses terminal output before it reaches the
 * model. This module is the one place that knows how to do it, so the POSIX
 * hook, the PowerShell hook, the cross-platform dispatcher and the OpenCode
 * plugin cannot disagree about it.
 *
 * THE PAYLOAD PROBLEM IT FIXES
 * ----------------------------
 * A PostToolUse hook does not receive the terminal output on stdin - it
 * receives the agent's hook payload, which for Claude Code, Codex, Goose and
 * Qoder is a JSON envelope:
 *
 *   {"tool_name":"Bash","tool_response":{"stdout":"...","stderr":"..."}}
 *
 * The previous revision piped that envelope straight into `rtk filter` and,
 * when rtk was missing, echoed the whole envelope back. `rtk` was asked to
 * compress JSON instead of terminal text, and the passthrough added the
 * untruncated envelope to the agent's context - the opposite of the point.
 *
 * So the payload is parsed first and the terminal text is extracted from it:
 *
 *   tool_response.stdout  ->  tool_response.output  ->  tool_output
 *   ->  output  ->  stdout  ->  command_output  ->  text  ->  content
 *
 * A payload that is not JSON is treated as terminal text already, which is
 * what a host that pipes raw output (Antigravity) sends.
 *
 * When no text can be found, the raw payload is emitted unchanged - the
 * filter never swallows output.
 */

import { spawnSync } from 'node:child_process';
import fs from 'node:fs';

/** Payload keys that can hold the terminal output, in priority order. */
export const TEXT_KEYS = [
  'stdout',
  'output',
  'tool_output',
  'command_output',
  'text',
  'content',
  'result',
];

/**
 * Collect every string candidate in a parsed hook payload.
 *
 * A candidate remembers the key it was found under, so the caller can prefer
 * `stdout` over `output` over a stray string such as the tool name.
 */
function collectCandidates(value, depth, found) {
  if (depth > 6 || value === null || value === undefined) return found;

  if (typeof value === 'string') {
    if (value.trim()) found.push({ key: '', text: value, depth });
    return found;
  }

  if (Array.isArray(value)) {
    for (const item of value) collectCandidates(item, depth + 1, found);
    return found;
  }

  if (typeof value !== 'object') return found;

  for (const key of Object.keys(value)) {
    const child = value[key];
    if (typeof child === 'string') {
      if (child.trim()) found.push({ key, text: child, depth });
      continue;
    }
    collectCandidates(child, depth + 1, found);
  }

  return found;
}

/**
 * Find the terminal text inside a parsed hook payload.
 *
 * The payload of a PostToolUse hook carries several strings - the tool name,
 * the command, the output - and only one of them is the output. The keys in
 * TEXT_KEYS win, in priority order; a string under any other key is the
 * fallback, and the shallowest match breaks a tie.
 */
export function extractTerminalText(value, depth = 0) {
  const candidates = collectCandidates(value, depth, []);
  if (candidates.length === 0) return '';

  // A key that is not in TEXT_KEYS is the weakest possible candidate -
  // indexOf returns -1 for it, which must not sort it to the front.
  const priority = (candidate) => {
    if (!candidate.key) return TEXT_KEYS.length;
    const index = TEXT_KEYS.indexOf(candidate.key);
    return index === -1 ? TEXT_KEYS.length : index;
  };

  candidates.sort((a, b) => priority(a) - priority(b) || a.depth - b.depth);
  return candidates[0].text;
}

/**
 * Split a raw stdin payload into the terminal text it carries.
 *
 * Returns the text unchanged when the payload is not JSON, and the raw
 * payload when no text can be extracted - the filter never loses output.
 */
export function splitPayload(raw) {
  const trimmed = (raw ?? '').trim();
  if (!trimmed) return { text: '', isJson: false };

  const looksJson = trimmed.startsWith('{') || trimmed.startsWith('[');
  if (looksJson) {
    try {
      const parsed = JSON.parse(trimmed);
      const text = extractTerminalText(parsed);
      if (text) return { text, isJson: true };
    } catch {
      // Not valid JSON after all - fall through to the raw payload.
    }
  }

  return { text: raw ?? '', isJson: false };
}

let rtkAvailable = null;

/** Probe for the rtk binary once and remember the answer. */
export function hasRtk() {
  if (rtkAvailable !== null) return rtkAvailable;

  const probeCmd = process.platform === 'win32' ? 'where' : 'which';
  const probe = spawnSync(probeCmd, ['rtk'], {
    timeout: 1000,
    encoding: 'utf-8',
    stdio: ['ignore', 'pipe', 'ignore'],
  });

  rtkAvailable = probe.status === 0 && Boolean(probe.stdout);
  return rtkAvailable;
}

/**
 * Compress text with `rtk filter`.
 *
 * Returns null whenever rtk cannot be used - missing binary, timeout, a
 * non-zero exit or empty output - so the caller can pass the text through.
 */
export function compressWithRtk(text) {
  if (!text || !hasRtk()) return null;

  const filter = spawnSync('rtk', ['filter'], {
    input: text,
    timeout: 5000,
    encoding: 'utf-8',
    stdio: ['pipe', 'pipe', 'pipe'],
  });

  if (filter.status !== 0 || !filter.stdout) return null;
  return filter.stdout;
}

/**
 * The whole filter: payload in, text out.
 *
 * The output is the compressed terminal text when rtk could do it, and the
 * original terminal text when it could not. Never the JSON envelope.
 */
export function filterPayload(raw) {
  const { text } = splitPayload(raw);
  if (!text) return '';

  const compressed = compressWithRtk(text);
  return compressed !== null ? compressed : text;
}

/** Read stdin in full. */
export function readStdin() {
  try {
    return fs.readFileSync(0, 'utf8');
  } catch {
    return '';
  }
}

// Executed directly: read stdin, filter it, write it out.
if (process.argv[1] && process.argv[1].endsWith('rtk-filter.mjs')) {
  const raw = readStdin();
  process.stdout.write(filterPayload(raw));
}
