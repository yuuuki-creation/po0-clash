import { type ReactNode, useEffect, useState } from 'react';

function iconSource(icon?: string | null) {
  const value = icon?.trim();
  if (!value) return null;
  if (value.startsWith('<svg') || value.startsWith('<?xml')) return `data:image/svg+xml;utf8,${encodeURIComponent(value)}`;
  if (/^(https?:|data:)/.test(value)) return value;
  return `data:image/png;base64,${value}`;
}

interface Props {
  icon?: string | null;
  /** `settings.groupIconStyle`: 'standard' | 'iconOnly' | 'hidden'. */
  style?: string;
  size?: number;
  /** The group's name; left out when the style is icon-only and the icon loads. */
  children: ReactNode;
}

export function GroupIcon({ icon, style = 'standard', size = 32, children }: Props) {
  const src = style === 'hidden' ? null : iconSource(icon);
  const [failed, setFailed] = useState(false);
  useEffect(() => setFailed(false), [src]);
  const shown = !!src && !failed;
  return (
    <>
      {shown && (
        <img
          src={src}
          alt=""
          width={size}
          height={size}
          style={{ marginRight: 12, borderRadius: 6, flex: 'none', objectFit: 'contain' }}
          onError={() => setFailed(true)}
        />
      )}
      {(style !== 'iconOnly' || !shown) && children}
    </>
  );
}
