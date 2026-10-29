#!/usr/bin/env bash
# Real-flow check on a disposable macOS machine with passwordless sudo (the CI runner): serves a local shadowsocks
# node and subscription, then runs po0-e2e against the app's mihomo and the app's real data dir. The fixtures keep
# running afterwards so later steps can connect through them.
#   PO0_APP      app bundle (default: dist/po0-clash.app)
#   PO0_E2E_BIN  checker built with WITH_E2E=1 (default: dist/po0-e2e)
set -euo pipefail

app_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
app="${PO0_APP:-$app_dir/dist/po0-clash.app}"
checker="${PO0_E2E_BIN:-$app_dir/dist/po0-e2e}"
work="${RUNNER_TEMP:-$app_dir/.build}/e2e"
port=18388
sub_port=18390
password=e2e-password-123
mkdir -p "$work/node"

iface="$(route -n get default | awk '/interface:/ {print $2}')"
cat > "$work/node/config.yaml" <<EOF
log-level: info
interface-name: $iface
listeners:
  - {name: ss-in, type: shadowsocks, listen: 127.0.0.1, port: $port, cipher: aes-128-gcm, password: $password}
EOF
nohup "$app/Contents/MacOS/mihomo" -d "$work/node" -f "$work/node/config.yaml" >> "$work/node.log" 2>&1 &

node="{type: ss, server: 127.0.0.1, port: $port, cipher: aes-128-gcm, password: $password}"
cat > "$work/subscription.yaml" <<EOF
proxies:
  - {name: Tokyo 01, $(echo "$node" | tr -d '{}')}
  - {name: Tokyo 02, $(echo "$node" | tr -d '{}')}
  - {name: Singapore, $(echo "$node" | tr -d '{}')}
proxy-groups:
  - {name: Proxy, type: select, proxies: [Tokyo 01, Tokyo 02, Singapore, Auto]}
  - {name: Auto, type: url-test, proxies: [Tokyo 01, Tokyo 02, Singapore], url: 'http://www.gstatic.com/generate_204', interval: 600}
rules:
  - MATCH,Proxy
EOF
nohup python3 -c '
import http.server, sys, time
port, body = int(sys.argv[1]), open(sys.argv[2], "rb").read()
expire = int(time.time()) + 40 * 86400
class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header("Content-Type", "text/yaml; charset=utf-8")
        self.send_header("profile-title", "po0 demo")
        self.send_header("subscription-userinfo", f"upload=2147483648; download=19327352832; total=107374182400; expire={expire}")
        self.end_headers()
        self.wfile.write(body)
    def log_message(self, *args):
        pass
http.server.HTTPServer(("127.0.0.1", port), Handler).serve_forever()
' "$sub_port" "$work/subscription.yaml" > "$work/subscription.log" 2>&1 &

for _ in $(seq 50); do
  nc -z 127.0.0.1 "$port" && nc -z 127.0.0.1 "$sub_port" && break
  sleep 0.2
done

userinfo="$(printf 'aes-128-gcm:%s' "$password" | base64)"
export PO0_E2E_MIHOMO="$app/Contents/MacOS/mihomo"
export PO0_E2E_SUBSCRIPTION="http://127.0.0.1:$sub_port/demo.yaml"
export PO0_E2E_LINK="ss://$userinfo@127.0.0.1:$port#Osaka%20link"
export PO0_E2E_NODE_LOG="$work/node.log"
export PO0_E2E_DATA="$HOME/Library/Application Support/io.github.yuuukicreation.po0clash/core"

status=0
"$checker" || status=$?
echo "--- node log (last 20 lines)"
tail -n 20 "$work/node.log"
exit "$status"
