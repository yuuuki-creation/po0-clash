export function bezier(x1, y1, x2, y2) {
  const coordinate = (a, b, t) => 3 * a * (1 - t) * (1 - t) * t + 3 * b * (1 - t) * t * t + t * t * t;
  return (x) => {
    if (x <= 0) return 0;
    if (x >= 1) return 1;
    let low = 0;
    let high = 1;
    for (let i = 0; i < 24; i++) {
      const middle = (low + high) / 2;
      if (coordinate(x1, x2, middle) < x) low = middle;
      else high = middle;
    }
    return coordinate(y1, y2, (low + high) / 2);
  };
}

// Svelte runs an outro's clock from 1 to 0, so a curve meant to play forward has to be mirrored.
export const forOutro = (easing) => (t) => 1 - easing(1 - t);

export const easeIn = bezier(0, 0, 0, 1);
export const easeOut = bezier(0.4, 0, 1, 1);
