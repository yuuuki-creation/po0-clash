import { proxy } from 'valtio';

export const view = proxy({
  query: '',
  open: {} as Record<string, boolean>,
  filter: {} as Record<string, string>,
  filtering: {} as Record<string, boolean>,
  touched: false,
  locate: null as string | null,
});

/** Opens the page on a group, and clears any filter that could hide it. */
export function focusGroup(name?: string | null) {
  view.query = '';
  if (!name) return;
  view.touched = true;
  view.open[name] = true;
  delete view.filter[name];
  view.locate = name;
}

export function toggleGroup(name: string) {
  view.touched = true;
  view.open[name] = !view.open[name];
}

export const delayColor = (delay: number | null) =>
  delay == null ? 'text.secondary' : delay === 0 ? 'error.main' : delay < 300 ? 'success.main' : delay < 800 ? 'warning.main' : 'error.main';

export const TILE_HEIGHT: Record<string, number> = { loose: 64, standard: 56, tight: 46 };
export const TILE_GAP: Record<string, number> = { loose: 10, standard: 8, tight: 6 };
