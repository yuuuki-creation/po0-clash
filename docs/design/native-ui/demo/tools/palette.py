import math
from pathlib import Path


def oklch(L, C, H):
    a, b = C * math.cos(math.radians(H)), C * math.sin(math.radians(H))
    l = (L + 0.3963377774 * a + 0.2158037573 * b) ** 3
    m = (L - 0.1055613458 * a - 0.0638541728 * b) ** 3
    s = (L - 0.0894841775 * a - 1.2914855480 * b) ** 3
    linear = (4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
              -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
              -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s)

    def gamma(x):
        x = min(1, max(0, x))
        return 12.92 * x if x <= 0.0031308 else 1.055 * x ** (1 / 2.4) - 0.055

    return '#%02x%02x%02x' % tuple(round(gamma(x) * 255) for x in linear)


def luminance(hex_color):
    def channel(i):
        v = int(hex_color[i:i + 2], 16) / 255
        return v / 12.92 if v <= 0.03928 else ((v + 0.055) / 1.055) ** 2.4

    return 0.2126 * channel(1) + 0.7152 * channel(3) + 0.0722 * channel(5)


def contrast(x, y):
    a, b = sorted((luminance(x), luminance(y)), reverse=True)
    return (a + 0.05) / (b + 0.05)


def rgba(hex_color, alpha):
    r, g, b = (int(hex_color[i:i + 2], 16) for i in (1, 3, 5))
    return f'rgba({r}, {g}, {b}, {alpha})'


PALETTES = {
    'a': {'name': '松灰', 'hue': 160, 'chroma': 0.006, 'accent': {'light': (0.47, 0.085, 162), 'dark': (0.79, 0.095, 162)}},
    'b': {'name': '暖灰', 'hue': 85, 'chroma': 0.007, 'accent': {'light': (0.47, 0.085, 162), 'dark': (0.79, 0.095, 162)}},
    'c': {'name': '深松', 'hue': 160, 'chroma': 0.006, 'accent': {'light': (0.34, 0.05, 165), 'dark': (0.83, 0.07, 162)}},
}
LEVELS = {
    'light': dict(page=.945, side=.915, card=.995, card_hover=.975, card_press=.96, btn=.995, btn_hover=.975, btn_press=.955,
                  track=.905, sw_off=.74, zebra=.97, ink=.24, ink2=.45, ink3=.62, sel=.895, fab=.995, overlay=.985, foot=.955),
    'dark': dict(page=.205, side=.24, card=.26, card_hover=.29, card_press=.24, btn=.30, btn_hover=.33, btn_press=.27,
                 track=.31, sw_off=.50, zebra=.285, ink=.96, ink2=.78, ink3=.62, sel=.36, fab=.31, overlay=.27, foot=.21),
}


def roles(palette, theme):
    spec = PALETTES[palette]
    neutral_c = spec['chroma'] * (0.8 if theme == 'dark' else 1)
    # Near-white surfaces show a tint far more than mid tones, so cards stay almost white against the tinted page.
    out = {k: oklch(v, neutral_c * (0.35 if v > 0.97 else 1), spec['hue']) for k, v in LEVELS[theme].items()}
    L, C, H = spec['accent'][theme]
    step = 0.05 if theme == 'light' else -0.05
    out['accent'] = oklch(L, C, H)
    out['accent_hover'] = oklch(L + step, C, H)
    out['accent_press'] = oklch(L + 2 * step, C, H)
    out['on_accent'] = '#ffffff' if theme == 'light' else oklch(0.22, 0.03, H)
    out['warn'] = oklch(0.50, 0.11, 75) if theme == 'light' else oklch(0.84, 0.11, 85)
    out['bad'] = oklch(0.50, 0.17, 28) if theme == 'light' else oklch(0.78, 0.12, 25)
    return out


def platform_vars(platform, theme, r):
    ink = r['ink']
    alpha = 1 if theme == 'light' else 1.15
    shared = {
        '--bg': r['page'], '--card': r['card'], '--line': rgba(ink, round(.11 * alpha, 3)),
        '--ink': ink, '--ink2': r['ink2'], '--ink3': r['ink3'], '--accent': r['accent'], '--on-accent': r['on_accent'],
        '--track': r['track'], '--scrim': rgba('#000000', .32 if theme == 'light' else .5),
        '--scrollbar': rgba(ink, .3), '--warn': r['warn'], '--bad': r['bad'],
    }
    if platform == 'win':
        return shared | {
            '--card-hover': r['card_hover'], '--card-press': r['card_press'], '--stroke': rgba(ink, .08), '--stroke-bottom': rgba(ink, .2),
            '--accent-hover': r['accent_hover'], '--accent-press': r['accent_press'],
            '--hover': rgba(ink, .055), '--press': rgba(ink, .035), '--btn': r['btn'], '--btn-hover': r['btn_hover'], '--btn-press': r['btn_press'],
            '--seg-bg': r['card'] if theme == 'light' else r['btn_hover'], '--seg-shadow': f'0 0 0 1px {rgba(ink, .1)}',
            '--sw-stroke': rgba(ink, .6), '--sw-knob': rgba(ink, .68), '--in-bottom': rgba(ink, .5),
            '--overlay': r['overlay'], '--overlay-foot': r['foot'],
        }
    if platform == 'mac':
        return shared | {
            '--side': r['side'], '--zebra': r['zebra'], '--stroke': rgba(ink, .07), '--press': rgba(ink, .07), '--list-sel': rgba(ink, .08),
            '--btn': r['btn'], '--btn-shadow': f'0 0 0 0.5px {rgba(ink, .18)}, 0 1px 1px {rgba("#000000", .07 if theme == "light" else .3)}',
            '--seg-bg': r['card'] if theme == 'light' else r['btn_hover'],
            '--seg-shadow': f'0 0 0 0.5px {rgba(ink, .1)}, 0 1px 2px {rgba("#000000", .18 if theme == "light" else .4)}',
            '--sw-off': r['sw_off'], '--focus': rgba(r['accent'], .38), '--overlay': r['overlay'], '--menu': r['overlay'],
        }
    return shared | {
        '--card-hi': r['track'], '--outline': r['ink3'], '--sel': r['sel'], '--on-sel': ink, '--fab': r['fab'], '--on-fab': ink, '--sheet': r['overlay'],
    }


css = []
print(f"{'':10}{'正文/卡片':>10}{'次要/卡片':>10}{'次要/页面':>10}{'按钮字/强调':>12}{'强调/卡片':>10}{'卡片/页面':>10}{'警告/卡片':>10}{'错误/卡片':>10}")
for palette, spec in PALETTES.items():
    for theme in ('light', 'dark'):
        r = roles(palette, theme)
        print(f"{spec['name'] + ' ' + theme:10}" + ''.join(f'{v:10.2f}' for v in (
            contrast(r['ink'], r['card']), contrast(r['ink2'], r['card']), contrast(r['ink2'], r['page']),
            contrast(r['on_accent'], r['accent']), contrast(r['accent'], r['card']), contrast(r['card'], r['page']),
            contrast(r['warn'], r['card']), contrast(r['bad'], r['card']))),
            f" page {r['page']} card {r['card']} accent {r['accent']}")
        for platform in ('win', 'mac', 'and'):
            body = '\n'.join(f'  {k}: {v};' for k, v in platform_vars(platform, theme, r).items())
            css.append(f'.{platform}.{theme}.pal-{palette} {{\n{body}\n}}\n')
(Path(__file__).resolve().parents[1] / 'src' / 'colors.css').write_text('\n'.join(css), encoding='utf-8', newline='\n')
