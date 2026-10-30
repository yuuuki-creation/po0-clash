<script>
  import { t } from './i18n.js';

  let { history } = $props();

  const W = 600;
  const H = 70;

  function smooth(points) {
    let d = `M${points[0][0].toFixed(1)},${points[0][1].toFixed(1)}`;
    for (let i = 0; i < points.length - 1; i++) {
      const [p0, p1, p2, p3] = [points[i - 1] ?? points[i], points[i], points[i + 1], points[i + 2] ?? points[i + 1]];
      const c1 = [p1[0] + (p2[0] - p0[0]) / 6, p1[1] + (p2[1] - p0[1]) / 6];
      const c2 = [p2[0] - (p3[0] - p1[0]) / 6, p2[1] - (p3[1] - p1[1]) / 6];
      d += ` C${c1.map((n) => n.toFixed(1))} ${c2.map((n) => n.toFixed(1))} ${p2.map((n) => n.toFixed(1))}`;
    }
    return d;
  }

  const paths = $derived.by(() => {
    const samples = history.length > 1 ? history : [{ up: 0, down: 0 }, { up: 0, down: 0 }];
    const max = Math.max(1, ...samples.flatMap((s) => [s.up, s.down])) * 1.1;
    const at = (key) => samples.map((s, i) => [(i / (samples.length - 1)) * W, H - 2 - (s[key] / max) * (H - 8)]);
    const down = smooth(at('down'));
    return { down, area: `${down} L${W},${H} L0,${H} Z`, up: smooth(at('up')) };
  });
</script>

<svg class="chart" viewBox="0 0 {W} {H}" preserveAspectRatio="none" role="img" aria-label={t('home.chartLabel')}>
  <path class="base" d="M0,{H - 0.5} H{W}" />
  <path class="area" d={paths.area} />
  <path class="down" d={paths.down} />
  <path class="up" d={paths.up} />
</svg>
