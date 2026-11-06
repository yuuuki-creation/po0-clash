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
    'a': {
        'name': 'Astryx Neutral',
        'light': dict(
            page='#F4F4F5', side='#FFFFFF', card='#FFFFFF', card_hover='#F8FAFC', card_press='#F1F5F9',
            btn='#FFFFFF', btn_hover='#F4F4F5', btn_press='#E4E4E7', track='#E4E4E7', sw_off='#A1A1AA',
            zebra='#FAFAFA', ink='#09090B', ink2='#52525B', ink3='#A1A1AA',
            sel='#0082FB26', fab='#0064E0', overlay='#FFFFFF', foot='#F4F4F5',
            accent='#0064E0', accent_hover='#0058C4', accent_press='#004BA8', on_accent='#FFFFFF',
            good='#0D8626', warn='#B45309', bad='#E3193B',
        ),
        'dark': dict(
            page='#111112', side='#1F1F22', card='#1F1F22', card_hover='#27272A', card_press='#18181B',
            btn='#27272A', btn_hover='#303036', btn_press='#1F1F22', track='#3F3F46', sw_off='#52525B',
            zebra='#232326', ink='#DFE2E5', ink2='#AAAFB5', ink3='#6F747C',
            sel='#0082FB3F', fab='#0171E3', overlay='#28292C', foot='#18181B',
            accent='#3E9EFB', accent_hover='#5CAEFF', accent_press='#2694FE', on_accent='#0A1317',
            good='#26A756', warn='#F2C00B', bad='#FF4D61',
        ),
    },
    'b': {
        'name': 'Astryx Core',
        'light': dict(
            page='#F1F4F7', side='#FFFFFF', card='#FFFFFF', card_hover='#F7F9FB', card_press='#EDF2F7',
            btn='#FFFFFF', btn_hover='#F1F4F7', btn_press='#E2E8F0', track='#CCD3DB', sw_off='#A4B0BC',
            zebra='#F8FAFC', ink='#0A1317', ink2='#4E606F', ink3='#8696A6',
            sel='#0082FB26', fab='#0064E0', overlay='#FFFFFF', foot='#F1F4F7',
            accent='#0064E0', accent_hover='#0056C2', accent_press='#0048A3', on_accent='#FFFFFF',
            good='#0D8626', warn='#9A6700', bad='#D31130',
        ),
        'dark': dict(
            page='#111112', side='#1F1F22', card='#1F1F22', card_hover='#26272B', card_press='#1A1A1D',
            btn='#28292C', btn_hover='#323438', btn_press='#222326', track='#494D53', sw_off='#5A5E66',
            zebra='#232428', ink='#DFE2E5', ink2='#AAAFB5', ink3='#6F747C',
            sel='#0082FB3F', fab='#0171E3', overlay='#28292C', foot='#18181A',
            accent='#3E9EFB', accent_hover='#5CAEFF', accent_press='#2694FE', on_accent='#0A1317',
            good='#26A756', warn='#F2C00B', bad='#FF4D61',
        ),
    },
    'c': {
        'name': 'Astryx Stone',
        'light': dict(
            page='#F3F4F6', side='#FFFFFF', card='#FFFFFF', card_hover='#F8FAFC', card_press='#EFF2F6',
            btn='#FFFFFF', btn_hover='#F3F4F6', btn_press='#E5E7EB', track='#D1D5DB', sw_off='#9CA3AF',
            zebra='#F9FAFB', ink='#111827', ink2='#4B5563', ink3='#9CA3AF',
            sel='#0082FB26', fab='#0064E0', overlay='#FFFFFF', foot='#F3F4F6',
            accent='#0064E0', accent_hover='#0056C2', accent_press='#0048A3', on_accent='#FFFFFF',
            good='#0D8626', warn='#9A6700', bad='#D31130',
        ),
        'dark': dict(
            page='#111112', side='#1F1F22', card='#1F1F22', card_hover='#26272B', card_press='#1A1A1D',
            btn='#28292C', btn_hover='#323438', btn_press='#222326', track='#494D53', sw_off='#5A5E66',
            zebra='#232428', ink='#DFE2E5', ink2='#AAAFB5', ink3='#6F747C',
            sel='#0082FB3F', fab='#0171E3', overlay='#28292C', foot='#18181A',
            accent='#3E9EFB', accent_hover='#5CAEFF', accent_press='#2694FE', on_accent='#0A1317',
            good='#26A756', warn='#F2C00B', bad='#FF4D61',
        ),
    },
}


