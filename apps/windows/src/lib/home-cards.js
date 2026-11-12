export const HOME_CARDS = [
  { id: 'subscription', view: 'profile', label: 'home.profile' },
  { id: 'currentNode', view: 'proxy', label: 'home.node' },
  { id: 'takeover', view: 'network', label: 'home.route' },
  { id: 'mode', view: 'mode', label: 'home.mode' },
  { id: 'traffic', view: 'traffic', label: 'home.traffic' },
  { id: 'whitelist', view: 'whitelist', label: 'nav.whitelist' },
  { id: 'exitIp', view: 'ip', label: 'home.exitIp' },
  { id: 'memory', view: 'info', label: 'home.info' },
];

export function shownHomeCards(saved) {
  const chosen = saved ?? HOME_CARDS.map(({ id }) => id);
  return HOME_CARDS.map(({ id }) => id).filter((id) => chosen.includes(id));
}

export function saveHomeCards(saved, chosen) {
  const desktop = new Set(HOME_CARDS.map(({ id }) => id));
  return [...new Set([...(saved ?? []).filter((id) => !desktop.has(id)), ...shownHomeCards(chosen)])];
}
