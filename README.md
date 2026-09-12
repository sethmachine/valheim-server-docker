# valheim-server-docker

This repo provides a Dockerfile that builds an image which runs a Valheim server.  Using Docker allows for running the server on most operating systems, including macOS (which is not supported by the Valheim game at all).  The custom server start script `start-valheim-server.sh` provides a mechanism to gracefully shut down a running Valheim server when using `docker stop`.  This is necessary so world data is properly saved back to disk.

This repo now provides **automatic update** for the Valheim server.  If this feature is enabled, a running Valheim server can automatically update itself as new Valheim updates are released, allowing a server to truly run 24/7.  

Steam-only servers need UDP port forwarding (Valheim uses the configured port and port+1, normally 2456-2457). Crossplay uses a relay and does not require router port forwarding. The host still needs to allow the server's network traffic through its firewall.

If you find this repo useful, I'd love to hear back in a note how you're using it.  If you use this repo to build on your own work, please provide a reference back to this repo's URL.

Built images are provided on Docker Hub: [sethmachineio/valheim-server:latest](https://hub.docker.com/r/sethmachineio/valheim-server)

I also have written a complete guide here that covers how to set up your own dedicated server at home: [Valheim Dedicated Server at Home Guide](https://www.sethmachine.io/2021/02/11/host-valheim-with-docker/).

For a detailed guide on how automatic update works, see this newer guide: [Automatic Update for Valheim Server](https://www.sethmachine.io/2021/02/11/host-valheim-with-docker/)

## Usage

### Nintendo Switch 2 and other consoles

Enable `VALHEIM_SERVER_CROSSPLAY=1` to launch the server with `-crossplay` (the PlayFab backend). Without this argument, only Steam clients can join. Crossplay is opt-in; existing Docker CLI and Compose configurations keep their Steam-only behavior.

**Known platform blocker, checked September 12, 2026:** Iron Gate's [September 11 hotfix notice](https://www.valheimgame.com/news/hotfix-1-0-10-1-0-12/) says the Switch 2 patch could not be uploaded and crossplay between Switch 2 and other platforms is temporarily unavailable. Enabling crossplay prepares the server, but cannot fix this game-version mismatch. Check that notice for updates and wait for compatible releases before testing a Switch connection. Do not downgrade an existing world to work around it.

For a PC host already using this repository's Compose service:

1. Preserve the existing `VALHEIM_WORLD_NAME`, password, and host data-directory mount in `docker-compose.yml`. The sample `NewWorld`/`./valheim-data` values are for a new setup; do not replace a working server's settings with them. Back up the full mounted data directory while the server is stopped (including `worlds_local`, `worlds`, and permission files if present). Do not run a second container against the same world.
2. Apply these source changes and build the crossplay image locally. The override keeps the base file's world, password, ports and volume settings, enables crossplay, and disables BepInEx. The published Docker Hub image is not updated by applying this patch.

   ```bash
   docker compose -f docker-compose.yml -f docker-compose.crossplay.yml build --pull valheim
   docker compose stop -t 120 valheim
   # Back up the existing mounted data directory here, while the server is stopped.
   docker compose -f docker-compose.yml -f docker-compose.crossplay.yml up -d --no-deps --force-recreate valheim
   ```

   Run these commands in the same project directory used for the existing server. If it was started with a custom Compose project name (`-p`) or file, keep that project name and use the actual base file. If the existing server was started with `docker run`, use the Docker CLI instructions below instead; this Compose command will not replace it.

3. Check the startup log for `Crossplay is enabled`. The actual game log contains PlayFab connection details and the join code:

   ```bash
   docker compose -f docker-compose.yml -f docker-compose.crossplay.yml logs --tail=100 valheim
   docker compose -f docker-compose.yml -f docker-compose.crossplay.yml exec valheim sh -c 'tail -n 200 "$VALHEIM_DATA_DIR/$VALHEIM_WORLD_NAME-logs.txt"'
   ```

4. Once compatible game updates are available, use **Join Game → Add server** on the Switch 2, enter the server's current join code, then its password. Obtain a fresh code after a restart. Crossplay cannot connect via a local address such as `192.168.x.x` or `127.0.0.1`, even for a player on the host PC. The server must be running and the PC awake.

For an existing **Docker CLI** setup, build with `docker build --pull -t valheim-server:crossplay-local .`, gracefully stop the old container with `docker stop -t 120 <container-name>`, and back up its mounted data. Recreate it from `valheim-server:crossplay-local` with the **same world, password, volume and other settings**, adding `--env VALHEIM_SERVER_CROSSPLAY=1 --env USE_BEPINEX=0`. Merely restarting the old container does not load a new image or environment variables. Preserve the stopped container until the replacement is confirmed working; do not start both against the same data.

Both the server and clients must run compatible public-release versions. A server's Steam auto-update can arrive before a console patch. `VALHEIM_SERVER_UPDATE_ON_START_UP=0` and `VALHEIM_SERVER_AUTO_UPDATE=0` pause future updates of an existing container; they do not downgrade it or pin the game version in a newly built image.

Consoles cannot install client mods. The supplied override sets `USE_BEPINEX=0`; if the world relies on modded content, use a separate unmodded world and data directory for console play instead of loading the modded world without its required mods. A nonempty `permittedlist.txt` also restricts who can join: the host must add the console player's actual ID from the game log if an allowlist is in use. Do not remove existing permissions to troubleshoot.

See Iron Gate's [dedicated server guide](https://www.valheimgame.com/support/a-guide-to-dedicated-servers/), [crossplay FAQ](https://www.valheimgame.com/support/crossplay-faq/), and [1.0 FAQ](https://www.valheimgame.com/support/valheim-1-0-faq/).

### Choose a launch method

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
| `VALHEIM_SERVER_CROSSPLAY`              | 0 (Steam only) or 1 (crossplay)           | 0; crossplay override uses 1 |
| `USE_BEPINEX`                          | 0 (vanilla) or 1 (modded)                 | 0                          |
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

The following environment parameters customize the server's runtime behavior. 2 of these are required to be set, otherwise the container will exit immediately.

* `VALHEIM_SERVER_NAME`: sets the server's name (**required**; spaces are supported).
* `VALHEIM_WORLD_NAME`: sets the world's name (**required**; spaces are supported).
* `VALHEIM_PASSWORD`: sets the server's password.
* `VALHEIM_PORT`: sets the server's port (default is `2456`).  Recommended not to change this.
* `VALHEIM_SERVER_PUBLIC`: allows the server to be listed in the public server list (enabled by default). A value of `0` hides it; use a join code for crossplay or an IP address for Steam-only play.
* `VALHEIM_SERVER_CROSSPLAY`: set to `1` to enable crossplay with consoles and other PC storefronts; defaults to `0` (Steam only). Recreate the container after changing it. Use a join code for crossplay, including when public visibility is disabled.
* `USE_BEPINEX`: set to `1` to enable BepInEx mods; defaults to `0`. Keep `0` for the supplied console configuration.
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
