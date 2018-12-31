# Application reinstallation after a branch modification
# ---
# Synopsis  : ./switch.sh {admin-password} {mode} [port]
# Parameter : database admin password
#             dev or prod or test mode
# ---
# Preconditions
# - eXist instance running
# ---
# Launch the switch deploy command to synch database with application configuration on file system
if [[ $# -lt 2 ]] ; then
    echo "Syntax: $0 password (dev|test|prod) [PORT]"
    exit 1
fi
./support/deploy.sh $1 $2 cockpit switch $3