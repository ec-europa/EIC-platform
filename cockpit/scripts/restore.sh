# Application reinstallation after a database restoration
# ---
# Synopsis  : ./restore.sh {admin-password} {mode} [PORT]
# Parameter : database admin password
#             dev or prod or test mode
# ---
# Preconditions
# - eXist instance running
# ---
# Launch the restore deploy command to synch database with application configuration on file system
if [[ $# -lt 2 ]] ; then
    echo "Syntax: $0 password (dev|test|prod) [PORT]"
    exit 1
fi
./support/deploy.sh $1 $2 cockpit restore $3
