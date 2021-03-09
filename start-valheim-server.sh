#!/usr/bin/env bash

# server name and world name need to be defined at runtime
if [ -z "${VALHEIM_SERVER_NAME}" ]
then
    echo "Please set the VALHEIM_SERVER_NAME property.  E.g. use --env VALHEIM_SERVER_NAME=\"My Server Name\""
    exit 1
fi

if [ "${VALHEIM_WORLD_NAME}" == "" ]
then
    echo "Please set the VALHEIM_WORLD_NAME property.  E.g. use --env VALHEIM_WORLD_NAME=\"AWholeNewWorld\""
    exit 1
fi

# docker sends a SIGTERM and then SIGKILL to the main process
# Valheim needs a SIGINT (CTRL+C) to terminate properly
function shutdownValheimGracefully()
{
    echo "Valheim server PID is: $1"
    # send a SIGINT to shut down the Valheim server gracefully
    kill -2 $1
    # wait for Valheim to terminate before shutting down the container
    wait $1
    exit 0
}

# catch Docker's SIGTERM, then then a SIGINT to the Valheim server process
trap 'shutdownValheimGracefully "$VALHEIM_PID"' SIGTERM

export templdpath=$LD_LIBRARY_PATH
export LD_LIBRARY_PATH=./linux64:$LD_LIBRARY_PATH
export SteamAppId=892970

echo "Starting server PRESS CTRL-C to exit"
echo "LD_LIBRARY_PATH: $LD_LIBRARY_PATH"

echo "Valheim port is: $VALHEIM_PORT"
echo "Valheim server name is: $VALHEIM_SERVER_NAME"
echo "Valheim world name is: $VALHEIM_WORLD_NAME"
echo "Valheim server is public: $VALHEIM_PUBLIC"

steamcmd/steamcmd.sh +login anonymous \
+force_install_dir $VALHEIM_SERVER_DIR \
+app_update 896660 \
validate +exit > "/home/steam/valheim-data/steamcmd_log.txt"

cd $VALHEIM_SERVER_DIR

echo ./valheim_server.x86_64 -name $VALHEIM_SERVER_NAME -port $VALHEIM_PORT -world $VALHEIM_WORLD_NAME -password $VALHEIM_PASSWORD -savedir $VALHEIM_DATA_DIR > "/home/steam/valheim-data/call.txt"

# start the server as a background process to get its PID ("&" at end of command)
# "&>>" means append all stdout and stderr to the log file
./valheim_server.x86_64 -name $VALHEIM_SERVER_NAME \
-public $VALHEIM_PUBLIC \
-port $VALHEIM_PORT \
-world $VALHEIM_WORLD_NAME \
-password $VALHEIM_PASSWORD \
-savedir $VALHEIM_DATA_DIR &>> "/home/steam/valheim-data/$VALHEIM_WORLD_NAME-logs.txt" &
VALHEIM_PID=$!
echo "Valheim server PID is: $VALHEIM_PID"

# since the server is run in the background, this is needed to keep the main process from exiting
while wait $!; [ $? != 0 ]; do true; done
