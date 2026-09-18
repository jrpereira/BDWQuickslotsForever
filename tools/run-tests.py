"""Run current production acceptance; historical probe suites are not selected."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
TESTS = ['audit_regressions','inventory_navigation','shortcut_targets','routing_lifecycle','suppression_events','widget_setup','config_notifications','startup_lifecycle','persistent_input','action_indicators','runtime_suppression','native_wheel_wiring','inventory_context_hooks','nondebug_bindings','suppression_targets','event_work','event_integration','performance_regression','hot_path','quickslot_scope','object_paths','wheel_layout']

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--lua', default=os.environ.get('LUA') or shutil.which('lua5.4') or shutil.which('lua'))
    parser.add_argument('--dmm-choices', help='Optional external DawnwalkerModMenu choices.lua for integration contract check')
    args = parser.parse_args()
    if not args.lua:
        parser.error('Lua 5.4 is required; set LUA or pass --lua')
    import json
    manifest = json.loads((ROOT / 'release-manifest.json').read_text())
    failed = []
    for rel in manifest['files'].values():
        if rel.endswith('.lua'):
            env = dict(os.environ, QSF_SYNTAX_FILE=str(ROOT / rel))
            result = subprocess.run([args.lua, '-e', 'assert(loadfile(os.getenv("QSF_SYNTAX_FILE")))'], cwd=ROOT, env=env)
            if result.returncode:
                failed.append('syntax:' + rel)
    for name in TESTS:
        command = [args.lua, f'tests/{name}_test.lua']
        if name == 'wheel_layout' and args.dmm_choices:
            command.append(str(Path(args.dmm_choices).resolve()))
        result = subprocess.run(command, cwd=ROOT)
        if result.returncode:
            failed.append(name)
    print('FAILED: ' + ', '.join(failed) if failed else f'PASS: {len(TESTS)} current Lua suites and {sum(p.endswith(".lua") for p in manifest["files"].values())} runtime syntax checks')
    if not args.dmm_choices:
        print('External DMM parser/model contract was not exercised; supply --dmm-choices for that integration check.')
    return bool(failed)

if __name__ == '__main__':
    raise SystemExit(main())
