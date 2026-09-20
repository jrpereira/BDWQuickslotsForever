"""One-shot deployment/launch gate; no gameplay polling or persisted ignore flag."""
import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import stat
import subprocess
import sys

from deployment_preflight import compare, digest, safe_file


PROTECTED_NAMES = {'config.ini', 'enabled.txt', '__folder_managed_by_vortex'}
CONFIG_SUFFIXES = {'.ini', '.json', '.toml', '.cfg'}
PUBLIC_CONFIGS = {'mod_settings.ini', 'config.example.ini'}


def protected(relative):
    name = PurePosixPath(relative).name.casefold()
    return (name in PROTECTED_NAMES
            or (PurePosixPath(name).suffix in CONFIG_SUFFIXES and name not in PUBLIC_CONFIGS))


def validate_manifest(manifest):
    if not isinstance(manifest, dict) or not isinstance(manifest.get('module'), str) or not manifest['module']:
        raise ValueError('Manifest module is required')
    if not isinstance(manifest.get('version'), str) or not manifest['version']:
        raise ValueError('Manifest version is required')
    entries = manifest.get('files')
    if not isinstance(entries, dict) or not entries:
        raise ValueError('Manifest files must be a non-empty object')
    normalized = set()
    for relative, expected in entries.items():
        if not isinstance(relative, str) or not relative:
            raise ValueError('Manifest path must be a non-empty string')
        path = PurePosixPath(relative)
        if path.as_posix() != relative or relative.strip() != relative:
            raise ValueError('Manifest paths must use normalized relative POSIX form')
        safe_file(Path('.'), relative)
        folded = relative.casefold()
        if folded in normalized:
            raise ValueError('Case-insensitive payload path collision')
        normalized.add(folded)
        if folded == 'manifest.json':
            raise ValueError('manifest.json is generated metadata, not a payload entry')
        if not isinstance(expected, str) or not re.fullmatch(r'[0-9a-fA-F]{64}', expected):
            raise ValueError('Manifest hashes must be SHA-256 hex strings')
    return manifest


def is_reparse(path):
    try:
        info = os.lstat(path)
    except FileNotFoundError:
        return False
    return stat.S_ISLNK(info.st_mode) or bool(getattr(info, 'st_file_attributes', 0)
                                              & getattr(stat, 'FILE_ATTRIBUTE_REPARSE_POINT', 0x400))


def checked_file(root, relative):
    target = safe_file(root, relative)
    anchor = root.resolve()
    current = anchor
    for part in PurePosixPath(relative).parts[:-1]:
        current = current / part
        if current.exists() and is_reparse(current):
            raise ValueError('Manifest path traverses a reparse point: '+relative)
    if target.exists() and is_reparse(target):
        raise ValueError('Manifest file is a reparse point: '+relative)
    return target


def read_manifest(path):
    try:
        value = json.loads(path.read_text(encoding='utf-8-sig'))
    except (OSError, json.JSONDecodeError) as error:
        raise ValueError('Invalid installed manifest: '+str(error)) from error
    return validate_manifest(value)


def verify_managed_tree(manifest, deployed):
    installed_path = checked_file(deployed, 'manifest.json')
    installed = read_manifest(installed_path)
    if installed != manifest:
        raise RuntimeError('Installed manifest does not match staged candidate')
    for relative, expected in manifest['files'].items():
        if not protected(relative) and digest(checked_file(deployed, relative)) != expected.lower():
            raise RuntimeError('Installed managed hash mismatch: '+relative)
    return True


def game_session():
    if os.name != 'nt':
        raise RuntimeError('Live process detection requires Windows')
    command = "@(Get-Process -Name Dawnwalker -ErrorAction SilentlyContinue | ForEach-Object { [pscustomobject]@{pid=$_.Id;started_at=$_.StartTime.ToUniversalTime().ToString('o')} }) | ConvertTo-Json -Compress"
    raw = subprocess.check_output(['powershell', '-NoProfile', '-NonInteractive', '-Command', command], text=True, timeout=20).strip()
    value = json.loads(raw) if raw else None
    if isinstance(value, list):
        if len(value) > 1:
            raise RuntimeError('Multiple Dawnwalker processes; resolve before deployment or launch')
        value = value[0] if value else None
    return value


