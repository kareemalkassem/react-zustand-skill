#!/usr/bin/env node
/**
 * Validate the react-zustand plugin repo. Zero dependencies by design — this is a
 * docs repo and should not grow a node_modules tree to lint itself.
 *
 * Checks:
 *   1. every skills/<dir> has a SKILL.md with flat `name:` and `description:` frontmatter
 *   2. the frontmatter `name` matches its directory name
 *   3. every `react-zustand-*` skill named in any SKILL.md body actually exists
 *   4. relative links resolve to real files
 *   5. the README's "family of N skills" claim matches the folder count
 *   6. the README skill table lists every skill directory, and no phantom ones
 *
 * Run: node scripts/validate-skills.mjs
 */
import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const SKILLS_DIR = path.join(ROOT, 'skills');
const README = path.join(ROOT, 'README.md');

const errors = [];
const warnings = [];
const fail = (msg) => errors.push(msg);
const warn = (msg) => warnings.push(msg);

/** Parse flat `key: value` frontmatter. No YAML dependency: the schema is two keys. */
const parseFrontmatter = (source) => {
  if (!source.startsWith('---')) return null;
  const end = source.indexOf('\n---', 3);
  if (end === -1) return null;

  const block = source.slice(4, end);
  const out = {};
  let currentKey = null;

  for (const line of block.split(/\r?\n/)) {
    const match = /^([A-Za-z_][A-Za-z0-9_-]*):\s?(.*)$/.exec(line);
    if (match) {
      currentKey = match[1];
      out[currentKey] = match[2].trim();
    } else if (currentKey && line.trim()) {
      out[currentKey] += ` ${line.trim()}`;      // folded continuation line
    }
  }
  return out;
};

/** Remove ``` fenced blocks so code samples are not scanned as prose. */
const stripFences = (source) => source.replace(/^```[\s\S]*?^```/gm, '');

if (!fs.existsSync(SKILLS_DIR)) {
  console.error('FAIL: skills/ directory not found');
  process.exit(1);
}

const skillDirs = fs
  .readdirSync(SKILLS_DIR, { withFileTypes: true })
  .filter((entry) => entry.isDirectory())
  .map((entry) => entry.name)
  .sort();

const known = new Set(skillDirs);

// --- checks 1, 2, 3, 4 -------------------------------------------------------
for (const dir of skillDirs) {
  const skillPath = path.join(SKILLS_DIR, dir, 'SKILL.md');

  if (!fs.existsSync(skillPath)) {
    fail(`${dir}: missing SKILL.md`);
    continue;
  }

  const source = fs.readFileSync(skillPath, 'utf8');
  const meta = parseFrontmatter(source);

  if (!meta) {
    fail(`${dir}/SKILL.md: missing or malformed frontmatter block`);
    continue;
  }
  if (!meta.name) fail(`${dir}/SKILL.md: frontmatter has no \`name\``);
  else if (meta.name !== dir) fail(`${dir}/SKILL.md: name "${meta.name}" does not match its directory`);

  if (!meta.description) fail(`${dir}/SKILL.md: frontmatter has no \`description\``);
  else if (meta.description.length < 40) warn(`${dir}/SKILL.md: description is very short — triggering will be unreliable`);
  else if (meta.description.length > 1024) warn(`${dir}/SKILL.md: description exceeds 1024 chars`);

  // Strip fenced code blocks before scanning prose. A regex literal or a template
  // string inside a fence can look exactly like a markdown link.
  const body = stripFences(source.slice(source.indexOf('\n---', 3) + 4));

  // cross-references, in backticks: `react-zustand-foo`
  for (const m of body.matchAll(/`(react-zustand-[a-z-]+)`/g)) {
    if (!known.has(m[1])) fail(`${dir}/SKILL.md: references unknown skill \`${m[1]}\``);
  }

  // relative markdown links
  for (const m of body.matchAll(/\]\((?!https?:|#)([^)]+)\)/g)) {
    const target = path.resolve(path.dirname(skillPath), m[1].split('#')[0]);
    if (!fs.existsSync(target)) fail(`${dir}/SKILL.md: dead link -> ${m[1]}`);
  }
}

// --- checks 5, 6 -------------------------------------------------------------
if (!fs.existsSync(README)) {
  fail('README.md not found');
} else {
  const readme = fs.readFileSync(README, 'utf8');

  const claim = /family of \*\*(\d+) focused skills\*\*|family of (\d+) skills/.exec(readme);
  if (!claim) {
    warn('README.md: no "family of N skills" claim found to verify');
  } else {
    const claimed = Number(claim[1] ?? claim[2]);
    if (claimed !== skillDirs.length) {
      fail(`README.md claims ${claimed} skills; ${skillDirs.length} directories exist`);
    }
  }

  for (const dir of skillDirs) {
    if (!readme.includes(dir)) fail(`README.md: skill table does not list \`${dir}\``);
  }
  for (const m of readme.matchAll(/`(react-zustand-[a-z-]+)`/g)) {
    if (!known.has(m[1])) fail(`README.md: lists unknown skill \`${m[1]}\``);
  }
}

// --- report ------------------------------------------------------------------
for (const w of warnings) console.warn(`WARN  ${w}`);
for (const e of errors) console.error(`FAIL  ${e}`);

if (errors.length) {
  console.error(`\n${errors.length} error(s), ${warnings.length} warning(s).`);
  process.exit(1);
}
console.log(`OK — ${skillDirs.length} skills validated, ${warnings.length} warning(s).`);
