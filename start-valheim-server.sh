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
        WARN "The Valheim server is not set to public.  It will not show up in the server list.  Use a join code for crossplay, or an IP address for Steam-only play"
    else
        INFO "The Valheim server is set to public visibility.  It will be visible in the server list.  Players will still need to enter the password to join"
    fi

    EXECUTABLE="./valheim_server.x86_64"

    # An array preserves spaces and special characters in names, passwords and paths.
    local serverArgs=(
        -name "$VALHEIM_SERVER_NAME"
        -port "$VALHEIM_PORT"
        -world "$VALHEIM_WORLD_NAME"
        -password "$VALHEIM_PASSWORD"
        -public "$VALHEIM_SERVER_PUBLIC"
        -savedir "$VALHEIM_DATA_DIR"
    )
    if [ "${VALHEIM_SERVER_CROSSPLAY:-0}" = 1 ]
    then
        serverArgs+=(-crossplay)
        INFO "Crossplay is enabled. Use the join code from the world log; local/loopback IP connections are not supported"
    else
        INFO "Crossplay is disabled. Only Steam players can join"
    fi

    if [ "${USE_BEPINEX}" = 1 ]
    then
        WARN "Using BepInEx modded valheim server!"
        if [ "${VALHEIM_SERVER_CROSSPLAY:-0}" = 1 ]
        then
            WARN "Console players cannot install client mods. Use USE_BEPINEX=0 for an unmodded crossplay server"
        fi
        # Only load mod files when explicitly enabled; vanilla servers need no mod folders.
        if [ -d "$VALHEIM_DATA_DIR/plugins" ]; then
            cp -r "$VALHEIM_DATA_DIR/plugins/." "$BEPINEX_PLUGINS_DIR/"
        fi
        if [ -d "$VALHEIM_DATA_DIR/config" ]; then
            cp -r "$VALHEIM_DATA_DIR/config/." "$BEPINEX_CONFIG_DIR/"
        fi
        # BepInEx-specific settings
        # NOTE: Do not edit unless you know what you are doing!
        ####
        export DOORSTOP_ENABLE=TRUE
        export DOORSTOP_INVOKE_DLL_PATH=./BepInEx/core/BepInEx.Preloader.dll
        export DOORSTOP_CORLIB_OVERRIDE_PATH=./unstripped_corlib

        export LD_LIBRARY_PATH="./doorstop_libs:$LD_LIBRARY_PATH"
        export LD_PRELOAD="libdoorstop_x64.so:$LD_PRELOAD"
        ####
        export LD_LIBRARY_PATH="./linux64:$LD_LIBRARY_PATH"
        export SteamAppId=892970
    fi


    cd "$VALHEIM_SERVER_DIR" || return 1
    # start the server as a background process to get its PID ("&" at end of command)
    # "&>>" means append all stdout and stderr to the log file
    "$EXECUTABLE" "${serverArgs[@]}" &>> "$VALHEIM_DATA_DIR/$VALHEIM_WORLD_NAME-logs.txt" &
    VALHEIM_SERVER_PID=$!
    INFO "Valheim server PID is: $VALHEIM_SERVER_PID"
}