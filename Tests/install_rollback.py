"""Opt-in integration check: deliberately fail registration and verify recovery."""
import os
from pathlib import Path
import subprocess
import sys
import tempfile

if sys.argv[1:] != ['--installed-app-test']:
    raise SystemExit('Use --installed-app-test to exercise the installed independent app.')
root = Path(__file__).resolve().parents[1]
installed = Path('/Applications/Markdown Quick Look.app')
info = installed / 'Contents/Info.plist'
before = info.read_bytes()
with tempfile.TemporaryDirectory(prefix='markdown-rollback-') as temporary:
    directory = Path(temporary)
    wrapper = directory / 'pluginkit'
    wrapper.write_text('''#!/bin/bash
if [[ "$1" == '-a' && ! -e "$ROLLBACK_MARKER" ]]; then
  touch "$ROLLBACK_MARKER"
  echo 'Injected registration failure for rollback verification' >&2
  exit 73
fi
exec /usr/bin/pluginkit "$@"
''')
    wrapper.chmod(0o755)
    env = dict(os.environ, PATH=f'{directory}:' + os.environ['PATH'], ROLLBACK_MARKER=str(directory / 'failed'))
    result = subprocess.run(['bash', 'Scripts/install.sh'], cwd=root, env=env, capture_output=True, text=True)
    (root / 'build/rollback-test.log').write_text(result.stdout + result.stderr)
    assert result.returncode != 0, 'Injected failure must remain visible'
    assert (directory / 'failed').exists(), 'Registration failure was exercised'
    assert info.read_bytes() == before, 'Previous installed app must be restored'
    subprocess.run(['codesign', '--verify', '--deep', '--strict', str(installed)], check=True)
    print('Registration failure returned nonzero; previous signed app restored.')