def deploy(manifest, staged, deployed, records, session_provider=game_session):
    """Copy only verified manifest entries; preserve settings and enablement."""
    if session_provider():
        raise RuntimeError('Close the game before deployment, then repeat this command')
    validate_manifest(manifest)
    entries = manifest['files']
    for relative, expected in entries.items():
        if digest(checked_file(staged, relative)) != expected.lower():
            raise ValueError('Staged hash mismatch: '+relative)
        checked_file(deployed, relative)
    staged_manifest = checked_file(staged, 'manifest.json')
    if read_manifest(staged_manifest) != manifest:
        raise ValueError('Staged manifest content differs from deployment manifest')
    installed_manifest = checked_file(deployed, 'manifest.json')
    prior = read_manifest(installed_manifest) if installed_manifest.is_file() else None
    obsolete = {}
    if prior:
        if prior['module'] != manifest['module']:
            raise ValueError('Installed manifest belongs to a different module')
        for relative, expected in prior['files'].items():
            if relative not in entries and not protected(relative):
                target = checked_file(deployed, relative)
                if target.is_file():
                    if digest(target) != expected.lower():
                        raise RuntimeError('Obsolete managed file was modified locally: '+relative)
                    obsolete[relative] = expected.lower()
    records = records.resolve()
    if records.is_relative_to(deployed.resolve()) or records.is_relative_to(staged.resolve()):
        raise ValueError('Keep deployment records outside payload roots')
    backup = records / datetime.now(timezone.utc).strftime('deploy-%Y%m%dT%H%M%S%fZ')
    backup.mkdir(parents=True, exist_ok=False)
    original = {}
    if deployed.exists():
        for path in deployed.rglob('*'):
            if path.is_symlink():
                raise ValueError('Review deployed symlink before copying: '+str(path))
            if path.is_file():
                relative = path.relative_to(deployed).as_posix()
                original[relative] = digest(path)
                target = safe_file(backup/'before', relative)
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(path, target)
                if digest(target) != original[relative]:
                    raise RuntimeError('Backup verification failed: '+relative)
    state = {'module': manifest['module'], 'version': manifest['version'], 'before': original,
             'payload': entries, 'changed': [], 'removed': [], 'status': 'backed-up'}
    def record():
        (backup/'result.json').write_text(json.dumps(state, indent=2)+'\n', encoding='utf-8')
    record()
    affected = {relative for relative in entries if not protected(relative)} | set(obsolete) | {'manifest.json'}
    def rollback():
        errors = []
        for relative in sorted(affected):
            try:
                target = checked_file(deployed, relative)
                if relative in original:
                    source = checked_file(backup/'before', relative)
                    target.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(source, target)
                    if digest(target) != original[relative]:
                        raise RuntimeError('restored hash mismatch')
                elif target.exists():
                    if not target.is_file():
                        raise RuntimeError('rollback target is not a file')
                    target.unlink()
            except Exception as rollback_error:
                errors.append(relative+': '+str(rollback_error))
        return errors
    try:
        for relative, expected in entries.items():
            if protected(relative):
                continue
            expected = expected.lower()
            if session_provider():
                raise RuntimeError('Game started during deployment; stop and review the recorded partial deployment')
            target = checked_file(deployed, relative)
            if digest(target) != original.get(relative):
                raise RuntimeError('Concurrent destination change: '+relative)
            if digest(target) != expected:
                source = checked_file(staged, relative)
                if digest(source) != expected:
                    raise RuntimeError('Staged file changed during deployment: '+relative)
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(source, target)
                state['changed'].append(relative)
            if digest(target) != expected:
                raise RuntimeError('Installed hash mismatch: '+relative)
        for relative, expected in obsolete.items():
            if session_provider():
                raise RuntimeError('Game started during deployment; stop and review the recorded partial deployment')
            target = checked_file(deployed, relative)
            if target.is_file():
                if digest(target) != original.get(relative) or digest(target) != expected:
                    raise RuntimeError('Concurrent obsolete-file change: '+relative)
                target.unlink()
                state['removed'].append(relative)
        for relative, expected in original.items():
            if relative not in affected:
                if digest(checked_file(deployed, relative)) != expected:
                    raise RuntimeError('Preserved file changed: '+relative)
        if session_provider():
            raise RuntimeError('Game started during deployment; stop and review the recorded partial deployment')
        if digest(installed_manifest) != original.get('manifest.json'):
            raise RuntimeError('Concurrent installed manifest change')
        installed_manifest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(staged_manifest, installed_manifest)
        if digest(installed_manifest) != digest(staged_manifest):
            raise RuntimeError('Installed manifest hash mismatch')
        verify_managed_tree(manifest, deployed)
        state['status'] = 'deployed'
        record()
    except Exception as error:
        rollback_errors = rollback()
        state['status'] = 'incomplete'
        state['error'] = str(error)
        state['rollback'] = 'failed' if rollback_errors else 'complete'
        if rollback_errors:
            state['rollback_errors'] = rollback_errors
        record()
        if rollback_errors:
            raise RuntimeError(str(error)+'; rollback failed: '+'; '.join(rollback_errors)) from error
        raise
    return backup


