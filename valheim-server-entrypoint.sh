#!/usr/bin/env bash

# Provides nicely formatting logging
# See: https://github.com/idelsink/b-log
source "$STEAM_DIR/b-log/b-log.sh"
LOG_LEVEL_ALL # All log levels are visible
# The entry point script manages starting, updating, and shutting down the Valheim server
# Note the script must be executed from the same directory as all the other scripts.
source start-valheim-server.sh
source update-valheim-server.sh
source shutdown-valheim-server.sh

# server name and world name need to be defined at runtime
if [ -z "${VALHEIM_SERVER_NAME}" ]
then
    FATAL "Please set the VALHEIM_SERVER_NAME property.  E.g. use --env VALHEIM_SERVER_NAME=\"My Server Name\""
    exit 1
fi

if [ -z "${VALHEIM_WORLD_NAME}" ]
then
    FATAL "Please set the VALHEIM_WORLD_NAME property.  E.g. use --env VALHEIM_WORLD_NAME=\"AWholeNewWorld\""
    exit 1
fi

if [ "${VALHEIM_SERVER_UPDATE_ON_START_UP}" = 1 ]
then
    INFO "Attempting one time update of the Valheim server on start up"
    updateValheimServerIfNewerBuildExists
fi

function terminateUpdateLoop(){
    INFO "Terminating the update loop.  PID is $VALHEIM_SERVER_UPDATE_LOOP_PID"
    # -15 is equivalent to SIGTERM
    kill -15 $VALHEIM_SERVER_UPDATE_LOOP_PID
    wait $VALHEIM_SERVER_UPDATE_LOOP_PID
    exit 0;
}

if [ "${VALHEIM_SERVER_AUTO_UPDATE}" = 0 ]
then
    # Handle starting and shutting down server normally if no auto update
    # catch Docker's SIGTERM, then send a SIGINT to the Valheim server process
    trap 'shutdownValheimServerAndExit' SIGTERM

    startValheimServer

    # since the server is run in the background, this is needed to keep the main process from exiting
    while wait $VALHEIM_SERVER_PID; [ $? != 0 ]; do true; done
else
    WARN "Experimental auto update is enabled.  The server will automatically update and restart when a new version is detected"
    INFO "Updates to the server will be checked every $VALHEIM_SERVER_AUTO_UPDATE_FREQUENCY"

    trap 'terminateUpdateLoop' SIGTERM
    startServerAndUpdateLoop &
    VALHEIM_SERVER_UPDATE_LOOP_PID=$!
    INFO "Valheim server update loop PID is: $VALHEIM_SERVER_UPDATE_LOOP_PID"
    while wait $VALHEIM_SERVER_UPDATE_LOOP_PID; [[ "${VALHEIM_SERVER_UPDATE_LOOP_PID}" != 0 ]]; do true; done
fi