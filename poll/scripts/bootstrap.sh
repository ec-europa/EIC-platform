# Synopsis  : ./bootstrap.sh {admin-password}
# Parameter : database admin password
# ---
# Preconditions
# - eXist instance running
# - edit ../../../../client.properties to point to the running instance (port number, etc.)
# ---
# Creates and loads /db/www/poll/config and /db/www/poll/mesh collections
../../../../bin/client.sh -u admin -P $1 -m /db/www/poll/mesh -p ../mesh
../../../../bin/client.sh -u admin -P $1 -m /db/www/poll/config -p ../config
echo -ne 'quit\n' | ../../../../bin/client.sh -u admin -P $1 -m /db/sites/poll/questionnaires -s
echo -ne 'quit\n' | ../../../../bin/client.sh -u admin -P $1 -m /db/sites/poll/forms -s

# give writing rights to guest to create sub-collection into /db/sites/poll/forms
echo "declare namespace xdb = \"http://exist-db.org/xquery/xmldb\";
let \$uri := '/db/sites/poll/forms'
return if (xdb:collection-available(\$uri)) then
	xdb:set-collection-permissions(\$uri,'guest','admin', util:base-to-integer(0774, 8)) else ()" > _tmp.xql
../../../../bin/client.sh -u admin -P $1 -F _tmp.xql
rm _tmp.xql