def launch(result, command, ignore_once=False, session_provider=game_session, runner=subprocess.Popen):
    if session_provider():
        raise RuntimeError('Game is already running; inspect that session instead')
    if result['needs_attention'] and not ignore_once:
        raise RuntimeError('Version check needs attention: correct the mismatch or choose --ignore-once for this launch')
    if not command:
        raise ValueError('Supply the game executable and arguments after --')
    return runner(command, shell=False)


def inspect_candidate(manifest, staged, deployed, working, session=None):
    if 'native_provenance' in manifest:
        from native_candidate import validate, version
        changes = validate(manifest, working)
        result = compare(manifest, staged, deployed, session, working_version=version(working))
        result['working_differences'] = changes
        if changes:
            result['needs_attention'] = True
            result['options'] = ['Rebuild current native source with native_candidate.py, then repeat verification.',
                                 'Ignore this discrepancy for this launch only; retain the warning in the test record.']
        return result
    from package_manifest import definition, version
    spec = definition(working)
    if manifest['module'] != spec['module'] or set(manifest['files']) != set(spec['files']):
        raise ValueError('Candidate must match the current module and complete release definition')
    return compare(manifest, staged, deployed, session, working, spec, version(working))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['check', 'deploy', 'launch'])
    for name in ['manifest', 'staged', 'deployed', 'working', 'records']:
        parser.add_argument('--'+name, type=Path, required=True)
    parser.add_argument('--ignore-once', action='store_true')
    argv = sys.argv[1:]
    split = argv.index('--') if '--' in argv else len(argv)
    args = parser.parse_args(argv[:split])
    command = argv[split+1:]
    if command and args.action != 'launch':
        parser.error('Unexpected arguments')
    if args.ignore_once and args.action != 'launch':
        parser.error('--ignore-once applies only to one launch')
    manifest = json.loads(args.manifest.read_text(encoding='utf-8-sig'))
    current_session = game_session()
    result = inspect_candidate(manifest, args.staged, args.deployed, args.working, current_session)
    print(json.dumps(result, indent=2))
    args.records.mkdir(parents=True, exist_ok=True)
    record = args.records / datetime.now(timezone.utc).strftime('preflight-%Y%m%dT%H%M%S%fZ.json')
    record.write_text(json.dumps({'action': args.action, 'ignore_once': args.ignore_once, 'result': result}, indent=2)+'\n')
    if args.action == 'deploy':
        if result['stage_integrity_errors'] or result['working_differences'] or result['staged_version_differs_from_working']:
            raise RuntimeError('Rebuild/restage current working source before deployment')
        print(deploy(manifest, args.staged, args.deployed, args.records))
    elif args.action == 'launch':
        launch(result, command, args.ignore_once)
    else:
        return 2 if result['needs_attention'] else 0
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
