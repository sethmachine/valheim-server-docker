#!/usr/bin/env bash

# Starts the Valheim server

# Keep track of the Valheim server process ID to shut it down later
VALHEIM_SERVER_PID=""

function startValheimServer()
{
    export templdpath=$LD_LIBRARY_PATH
    export LD_LIBRARY_PATH=./linux64:$LD_LIBRARY_PATH
    export SteamAppId=892970

    INFO "Starting the Valheim server"
    INFO "LD_LIBRARY_PATH: $LD_LIBRARY_PATH"

    INFO "Valheim port is: $VALHEIM_PORT"
    INFO "Valheim server name is: $VALHEIM_SERVER_NAME"
    INFO "Valheim world name is: $VALHEIM_WORLD_NAME"
    if [ "${VALHEIM_SERVER_PUBLIC}" = 0 ]
    then
        WARN "The Valheim server is not set to public.  It will not show up in the server list.  Players must join via IP address instead"
    else
        INFO "The Valheim server is set to public visibility.  It will be visible in the server list.  Players will still need to enter the password to join"
    fi

    cd $VALHEIM_SERVER_DIR
    # start the server as a background process to get its PID ("&" at end of command)
    # "&>>" means append all stdout and stderr to the log file
    ./valheim_server.x86_64 -name $VALHEIM_SERVER_NAME \
    -port $VALHEIM_PORT \
    -world $VALHEIM_WORLD_NAME \
    -password $VALHEIM_PASSWORD \
    -public $VALHEIM_SERVER_PUBLIC \
    -savedir $VALHEIM_DATA_DIR &>> "/home/steam/valheim-data/$VALHEIM_WORLD_NAME-logs.txt" &
    VALHEIM_SERVER_PID=$!
    INFO "Valheim server PID is: $VALHEIM_SERVER_PID"
}