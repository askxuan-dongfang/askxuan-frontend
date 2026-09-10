#!/usr/bin/env bash
# Build all four Web clients from exact Git archives; keep existing services and data.
# Usage: bash deploy-web.sh RELEASE FRONTEND_SHA H5_SHA
set -euo pipefail
umask 077
release="${1:?release}"; frontend_sha="${2:?frontend SHA}"; h5_sha="${3:?H5 SHA}"
[[ "$release" =~ ^[a-zA-Z0-9-]+$ && "$frontend_sha" =~ ^[0-9a-f]{7,40}$ && "$h5_sha" =~ ^[0-9a-f]{7,40}$ ]]
base=/opt/askxuan
candidate="$base/runtime/$release"; backup="$base/backups/$release"
public="/var/www/askxuan/releases/$release/public"
previous=$(readlink -f /var/www/askxuan/public)
test -s "$previous/index.html"
test ! -e "$candidate"
test ! -e "$public"
mkdir -p "$candidate/frontend/apps/web-h5" "$backup" "$public"
printf '%s\n' "$previous" > "$backup/previous-public"
previous_release=$(basename "$(dirname "$previous")")
cp "$base/runtime/$previous_release/release.txt" "$backup/previous-release.txt"
tar --exclude=node_modules --exclude=dist --exclude=build --exclude=Pods --exclude=.git --exclude=logs --exclude=artifacts -czf "$backup/frontend-before.tar.gz" -C "$base/frontend" .
tar -xzf "$base/runtime/askxuan-frontend-$frontend_sha.tar.gz" -C "$candidate/frontend"
tar -xzf "$base/runtime/askxuan-h5-source-$h5_sha.tar.gz" -C "$candidate/frontend/apps/web-h5"
node_image="${ASKXUAN_NODE_IMAGE:-node:22-bookworm-slim}"
if ! docker image inspect "$node_image" >/dev/null 2>&1; then node_image=askxuan/taibu-mcp:local; fi
docker image inspect "$node_image" >/dev/null
for app in web-h5 web-platform-admin web-shop-admin web-temple-admin; do
 docker run --rm --user 0:0 -v "$candidate/frontend:/workspace" -v "$base/runtime/npm-cache:/root/.npm" -w "/workspace/apps/$app" "$node_image" sh -c 'npm ci --registry=https://registry.npmmirror.com && npm run build' > "$candidate/build-$app.log" 2>&1
 test -s "$candidate/frontend/apps/$app/dist/index.html"
 echo "BUILT $app"
done
cp -a "$previous/." "$public/"
cp -a "$candidate/frontend/apps/web-h5/dist/." "$public/"
for pair in 'web-platform-admin admin' 'web-shop-admin shop' 'web-temple-admin temple'; do
 read -r app target <<< "$pair"
 mkdir -p "$public/$target"
 cp -a "$candidate/frontend/apps/$app/dist/." "$public/$target/"
 cmp "$public/$target/index.html" "$candidate/frontend/apps/$app/dist/index.html"
done
chmod -R a+rX "/var/www/askxuan/releases/$release"
nginx -t
curl -fsS http://127.0.0.1:8080/api/v1/health > "$candidate/gateway-health.json"
rollback() {
 trap - ERR
 ln -s "$previous" "/var/www/askxuan/public.rollback-$release"
 mv -Tf "/var/www/askxuan/public.rollback-$release" /var/www/askxuan/public
 tar -xzf "$backup/frontend-before.tar.gz" -C "$base/frontend"
 echo ROLLED_BACK >&2
}
trap rollback ERR
ln -s "$public" "/var/www/askxuan/public.next-$release"
mv -Tf "/var/www/askxuan/public.next-$release" /var/www/askxuan/public
tar -xzf "$base/runtime/askxuan-frontend-$frontend_sha.tar.gz" -C "$base/frontend"
tar -xzf "$base/runtime/askxuan-h5-source-$h5_sha.tar.gz" -C "$base/frontend/apps/web-h5"
python3 - "$backup/previous-release.txt" "$candidate/release.txt" "$release" "$frontend_sha" "$h5_sha" "$previous_release" <<'PY'
from pathlib import Path
import sys
old,new,release,frontend,h5,parent=sys.argv[1:]
values=dict(line.split('=',1) for line in Path(old).read_text().splitlines() if '=' in line)
values.update(release=release,frontend=frontend,h5=h5,ios_frontend=frontend,inherited_from=parent)
Path(new).write_text(''.join(f'{k}={v}\n' for k,v in values.items()))
PY
cmp "$public/index.html" "$candidate/frontend/apps/web-h5/dist/index.html"
touch "$candidate/DEPLOYED"
trap - ERR
echo "DEPLOYED $release"
