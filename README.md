# valheim-server-docker

This repo provides a Dockerfile that builds an image which runs a Valheim server.  Using Docker allows for running the server on most operating systems, including macOS (which is not supported by the Valheim game at all).  The custom server start script `start-valheim-server.sh` provides a mechanism to gracefully shut down a running Valheim server when using `docker stop`.  This is necessary so world data is properly saved back to disk.

This repo now provides **automatic update** for the Valheim server.  If this feature is enabled, a running Valheim server can automatically update itself as new Valheim updates are released, allowing a server to truly run 24/7.  

Note you will still need to forward and open ports 2456, 2457, and 2458 (UDP protocol) on the host machine for the server to be listed and accessible.

If you find this repo useful, I'd love to hear back in a note how you're using it.  If you use this repo to build on your own work, please provide a reference back to this repo's URL.

Built images are provided on Docker Hub: [sethmachineio/valheim-server:latest](https://hub.docker.com/r/sethmachineio/valheim-server)

I also have written a complete guide here that covers how to set up your own dedicated server at home: [Valheim Dedicated Server at Home Guide](https://www.sethmachine.io/2021/02/11/host-valheim-with-docker/).

For a detailed guide on how automatic update works, see this newer guide: [Automatic Update for Valheim Server](https://www.sethmachine.io/2021/02/11/host-valheim-with-docker/)

## Usage

You have two possibilities to run the container:

- Docker CLI

- Docker Compose

When wanting to save your configuration easily, for the sake of backups,
easier editing, or transport, use `docker-compose`.

### Docker Compose

*Note: Docker compose is currently untested with new automatic update feature.*

Clone the repo, edit the `docker-compose.yml` to your liking, and run
the container in the background using `docker-compose up -d`. In order
to stop the container, run `docker-compose down`. Remember to restart
your container after editing the config.

| **Variables**               | **Possible Values**                       | **Default**                |
|-----------------------------|-------------------------------------------|----------------------------|
| `user`                      | Any UUID and GUID                         | 1000:1000                  |
| `ports`                     | Any port, keep default internal ports     | Same internal and external |
| `volumes`                   | Any path on your local system             | `./valheim-data`           |
| `VALHEIM_SERVER_NAME`       | Any string                                | "MyServer"                 |
| `VALHEIM_WORLD_NAME`        | Any string                                | "NewWorld"                 |
| `VALHEIM_PASSWORD`          | Any string                                | "password"                 |
| `VALHEIM_SERVER_PUBLIC`                 | 0 or 1                                    | 1                          |
| `VALHEIM_SERVER_UPDATE_ON_START_UP`     | 0 or 1                                    | 1                          |
| `VALHEIM_SERVER_AUTO_UPDATE`            | 0 or 1                                    | 1                          |
| `VALHEIM_SERVER_AUTO_UPDATE_FREQUENCY`  | [sleep number](https://man7.org/linux/man-pages/man1/sleep.1.html)     | "30m"                          |


### Docker CLI

Pull the latest image using Docker:

```bash
docker pull sethmachineio/valheim-server:latest
```

You'll need to mount a directory on the host machine to the image's volume specified as `/home/steam/valheim-data`.  This is the mechanism by which world data is persisted even if the container is stopped, and also allows you to use existing worlds.  The structure of the host directory (`/home/sethmachine/valheim-data`) should look like this:

```bash
/home/sethmachine/valheim-data
└── worlds
    ├── OldWorld.db
    └── OldWorld.fwl
```

The subdirectory `worlds` can be empty or not exist at all.

There are 8 environment parameters to customize the server's runtime behavior.  2 of these are required to be set, otherwise the container will exit immediately.

* `VALHEIM_SERVER_NAME`: sets the server's name (**required**, truncated at first whitespace).
* `VALHEIM_WORLD_NAME`: sets the world's name (**required**, truncated at first whitespace).
* `VALHEIM_PASSWORD`: sets the server's password.
* `VALHEIM_PORT`: sets the server's port (default is `2456`).  Recommended not to change this.
* `VALHEIM_SERVER_PUBLIC`: allows the server to be listed in public server list (enable by default).  A value of `0` would mean the server is only joinable via IP.  
* `VALHEIM_SERVER_UPDATE_ON_START_UP`: attempt to update the Valheim server each time the Docker container is started.  
* `VALHEIM_SERVER_AUTO_UPDATE`: enables automatic update for the Valheim server.  Set to `0` to disable automatic update.  
* `VALHEIM_SERVER_AUTO_UPDATE_FREQUENCY`: how frequent to check and perform an update if the server is outdated (default is "30m" or 30 minutes)

Below is an example command to run the server as a Docker container: 

```bash
docker run --name=valheim-server -d \
--restart always \
-p 2456:2456/udp -p 2457:2457/udp -p 2458:2458/udp \
-v /Users/sethmachine/valheim-data:/home/steam/valheim-data \
--env VALHEIM_SERVER_NAME="MyValheimServer" \
--env VALHEIM_WORLD_NAME="MyValheimWorld" \
--env VALHEIM_PASSWORD="HardToGuessPassword" \
--env VALHEIM_PUBLIC=1 \
--env VALHEIM_SERVER_UPDATE_ON_START_UP=1 \
--env VALHEIM_SERVER_AUTO_UPDATE=1 \
--env VALHEIM_SERVER_AUTO_UPDATE_FREQUENCY=30m \
sethmachineio/valheim-server
```

After running for the 1st time, the banlist, permitted list, and admin list will be created if they do not already exist in the host's directory.  There will also be a world specific log file.

```bash
├── MyValheimWorld-logs.txt
├── adminlist.txt
├── bannedlist.txt
├── permittedlist.txt
└── worlds
    ├── MyValheimWorld.db
    ├── MyValheimWorld.fwl
```

Explanation:

* `MyValheimWorld-logs.txt`: this is a Valheim specific log file for the world we created
* `adminlist.txt`: determines who is an admin (add Steam ID, one per line)
* `bannedlist.txt`: automatically bans players (add Steam ID, one per line)
* `permittedlist.txt`: whitelist for who can join (add Steam ID, one per line).  Note if this has a single Steam ID in it, this will ban everyone else from the server besides players whose Steam ID is in this list.

## Logs

Two different logs are provided: from the custom start script and from Valheim specific logging.

Access the custom start script log by running `docker logs <containerID>`:

```bash
sethmachine valheim-server-docker % docker logs valheim-server
[2021-05-21 03:32:20.674][INFO  ][main:28 ] Attempting one time update of the Valheim server on start up
[2021-05-21 03:32:20.678][INFO  ][updateValheimServerIfNewerBuildExists:75 ] Checking to see if the Valheim server needs to be updated
[2021-05-21 03:32:20.684][INFO  ][findAndSetLocalValheimServerBuildId:30 ] The local build ID is 6663905
[2021-05-21 03:32:20.686][INFO  ][findAndSetRemoteValheimServerBuildId:39 ] Deleting cached app info: /home/steam/Steam/appcache/appinfo.vdf
[2021-05-21 03:32:20.689][INFO  ][findAndSetRemoteValheimServerBuildId:44 ] Querying the remote server for the latest build ID for the Valheim server
[2021-05-21 03:32:25.722][INFO  ][findAndSetRemoteValheimServerBuildId:56 ] The remote server build ID is 6663905
[2021-05-21 03:32:25.725][INFO  ][updateValheimServerIfNewerBuildExists:80 ] The Valheim server is already up to date with build ID 6663905
[2021-05-21 03:32:25.727][WARN  ][main:51 ] Experimental auto update is enabled.  The server will automatically update and restart when a new version is detected
[2021-05-21 03:32:25.730][INFO  ][main:52 ] Updates to the server will be checked every 30m
[2021-05-21 03:32:25.733][INFO  ][main:57 ] Valheim server update loop PID is: 48
[2021-05-21 03:32:25.733][INFO  ][startValheimServer:14 ] Starting the Valheim server
[2021-05-21 03:32:25.736][INFO  ][startValheimServer:15 ] LD_LIBRARY_PATH: ./linux64:
[2021-05-21 03:32:25.738][INFO  ][startValheimServer:17 ] Valheim port is: 2456
[2021-05-21 03:32:25.741][INFO  ][startValheimServer:18 ] Valheim server name is: MyValheimServer
[2021-05-21 03:32:25.744][INFO  ][startValheimServer:19 ] Valheim world name is: MyValheimWorld
[2021-05-21 03:32:25.746][INFO  ][startValheimServer:24 ] The Valheim server is set to public visibility.  It will be visible in the server list.  Players will still need to enter the password to join
[2021-05-21 03:32:25.750][INFO  ][startValheimServer:37 ] Valheim server PID is: 56
[2021-05-21 03:32:25.753][INFO  ][startServerAndUpdateLoop:111] Sleeping for 30m before checking for Valheim server update

```

Access world specific Valheim logs from the \<WorldName\>-logs.txt created in the host's directory:

```bash
sethmachine valheim-server-docker % tail -f /home/sethmachine/valheim-data/MyValheimWorld-logs.txt
(Filename: ./Runtime/Export/Debug/Debug.bindings.h Line: 35)

02/15/2021 04:19:30: Net scene destroyed

(Filename: ./Runtime/Export/Debug/Debug.bindings.h Line: 35)

02/15/2021 04:19:30: Steam manager on destroy

(Filename: ./Runtime/Export/Debug/Debug.bindings.h Line: 35)
```

## How to build the image

Clone the repository and cd into the repo, then run `docker build`:

```bash
docker build -t sethmachineio/valheim-server .
```

If you build the image locally and then Valheim updates its server, rebuilding the image won't update to the new server, as Docker will still use the cache as it has no idea Valheim updated the server.  To force re-downloading the latest server, use the `--no-cache` option when building the Docker image, e.g.:

```bash
docker build -t sethmachineio/valheim-server --no-cache .
```


## How to use automatic update

The automatic update feature removes the need to keep rebuilding the Docker image whenever Valheim has an update, since it will update itself within the container.  This means even if the Docker image's Valheim server is out of date, the container will run at the latest version once the update has completed.  Further, if the container is stopped, it will continue to use the updated Valheim server when started up again.  However, if the container is deleted, then it may go through updates if the Docker image uses an older version of the server.  Existing worlds can continue to be used without issue as long as the right worlds directory is chosen when starting the container.  

You'll first start the server like this:

```bash
docker run --name=valheim-server -d \
--restart always \
-p 2456:2456/udp -p 2457:2457/udp -p 2458:2458/udp \
-v /Users/sethmachine/valheim-data:/home/steam/valheim-data \
--env VALHEIM_SERVER_NAME="MyValheimServer" \
--env VALHEIM_WORLD_NAME="MyValheimWorld" \
--env VALHEIM_PASSWORD="HardToGuessPassword" \
--env VALHEIM_PUBLIC=1 \
--env VALHEIM_SERVER_UPDATE_ON_START_UP=1 \
--env VALHEIM_SERVER_AUTO_UPDATE=1 \
--env VALHEIM_SERVER_AUTO_UPDATE_FREQUENCY=30m \
sethmachineio/valheim-server
```

At some point the server will stop itself, update, and restart when a new update comes in.  If ever the server is stopped (either you shut it down manually or the host machine was turned off unexpectedly), the container itself will still exist and have the updated server.  Simply start it up again with `docker start valheim-server` (or however the container is named) and it should be up to date.  

If you need to execute a manual update sooner than the auto update, simple stop the container and then start it again.  Make sure `VALHEIM_SERVER_UPDATE_ON_START_UP` is set to 1.  Starting it again will trigger a check for an update immediately.  

## Known Issues / FAQ
