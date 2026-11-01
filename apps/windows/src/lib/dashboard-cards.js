export function moveCard(cards, from, to) {
  const order = [...cards];
  const source = order.indexOf(from);
  const target = order.indexOf(to);
  if (source < 0 || target < 0 || source === target) return order;
  order.splice(source, 1);
  order.splice(target, 0, from);
  return order;
}
