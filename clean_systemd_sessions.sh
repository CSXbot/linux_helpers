#!/bin/bash

# Clean session collected due to a bug in systemd/dbus:
# https://github.com/systemd/systemd/issues/1961

echo $(date +"%Y-%m-%d %T") "Start"

SESSIONS_LIST_FILENAME=$(mktemp -t `basename ${0}`.XXXXXXXXXX.tmp)
if [ -f $FILE ]; then
	cat /dev/null > $SESSIONS_LIST_FILENAME
else
	echo $(date +"%Y-%m-%d %T") "Can't find file for SESSIONS"
	exit 1
fi

echo $(date +"%Y-%m-%d %T") "Collecting sessions lists"
SESSION_FILES=$(find /run/systemd/system -maxdepth 1 -name "session*.scope*")
SESSION_FILES_COUNT=$(echo "${SESSION_FILES}" | wc -l)
SESSIONS_LIST=$(/usr/bin/systemctl | grep -P '^session-.*?\.scope' | awk '{print $1}')
SESSIONS_COUNT=$(echo "${SESSIONS_LIST}" | wc -l)

echo $(date +"%Y-%m-%d %T") "Total session files: ${SESSION_FILES_COUNT}"
echo $(date +"%Y-%m-%d %T") "Total sessions: ${SESSIONS_COUNT}"

# Stashing statistics to show it at the end
SESSION_FILES_COUNT_START="$SESSION_FILES_COUNT"
SESSIONS_COUNT_START="$SESSIONS_COUNT"

echo $(date +"%Y-%m-%d %T") "Starting to stop unused sessions"
SESSIONS_COUNTER=1
for SESSION in $(echo "${SESSIONS_LIST}"); do
	COUNTER_TEXT="[${SESSIONS_COUNTER}/${SESSIONS_COUNT}]"
	SESSION_STATUS=$(/usr/bin/systemctl status ${SESSION})
	echo "${SESSION_STATUS}" | grep -q CGroup
	RESULT=$?
	if [ $RESULT -ne 0 ]; then
		# Get all sessions and check that nothing is running under them.
		# If something is it will be shown in CGroup field.
		# If nothing is running -- KILL IT WITH IRON AND FIRE!
		/usr/bin/systemctl stop ${SESSION} && echo $(date +"%Y-%m-%d %T") "${COUNTER_TEXT} Stopped ${SESSION}"
	else
		echo $(date +"%Y-%m-%d %T") "${COUNTER_TEXT} Session ${SESSION} has folloing process(es) running:"
		echo "${SESSION_STATUS}" | grep '├─' | sed -r 's/^\s+├─\s*[0-9]+\s+/\t/g' | sort | uniq
	fi
	((SESSIONS_COUNTER++))
done

echo $(date +"%Y-%m-%d %T") "Updating sessions lists"
SESSIONS_LIST=$(/usr/bin/systemctl | grep -P '^session-.*?\.scope' | awk '{print $1}')
SESSIONS_COUNT=$(echo "${SESSIONS_LIST}" | wc -l)
SESSION_FILES=$(find /run/systemd/system -maxdepth 1 -name "session*.scope*")
SESSION_FILES_COUNT=$(echo "${SESSION_FILES}" | wc -l)

echo "${SESSIONS_LIST}" >> $SESSIONS_LIST_FILENAME
echo $(date +"%Y-%m-%d %T") "Collected ${SESSIONS_COUNT} sessions to ${SESSIONS_LIST_FILENAME}"

echo $(date +"%Y-%m-%d %T") "Starting to delete stale session files"
SESSION_FILES_COUNTER=1
for SESSION_FILE in $(echo "${SESSION_FILES}"); do
	COUNTER_TEXT="[${SESSION_FILES_COUNTER}/${SESSION_FILES_COUNT}]"
	# Using list of sessions we collected to filter out files the system may still need
	SESSION_FILE_NAME=$(basename ${SESSION_FILE} | cut -d. -f1-2)
	grep -q "${SESSION_FILE_NAME}" $SESSIONS_LIST_FILENAME
	RESULT=$?
	if [ $RESULT -ne 0 ]; then
		rm -r ${SESSION_FILE} && echo $(date +"%Y-%m-%d %T") "${COUNTER_TEXT} Removed stale file ${SESSION_FILE}"
	else
		echo $(date +"%Y-%m-%d %T") "${COUNTER_TEXT} ${SESSION_FILE} is used by a session"
	fi
	((SESSION_FILES_COUNTER++))
done

rm $SESSIONS_LIST_FILENAME

echo $(date +"%Y-%m-%d %T") "Updating sessions lists for final statistics"
SESSION_FILES=$(find /run/systemd/system -maxdepth 1 -name "session*.scope*")
SESSION_FILES_COUNT=$(echo "${SESSION_FILES}" | wc -l)
SESSIONS_LIST=$(/usr/bin/systemctl)
SESSIONS_COUNT=$(echo "${SESSIONS_LIST}" | grep -Pc '^session-.*?\.scope')

SESSION_FILES_DELETED=$(expr $SESSION_FILES_COUNT_START - $SESSION_FILES_COUNT)
SESSIONS_DELETED=$(expr $SESSIONS_COUNT_START - $SESSIONS_COUNT)

echo $(date +"%Y-%m-%d %T") "Total session files: ${SESSION_FILES_COUNT} (${SESSION_FILES_DELETED} deleted)"
echo $(date +"%Y-%m-%d %T") "Total sessions: ${SESSIONS_COUNT} (${SESSIONS_DELETED} deleted)"
echo $(date +"%Y-%m-%d %T") "Finished"