def roles(palette, theme):
    return dict(PALETTES[palette][theme])


def platform_vars(platform, theme, r):
    ink = r['ink']
    alpha = 1 if theme == 'light' else 1.15
    shared = {
        '--color-background-body': r['page'],
        '--color-background-surface': r['side'],
        '--color-background-card': r['card'],
        '--color-background-popover': r['overlay'],
        '--color-background-muted': rgba(ink, .05 if theme == 'light' else .08),
        '--color-overlay-hover': rgba(ink, .05 if theme == 'light' else .06),
        '--color-overlay-pressed': rgba(ink, .09 if theme == 'light' else .10),
        '--color-border': rgba(ink, round(.10 * alpha, 3)),
        '--color-border-emphasized': r['track'],
        '--color-text-primary': ink,
        '--color-text-secondary': r['ink2'],
        '--color-text-disabled': r['ink3'],
        '--color-accent': r['accent'],
        '--color-accent-muted': r['sel'],
        '--color-on-accent': r['on_accent'],
        '--color-success': r['good'],
        '--color-warning': r['warn'],
        '--color-error': r['bad'],
        '--radius-inner': '4px',
        '--radius-element': '8px',
        '--radius-container': '12px',
        '--radius-full': '9999px',
        '--bg': r['page'], '--card': r['card'], '--line': rgba(ink, round(.10 * alpha, 3)),
        '--ink': ink, '--ink2': r['ink2'], '--ink3': r['ink3'], '--accent': r['accent'], '--on-accent': r['on_accent'],
        '--track': r['track'], '--scrim': rgba('#011228' if theme == 'light' else '#111112', .4 if theme == 'light' else .6),
        '--scrollbar': rgba(ink, .28), '--good': r['good'], '--warn': r['warn'], '--bad': r['bad'],
    }
    if platform == 'win':
        return shared | {
            '--card-hover': r['card_hover'], '--card-press': r['card_press'], '--stroke': rgba(ink, .09), '--stroke-bottom': rgba(ink, .18),
            '--accent-hover': r['accent_hover'], '--accent-press': r['accent_press'],
            '--hover': rgba(ink, .05), '--press': rgba(ink, .08), '--btn': r['btn'], '--btn-hover': r['btn_hover'], '--btn-press': r['btn_press'],
            '--seg-bg': r['card'] if theme == 'light' else r['btn_hover'], '--seg-shadow': f'0 1px 2px {rgba("#000000", .08 if theme == "light" else .25)}, 0 0 0 1px {rgba(ink, .08)}',
            '--sw-stroke': rgba(ink, .45), '--sw-knob': rgba(ink, .62), '--in-bottom': rgba(ink, .35),
            '--overlay': r['overlay'], '--overlay-foot': r['foot'],
        }
    if platform == 'mac':
        return shared | {
            '--side': r['side'], '--zebra': r['zebra'], '--stroke': rgba(ink, .08), '--press': rgba(ink, .08), '--list-sel': r['sel'],
            '--btn': r['btn'], '--btn-shadow': f'0 0 0 0.5px {rgba(ink, .16)}, 0 1px 2px {rgba("#000000", .06 if theme == "light" else .28)}',
            '--seg-bg': r['card'] if theme == 'light' else r['btn_hover'],
            '--seg-shadow': f'0 0 0 0.5px {rgba(ink, .1)}, 0 1px 2px {rgba("#000000", .14 if theme == "light" else .36)}',
            '--sw-off': r['sw_off'], '--focus': rgba(r['accent'], .38), '--overlay': r['overlay'], '--menu': r['overlay'],
        }
    return shared | {
        '--card-hi': r['track'], '--outline': r['ink3'], '--sel': r['sel'], '--on-sel': r['accent'], '--fab': r['fab'], '--on-fab': r['on_accent'], '--sheet': r['overlay'],
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
