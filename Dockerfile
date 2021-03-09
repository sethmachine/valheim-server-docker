FROM cm2network/steamcmd:latest


# where the Valheim server is installed to
ENV STEAM_HOME_DIR "/home/steam"

# where the Valheim server is installed to
ENV VALHEIM_SERVER_DIR "/home/steam/valheim-server"

# changes the uuid and guid to 1000:1000, allowing for the files to save on GNU/Linux
USER 1000:1000

# where world data is stored, map this to the host directory where your worlds are stored
# e.g. docker run -v /path/to/host/directory:/home/steam/valheim-data
ENV VALHEIM_DATA_DIR "/home/steam/valheim-data"
# don't change the port unless you know what you are doing
ENV VALHEIM_PORT 2456
# server and world name are truncated after 1st white space
# you must set values to the server and world name otherwise the container will exit immediately
ENV VALHEIM_SERVER_NAME=""
ENV VALHEIM_WORLD_NAME=""
ENV VALHEIM_PASSWORD "password"
ENV VALHEIM_PUBLIC 1

# the server needs these 3 ports exposed by default
EXPOSE 2456/udp
EXPOSE 2457/udp
EXPOSE 2458/udp

VOLUME ${VALHEIM_DATA_DIR}
VOLUME ${VALHEIM_SERVER_DIR}

# copy over the modified server start script
COPY start-valheim-server.sh ${STEAM_HOME_DIR}
WORKDIR ${STEAM_HOME_DIR}

ENTRYPOINT ["./start-valheim-server.sh"]
