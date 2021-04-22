#!/usr/bin/env bash

# The entry point script manages starting, updating, and shutting down the Valheim server
# Note the script must be executed from the same directory as all the other scripts.
source start-valheim-server.sh
source update-valheim-server.sh
source shutdown-valheim-server.sh

# server name and world name need to be defined at runtime
if [ -z "${VALHEIM_SERVER_NAME}" ]
then
    echo "Please set the VALHEIM_SERVER_NAME property.  E.g. use --env VALHEIM_SERVER_NAME=\"My Server Name\""
    exit 1
fi

if [ -z "${VALHEIM_WORLD_NAME}" ]
then
    echo "Please set the VALHEIM_WORLD_NAME property.  E.g. use --env VALHEIM_WORLD_NAME=\"AWholeNewWorld\""
    exit 1
fi

findAndSetLocalValheimServerBuildId
echo "Valheim Server build ID is $VALHEIM_SERVER_LOCAL_BUILD_ID"

function foof(){
    echo "inside foof. Killing $VALHEIM_SERVER_UPDATE_LOOP_PID"
    kill -15 $VALHEIM_SERVER_UPDATE_LOOP_PID
    wait $VALHEIM_SERVER_UPDATE_LOOP_PID
    exit 0;
}

if [ "${VALHEIM_SERVER_AUTO_UPDATE}" = 0 ]
then
    # Handle starting and shutting down server normally if no auto update
    # catch Docker's SIGTERM, then send a SIGINT to the Valheim server process
    trap 'shutdownValheimServerAndExit "$VALHEIM_SERVER_PID"' SIGTERM

    startValheimServer

    # since the server is run in the background, this is needed to keep the main process from exiting
    while wait $VALHEIM_SERVER_PID; [ $? != 0 ]; do true; done
else
    echo "WARNING: Experimental auto update is enabled.  The server will automatically update and restart when a new version is detected"
    echo "Updates will be checked for every $VALHEIM_SERVER_AUTO_UPDATE_FREQUENCY"

#    trap 'terminateCheckForUpdateLoop "$VALHEIM_SERVER_UPDATE_LOOP_PID" "$VALHEIM_SERVER_PID"' SIGTERM
    trap 'foof' SIGTERM
    startServerAndDoCheckForUpdateLoop &
    VALHEIM_SERVER_UPDATE_LOOP_PID=$!
    echo "Valheim server update loop PID is: $VALHEIM_SERVER_UPDATE_LOOP_PID"
    while wait $VALHEIM_SERVER_UPDATE_LOOP_PID; [[ "${VALHEIM_SERVER_UPDATE_LOOP_PID}" != 0 ]]; do true; done
fi