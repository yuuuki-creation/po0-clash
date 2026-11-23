// Follows Clash Verge Rev 2.5.10 (GPL-3.0): components/layout/traffic-graph.tsx.
import { useMediaQuery, useTheme } from '@mui/material';
import { useEffect, useRef } from 'react';
import { useSnapshot } from 'valtio';
import { app } from '../state/core';

const POINTS = 30;

export function TrafficGraph() {
  const { history } = useSnapshot(app);
  const { palette } = useTheme();
  const reduced = useMediaQuery('(prefers-reduced-motion: reduce)');
  const canvas = useRef<HTMLCanvasElement>(null);
  const latest = useRef(history);
  const redraw = useRef<(animate: boolean) => void>(() => {});
  useEffect(() => {
    latest.current = history;
    redraw.current(true);
  }, [history]);

  useEffect(() => {
    const el = canvas.current!;
    const ctx = el.getContext('2d');
    if (!ctx) return;
    let animation: Animation | undefined;
    const draw = (animate: boolean) => {
      const elapsed = animate ? 0 : Number(animation?.currentTime ?? 1000);
      animation?.cancel();
      const width = el.clientWidth;
      const height = el.clientHeight;
      if (!width || !height) return;
      const ratio = window.devicePixelRatio || 1;
      const pixelWidth = Math.round(width * ratio);
      const pixelHeight = Math.round(height * ratio);
      if (el.width !== pixelWidth) el.width = pixelWidth;
      if (el.height !== pixelHeight) el.height = pixelHeight;
      ctx.setTransform(ratio, 0, 0, ratio, 0, 0);
      ctx.clearRect(0, 0, width, height);
      const samples = latest.current.slice(-(POINTS + 2));
      const points = Array.from({ length: POINTS + 2 }, (_, i) => samples[i - (POINTS + 2 - samples.length)] ?? { up: 0, down: 0 });
      const peak = Math.max(1024, ...points.map((p) => Math.max(p.up, p.down)));
      const dx = width / (POINTS + 1);
      ctx.strokeStyle = palette.divider;
      ctx.lineWidth = 1;
      for (const y of [height / 3, height * 2 / 3]) {
        ctx.beginPath();
        ctx.moveTo(0, y);
        ctx.lineTo(width, y);
        ctx.stroke();
      }
      for (const [key, color, opacity] of [['up', palette.secondary.main, 0.6], ['down', palette.primary.main, 1]] as const) {
        const y = (i: number) => height - 2 - points[i][key] / peak * (height - 6);
        ctx.beginPath();
        ctx.moveTo(-dx, y(0));
        for (let i = 1; i < points.length; i++) {
          const next = Math.min(i + 1, points.length - 1);
          ctx.quadraticCurveTo((i - 1) * dx, y(i), (i - 0.5) * dx, (y(i) + y(next)) / 2);
        }
        ctx.strokeStyle = color;
        ctx.globalAlpha = opacity;
        ctx.lineWidth = 2;
        ctx.stroke();
      }
      ctx.globalAlpha = 1;
      if (!reduced && !document.hidden && points.some((p) => p.up || p.down)) {
        animation = el.animate([{ transform: 'translateX(0)' }, { transform: `translateX(${-dx}px)` }], {
          duration: 1000, easing: 'linear', fill: 'forwards',
        });
        animation.currentTime = Math.min(elapsed, 1000);
      } else {
        el.style.transform = 'none';
      }
    };
    redraw.current = draw;
    draw(false);
    const observer = new ResizeObserver(() => draw(false));
    observer.observe(el.parentElement!);
    const visibility = () => draw(false);
    document.addEventListener('visibilitychange', visibility);
    return () => {
      redraw.current = () => {};
      observer.disconnect();
      animation?.cancel();
      document.removeEventListener('visibilitychange', visibility);
    };
  }, [palette, reduced]);

  return <div className="traffic-graph" style={{ height: 60, marginBottom: 6, overflow: 'hidden' }}>
    <canvas ref={canvas} style={{ width: `${(POINTS + 1) / POINTS * 100}%`, height: '100%', display: 'block' }} />
  </div>;
}
