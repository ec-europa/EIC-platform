# Application initialization on blank database (to be run after install.sh)
# ---
# Synopsis  : ./init.sh {admin-password} {mode} [PORT]
# Parameter : database admin password
#             mode dev or prod or test
# ---
# Preconditions
# - eXist instance running
# ---
# Launch the bootstrap deploy command to load application configuration into database
if [[ $# -lt 2 ]] ; then
    echo "Syntax: $0 password (dev|test|prod) [PORT]"
    exit 1
fi
./support/deploy.sh $1 $2 cockpit bootstrap $3
