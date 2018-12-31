# Synopsis  : ./bootstrap.sh {admin-password}
# Parameter : database admin password
# ---
# Preconditions
# - eXist instance running (version 2.2 or superior)
# - edit ../../../../client.properties to point to the running instance (port number, etc.)
# ---
# Create initial collections to deploy
# Create users group (this must be done before restoring a DB)
# You MUST use curl {home}/admin/deploy?t=bootstrap&pwd=[PASSWORD] to terminate the installation
../../../../bin/client.sh -u admin -P $1 -m /db/www/ccmatch/mesh -p ../mesh -s
../../../../bin/client.sh -u admin -P $1 -m /db/www/ccmatch/config -p ../config -s
../../../../bin/client.sh -u admin -P $1 -F bootstrap.xql
echo
echo "===> To finish the installation run : init.sh {password} {mode}"
echo
