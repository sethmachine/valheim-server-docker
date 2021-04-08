#!/usr/bin/env bash
# Provides functions to check if there is a newer Valheim server available

# This is where the app manifest is that stores the build ID of the Valheim server
VALHEIM_SERVER_APP_MANIFEST="$VALHEIM_SERVER_DIR/steamapps/appmanifest_896660.acf"
# This is where the local/current build ID is stored
VALHEIM_SERVER_LOCAL_BUILD_ID=""
# This is what Steam reports is the latest build ID
VALHEIM_SERVER_REMOTE_BUILD_ID=""
# Steam caches all app infos (contain build IDs); need to delete this file to get latest remote build IDs
STEAM_CACHED_APP_INFO="$STEAM_DIR/appcache/appinfo.vdf"

function findAndSetLocalValheimServerBuildId(){
    # Finds the buildId from the Valheim server's local app manifest
    # Check if there was a previous local build ID so we can see if anything changed
    local previousLocalBuildId=""
    if [[ ! -z "${VALHEIM_SERVER_LOCAL_BUILD_ID}" ]]
    then
        local previousLocalBuildId=$VALHEIM_SERVER_LOCAL_BUILD_ID
    fi
     VALHEIM_SERVER_LOCAL_BUILD_ID = $(${VALHEIM_SERVER_APP_MANIFEST} | grep "buildid" | sed 's/^.*"\([0-9][0-9]*\)".*$/\1/g')
     if [[ -z "${previousLocalBuildId}" ]] && [[ previousLocalBuildId != VALHEIM_SERVER_LOCAL_BUILD_ID ]]
     then
        echo "The local build ID was updated from $previousLocalBuildId to $VALHEIM_SERVER_LOCAL_BUILD_ID"
     else
        echo "The local build ID is $VALHEIM_SERVER_LOCAL_BUILD_ID"
     fi
}

function findAndSetRemoteValheimServerBuildId(){
    # Finds the latest build ID from Steam
    # Delete the cached app info so the latest build ID is fetched from Steam
    if [ -f STEAM_CACHED_APP_INFO ]
    then
        echo "Deleting cached app info: $STEAM_CACHED_APP_INFO"
        rm $STEAM_CACHED_APP_INFO
    fi
    /bin/bash $STEAMCMD_DIR/steamcmd.sh +login anonymous +app_info_update 1 +app_info_print 896660 +quit

    pcregrep -o1 -M '"branches".*\n*.*{\n*.*"public".*\n*.*{.*\n*.*"buildid".*"([0-9]+)*"'
}

