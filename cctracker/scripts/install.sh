# Synopsis  : ./install.sh {admin-password}
# Parameter : database admin password
# ---
# Preconditions
# - eXist instance running
# - oppidum projects directory called projects
# - edit ../../../../client.properties to point to the running instance (port number, etc.)
# - you have cloned oppidum and platform
PORT='8080'
cd ../../oppidum/scripts
./bootstrap.sh $1
cd ../../cctracker/scripts
./bootstrap.sh $1
curl "http://localhost:$PORT/exist/projects/cctracker/admin/deploy?t=all&pwd=$1"
cd ../../platform/scripts
../../platform/scripts/bootstrap.sh $1
curl "http://localhost:$PORT/exist/projects/platform/deploy?pwd=$1"
cd ../../cctracker/scripts
