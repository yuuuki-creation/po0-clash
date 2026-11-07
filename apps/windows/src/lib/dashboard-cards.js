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


