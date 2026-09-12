#!/usr/bin/env bash
# Provides functions to update to a newer Valheim server automatically

# This is where the app manifest is that stores the build ID of the local Valheim server
VALHEIM_SERVER_APP_MANIFEST="$VALHEIM_SERVER_DIR/steamapps/appmanifest_896660.acf"
# This is where the local/current build ID is stored
VALHEIM_SERVER_LOCAL_BUILD_ID=""
VALHEIM_SERVER_LOCAL_BRANCH=""
# This is what Steam reports is the latest build ID
VALHEIM_SERVER_REMOTE_BUILD_ID=""
# Steam caches all app infos (contain build IDs); need to delete this file to get latest remote build IDs
STEAM_CACHED_APP_INFO="$STEAM_DIR/appcache/appinfo.vdf"
# The PID of the loop that periodically checks whether to update the Valheim server
VALHEIM_SERVER_UPDATE_LOOP_PID=""

function findAndSetLocalValheimServerBuildId(){
    # Finds the buildId from the Valheim server's local app manifest
    # Check if there was a previous local build ID so we can see if anything changed
    local previousLocalBuildId=""
    if [[ ! -z "${VALHEIM_SERVER_LOCAL_BUILD_ID}" ]]
    then
        local previousLocalBuildId=$VALHEIM_SERVER_LOCAL_BUILD_ID
    fi

    VALHEIM_SERVER_LOCAL_BUILD_ID=""
    VALHEIM_SERVER_LOCAL_BRANCH=""
    if [[ ! -f "$VALHEIM_SERVER_APP_MANIFEST" ]]
    then
        WARN "No local app manifest found; the server needs to be installed"
        return 1
    fi
    VALHEIM_SERVER_LOCAL_BUILD_ID=$(awk -F '"' '$2 == "buildid" && $4 ~ /^[0-9]+$/ { print $4; exit }' "$VALHEIM_SERVER_APP_MANIFEST")
    VALHEIM_SERVER_LOCAL_BRANCH=$(awk -F '"' '$2 == "BetaKey" { print $4; exit }' "$VALHEIM_SERVER_APP_MANIFEST")
    VALHEIM_SERVER_LOCAL_BRANCH=${VALHEIM_SERVER_LOCAL_BRANCH:-public}
    if [[ -z "$VALHEIM_SERVER_LOCAL_BUILD_ID" ]]
    then
        ERROR "Could not read a valid build ID from the local app manifest"
        return 1
    fi

    if [[ ! -z "${previousLocalBuildId}" ]] && [[ ${previousLocalBuildId} != ${VALHEIM_SERVER_LOCAL_BUILD_ID} ]]
    then
        INFO "The local build ID was updated from $previousLocalBuildId to $VALHEIM_SERVER_LOCAL_BUILD_ID"
    else
        INFO "The local build ID is $VALHEIM_SERVER_LOCAL_BUILD_ID"
    fi
}

