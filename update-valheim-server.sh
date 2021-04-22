#!/usr/bin/env bash
# Provides functions to update to a newer Valheim server automatically

# Keep track of where echo statements come from
export VALHEIM_UPDATE_PREFIX="ValheimAutoUpdate"
# This is where the app manifest is that stores the build ID of the local Valheim server
export VALHEIM_SERVER_APP_MANIFEST="$VALHEIM_SERVER_DIR/steamapps/appmanifest_896660.acf"
# This is where the local/current build ID is stored
export VALHEIM_SERVER_LOCAL_BUILD_ID=""
# This is what Steam reports is the latest build ID
export VALHEIM_SERVER_REMOTE_BUILD_ID=""
# Steam caches all app infos (contain build IDs); need to delete this file to get latest remote build IDs
export STEAM_CACHED_APP_INFO="$STEAM_DIR/appcache/appinfo.vdf"
# The PID of the loop that periodically checks whether to update the Valheim server
export VALHEIM_SERVER_UPDATE_LOOP_PID=""

function findAndSetLocalValheimServerBuildId(){
    # Finds the buildId from the Valheim server's local app manifest
    # Check if there was a previous local build ID so we can see if anything changed
    local previousLocalBuildId=""
    if [[ ! -z "${VALHEIM_SERVER_LOCAL_BUILD_ID}" ]]
    then
        local previousLocalBuildId=$VALHEIM_SERVER_LOCAL_BUILD_ID
    fi

    VALHEIM_SERVER_LOCAL_BUILD_ID=$(cat ${VALHEIM_SERVER_APP_MANIFEST} | pcregrep -o1 -M '"buildid".*"([0-9]+)"')

    if [[ ! -z "${previousLocalBuildId}" ]] && [[ ${previousLocalBuildId} != ${VALHEIM_SERVER_LOCAL_BUILD_ID} ]]
    then
        echo "$VALHEIM_UPDATE_PREFIX: The local build ID was updated from $previousLocalBuildId to $VALHEIM_SERVER_LOCAL_BUILD_ID"
    else
        echo "$VALHEIM_UPDATE_PREFIX: The local build ID is $VALHEIM_SERVER_LOCAL_BUILD_ID"
    fi
}

function findAndSetRemoteValheimServerBuildId(){
    # Finds the latest build ID from Steam
    # Delete the cached app info so the latest build ID is fetched from Steam
    if [[ -f "${STEAM_CACHED_APP_INFO}" ]]
    then
        echo "$VALHEIM_UPDATE_PREFIX: Deleting cached app info: $STEAM_CACHED_APP_INFO"
        rm $STEAM_CACHED_APP_INFO
    fi

    # First update the app info get the latest build IDs from the Steam remote
    # "tee /dev/tty" allows for printing the output while also storing it in the local variable
    echo "$VALHEIM_UPDATE_PREFIX: Querying the remote server for the latest build ID for the Valheim server"
    local appInfo=$(/bin/bash $STEAMCMD_DIR/steamcmd.sh +login anonymous +app_info_update 1 +app_info_print 896660 +quit | tee)
    # Use a regex that looks for the build ID under the public branch:
    #                    "branches"
    #                {
    #                        "public"
    #                        {
    #                                "buildid"               "6437354"
    #
    # TODO: use a VDF parser, as the regex will easily break if the line order changes
    VALHEIM_SERVER_REMOTE_BUILD_ID=$(echo "$appInfo" | pcregrep -o1 -M '"branches".*\n*.*{\n*.*"public".*\n*.*{.*\n*.*"buildid".*"([0-9]+)"')

    echo "$VALHEIM_UPDATE_PREFIX: The remote server build ID is $VALHEIM_SERVER_REMOTE_BUILD_ID"
}

