# Synopsis  : sudo post-update.sh PATH_TO_STATIC_RESOURCES
# Example   : sudo post-update.sh ../resources
# ---
# Preconditions
# - none
# ---
# Touch all static resources to be sure NGINX will invalidate its internal cache
# (otherwise we had some experience where it didn't update its Last-Modified date and returned a 304)
find $1  -name '*'  -type f -exec touch \{} \;