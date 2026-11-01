const CORE_DEFAULT_ORDER = [
  'currentNode',
  'speed',
  'mode',
  'takeover',
  'whitelist',
  'traffic',
  'connections',
  'memory',
  'intranetIp',
  'subscription',
  'exitIp',
];

const DESIGN_ORDER = [
  'currentNode',
  'mode',
  'takeover',
  'whitelist',
  'subscription',
  'exitIp',
  'intranetIp',
  'speed',
  'traffic',
  'connections',
  'memory',
];

const SECTION = {
  currentNode: 'control',
  mode: 'control',
  takeover: 'control',
  whitelist: 'info',
  subscription: 'info',
  exitIp: 'info',
  intranetIp: 'info',
  speed: 'speed',
  traffic: 'stats',
  connections: 'stats',
  memory: 'stats',
};

const ROW_HEIGHT = 52;
const SPEED_HEIGHT = 202;
const SECTION_GAP = 16;

export function moveCard(cards, from, to) {
  const order = [...cards];
  const source = order.indexOf(from);
  const target = order.indexOf(to);
  if (source < 0 || target < 0 || source === target) return order;
  order.splice(source, 1);
  order.splice(target, 0, from);
  return order;
}

/** The core's untouched default reads as the designed layout; any list the user has edited is taken as written. */
export const displayOrder = (cards) =>
  cards.length === CORE_DEFAULT_ORDER.length && cards.every((id, i) => id === CORE_DEFAULT_ORDER[i]) ? DESIGN_ORDER : cards;

function sections(cards) {
  const result = [];
  for (const id of cards) {
    const last = result.at(-1);
    if (last?.key === SECTION[id]) last.cards.push(id);
    else result.push({ key: SECTION[id], cards: [id] });
  }
  return result;
}

const height = (cards) =>
  sections(cards).reduce(
    (sum, section) =>
      sum + SECTION_GAP + section.cards.reduce((rows, id) => rows + (id === 'speed' ? SPEED_HEIGHT : ROW_HEIGHT), 0),
    0,
  );

/** Newspaper columns: the order reads down the left column and on down the right, broken where they balance best. */
export function arrangeCards(cards) {
  let split = 0;
  let best = Infinity;
  for (let i = 0; i <= cards.length; i++) {
    const difference = Math.abs(height(cards.slice(0, i)) - height(cards.slice(i)));
    if (difference < best) {
      best = difference;
      split = i;
    }
  }
  return [sections(cards.slice(0, split)), sections(cards.slice(split))].filter((column) => column.length);
}
