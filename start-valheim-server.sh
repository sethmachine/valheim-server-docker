#!/usr/bin/env bash

function shutdownValheimGracefully()
{
    echo "Got Valheim Server PID: $1"
    # send a SIGINT to shut down the Valheim server gracefully
    kill -2 $1
    # wait for Valheim to terminate before shutting down the container
    wait $1
    exit 0
}

trap 'shutdownValheimGracefully "$VALHEIM_PID"' SIGTERM

export templdpath=$LD_LIBRARY_PATH
export LD_LIBRARY_PATH=./linux64:$LD_LIBRARY_PATH
export SteamAppId=892970

echo "Starting server PRESS CTRL-C to exit"
echo "LD_LIBRARY_PATH: $LD_LIBRARY_PATH"

echo "Valheim port is: $VALHEIM_PORT"
echo "Valheim server name is: $VALHEIM_SERVER_NAME"
echo "Valheim world name is: $VALHEIM_WORLD_NAME"

cd $VALHEIM_SERVER_DIR
./valheim_server.x86_64 -name $VALHEIM_SERVER_NAME \
-port $VALHEIM_PORT \
-world $VALHEIM_WORLD_NAME \
-password $VALHEIM_PASSWORD \
-savedir $VALHEIM_DATA_DIR &>> "/home/steam/valheim-data/$VALHEIM_WORLD_NAME-logs.txt" &
VALHEIM_PID=$!
echo "Valheim PID is $VALHEIM_PID"

while true; do :; done



