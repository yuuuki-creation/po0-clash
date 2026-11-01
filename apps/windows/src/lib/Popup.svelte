<script>
  import { menuIn, menuOut } from './motion.svelte.js';
  import { placePopup, portal } from './popup.js';

  let { anchor, onclose, label, role = 'menu', align = 'end', matchWidth = false, class: extra = '', children } = $props();
  let node;

  // Text scale zooms the root, so viewport-measured rects have to be divided back into the popup's own CSS pixels.
  const zoom = () => parseFloat(document.documentElement.style.zoom) || 1;
  const scaled = ({ left, right, top, bottom }, z) => ({ left: left / z, right: right / z, top: top / z, bottom: bottom / z });

  function place(element) {
    node = element;
    const z = zoom();
    const box = scaled(anchor.getBoundingClientRect(), z);
    if (matchWidth) element.style.width = `${box.right - box.left}px`;
    const { left, top } = placePopup(
      box,
      { width: element.offsetWidth, height: element.offsetHeight },
      { width: innerWidth / z, height: innerHeight / z },
      { align },
    );
    element.style.left = `${left}px`;
    element.style.top = `${top}px`;
    element.querySelector('.sel, [aria-checked="true"]')?.scrollIntoView({ block: 'nearest' });
  }

  function outside(event) {
    if (node && !node.contains(event.target) && !anchor.contains(event.target)) onclose();
  }

  function keydown(event) {
    if (event.key === 'Escape') {
      event.stopPropagation();
      onclose();
      anchor.focus();
      return;
    }
    const step = { ArrowDown: 1, ArrowUp: -1 }[event.key];
    if (!step) return;
    event.preventDefault();
    const items = [...node.querySelectorAll('button:not(:disabled)')];
    const next = items.indexOf(document.activeElement) + step;
    items[(next + items.length) % items.length]?.focus();
  }
</script>

<svelte:window
  onpointerdown={outside}
  onkeydowncapture={keydown}
  onresize={onclose}
  onscrollcapture={(event) => node && !node.contains(event.target) && onclose()}
/>

<div class="menu {extra}" {role} aria-label={label} use:portal use:place in:menuIn out:menuOut>
  {@render children()}
</div>
