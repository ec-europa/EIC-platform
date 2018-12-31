# First time application module installation 
# ---
# Synopsis  : ./install.sh {admin-password}
# Parameter : database admin password
# ---
# Preconditions
# - eXist instance running
# - oppidum projects directory called projects
# - be sure ../../../../client.properties points to the running instance (port number, etc.)
# - oppidum and platform cloned in projects directory
cd ../../oppidum/scripts
./bootstrap.sh $1
cd ../../ccmatch/scripts
./bootstrap.sh $1
cd ../../platform/scripts
../../platform/scripts/bootstrap.sh $1
