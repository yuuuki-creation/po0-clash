// Setting rows follow Clash Verge Rev (GPL-3.0): src/components/setting/mods/setting-comp.tsx.
import { ChevronRightRounded } from '@mui/icons-material';
import {
  Box,
  CircularProgress,
  List,
  ListItem,
  ListItemButton,
  ListItemText,
  ListSubheader,
  MenuItem,
  Select,
  TextField,
  type TextFieldProps,
  Typography,
} from '@mui/material';
import { useVirtualizer } from '@tanstack/react-virtual';
import { type ReactNode, useEffect, useRef, useState } from 'react';
import { useSnapshot } from 'valtio';
import { Switch } from '../../base';
import { invoke } from '../../ipc';
import { app, notify } from '../../state/core';
import { engine, patchOptions, settings, updateSettings } from '../../state/settings';

export const useAppSettings = () => useSnapshot(settings).value as any;
export const useEngineOptions = () => useSnapshot(engine).options as any;

export const saveSettings = updateSettings;

export const openUrl = (url: string) => invoke('open_url', { url }).catch(() => {});

/** `act` for commands that return nothing: Tauri answers those with null and the mock with undefined, so success is reported here. */
export async function run(key: string, command: string, args?: Record<string, unknown>): Promise<boolean> {
  app.busy[key] = true;
  try {
    await invoke(command, args);
    return true;
  } catch (error) {
    notify(error);
    return false;
  } finally {
    delete app.busy[key];
  }
}

export function SettingList({ title, children }: { title: string; children: ReactNode }) {
  return (
    <List>
      <ListSubheader disableSticky sx={{ background: 'transparent', fontSize: 16, fontWeight: 700, color: 'text.primary' }}>
        {title}
      </ListSubheader>
      {children}
    </List>
  );
}

interface ItemProps {
  label: ReactNode;
  extra?: ReactNode;
  secondary?: ReactNode;
  children?: ReactNode;
  onClick?: () => void;
  disabled?: boolean;
  loading?: boolean;
  /** Shown at the right of a clickable row in place of the chevron. */
  trailing?: ReactNode;
}

export function SettingItem({ label, extra, secondary, children, onClick, disabled, loading, trailing }: ItemProps) {
  const primary = (
    <Box sx={{ display: 'flex', alignItems: 'center', fontSize: 14 }}>
      <span>{label}</span>
      {extra}
    </Box>
  );
  if (!onClick) {
    return (
      <ListItem sx={{ pt: '5px', pb: '5px' }}>
        <ListItemText primary={primary} secondary={secondary} />
        {children}
      </ListItem>
    );
  }
  return (
    <ListItem disablePadding>
      <ListItemButton onClick={onClick} disabled={disabled || loading}>
        <ListItemText primary={primary} secondary={secondary} />
        {loading ? <CircularProgress color="inherit" size={20} /> : (trailing ?? <ChevronRightRounded />)}
      </ListItemButton>
    </ListItem>
  );
}

export function AppSwitchItem({ label, name }: { label: string; name: string }) {
  const s = useAppSettings();
  return (
    <SettingItem label={label}>
      <Switch edge="end" checked={!!s?.[name]} disabled={!s} onChange={(_, on) => updateSettings({ [name]: on })} />
    </SettingItem>
  );
}

export function OptionSwitchItem({ label, name }: { label: string; name: string }) {
  const o = useEngineOptions();
  return (
    <SettingItem label={label}>
      <Switch edge="end" checked={!!o?.[name]} disabled={!o} onChange={(_, on) => patchOptions({ [name]: on })} />
    </SettingItem>
  );
}

interface ChoiceProps {
  value: string;
  options: { value: string; label: string }[];
  onChange: (value: string) => void;
  width?: number;
  disabled?: boolean;
}

export function Choice({ value, options, onChange, width = 120, disabled }: ChoiceProps) {
  return (
    <Select size="small" value={value} disabled={disabled} sx={{ width, '> div': { py: '7.5px' } }} onChange={(event) => onChange(event.target.value)}>
      {options.map((option) => (
        <MenuItem key={option.value} value={option.value}>
          {option.label}
        </MenuItem>
      ))}
    </Select>
  );
}

const plainInput = { autoComplete: 'off', autoCorrect: 'off', autoCapitalize: 'off', spellCheck: false } as const;

export function PlainField(props: TextFieldProps) {
  return <TextField size="small" {...props} slotProps={{ ...props.slotProps, htmlInput: { ...plainInput, ...(props.slotProps as any)?.htmlInput } }} />;
}

interface LinesProps {
  label: string;
  value: string;
  onChange: (value: string) => void;
  rows?: number;
  placeholder?: string;
}

export function LinesField({ label, value, onChange, rows = 3, placeholder }: LinesProps) {
  return (
    <Box sx={{ py: '5px', px: '2px' }}>
      <Typography sx={{ fontSize: 14, mb: 0.75 }}>{label}</Typography>
      <PlainField
        fullWidth
        multiline
        minRows={rows}
        maxRows={Math.max(rows, 8)}
        value={value}
        placeholder={placeholder}
        onChange={(event) => onChange(event.target.value)}
        sx={{ '& textarea': { fontFamily: 'Consolas, Menlo, monospace', fontSize: 13, lineHeight: 1.5 } }}
      />
    </Box>
  );
}

export function DialogRow({ label, children }: { label: ReactNode; children?: ReactNode }) {
  return (
    <ListItem sx={{ padding: '5px 2px' }}>
      <ListItemText primary={label} slotProps={{ primary: { sx: { fontSize: 14 } } }} />
      {children}
    </ListItem>
  );
}

export function DialogSection({ title }: { title: string }) {
  return <Typography sx={{ fontSize: 14, fontWeight: 700, px: '2px', pt: 1.5, pb: 0.5 }}>{title}</Typography>;
}

interface VirtualProps<T> {
  items: readonly T[];
  rowHeight: number;
  height: number;
  itemKey: (item: T) => string;
  children: (item: T) => ReactNode;
}

export function VirtualRows<T>({ items, rowHeight, height, itemKey, children }: VirtualProps<T>) {
  const parent = useRef<HTMLDivElement>(null);
  const virtual = useVirtualizer({
    count: items.length,
    getScrollElement: () => parent.current,
    estimateSize: () => rowHeight,
    overscan: 8,
    getItemKey: (index) => itemKey(items[index]),
  });
  return (
    <Box ref={parent} sx={{ height, overflow: 'auto' }}>
      <Box sx={{ height: virtual.getTotalSize(), position: 'relative' }}>
        {virtual.getVirtualItems().map((row) => (
          <Box key={row.key} sx={{ position: 'absolute', top: 0, left: 0, width: '100%', height: rowHeight, transform: `translateY(${row.start}px)` }}>
            {children(items[row.index])}
          </Box>
        ))}
      </Box>
    </Box>
  );
}

/** Runs `load` once when the component mounts and keeps its result. */
export function useLoaded<T>(load: () => Promise<T>, initial: T): [T, () => Promise<void>] {
  const [value, setValue] = useState(initial);
  const reload = () =>
    load().then(
      (next) => setValue(next),
      () => {},
    );
  useEffect(() => {
    reload();
  }, []);
  return [value, reload];
}
