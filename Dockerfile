FROM cm2network/steamcmd

# where the Valheim server is installed to
ENV VALHEIM_SERVER_DIR "/home/steam/valheim-server"

# install the Valheim server
RUN ./steamcmd.sh +login anonymous \
+force_install_dir $VALHEIM_SERVER_DIR \
+app_update 896660 \
validate +exit

# where world data is stored, map this to the host directory where your worlds are stored
# e.g. docker run -v /path/to/host/directory:/home/steam/valheim-data
ENV VALHEIM_DATA_DIR "/home/steam/valheim-data"
# don't change the port unless you know what you are doing
ENV VALHEIM_PORT 2456"
# server and world name are truncated after 1st white space
# you must set values to the server and world name otherwise the container will exit immediately
ENV VALHEIM_SERVER_NAME=""
ENV VALHEIM_WORLD_NAME=""
ENV VALHEIM_PASSWORD "password"

# the server needs these 3 ports exposed by default
EXPOSE 2456/udp
EXPOSE 2457/udp
EXPOSE 2458/udp

VOLUME ${VALHEIM_DATA_DIR}

# copy over the modified server start script
COPY start-valheim-server.sh ${VALHEIM_SERVER_DIR}
WORKDIR ${VALHEIM_SERVER_DIR}

ENTRYPOINT ["./start-valheim-server.sh"]

