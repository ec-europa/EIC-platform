# Application reinstallation after a branch modification
# ---
# Synopsis  : ./switch.sh {admin-password} {mode}
# Parameter : database admin password
#             dev or prod or test mode
# ---
# Preconditions
# - eXist instance running
# ---
# Launch the switch deploy command to synch database with application configuration on file system
curl "http://localhost:7070/exist/projects/ccmatch/admin/deploy?t=switch&pwd=$1&m=$2"
curl "http://localhost:7070/exist/projects/platform/deploy?pwd=$1"
