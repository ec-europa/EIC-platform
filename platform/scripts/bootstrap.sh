# Synopsis  : ./bootstrap.sh {admin-password}
# Parameter : database admin password
# ---
# Preconditions
# - eXist instance running
# - edit ../../../../client.properties to point to the running instance (port number, etc.)
# ---
# Creates /db/www/platform/config fo running platform modules post-deployment script
../../../../bin/client.sh -u admin -P $1 -m /db/www/platform/config -p ../config
