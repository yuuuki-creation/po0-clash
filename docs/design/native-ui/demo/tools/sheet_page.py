import sys
from pathlib import Path

out, cols, *images = sys.argv[1:]
cells = ''.join(f'<img src="{name}">' for name in images)
Path(out).write_text(f'''<!doctype html>
<meta charset="utf-8">
<title>po0-clash overview</title>
<style>
body {{ margin: 0; background: #d4d4d6; }}
main {{ display: grid; grid-template-columns: repeat({cols}, max-content); align-items: start; gap: 32px; width: max-content; padding: 32px; }}
img {{ display: block; border-radius: 10px; box-shadow: 0 6px 24px rgba(0, 0, 0, 0.25); }}
</style>
<main>{cells}</main>
''', encoding='utf-8')
