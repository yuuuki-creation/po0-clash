// Follows Clash Verge Rev (GPL-3.0): src/components/base/base-search-box.tsx and utils/search-matcher.ts.
import { ClearRounded } from '@mui/icons-material';
import { Box, IconButton, SvgIcon, TextField, Tooltip } from '@mui/material';
import { useMemo } from 'react';
import { t } from '../lib/i18n.js';

export interface SearchState {
  text: string;
  matchCase: boolean;
  wholeWord: boolean;
  regex: boolean;
}

export const emptySearch = (): SearchState => ({ text: '', matchCase: false, wholeWord: false, regex: false });

const escapeRegex = (value: string) => value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

function buildRegex(pattern: string, flags: string) {
  try {
    return new RegExp(pattern, flags);
  } catch {
    return null;
  }
}

/** Returns null when the text is an invalid regular expression. */
export function compileMatcher({ text, matchCase, wholeWord, regex }: SearchState): ((content: string) => boolean) | null {
  if (!text) return () => true;
  const flags = matchCase ? '' : 'i';
  if (regex || wholeWord) {
    const compiled = buildRegex(regex ? text : `\\b${escapeRegex(text)}\\b`, flags);
    return compiled && ((content) => compiled.test(content));
  }
  if (matchCase) return (content) => content.includes(text);
  const target = text.toLowerCase();
  return (content) => content.toLowerCase().includes(target);
}

/** The matcher for a search state; an invalid regular expression matches nothing. */
export function useMatcher(state: SearchState) {
  const { text, matchCase, wholeWord, regex } = state;
  return useMemo(
    () => compileMatcher({ text, matchCase, wholeWord, regex }) ?? (() => false),
    [text, matchCase, wholeWord, regex],
  );
}

const icons = {
  matchCase:
    'M 175.755 768.851 L 334.113 343.826 L 394.912 343.826 L 554.501 768.851 L 494.851 768.851 L 453.989 653.897 L 275.036 653.897 L 234.583 768.851 L 175.755 768.851 Z M 293.332 604.339 L 436.102 604.339 L 366.441 406.757 L 362.994 406.757 L 293.332 604.339 Z M 703.344 780.174 C 670.415 780.174 644.541 771.518 625.724 754.205 C 606.907 736.892 597.499 713.412 597.499 683.764 C 597.499 653.898 608.575 629.61 630.729 610.902 C 652.882 592.195 681.682 582.842 717.129 582.842 C 732.663 582.842 747.433 584.223 761.437 586.985 C 775.44 589.747 787.419 593.973 797.375 599.662 L 797.375 580.626 C 797.375 557.323 790.66 539.299 777.231 526.554 C 763.802 513.808 744.753 507.435 720.082 507.435 C 705.423 507.435 691.652 510.293 678.769 516.01 C 665.887 521.726 654.004 530.218 643.118 541.486 L 607.099 512.687 C 621.43 495.948 637.95 483.422 656.657 475.107 C 675.365 466.793 696.726 462.636 720.739 462.636 C 762.639 462.636 794.365 472.988 815.918 493.693 C 837.469 514.397 848.245 544.797 848.245 584.893 L 848.245 770.574 L 798.031 770.574 L 798.031 731.025 L 794.421 731.025 C 784.903 746.889 772.39 759.046 756.882 767.498 C 741.375 775.948 723.529 780.174 703.344 780.174 Z M 709.087 736.688 C 734.031 736.688 754.981 727.594 771.939 709.406 C 788.896 691.218 797.375 668.694 797.375 641.836 C 787.693 636.147 776.315 631.812 763.242 628.831 C 750.168 625.849 737.751 624.358 725.99 624.358 C 701.594 624.358 682.735 629.555 669.415 639.949 C 656.096 650.342 649.436 664.947 649.436 683.764 C 649.436 699.628 654.906 712.414 665.846 722.124 C 676.786 731.833 691.2 736.688 709.087 736.688 Z',
  wholeWord:
    'M 64.002 831.066 L 64.002 649.735 L 128 649.735 L 128 767.067 L 896 767.067 L 896 649.735 L 959.999 649.735 L 959.999 831.066 L 64.001 831.066 L 64.002 831.066 Z M 414.031 680.257 L 414.031 640.708 L 410.421 640.708 C 400.903 656.571 388.39 668.729 372.882 677.18 C 357.375 685.631 339.529 689.857 319.344 689.857 C 286.688 689.857 260.883 681.2 241.929 663.887 C 222.975 646.575 213.499 623.095 213.499 593.447 C 213.499 563.58 224.575 539.293 246.729 520.585 C 268.883 501.878 297.546 492.524 332.719 492.524 C 348.254 492.524 363.023 493.905 377.026 496.667 C 391.029 499.43 403.146 503.656 413.375 509.345 L 413.375 490.309 C 413.375 467.006 406.729 448.982 393.437 436.236 C 380.144 423.49 361.299 417.117 336.902 417.117 C 321.969 417.117 307.993 419.976 294.975 425.692 C 281.956 431.408 270.004 439.9 259.118 451.169 L 223.099 422.37 C 237.43 405.631 253.95 393.104 272.657 384.79 C 291.365 376.476 312.862 372.318 337.149 372.318 C 379.05 372.318 410.708 382.671 432.123 403.375 C 453.538 424.079 464.245 454.479 464.245 494.575 L 464.245 680.257 L 414.031 680.257 Z M 341.99 534.041 C 317.867 534.041 299.077 539.238 285.62 549.631 C 272.164 560.024 265.436 574.493 265.436 593.036 C 265.436 609.174 270.974 622.097 282.051 631.806 C 293.128 641.516 307.61 646.371 325.498 646.371 C 350.441 646.371 371.323 637.277 388.144 619.089 C 404.965 600.9 413.375 578.377 413.375 551.518 C 403.693 545.83 392.315 541.495 379.242 538.514 C 366.168 535.532 353.751 534.041 341.99 534.041 Z M 541.375 680.667 L 541.375 252.934 L 593.558 252.934 L 593.558 384.545 L 590.358 427.211 L 593.148 427.211 C 598.564 418.733 608.943 408.435 624.287 396.319 C 639.631 384.203 660.977 378.145 688.327 378.145 C 729.735 378.145 762.638 393.27 787.035 423.519 C 811.431 453.769 823.629 491.047 823.629 535.355 C 823.629 579.116 811.609 615.874 787.568 645.631 C 763.527 675.389 730.31 690.267 687.917 690.267 C 662.044 690.267 641.258 684.688 625.558 673.529 C 609.859 662.37 599.056 651.594 593.148 641.201 L 590.358 641.201 L 590.358 680.667 L 541.375 680.667 Z M 681.6 426.801 C 653.702 426.801 631.521 437.563 615.056 459.087 C 598.591 480.613 590.358 505.816 590.358 534.698 C 590.358 564.018 598.591 589.263 615.056 610.433 C 631.521 631.602 653.702 642.186 681.6 642.186 C 709.497 642.186 731.309 631.807 747.036 611.048 C 762.762 590.289 770.625 564.839 770.625 534.698 C 770.625 504.558 762.762 479.04 747.036 458.145 C 731.309 437.249 709.497 426.801 681.6 426.801 Z',
  regex:
    'M 838.757 427.686 L 808.603 338.337 L 633.84 409.02 L 645.314 217.721 L 549.541 217.721 L 561.015 409.02 L 386.252 338.337 L 356.098 427.686 L 539.205 477.619 L 413.277 620.027 L 487.146 678.203 L 597.428 519.119 L 706.666 678.203 L 780.535 620.027 L 654.607 477.619 L 838.757 427.686 Z M 185.244 735.674 C 185.244 789.945 243.994 823.864 290.994 796.729 C 312.807 784.135 326.244 760.861 326.244 735.674 C 326.244 681.403 267.494 647.484 220.494 674.619 C 198.681 687.213 185.244 710.487 185.244 735.674 Z',
};

