// Liquid glass refraction: an SVG displacement map, sized to each element, bends what is behind it inside a narrow bezel
// along the edge and leaves the middle untouched. WebView2 (Chromium) applies SVG filters in `backdrop-filter`.

const NS = 'http://www.w3.org/2000/svg';
const maps = new Map();
let defs;

function container() {
  if (!defs) {
    const svg = document.createElementNS(NS, 'svg');
    svg.setAttribute('aria-hidden', 'true');
    svg.style.cssText = 'position:absolute;width:0;height:0;overflow:hidden';
    defs = document.createElementNS(NS, 'defs');
    svg.append(defs);
    document.body.append(svg);
  }
  return defs;
}

// Red and green carry where each pixel samples from: inward along the edge normal, strongest at the rim.
function displacementMap(width, height, radius, bezel) {
  const canvas = document.createElement('canvas');
  canvas.width = width;
  canvas.height = height;
  const context = canvas.getContext('2d');
  const image = context.createImageData(width, height);
  const r = Math.min(radius, width / 2, height / 2);
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      const px = x + 0.5 - width / 2;
      const py = y + 0.5 - height / 2;
      const qx = Math.abs(px) - (width / 2 - r);
      const qy = Math.abs(py) - (height / 2 - r);
      const outside = Math.hypot(Math.max(qx, 0), Math.max(qy, 0));
      const depth = r - outside - Math.min(Math.max(qx, qy), 0);
      let dx = 0;
      let dy = 0;
      if (depth < bezel) {
        const t = (1 - Math.max(depth, 0) / bezel) ** 2;
        let nx = qx > 0 || qy > 0 ? Math.max(qx, 0) : qx > qy ? 1 : 0;
        let ny = qx > 0 || qy > 0 ? Math.max(qy, 0) : qx > qy ? 0 : 1;
        const length = Math.hypot(nx, ny) || 1;
        nx = (nx / length) * Math.sign(px);
        ny = (ny / length) * Math.sign(py);
        dx = -nx * t;
        dy = -ny * t;
      }
      const i = (y * width + x) * 4;
      image.data[i] = Math.round(127.5 + dx * 127.5);
      image.data[i + 1] = Math.round(127.5 + dy * 127.5);
      image.data[i + 2] = 128;
      image.data[i + 3] = 255;
    }
  }
  context.putImageData(image, 0, 0);
  return canvas.toDataURL();
}

function filterFor(width, height, radius, strength) {
  const bezel = Math.min(16, Math.min(width, height) * 0.35);
  const key = `${width}x${height}r${radius}s${strength}`;
  if (maps.has(key)) return maps.get(key);
  const id = `glass-${maps.size}`;
  const filter = document.createElementNS(NS, 'filter');
  filter.id = id;
  for (const [name, value] of Object.entries({
    x: 0,
    y: 0,
    width,
    height,
    filterUnits: 'userSpaceOnUse',
    'color-interpolation-filters': 'sRGB',
  })) {
    filter.setAttribute(name, value);
  }
  const map = document.createElementNS(NS, 'feImage');
  map.setAttribute('href', displacementMap(width, height, radius, bezel));
  map.setAttribute('width', width);
  map.setAttribute('height', height);
  map.setAttribute('result', 'map');
  const displace = document.createElementNS(NS, 'feDisplacementMap');
  displace.setAttribute('in', 'SourceGraphic');
  displace.setAttribute('in2', 'map');
  displace.setAttribute('scale', strength);
  displace.setAttribute('xChannelSelector', 'R');
  displace.setAttribute('yChannelSelector', 'G');
  filter.append(map, displace);
  container().append(filter);
  maps.set(key, id);
  return id;
}

const strengths = [
  ['.dialog', 14],
  ['.menu-pop', 8],
  ['.tb-group, .round-glass, .search', 10],
];

/** Gives every floating `.glass` layer its refraction; the sidebar floats over Mica, which the web view cannot see. */
export function watchGlass(root = document.body) {
  const observers = new WeakMap();
  const attach = (node) => {
    const strength = strengths.find(([selector]) => node.matches(selector))?.[1];
    if (!strength || observers.has(node)) return;
    const update = () => {
      const width = Math.round(node.offsetWidth);
      const height = Math.round(node.offsetHeight);
      if (width < 8 || height < 8 || width * height > 900_000) return node.style.removeProperty('--refract');
      const radius = Math.round(parseFloat(getComputedStyle(node).borderTopLeftRadius) || 0);
      node.style.setProperty('--refract', `url(#${filterFor(width, height, radius, strength)})`);
    };
    const observer = new ResizeObserver(update);
    observer.observe(node);
    observers.set(node, observer);
  };
  const scan = (node) => {
    if (node.nodeType !== 1) return;
    if (node.classList.contains('glass')) attach(node);
    node.querySelectorAll('.glass').forEach(attach);
  };
  const detach = (node) => {
    if (node.nodeType !== 1) return;
    for (const glass of [node, ...node.querySelectorAll('.glass')]) {
      observers.get(glass)?.disconnect();
      observers.delete(glass);
    }
  };
  new MutationObserver((records) => {
    for (const record of records) {
      record.addedNodes.forEach(scan);
      record.removedNodes.forEach(detach);
    }
  }).observe(root, { childList: true, subtree: true });
  scan(root);
}
