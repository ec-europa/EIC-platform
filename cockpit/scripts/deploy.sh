# Stub script to call module deploy command with a given target
DEFAULT_PORT=5050
if [[ $# -lt 2 ]] ; then
    echo "Syntax: $0 password target [PORT]"
    exit 1
fi
MODULE=cockpit
PASSWORD=$1
TARGET=$2
if [ "$3" -gt 0 >/dev/null 2>&1 ]; then
  PORT="${3}";
else
  PORT=$DEFAULT_PORT
fi
curl "http://localhost:${PORT}/exist/projects/${MODULE}/admin/deploy?t=${TARGET}&pwd=${PASSWORD}"
