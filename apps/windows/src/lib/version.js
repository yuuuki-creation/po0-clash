export function parseVersion(text) {
  let rest = String(text).trim().replace(/^v+/, '');
  rest = rest.split('+')[0];
  const dash = rest.indexOf('-');
  const core = (dash < 0 ? rest : rest.slice(0, dash)).split('.');
  const pre = dash < 0 ? null : rest.slice(dash + 1);
  if (core.length !== 3 || core.some((part) => !/^\d+$/.test(part))) return null;
  return { core: core.map(Number), pre, text: rest };
}

function comparePre(a, b) {
  const [x, y] = [a.split('.'), b.split('.')];
  for (let i = 0; i < Math.min(x.length, y.length); i++) {
    const [p, q] = [x[i], y[i]];
    const [pn, qn] = [/^\d+$/.test(p), /^\d+$/.test(q)];
    if (pn && qn) {
      if (Number(p) !== Number(q)) return Number(p) - Number(q);
    } else if (pn !== qn) {
      return pn ? -1 : 1;
    } else if (p !== q) {
      return p < q ? -1 : 1;
    }
  }
  return x.length - y.length;
}

/** Semver precedence: a pre-release sorts before its release, and numeric identifiers compare as numbers. */
export function compareVersions(a, b) {
  for (let i = 0; i < 3; i++) if (a.core[i] !== b.core[i]) return a.core[i] - b.core[i];
  if (a.pre === null || b.pre === null) return (a.pre === null ? 1 : 0) - (b.pre === null ? 1 : 0);
  return comparePre(a.pre, b.pre);
}

const TAG_PREFIX = 'native-v';

/** Mirrors `crates/core/src/update.rs`: a stable build is never offered a pre-release, drafts never count. */
export function newestAbove(appVersion, releases) {
  const current = parseVersion(appVersion);
  if (!current || !Array.isArray(releases)) return null;
  let best = null;
  for (const release of releases) {
    const tag = release?.tag_name;
    if (release?.draft === true || typeof tag !== 'string' || !tag.startsWith(TAG_PREFIX)) continue;
    const version = parseVersion(tag.slice(TAG_PREFIX.length));
    if (!version || (current.pre === null && version.pre !== null)) continue;
    if (compareVersions(version, current) <= 0) continue;
    if (!best || compareVersions(version, best.version) > 0) best = { version, release };
  }
  if (!best) return null;
  const field = (name) => (typeof best.release[name] === 'string' ? best.release[name] : '');
  return { version: best.version.text, url: field('html_url'), notes: field('body') };
}
