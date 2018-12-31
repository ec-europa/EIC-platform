# Helper script
# ---
# Don't call it directly but call (init|restore|switch).sh instead

DEFAULT_PORT=5050

if [[ $# -lt 4 ]] ; then
    echo "Syntax: $0 password (dev|test|prod) module target [PORT]"
    exit 1
fi
PASSWORD=$1
MODE=$2
MODULE=$3
TARGET=$4
if [ "$5" -gt 0 >/dev/null 2>&1 ]; then
  PORT="${5}";
else
  PORT=$DEFAULT_PORT
fi
curl "http://localhost:${PORT}/exist/projects/${MODULE}/admin/deploy?t=${TARGET}&pwd=${PASSWORD}&m=${MODE}"
curl "http://localhost:${PORT}/exist/projects/platform/deploy?pwd=${PASSWORD}"
