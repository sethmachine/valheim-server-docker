# valheim-server-docker

This repo provides a Dockerfile that builds an image which runs a Valheim server.  Using Docker allows for running the server on most operating systems, including macOS (which is not supported by the Valheim game at all).  The custom server start script `start-valheim-server.sh` provides a mechanism to gracefully shut down a running Valheim server when using `docker stop`.  This is necessary so world data is properly saved back to disk.

Note you will still need to forward and open ports 2456, 2457, and 2458 (UDP protocol) on the host machine for the server to be listed and accessible.

If you find this repo useful, I'd love to hear back in a note how you're using it.  If you use this repo to build on your own work, please provide a reference back to this repo's URL.

Built images are provided on Docker Hub: [sethmachineio/valheim-server:latest](https://hub.docker.com/r/sethmachineio/valheim-server)

I also have written a complete guide here that covers how to set up your own dedicated server at home: [Valheim Dedicated Server at Home Guide](https://sethmachine.gitlab.io/2021/02/11/host-valheim-with-docker/).

## Usage

You have two possibilities to run the container:

- Docker CLI

- Docker Compose

When wanting to save your configuration easily, for the sake of backups,
easier editing, or transport, use `docker-compose`.

### Docker Compose

Clone the repo, edit the `docker-compose.yml` to your liking, and run
the container in the background using `docker-compose up -d`. In order
to stop the container, run `docker-compose down`. Remember to restart
your container after editing the config.

| **Variables**               | **Possible Values**                       | **Default**                            |
|-----------------------------|-------------------------------------------|----------------------------------------|
| `user`                      | Any UUID and GUID                         | 1000:1000                              |
| `ports`                     | Any port, keep default internal ports     | Same internal and external             |
| `volumes`: 'valheim-data'   | Any path on your local system             | `./valheim-data`                       |
| `volumes`: 'valheim-server' | Any path on your local system             | `./valheim-server`                     |
| `VALHEIM_SERVER_NAME`       | Any string                                | "MyServer"                             |
| `VALHEIM_WORLD_NAME`        | Any string                                | "NewWorld"                             |
| `VALHEIM_PASSWORD`          | Any string                                | "password"                             |
| `VALHEIM_PUBLIC`            | 0 or 1 (0 = server will not be listed)    | 1 (means server will be listed ingame) |


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

There are 5 environment parameters to customize the server's runtime behavior.  2 of these are required to be set, otherwise the container will exit immediately.

* `VALHEIM_SERVER_NAME`: sets the server's name (**required**, truncated at first whitespace).
* `VALHEIM_WORLD_NAME`: sets the world's name (**required**, truncated at first whitespace).
* `VALHEIM_PASSWORD`: sets the server's password.
* `VALHEIM_PORT`: sets the server's port (default is `2456`).  Recommended not to change this.
* `VALHEIM_PUBLIC`: Specify, if the server should be listed ingame in Valheim's server list. (0 means it will not be listed; 1 means it will be listed)

Below is an example command to run the server as a Docker container that restarts automatically whenever it is stopped:

```bash
docker run --name=valheim -d \
--restart always \
-p 2456:2456/udp -p 2457:2457/udp -p 2458:2458/udp \
-v /home/sethmachine/valheim-data:/home/steam/valheim-data \
-v /home/sethmachine/valheim-server:/home/steam/valheim-server \
--env VALHEIM_SERVER_NAME="sethmachine'sServer" \
--env VALHEIM_WORLD_NAME="AWholeNewWorld" \
--env VALHEIM_PASSWORD="HardToGuessPassword" \
--env VALHEIM_PUBLIC=1 \
sethmachineio/valheim-server
```

After running for the 1st time, the banlist, permitted list, and admin list will be created if they do not already exist in the host's directory.  There will also be a world specific log file.

```bash
├── AWholeNewWorld-logs.txt
├── adminlist.txt
├── bannedlist.txt
├── permittedlist.txt
└── worlds
    ├── AWholeNewWorld.db
    ├── AWholeNewWorld.fwl
```

Explanation:

* `AWholeNewWorld-logs.txt`: this is a Valheim specific log file for the world we created
* `adminlist.txt`: determines who is an admin (add Steam ID, one per line)
* `bannedlist.txt`: automatically bans players (add Steam ID, one per line)
* `permittedlist.txt`: whitelist for who can join (add Steam ID, one per line).  Note if this has a single Steam ID in it, this will ban everyone else from the server besides players whose Steam ID is in this list.

## Logs

Two different logs are provided: from the custom start script and from Valheim specific logging.

Access the custom start script log by running `docker logs <containerID>`:

```bash
sethmachine valheim-server-docker % docker logs valheim
Starting server PRESS CTRL-C to exit
LD_LIBRARY_PATH: ./linux64:
Valheim port is: 2456
Valheim server name is: sethmachine's server
Valheim world name is: AWholeNewWorld
Valheim server PID is: 7
```

Access world specific Valheim logs from the \<WorldName\>-logs.txt created in the host's directory:

```bash
sethmachine valheim-server-docker % tail -f /home/sethmachine/valheim-data/AWholeNewWorld-logs.txt
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


## Known Issues

* The server does not update itself automatically.  When Valheim releases a new client/server, they don't appear to be backwards compatible, so once a player updates their game, they may not be able to join the server.  The work around is to manually trigger a rebuild of the Docker image, stop the server, delete the container, pull the image again, and then re-run the server.  In future I'll add support for automatic updates so you don't have to do this manual process.
