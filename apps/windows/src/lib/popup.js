/** Lifts an overlay to the body so an ancestor's overflow or containment cannot clip or capture it. */
export function portal(node) {
  document.body.append(node);
  return { destroy: () => node.remove() };
}

/** Top-left corner for a popup under its anchor, kept inside the viewport and opening upward when only that fits. */
export function placePopup(anchor, size, viewport, { align = 'end', gap = 4, margin = 8 } = {}) {
  const left = align === 'end' ? anchor.right - size.width : anchor.left;
  const below = anchor.bottom + gap;
  const above = anchor.top - gap - size.height;
  const fitsBelow = below + size.height <= viewport.height - margin;
  const top = fitsBelow || above < margin ? Math.min(below, viewport.height - margin - size.height) : above;
  return {
    left: Math.max(margin, Math.min(left, viewport.width - margin - size.width)),
    top: Math.max(margin, top),
  };
}
