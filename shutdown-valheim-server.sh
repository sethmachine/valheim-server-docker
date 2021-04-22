#!/usr/bin/env bash

# docker sends a SIGTERM and then SIGKILL to the main process
# Valheim needs a SIGINT (CTRL+C) to terminate properly
function shutdownValheimServerAndExit()
{
    echo "Shutting down the Valheim server.  PID is: $VALHEIM_SERVER_PID"
    # send a SIGINT to shut down the Valheim server gracefully
    kill -2 $VALHEIM_SERVER_PID
    # wait for Valheim to terminate before shutting down the container
    wait $VALHEIM_SERVER_PID
    exit 0
}


function shutdownValheimServer()
{
    # Shut down the Valheim server without exiting the current process
    echo "Shutting down the Valheim server.  PID is: $VALHEIM_SERVER_PID"
    kill -2 $VALHEIM_SERVER_PID
    wait $VALHEIM_SERVER_PID
}
