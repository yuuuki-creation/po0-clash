import json
from pathlib import Path
import re
import subprocess
import time
import xml.etree.ElementTree as ET

out = Path('reference-android')
out.mkdir(exist_ok=True)

def adb(*args, **kwargs):
    return subprocess.run(['adb', *args], check=True, capture_output=True, **kwargs).stdout

def snapshot(name):
    adb('shell', 'uiautomator', 'dump', '/sdcard/window.xml')
    raw = adb('shell', 'cat', '/sdcard/window.xml')
    (out / f'{name}.xml').write_bytes(raw)
    (out / f'{name}.png').write_bytes(adb('exec-out', 'screencap', '-p'))
    return ET.fromstring(raw)

def find(root, label):
    candidates = [node for node in root.iter('node') if node.get('text') == label or node.get('content-desc', '').split('\n')[0] == label]
    if not candidates:
        raise ValueError(f'Cannot find {label}')
    bounds = [list(map(int, re.findall(r'\d+', node.get('bounds')))) for node in candidates]
    x1, y1, x2, y2 = max(bounds, key=lambda bounds: bounds[1])
    return (x1 + x2) // 2, (y1 + y2) // 2

def tap(point):
    adb('shell', 'input', 'tap', *map(str, point))

def record(name, commands):
    recording = subprocess.Popen(['adb', 'shell', 'screenrecord', '--bit-rate', '12000000', '--time-limit', '20', f'/sdcard/{name}.mp4'])
    time.sleep(1)
    started = time.monotonic()
    adb('shell', '; '.join(commands))
    elapsed = time.monotonic() - started
    time.sleep(1)
    adb('shell', 'pkill', '-INT', 'screenrecord')
    recording.wait(timeout=10)
    adb('pull', f'/sdcard/{name}.mp4', str(out / f'{name}.mp4'))
    (out / f'{name}-input.json').write_text(json.dumps({'commands': commands, 'elapsed': elapsed}, indent=2))

config = {'appSettingProps': {'locale': 'en', 'acceptedDisclaimerVersion': 1, 'autoCheckUpdate': False}, 'themeProps': {'themeMode': 'light'}}
preferences = ET.Element('map')
ET.SubElement(preferences, 'string', name='flutter.config').text = json.dumps(config)
fixture = out / 'FlutterSharedPreferences.xml'
fixture.write_bytes(ET.tostring(preferences))
adb('shell', 'mkdir', '-p', '/data/data/com.follow.clash/shared_prefs')
adb('push', str(fixture), '/data/data/com.follow.clash/shared_prefs/FlutterSharedPreferences.xml')
adb('shell', 'chmod', '777', '/data/data/com.follow.clash/shared_prefs')
adb('shell', 'chmod', '666', '/data/data/com.follow.clash/shared_prefs/FlutterSharedPreferences.xml')

for name, package in [('flclash', 'com.follow.clash'), ('po0', 'io.github.yuuukicreation.po0clash')]:
    adb('shell', 'am', 'force-stop', package)
    adb('shell', 'am', 'start', '-W', '-n', f'{package}/.MainActivity')
    time.sleep(8)
    home = snapshot(f'{name}-home')
    for attempt in range(3):
        if not any("isn't responding" in node.get('text', '') for node in home.iter('node')):
            break
        tap(find(home, 'Close app'))
        adb('shell', 'am', 'start', '-W', '-n', f'{package}/.MainActivity')
        time.sleep(5)
        home = snapshot(f'{name}-home-retry-{attempt}')
    labels = sorted({n.get('text') or n.get('content-desc') for n in home.iter('node') if n.get('text') or n.get('content-desc')})
    print(name, 'home labels:', json.dumps(labels), flush=True)
    dashboard = find(home, 'Dashboard')
    profiles = find(home, 'Profiles')
    tools = find(home, 'Tools')
    def command(point): return f'input tap {point[0]} {point[1]}'
    record(f'{name}-tabs', [command(profiles), 'sleep 1', command(tools), 'sleep 1', command(dashboard), 'sleep 1', command(profiles), 'sleep 0.06', command(tools), 'sleep 0.06', command(dashboard), 'sleep 1'])
    snapshot(f'{name}-tabs-final')
    tap(tools)
    time.sleep(1)
    settings = snapshot(f'{name}-tools')
    labels = sorted({n.get('text') or n.get('content-desc') for n in settings.iter('node') if n.get('text') or n.get('content-desc')})
    print(name, 'tools labels:', json.dumps(labels), flush=True)
    entry = find(settings, 'General' if name == 'flclash' else 'Application')
    record(f'{name}-push', [command(entry), 'sleep 1', 'input keyevent 4', 'sleep 1', command(entry), 'sleep 0.08', 'input keyevent 4', 'sleep 1'])
    tap(entry)
    time.sleep(1)
    options = snapshot(f'{name}-general')
    switches = [node for node in options.iter('node') if node.get('checkable') == 'true' and node.get('enabled') == 'true']
    if not switches:
        raise ValueError(f'{name}: no enabled switch in settings')
    node = switches[0]
    x1, y1, x2, y2 = map(int, re.findall(r'\d+', node.get('bounds')))
    point = ((x1 + x2) // 2, (y1 + y2) // 2)
    (out / f'{name}-switch-bounds.json').write_text(json.dumps(node.attrib))
    record(f'{name}-switch', [command(point), 'sleep 1', command(point), 'sleep 1', command(point), 'sleep 0.06', command(point), 'sleep 0.06', command(point), 'sleep 1'])
    snapshot(f'{name}-switch-final')
    adb('shell', 'am', 'force-stop', package)
