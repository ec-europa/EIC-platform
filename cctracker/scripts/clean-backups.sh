#! /bin/sh
# Usage : ./clean-backups.sh /path/to/backups
MAX_DAYS=10
BACKUPS_DIR="$1"
# OS X
# DATE_LIMIT=`date -v -"$MAX_DAYS"d "+%Y%m%d-%H%M"`
# Debian
DATE_LIMIT=`date +"%Y%m%d-%H%M" -d "$MAX_DAYS days ago"`
echo "At `date +"%H:%M on %Y-%m-%d"` removing backups anteriors to $DATE_LIMIT"
FULL="`ls -1 "$BACKUPS_DIR"/full*`"
for F in $FULL; do
  if [ $(expr ${F#$BACKUPS_DIR/full} \< "$DATE_LIMIT.zip") -eq 1 ]
  then
    echo "deleting $F"
  fi
done
INC="`ls -1 "$BACKUPS_DIR"/inc*`"
for F in $INC; do
  if [ $(expr ${F#$BACKUPS_DIR/inc} \< "$DATE_LIMIT.zip") -eq 1 ]
  then
    echo "deleting $F"
  fi
done