function findAndSetRemoteValheimServerBuildId(){
    # Finds the latest build ID from Steam
    # Delete the cached app info so the latest build ID is fetched from Steam
    if [[ -f "${STEAM_CACHED_APP_INFO}" ]]
    then
        INFO "Deleting cached app info: $STEAM_CACHED_APP_INFO"
        rm -- "$STEAM_CACHED_APP_INFO"
    fi

    # First update the app info get the latest build IDs from the Steam remote
    local branch=${VALHEIM_SERVER_BRANCH:-public}
    INFO "Querying Steam for the Valheim server build on branch $branch"
    local appInfo
    VALHEIM_SERVER_REMOTE_BUILD_ID=""
    if ! appInfo=$(/bin/bash "$STEAMCMD_DIR/steamcmd.sh" +login anonymous +app_info_update 1 +app_info_print "$VALHEIM_SERVER_APP_ID" +quit)
    then
        ERROR "Steam could not return app information; update skipped"
        return 1
    fi
    # SteamCMD prints VDF with one key or brace per line. Only inspect the
    # requested branch inside branches; its position and field order can vary.
    VALHEIM_SERVER_REMOTE_BUILD_ID=$(printf '%s\n' "$appInfo" | awk -F '"' -v branch="$branch" '
        $2 == "branches" { branches = 1; next }
        branches {
            if ($0 ~ /^[[:space:]]*\{[[:space:]]*$/) { depth++; next }
            if ($0 ~ /^[[:space:]]*\}[[:space:]]*$/) {
                if (depth == 2) selected = 0
                depth--
                if (depth == 0) exit
                next
            }
            if (depth == 1 && $2 == branch) selected = 1
            if (depth == 2 && selected && $2 == "buildid" && $4 ~ /^[0-9]+$/) {
                print $4
                exit
            }
        }
    ')
    if [[ -z "$VALHEIM_SERVER_REMOTE_BUILD_ID" ]]
    then
        ERROR "No build ID found for branch $branch; update skipped (no fallback to public)"
        return 1
    fi

    INFO "The remote server build ID is $VALHEIM_SERVER_REMOTE_BUILD_ID"
}

function assertLocalBuildIsLatest(){
    if [[ ${VALHEIM_SERVER_LOCAL_BUILD_ID} != ${VALHEIM_SERVER_REMOTE_BUILD_ID} ]]
    then
        ERROR "The local build differs from the remote build after updating.  Local build ID: $VALHEIM_SERVER_LOCAL_BUILD_ID.  Remote build ID: $VALHEIM_SERVER_REMOTE_BUILD_ID"
        return 1
    else
        INFO "The local build ID is the same as the latest remote build ID"
    fi
}

function updateValheimServer(){
    INFO "Installing Valheim server branch ${VALHEIM_SERVER_BRANCH:-public}"
    /bin/bash "$STEAMCMD_DIR/steamcmd.sh" +force_install_dir "$VALHEIM_SERVER_DIR" +login anonymous +app_update "$VALHEIM_SERVER_APP_ID" -beta "${VALHEIM_SERVER_BRANCH:-public}" validate +quit
}

function updateValheimServerIfNewerBuildExists(){
    # Only call this function before the first time the server ever starts up
    INFO "Checking to see if the Valheim server needs to be updated"
    findAndSetLocalValheimServerBuildId || true
    findAndSetRemoteValheimServerBuildId || return 1
    if [[ "$VALHEIM_SERVER_LOCAL_BUILD_ID" = "$VALHEIM_SERVER_REMOTE_BUILD_ID" && "$VALHEIM_SERVER_LOCAL_BRANCH" = "${VALHEIM_SERVER_BRANCH:-public}" ]]
    then
        INFO "The Valheim server is already up to date with build ID $VALHEIM_SERVER_LOCAL_BUILD_ID"
    else
        updateValheimServer || return 1
        findAndSetLocalValheimServerBuildId || return 1
        assertLocalBuildIsLatest || return 1
    fi
}

function checkForAndUpdateValheimServer(){
    # Check if the Valheim server needs to be updated, and if so update it
    # Need to stop the Valheim server and then restart it afterwards
    INFO "Checking to see if the Valheim server needs to be updated"
    findAndSetLocalValheimServerBuildId || return 1
    findAndSetRemoteValheimServerBuildId || return 1
    if [[ "$VALHEIM_SERVER_LOCAL_BUILD_ID" = "$VALHEIM_SERVER_REMOTE_BUILD_ID" && "$VALHEIM_SERVER_LOCAL_BRANCH" = "${VALHEIM_SERVER_BRANCH:-public}" ]]
    then
        INFO "The Valheim server is already up to date with build ID $VALHEIM_SERVER_LOCAL_BUILD_ID"
    else
        INFO "Updating the Valheim server from $VALHEIM_SERVER_LOCAL_BUILD_ID (old) to $VALHEIM_SERVER_REMOTE_BUILD_ID (new)"
        shutdownValheimServer
        updateValheimServer || return 1
        findAndSetLocalValheimServerBuildId || return 1
        assertLocalBuildIsLatest || return 1
        startValheimServer
    fi
}

function startServerAndUpdateLoop(){
    trap 'shutdownValheimServerAndExit' SIGTERM
    startValheimServer

    while true
    do
        INFO "Sleeping for $VALHEIM_SERVER_AUTO_UPDATE_FREQUENCY before checking for Valheim server update"
        sleep $VALHEIM_SERVER_AUTO_UPDATE_FREQUENCY &
        sleep_pid=$!
        wait $sleep_pid
        checkForAndUpdateValheimServer
    done
}
