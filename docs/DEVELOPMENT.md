# Development, testing, and releases


Run from the repository root with Lua 5.4 and Python 3.12:

```sh
python tools/bootstrap.py
python tools/run-tests.py --lua lua5.4
python -m unittest discover -s tests -p 'test_*.py' -v
python tools/package.py
```

Pushes and pull requests compile Lua, run mocked regression tests and package checks,
and upload a ZIP plus SHA-256 checksum as the `mod-package` Actions artifact.
These tests do not run Unreal or certify in-game input, rendering, or persistence.

To publish a release, update the Lua VERSION (and QuickslotsForever metadata when
applicable), commit, and push a branch named `release/vSEMVER`. Supported
prereleases such as `release/v0.3.54-rc.1` are published as prereleases.
The release workflow reruns the checks, rejects a version mismatch, and publishes
the archive and checksum at that exact commit. An existing release/tag is not
silently overwritten. Only the publishing job receives repository write permission.
Opening a pull request never publishes a release. Do not create release branches
until the candidate has passed the required in-game tests.

Artifacts contain only allowlisted mod files; tests, logs, crash dumps, local configuration,
and workspace notes are excluded. No game files or Dawnwalker Mod Menu source are included.

## Related projects

- [QuickslotsForever](https://github.com/jrpereira/BDWQuickslotsForever)
- [ModMenuDecorator](https://github.com/jrpereira/BDWModMenuDecorator)
- [UE4SSLuaEventBridge](https://github.com/jrpereira/UE4SSLuaEventBridge)

Optional local DMM integration check (requires a separately installed DMM; its source is not bundled or required by CI):

```sh
python tools/run-tests.py --lua lua5.4 --dmm-choices "path/to/DawnwalkerModMenu/Scripts/choices.lua"
```

To also validate configuration migration against ModMenuDecorator 0.1.43 or newer:

```sh
python tools/run-tests.py --lua lua5.4 --dmm-choices "path/to/DawnwalkerModMenu/Scripts/choices.lua" --mmd-init-config "path/to/ModMenuDecorator/Scripts/init_config.lua"
```

This exercises legacy configurations, menu values and Apply using in-memory files;
it never edits personal settings or starts the game.
