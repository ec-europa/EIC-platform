# Synopsis  : ./install.sh {password}
# Parameter : database admin password
# ---
# Preconditions
# - eXist instance running
# - depot cloned to your projects folder (see README.txt)
# ---
if [[ $# -lt 1 ]] ; then
    echo "Syntax: $0 password"
    exit 1
fi
cd ../../oppidum/scripts
./bootstrap.sh $1
cd ../../cockpit/scripts
./bootstrap.sh $1
cd ../../platform/scripts
./bootstrap.sh $1
echo
echo "oppidum, cockpit and platform installation complete"
echo
echo "===> To finish the installation run : init.sh {password} {mode} to start with an empty database"
echo "===>                         or run : restore.sh {password} {mode} after the restoration of a production database backup"
echo
