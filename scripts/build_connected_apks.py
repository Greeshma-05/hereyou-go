#!/usr/bin/env python3
"""Build all three APKs with one verified, public, non-secret service address."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import ssl
import subprocess
import urllib.error
import urllib.parse
import urllib.request

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('url', help='Deployed HTTPS /fulfillment URL')
parser.add_argument('--flutter', default=os.environ.get('FLUTTER_BIN', 'flutter'))
args = parser.parse_args()
url = urllib.parse.urlsplit(args.url)
if (url.scheme != 'https' or not url.hostname or url.username or url.password
        or url.query or url.fragment or url.path != '/fulfillment'):
    parser.error('Use the deployed HTTPS /fulfillment URL without credentials or query parameters.')
tls = ssl.create_default_context()
# Python.org macOS installs can lack a default CA bundle. Use the operating
# system's CA bundle when available; certificate verification stays enabled.
if not ssl.get_default_verify_paths().cafile and Path('/etc/ssl/cert.pem').is_file():
    tls.load_verify_locations(cafile='/etc/ssl/cert.pem')
with urllib.request.urlopen(urllib.parse.urlunsplit(url._replace(path='/healthz')), timeout=120, context=tls) as response:
    if json.load(response) != {'status': 'ok'}:
        raise SystemExit('The order service health check failed.')
request = urllib.request.Request(args.url, data=b'{"data":{"action":"nearby"}}',
                                 headers={'Content-Type': 'application/json'})
try:
    urllib.request.urlopen(request, timeout=120, context=tls)
except urllib.error.HTTPError as error:
    if error.code != 401 or json.load(error).get('error', {}).get('status') != 'UNAUTHENTICATED':
        raise SystemExit('The order service did not enforce Firebase authentication.')
else:
    raise SystemExit('Refusing to build against an endpoint that accepts unauthenticated requests.')

root = Path(__file__).resolve().parent.parent
output = root / 'releases' / 'connected'
output.mkdir(parents=True, exist_ok=True)
manifest = {'fulfillmentUrl': args.url, 'apks': []}
for folder, name in [('.', 'customer'), ('vendor_app', 'vendor'), ('delivery_app', 'delivery')]:
    project = root / folder
    subprocess.run([args.flutter, 'build', 'apk', '--release',
                    f'--dart-define=FULFILLMENT_URL={args.url}'], cwd=project, check=True)
    version = next(line.split(':', 1)[1].strip() for line in (project / 'pubspec.yaml').read_text().splitlines()
                   if line.startswith('version:'))
    destination = output / f'here-you-go-{name}-{version.split("+")[0]}.apk'
    shutil.copy2(project / 'build/app/outputs/flutter-apk/app-release.apk', destination)
    manifest['apks'].append({'file': destination.name, 'version': version,
                              'sha256': hashlib.sha256(destination.read_bytes()).hexdigest()})
(output / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
print(f'Connected APKs: {output}')
