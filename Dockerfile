FROM cm2network/steamcmd:latest

USER root
# Install PCREGREP (http://www.pcre.org/) to extract build IDs from the VDF format
# PCREGREP allows for writing easy to understand regular expressions that can span multiple lines
RUN apt-get update && apt-get install pcregrep -y && apt-get install -y procps && apt-get install git -y

# where Steam is installed
ENV STEAM_DIR "/home/steam/Steam"
# where steamcmd is installed
ENV STEAMCMD_DIR "/home/steam/steamcmd"
# where the Valheim server is installed to
ENV VALHEIM_SERVER_DIR "/home/steam/valheim-server"
# the Steam app ID that uniquely identifies the server
ENV VALHEIM_SERVER_APP_ID 896660
# 1 enables a one time check to update the Valheim server whenever it is first started
ENV VALHEIM_SERVER_UPDATE_ON_START_UP 1
# 1 enables auto update; set to 0 to disable auto update
ENV VALHEIM_SERVER_AUTO_UPDATE 1
# how often to check for server updates
# For format: https://linuxize.com/post/how-to-use-linux-sleep-command-to-pause-a-bash-script/
ENV VALHEIM_SERVER_AUTO_UPDATE_FREQUENCY "30m"

RUN cd ${STEAM_DIR} && git clone https://github.com/idelsink/b-log.git && apt-get remove git -y && chown -R steam:steam b-log/

# changes the uuid and guid to 1000:1000, allowing for the files to save on GNU/Linux
USER steam

RUN ./steamcmd.sh +login anonymous \
+force_install_dir $VALHEIM_SERVER_DIR \
+app_update $VALHEIM_SERVER_APP_ID \
validate +exit

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
# 1 allows viewing the server in the public list; 0 hides it (must join by IP)
ENV VALHEIM_SERVER_PUBLIC 1

# the server needs these 3 ports exposed by default
EXPOSE 2456/udp
EXPOSE 2457/udp
EXPOSE 2458/udp

VOLUME ${VALHEIM_DATA_DIR}

# copy over the scripts to start, update, and shutdown the server
COPY --chown=steam valheim-server-entrypoint.sh ${VALHEIM_SERVER_DIR}
COPY --chown=steam start-valheim-server.sh ${VALHEIM_SERVER_DIR}
COPY --chown=steam update-valheim-server.sh ${VALHEIM_SERVER_DIR}
COPY --chown=steam shutdown-valheim-server.sh ${VALHEIM_SERVER_DIR}

WORKDIR ${VALHEIM_SERVER_DIR}

ENTRYPOINT ["./valheim-server-entrypoint.sh"]