interface Props {
  value: SearchState;
  onChange: (next: SearchState) => void;
  placeholder?: string;
  autoFocus?: boolean;
}

export function SearchBox({ value, onChange, placeholder, autoFocus }: Props) {
  const invalid = value.regex && !!value.text && !compileMatcher(value);

  const toggle = (key: 'matchCase' | 'wholeWord' | 'regex', path: string) => (
    <Tooltip title={t(`search.${key}`)}>
      <SvgIcon
        viewBox="0 0 1024 1024"
        role="button"
        aria-label={t(`search.${key}`)}
        aria-pressed={value[key]}
        onClick={() => onChange({ ...value, [key]: !value[key] })}
        sx={{ width: 24, height: 24, cursor: 'pointer', color: value[key] ? 'primary.light' : '#A7A7A7' }}
      >
        <path d={path} />
      </SvgIcon>
    </Tooltip>
  );

  return (
    <Tooltip title={invalid ? t('search.invalidRegex') : ''} placement="bottom-start">
      <TextField
        hiddenLabel
        fullWidth
        size="small"
        variant="outlined"
        autoComplete="off"
        autoFocus={autoFocus}
        spellCheck={false}
        placeholder={placeholder ?? t('search.filter')}
        value={value.text}
        error={invalid}
        onChange={(event) => onChange({ ...value, text: event.target.value })}
        sx={(theme) => ({
          input: { py: 0.65, px: 1.25 },
          '& .MuiInputBase-root': { background: theme.palette.mode === 'light' ? '#fff' : undefined, pr: 1 },
        })}
        slotProps={{
          htmlInput: { 'aria-label': placeholder ?? t('search.filter') },
          input: {
            endAdornment: (
              <Box sx={{ display: 'flex', alignItems: 'center' }}>
                {!!value.text && (
                  <Tooltip title={t('search.reset')}>
                    <IconButton size="small" sx={{ width: 24, height: 24 }} onClick={() => onChange({ ...value, text: '' })}>
                      <ClearRounded fontSize="inherit" />
                    </IconButton>
                  </Tooltip>
                )}
                {toggle('matchCase', icons.matchCase)}
                {toggle('wholeWord', icons.wholeWord)}
                {toggle('regex', icons.regex)}
              </Box>
            ),
          },
        }}
      />
    </Tooltip>
  );
}
