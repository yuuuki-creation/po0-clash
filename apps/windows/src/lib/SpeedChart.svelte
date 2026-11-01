<script>
  import { t } from './i18n.js';
  import { motion } from './motion.svelte.js';

  let { history } = $props();

  const LENGTH = 60;
  const W = 480;
  const H = 148;
  // The core keeps 60 samples, so one of them always waits past the right edge for the next glide.
  const STEP = W / (LENGTH - 2);
  let slide;

  const samples = $derived(
    Array.from({ length: LENGTH }, (_, i) => history[history.length - LENGTH + i] ?? { up: 0, down: 0 }),
  );
  const top = $derived(Math.max(1024, ...samples.flatMap((s) => [s.up, s.down])) / 0.9);
  const line = (key) =>
    samples.map((s, i) => `${i ? 'L' : 'M'}${(i * STEP).toFixed(1)} ${(H - 6 - (s[key] / top) * (H - 16)).toFixed(1)}`).join('');

  // One sample arrives each second: the frame restarts one step back and glides to it, so the line never jumps.
  $effect(() => {
    history;
    if (!slide) return;
    slide.style.transition = 'none';
    slide.style.transform = 'translateX(0)';
    slide.getBoundingClientRect();
    if (motion(1)) {
      slide.style.transition = 'transform 1000ms linear';
      slide.style.transform = `translateX(${-STEP}px)`;
    }
  });
</script>

<div class="chart-wrap">
  <svg class="chart" viewBox="0 0 {W} {H}" preserveAspectRatio="none" role="img" aria-label={t('home.speed')}>
    <g bind:this={slide}>
      <path class="up" d={line('up')} />
      <path class="dn" d={line('down')} />
    </g>
  </svg>
</div>
