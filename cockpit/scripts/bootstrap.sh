# NOTE : script not called directly, usually called from init.sh
# ---
# Synopsis  : ./bootstrap.sh {password}
# Parameter : database admin password
# ---
# Preconditions
# - eXist instance running
# - edit ../../../../client.properties to point to the running instance (port number, etc.)
# ---
# Creates initial /db/www//cockpit/config and /db/www//cockpit/mesh collections
# You should then use curl {home}/admin/deploy?t=[targets] to terminate the installation
# and then restore some application data / users from an application backup using {exist}/bin/backup.sh
if [[ $# -lt 1 ]] ; then
    echo "Syntax: $0 password"
    exit 1
fi
../../../../bin/client.sh -u admin -P $1 -m /db/www/cockpit/mesh --parse ../mesh -s
../../../../bin/client.sh -u admin -P $1 -m /db/www/cockpit/config --parse ../config -s
../../../../bin/client.sh -u admin -P $1 -F support/bootstrap.xql
