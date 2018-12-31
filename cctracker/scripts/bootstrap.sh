# Synopsis  : ./bootstrap.sh {admin-password}
# Parameter : database admin password
# ---
# Preconditions
# - eXist instance running
# - edit ../../../../client.properties to point to the running instance (port number, etc.)
# ---
# Creates initial /db/www/cctracker/config and /db/www/oppidum/mesh collections
# You should then use curl {home}/admin/deploy?t=users,policies,caches,debug,templates,forms to terminate the installation
# and then restore some application data / users from an application backup using {exist}/bin/backup.sh
../../../../bin/client.sh -u admin -P $1 -m /db/www/cctracker/mesh -p ../mesh
../../../../bin/client.sh -u admin -P $1 -m /db/www/cctracker/config -p ../config

../../../../bin/client.sh -u admin -P $1 -F bootstrap.xql