function assertLocalBuildIsLatest(){
    if [[ ${VALHEIM_SERVER_LOCAL_BUILD_ID} != ${VALHEIM_SERVER_REMOTE_BUILD_ID} ]]
    then
        echo "$VALHEIM_UPDATE_PREFIX: ERROR: The local build differs from the remote build after updating.  Local build ID: $VALHEIM_SERVER_LOCAL_BUILD_ID.  Remote build ID: $VALHEIM_SERVER_REMOTE_BUILD_ID"
    else
        echo "The local build ID is the same as the latest remote build ID"
    fi
}

function updateValheimServer(){
    /bin/bash $STEAMCMD_DIR/steamcmd.sh +login anonymous +force_install_dir $VALHEIM_SERVER_DIR +app_update 896660 +quit
}

function checkForAndUpdateValheimServer(){
    # Check if the Valheim server needs to be updated, and if so update it
    # Need to stop the Valheim server and then restart it afterwards
    echo "$VALHEIM_UPDATE_PREFIX: Checking to see if the Valheim server needs to be updated"
    findAndSetLocalValheimServerBuildId
    findAndSetRemoteValheimServerBuildId
    if [[ "$VALHEIM_SERVER_LOCAL_BUILD_ID" = "$VALHEIM_SERVER_REMOTE_BUILD_ID" ]]
    then
        echo "$VALHEIM_UPDATE_PREFIX: The Valheim server is already up to date with build ID $VALHEIM_SERVER_LOCAL_BUILD_ID"
    else
        echo "$VALHEIM_UPDATE_PREFIX: Updating the Valheim server from $VALHEIM_SERVER_LOCAL_BUILD_ID (old) to $VALHEIM_SERVER_REMOTE_BUILD_ID (new)"
        echo "$VALHEIM_UPDATE_PREFIX: Shutting down Valheim server"
        shutdownValheimServer
        echo "$VALHEIM_UPDATE_PREFIX: Updating the Valheim server"
        updateValheimServer
        findAndSetLocalValheimServerBuildId
        assertLocalBuildIsLatest
        echo "$VALHEIM_UPDATE_PREFIX: Starting the Valheim server"
        startValheimServer
    fi
}

function startServerAndDoCheckForUpdateLoop(){
    trap 'terminateCheckForUpdateLoop "$VALHEIM_SERVER_UPDATE_LOOP_PID"' SIGTERM
    startValheimServer
    echo "$VALHEIM_UPDATE_PREFIX: first time Valheim server PID is: $VALHEIM_SERVER_PID"
    while true
    do
        echo "$VALHEIM_UPDATE_PREFIX: Sleeping for $VALHEIM_SERVER_AUTO_UPDATE_FREQUENCY before checking for Valheim server update"
        sleep $VALHEIM_SERVER_AUTO_UPDATE_FREQUENCY &
        sleep_pid=$!
        wait $sleep_pid
        checkForAndUpdateValheimServer
    done
}

function terminateCheckForUpdateLoop(){
    echo "$VALHEIM_UPDATE_PREFIX: Shutting down Valheim server.  PID is: $VALHEIM_SERVER_PID"
    # send a SIGINT to shut down the Valheim server gracefully
    kill -2 $VALHEIM_SERVER_PID
    wait $VALHEIM_SERVER_PID
    exit 0
}

function terminateCheckForUpdateLoopOld(){
    echo "hello world"
    echo "$VALHEIM_UPDATE_PREFIX: Valheim server PID before shutdown is $VALHEIM_SERVER_PID"
    echo "$VALHEIM_UPDATE_PREFIX: arg 2 is $2"
    echo "$VALHEIM_UPDATE_PREFIX: Shutting down the check for update loop.  PID is: $1"
    # send a SIGTERM to stop the loop
    kill -15 $1
    # wait for the update process to finish
    wait $1
    echo "$VALHEIM_UPDATE_PREFIX: Finished waiting for loop to stop"
    echo "$VALHEIM_UPDATE_PREFIX: Shutting down Valheim server.  PID is: $VALHEIM_SERVER_PID"
    # send a SIGINT to shut down the Valheim server gracefully
    kill -2 $VALHEIM_SERVER_PID
    wait $VALHEIM_SERVER_PID
    exit 0
}