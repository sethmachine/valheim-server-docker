"""Exercise the real shell entrypoints with disposable fake game/Steam executables."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
APP_INFO = '''
"896660"
{
    "depots"
    {
        "branches"
        {
            "public"
            {
                "buildid" "200"
            }
            "default_old"
            {
                "description" "Previous release"
                "timeupdated" "1234567890"
                "buildid" "100"
            }
        }
    }
}
'''


class ServerTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="valheim test ")
        self.addCleanup(self.tmp.cleanup)
        self.base = Path(self.tmp.name)
        self.server = self.base / "server files"
        self.data = self.base / "world data"
        self.steam = self.base / "steam"
        self.cmd = self.base / "steamcmd"
        for path in (self.server / "steamapps", self.data, self.steam / "b-log", self.cmd):
            path.mkdir(parents=True)
        for name in ("start-valheim-server.sh", "update-valheim-server.sh",
                     "shutdown-valheim-server.sh", "valheim-server-entrypoint.sh"):
            shutil.copy2(ROOT / name, self.server / name)
        (self.steam / "b-log/b-log.sh").write_text('''
LOG_LEVEL_ALL() { :; }
INFO() { printf '%s\\n' "$*"; }
WARN() { printf '%s\\n' "$*"; }
ERROR() { printf '%s\\n' "$*"; }
FATAL() { printf '%s\\n' "$*"; }
''')
        fake_server = self.server / "valheim_server.x86_64"
        fake_server.write_text('''#!/usr/bin/env python3
import json, os, sys
from pathlib import Path
Path(os.environ["GAME_ARGS"]).write_text(json.dumps(sys.argv[1:]))
print("Game server connected; join code 123456")
''')
        fake_server.chmod(0o755)
        (self.cmd / "steamcmd.sh").write_text('python3 "$FAKE_STEAM_HELPER" "$@"\n')
        helper = self.base / "fake_steam.py"
        helper.write_text('''import json, os, sys
from pathlib import Path
args = sys.argv[1:]
with open(os.environ["STEAM_CALLS"], "a") as log:
    log.write(json.dumps(args) + "\\n")
if "+app_info_print" in args:
    print(Path(os.environ["APP_INFO_FILE"]).read_text())
    sys.exit(int(os.environ.get("QUERY_EXIT", "0")))
if "+app_update" in args:
    if os.environ.get("UPDATE_EXIT"):
        sys.exit(int(os.environ["UPDATE_EXIT"]))
    branch = args[args.index("-beta") + 1]
    build = os.environ.get("INSTALL_BUILD", "100" if branch == "default_old" else "200")
    manifest = Path(os.environ["VALHEIM_SERVER_DIR"]) / "steamapps/appmanifest_896660.acf"
    manifest.write_text('"buildid" "' + build + '"\\n"BetaKey" "' + branch + '"\\n')
''')
        self.info = self.base / "app-info.vdf"
        self.info.write_text(APP_INFO)
        self.env = dict(os.environ, STEAM_DIR=str(self.steam), STEAMCMD_DIR=str(self.cmd),
                        VALHEIM_SERVER_DIR=str(self.server), VALHEIM_DATA_DIR=str(self.data),
                        VALHEIM_SERVER_APP_ID="896660", VALHEIM_SERVER_BRANCH="default_old",
                        VALHEIM_CROSSPLAY="1", VALHEIM_SERVER_NAME="Friends Server",
                        VALHEIM_WORLD_NAME="Existing World", VALHEIM_PASSWORD="synthetic test value",
                        VALHEIM_PORT="2456", VALHEIM_SERVER_PUBLIC="1", USE_BEPINEX="0",
                        VALHEIM_SERVER_UPDATE_ON_START_UP="1", VALHEIM_SERVER_AUTO_UPDATE="0",
                        GAME_ARGS=str(self.base / "game-args.json"), STEAM_CALLS=str(self.base / "steam-calls.jsonl"),
                        APP_INFO_FILE=str(self.info), FAKE_STEAM_HELPER=str(helper),
                        LD_LIBRARY_PATH="")
        self.write_manifest("200", "public")

    def write_manifest(self, build, branch):
        (self.server / "steamapps/appmanifest_896660.acf").write_text(
            f'"buildid" "{build}"\n"BetaKey" "{branch}"\n')

    def shell(self, code):
        return subprocess.run(["bash", "-c", code], cwd=self.server, env=self.env,
                              text=True, capture_output=True, timeout=10)

    def entrypoint(self):
        return self.shell('exec bash ./valheim-server-entrypoint.sh')

    def calls(self):
        path = Path(self.env["STEAM_CALLS"])
        return [json.loads(line) for line in path.read_text().splitlines()] if path.exists() else []

    def updates(self):
        return [args for args in self.calls() if "+app_update" in args]

    def test_crossplay_and_arguments_with_spaces(self):
        for crossplay in ("1", "0"):
            with self.subTest(crossplay=crossplay):
                self.env["VALHEIM_CROSSPLAY"] = crossplay
                result = self.entrypoint()
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                args = json.loads(Path(self.env["GAME_ARGS"]).read_text())
                self.assertEqual("-crossplay" in args, crossplay == "1")
                for flag, value in (("-name", "Friends Server"), ("-world", "Existing World"),
                                    ("-savedir", str(self.data)), ("-password", "synthetic test value")):
                    self.assertEqual(args[args.index(flag) + 1], value)
                self.assertNotIn("synthetic test value", result.stdout + result.stderr)
                self.assertIn("join code", (self.data / "Existing World-logs.txt").read_text())

    def test_downgrade_installs_selected_branch_before_start(self):
        result = self.entrypoint()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(len(self.updates()), 1)
        args = self.updates()[0]
        self.assertEqual(args[args.index("-beta") + 1], "default_old")
        self.assertLess(args.index("+force_install_dir"), args.index("+login"))
        self.assertTrue(Path(self.env["GAME_ARGS"]).exists())

    def test_crossplay_remains_opt_in_without_switch_override(self):
        self.env.pop("VALHEIM_CROSSPLAY")
        result = self.entrypoint()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        args = json.loads(Path(self.env["GAME_ARGS"]).read_text())
        self.assertNotIn("-crossplay", args)

    def test_matching_branch_does_not_download_again(self):
        self.write_manifest("100", "default_old")
        result = self.entrypoint()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(self.updates(), [])

    def test_branch_switch_with_identical_build_still_applies_beta(self):
        self.write_manifest("100", "public")
        result = self.entrypoint()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(len(self.updates()), 1)

    def test_return_to_public_explicitly_resets_beta(self):
        self.write_manifest("100", "default_old")
        self.env["VALHEIM_SERVER_BRANCH"] = "public"
        result = self.entrypoint()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        args = self.updates()[0]
        self.assertEqual(args[args.index("-beta") + 1], "public")

    def test_missing_branch_does_not_fall_back_or_launch(self):
        self.info.write_text(APP_INFO.replace('"default_old"', '"another_branch"'))
        result = self.entrypoint()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.updates(), [])
        self.assertFalse(Path(self.env["GAME_ARGS"]).exists())
        self.assertIn("no fallback to public", result.stdout)

    def test_query_failure_does_not_stop_running_server(self):
        self.env["QUERY_EXIT"] = "1"
        result = self.shell('''
source "$STEAM_DIR/b-log/b-log.sh"
source ./update-valheim-server.sh
shutdownValheimServer() { echo "UNEXPECTED_SHUTDOWN"; }
checkForAndUpdateValheimServer
''')
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("UNEXPECTED_SHUTDOWN", result.stdout)
        self.assertEqual(self.updates(), [])

    def test_periodic_check_does_not_upgrade_old_branch_to_public(self):
        self.write_manifest("100", "default_old")
        result = self.shell('''
source "$STEAM_DIR/b-log/b-log.sh"
source ./update-valheim-server.sh
shutdownValheimServer() { echo "UNEXPECTED_SHUTDOWN"; }
startValheimServer() { echo "UNEXPECTED_RESTART"; }
checkForAndUpdateValheimServer
''')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertNotIn("UNEXPECTED_", result.stdout)
        self.assertEqual(self.updates(), [])

    def test_failed_install_does_not_launch_wrong_version(self):
        for key, value in (("UPDATE_EXIT", "1"), ("INSTALL_BUILD", "999")):
            with self.subTest(failure=key):
                self.env[key] = value
                result = self.entrypoint()
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse(Path(self.env["GAME_ARGS"]).exists())
                self.env.pop(key)

    def test_invalid_configuration_is_rejected_before_steam(self):
        for key, value in (("VALHEIM_SERVER_BRANCH", "bad branch"), ("VALHEIM_CROSSPLAY", "yes")):
            with self.subTest(setting=key):
                previous = self.env[key]
                self.env[key] = value
                result = self.entrypoint()
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(self.calls(), [])
                self.assertFalse(Path(self.env["GAME_ARGS"]).exists())
                self.env[key] = previous


if __name__ == "__main__":
    unittest.main()
