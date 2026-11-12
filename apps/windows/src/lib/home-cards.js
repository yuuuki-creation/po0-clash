export const HOME_CARDS = [
  { id: 'profile', label: 'home.profile' },
  { id: 'proxy', label: 'home.node' },
  { id: 'network', label: 'home.route' },
  { id: 'mode', label: 'home.mode' },
  { id: 'traffic', label: 'home.traffic' },
  { id: 'whitelist', label: 'nav.whitelist' },
  { id: 'ip', label: 'home.exitIp' },
  { id: 'info', label: 'home.info' },
];

export function shownHomeCards(saved) {
  const chosen = saved ?? HOME_CARDS.map(({ id }) => id);
  return HOME_CARDS.map(({ id }) => id).filter((id) => chosen.includes(id));
}
