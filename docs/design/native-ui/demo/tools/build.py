import json
import re
import shutil
from pathlib import Path

base = Path(__file__).resolve().parents[1]
src = base / 'src'
out = base / 'build' / 'project'
FONTS = {
    'and': 'family=Noto+Sans+SC:wght@400;500;600&amp;family=Roboto:wght@400;500&amp;display=swap',
    'desktop': 'family=Noto+Sans+SC:wght@400;500;600&amp;display=swap',
}


def page(title, body, script, preview, platform, props=True):
    font = FONTS['and' if platform == 'and' else 'desktop']
    data = {'$preview': {'width': preview[0], 'height': preview[1]}}
    if props:
        data = {'theme': {'editor': 'enum', 'options': ['light', 'dark'], 'default': 'light'}, 'palette': {'editor': 'enum', 'options': ['a', 'b', 'c'], 'default': 'b'}, **data}
    return f'''<!doctype html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<title>{title}</title>
<script src="./support.js"></script>
<link rel="stylesheet" href="./po0.css">
</head>
<body>
<x-dc>
<helmet>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?{font}">
<style>body{{margin:0}}</style>
</helmet>
{body}
</x-dc>
<script type="text/x-dc" data-dc-script data-props='{json.dumps(data)}'>
{script}
</script>
</body>
</html>
'''


def expand(text, platform):
    def include(m):
        return (src / m.group(1)).read_text(encoding='utf-8')

    text = re.sub(r'<!--include (\S+)-->', include, text)

    def cond(m):
        return m.group(2) if platform in m.group(1).split(',') else ''

    innermost = r'<!--if ([\w,]+)-->((?:(?!<!--if ).)*?)<!--endif-->'
    while re.search(innermost, text, flags=re.S):
        text = re.sub(innermost, cond, text, flags=re.S)
    return text


def wrapper(title, target, theme, preview, platform, palette=None):
    attr = (f' theme="{theme}"' if theme else '') + (f' palette="{palette}"' if palette else '')
    body = f'<dc-import name="{target}"{attr} hint-size="{preview[0]}px,{preview[1]}px"></dc-import>'
    script = 'class Component extends DCLogic {\n  renderVals() {\n    return {};\n  }\n}'
    return page(title, body, script, preview, platform, props=False)


logic = (src / 'logic.js').read_text(encoding='utf-8')
files = {}
apps = [('win', 'Main', 'Windows', (1240, 780)), ('mac', 'macOS', 'macOS', (1240, 780)), ('and', 'Android', 'Android', (390, 844))]
for platform, name, label, preview in apps:
    body = expand((src / f'{platform}.html').read_text(encoding='utf-8'), platform)
    files[f'{name}.dc.html'] = page(f'po0-clash {label}', body, logic.replace('__PLATFORM__', platform), preview, platform)
    files[f'{label}-Dark.dc.html'] = wrapper(f'po0-clash {label} 深色', name, 'dark', preview, platform)

sizes = [('Windows-Compact', 'Main', 'win', (860, 620)), ('Windows-Min', 'Main', 'win', (720, 560)), ('macOS-Narrow', 'macOS', 'mac', (700, 540)), ('Android-Medium', 'Android', 'and', (760, 900)), ('Android-Expanded', 'Android', 'and', (1040, 700))]
for name, target, platform, preview in sizes:
    files[f'{name}.dc.html'] = wrapper(f'po0-clash {name}', target, None, preview, platform)

for palette in 'abc':
    for target, label, platform, preview in [('Main', 'Windows', 'win', (1240, 780)), ('macOS', 'macOS', 'mac', (1240, 780)), ('Android', 'Android', 'and', (390, 844))]:
        files[f'Palette-{palette}-{label}.dc.html'] = wrapper(f'配色 {palette} {label}', target, None, preview, platform, palette)

for platform, label, preview in [('win', 'Windows', (1000, 1790)), ('mac', 'macOS', (1000, 1560)), ('and', 'Android', (420, 2090))]:
    body = expand((src / 'sheet.html').read_text(encoding='utf-8'), platform).replace('__PLATFORM__', platform)
    script = (src / 'sheet.js').read_text(encoding='utf-8').replace('__PLATFORM__', platform)
    name = f'Sheet-{label}'
    files[f'{name}.dc.html'] = page(f'{label} 组件', body, script, preview, platform)
    files[f'{name}-Dark.dc.html'] = wrapper(f'{label} 组件 深色', name, 'dark', preview, platform)

out.mkdir(parents=True, exist_ok=True)
for path in out.glob('*.dc.html'):
    if path.name not in files:
        path.unlink()
for name, text in files.items():
    (out / name).write_text(text, encoding='utf-8', newline='\n')
(out / 'po0.css').write_text((src / 'po0.css').read_text(encoding='utf-8') + '\n' + (src / 'colors.css').read_text(encoding='utf-8'), encoding='utf-8', newline='\n')
shutil.copyfile(src / 'canvas.json', out / 'canvas.json')
print(f'{len(files)} artboards in {out}')
