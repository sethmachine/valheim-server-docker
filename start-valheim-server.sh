#!/usr/bin/env bash

# Starts the Valheim server

# Keep track of the Valheim server process ID to shut it down later
export VALHEIM_SERVER_PID=""

function startValheimServer()
{
    export templdpath=$LD_LIBRARY_PATH
    export LD_LIBRARY_PATH=./linux64:$LD_LIBRARY_PATH
    export SteamAppId=892970

    echo "Starting server PRESS CTRL-C to exit"
    echo "LD_LIBRARY_PATH: $LD_LIBRARY_PATH"

    echo "Valheim port is: $VALHEIM_PORT"
    echo "Valheim server name is: $VALHEIM_SERVER_NAME"
    echo "Valheim world name is: $VALHEIM_WORLD_NAME"

    cd $VALHEIM_SERVER_DIR
    # start the server as a background process to get its PID ("&" at end of command)
    # "&>>" means append all stdout and stderr to the log file
    ./valheim_server.x86_64 -name $VALHEIM_SERVER_NAME \
    -port $VALHEIM_PORT \
    -world $VALHEIM_WORLD_NAME \
    -password $VALHEIM_PASSWORD \
    -savedir $VALHEIM_DATA_DIR &>> "/home/steam/valheim-data/$VALHEIM_WORLD_NAME-logs.txt" &
    VALHEIM_SERVER_PID=$!
    echo "Valheim server PID is: $VALHEIM_SERVER_PID"
}