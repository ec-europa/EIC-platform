# Application initialization on blank database (to be run after install.sh)
# ---
# Synopsis  : ./init.sh {admin-password} {mode}
# Parameter : database admin password
#             mode dev or prod or test
# ---
# Preconditions
# - eXist instance running
# ---
# Launch the bootstrap deploy command to load application configuration into database
curl "http://localhost:7070/exist/projects/ccmatch/admin/deploy?t=bootstrap&pwd=$1&m=$2"
curl "http://localhost:7070/exist/projects/platform/deploy?pwd=$1"
