#!/bin/bash
# Добавить один или несколько RU-доменов в ru-extras.json и запушить в оба remote.
#
# Использование:
#   ./add-domain.sh habr.com vc.ru rb.ru       — добавит как domain_suffix (default)
#   ./add-domain.sh -e habr.com                — exact (только habr.com, не *.habr.com)
#   ./add-domain.sh -s habr.com vc.ru          — explicit suffix
#
# После push — sing-box на всех клиентах подхватит за ≤1 час (update_interval=1h).
# Force-update на устройстве: sudo systemctl restart sing-box

set -euo pipefail
cd "$(dirname "$0")"

MODE="suffix"
DOMAINS=()
for arg in "$@"; do
    case "$arg" in
        -s|--suffix) MODE="suffix" ;;
        -e|--exact)  MODE="exact" ;;
        -h|--help) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        -*) echo "unknown flag: $arg" >&2; exit 2 ;;
        *) DOMAINS+=("$arg") ;;
    esac
done

if [ ${#DOMAINS[@]} -eq 0 ]; then
    echo "Usage: $0 [-s|-e] <domain> [...]"
    echo "  -s (default): добавить как domain_suffix"
    echo "  -e:           добавить как exact domain"
    exit 2
fi

# Передаём в Python через env JSON, без shell-interpolation в heredoc
DOMAINS_JSON=$(printf '%s\n' "${DOMAINS[@]}" | python3 -c 'import json,sys; print(json.dumps([l.strip() for l in sys.stdin if l.strip()]))')
export DOMAINS_JSON MODE

python3 <<'PY'
import json, os, sys
domains = json.loads(os.environ["DOMAINS_JSON"])
mode = os.environ["MODE"]
field = "domain_suffix" if mode == "suffix" else "domain"

with open("ru-extras.json") as f: cfg = json.load(f)

# Найти rule с этим полем; иначе использовать первый rule; иначе создать
rule = None
for r in cfg["rules"]:
    if field in r:
        rule = r; break
if rule is None and cfg["rules"]:
    rule = cfg["rules"][0]
if rule is None:
    rule = {}
    cfg["rules"].append(rule)
rule.setdefault(field, [])

added = []
for d in domains:
    if d not in rule[field]:
        rule[field].append(d)
        added.append(d)
rule[field].sort()

if not added:
    print("  все домены уже в списке, изменений нет")
    sys.exit(0)

with open("ru-extras.json", "w") as f:
    json.dump(cfg, f, indent=2, ensure_ascii=False)
    f.write("\n")

print(f"  + {field}: {', '.join(added)}")
PY

# Если файл не изменился (already-in-list) — выход
if git diff --quiet ru-extras.json; then
    exit 0
fi

DOMS_STR="${DOMAINS[*]}"
echo
git add ru-extras.json
git commit -m "Add ($MODE): $DOMS_STR"
git push github main
git push origin main

echo
echo "✓ Push прошёл. Sing-box подхватит обновление за ≤1 час."
echo "  Force-update на устройстве: sudo systemctl restart sing-box"
