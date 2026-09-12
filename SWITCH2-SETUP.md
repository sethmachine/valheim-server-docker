# Switch 2 crossplay setup

The Dockerfile and launcher support opt-in crossplay, while the updater installs the selected Steam branch. The included `docker-compose.switch2.yml` enables crossplay and the temporary `default_old` workaround described in the September 11, 2026 developer announcement linked below.

Crossplay requires `VALHEIM_CROSSPLAY=1`. The updater previously always fetched the public Steam branch, which could also undo a manual downgrade during a console patch delay. The override selects the compatible branch for both the image build and runtime updates.

## Build and run on the server PC

Use a checkout containing these changes and your existing Compose configuration. Keep your current world name, saved-data mount, and credentials instead of substituting this repository's sample values. Commands below assume your Compose file is named `docker-compose.yml` and the service is `valheim`.

1. Build the patched image while the current server continues running:

   ```sh
   docker compose -f docker-compose.yml -f docker-compose.switch2.yml build valheim
   ```

2. Have players disconnect, then stop the server gracefully:

   ```sh
   docker compose -f docker-compose.yml stop -t 120 valheim
   ```

3. Make a backup copy of the **entire existing save-data directory** on the PC before switching game versions. Keep that copy outside the Docker build folder. This includes modern world subdirectories and older `.db`/`.fwl` files. Keep the original directory mounted at `/home/steam/valheim-data`.

4. Start the patched server using the merged configuration:

   ```sh
   docker compose -f docker-compose.yml -f docker-compose.switch2.yml up -d --no-deps valheim
   docker compose -f docker-compose.yml -f docker-compose.switch2.yml logs --tail=80 valheim
   ```

   Allow time for Steam to install/verify the selected branch. An unavailable branch causes startup to stop with an error rather than fall back to `public`.

## Get the join code and connect

This wrapper writes the actual game output to a world log in its mounted data directory. To show recent connection-related lines:

```sh
docker compose -f docker-compose.yml -f docker-compose.switch2.yml exec valheim bash -lc 'tail -n 200 "$VALHEIM_DATA_DIR/$VALHEIM_WORLD_NAME-logs.txt" | grep -Ei "join code|PlayFab|game server connected|version|failed|error"'
```

Alternatively, join the world on PC, press Esc, and copy the join code from the pause menu. On Switch 2, use **Join Game → Add server** and enter that code. Each Steam player's game must also use the compatible `default_old` branch under **Properties → Game Versions & Betas** for this temporary workaround.

The override disables BepInEx for this connection check. Worlds that depend on mods should be tested on a backup copy first.

## What the override changes

```yaml
VALHEIM_CROSSPLAY: "1"
VALHEIM_SERVER_BRANCH: default_old
VALHEIM_SERVER_UPDATE_ON_START_UP: "1"
VALHEIM_SERVER_AUTO_UPDATE: "0"
USE_BEPINEX: "0"
```

The build uses `default_old` too. Startup verifies that branch, while periodic automatic updates stay off. `default_old` is a moving branch: a future restart/rebuild can install a newer build from it. Verify compatibility again after future patches.

## Return to current releases

Once Switch 2 receives the compatible update, change **both** `VALHEIM_SERVER_BRANCH` entries in `docker-compose.switch2.yml` (build argument and environment) to `public`, set `VALHEIM_SERVER_AUTO_UPDATE` to `"1"` if desired, rebuild, back up, and recreate using the same commands. Keep `VALHEIM_CROSSPLAY` enabled. Steam players should return their clients to the current public release too.

## Verification and limits

Run script checks with `python3 -m unittest discover -s tests -v`. They use fake SteamCMD responses and a fake server executable; they do not connect to Steam, touch real saves, or read credentials. Compose can be checked with `docker compose -f docker-compose.yml -f docker-compose.switch2.yml config --quiet`.

A real Docker build, Switch-to-server connection, and graceful shutdown/save must also be tested on the host PC before using the image with an existing world.

Sources: [official dedicated-server guide](https://www.valheimgame.com/support/a-guide-to-dedicated-servers/), [crossplay FAQ](https://www.valheimgame.com/support/crossplay-faq/), and [September 11 hotfix/workaround announcement](https://store.steampowered.com/oldnews/?appgroupname=Valheim&appids=892970&feed=steam_community_announcements).
