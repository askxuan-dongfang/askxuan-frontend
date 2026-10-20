#!/usr/bin/env python3
"""Local in-memory DIY acceptance fixture. No remote writes or credentials.

--catalog is a local JSON response captured from the public material GET endpoint.
All edits affect synthetic designs in this process only. Restart resets them.
"""
import argparse
import importlib.util
import json
from pathlib import Path
from http.server import ThreadingHTTPServer
from urllib.parse import urlparse, parse_qs

spec = importlib.util.spec_from_file_location("parity_fixture", Path(__file__).with_name("native-parity-fixture.py"))
base = importlib.util.module_from_spec(spec)
spec.loader.exec_module(base)
DESIGNS = {}
CATALOG = {}
SEARCH_ROWS = {}
POST_FAILURES = 1

class Handler(base.Handler):
    def do_GET(self):
        global POST_FAILURES
        url = urlparse(self.path)
        path = url.path
        params = parse_qs(url.query)
        if path in SEARCH_ROWS:
            rows = SEARCH_ROWS[path]
            if params.get("manageBy"):
                rows = [row for row in rows if row.get("manageBy", "platform") == params["manageBy"][0]]
            for key in ["regionCode", "beliefCode"]:
                if params.get(key): rows = [row for row in rows if row.get(key) == params[key][0]]
            if params.get("traditionCode"):
                rows = [row for row in rows if params["traditionCode"][0] in row.get("traditionCodes", [])]
            number = int(params.get("page", ["1"])[0])
            size = min(2, int(params.get("size", ["2"])[0]))
            return self.respond({"list": rows[(number - 1) * size:number * size], "total": len(rows), "page": number, "size": size})
        if path == "/api/v1/community/feed" and POST_FAILURES > 0:
            POST_FAILURES -= 1
            return self.respond({}, 503)
        if path == "/api/v1/diy/materials": return self.respond(CATALOG)
        if path == "/api/v1/diy/designs": return self.respond(base.page([d for d in DESIGNS.values() if d["status"] == "public"]))
        if path == "/api/v1/diy/my-designs": return self.respond(base.page([d for d in DESIGNS.values() if d["userId"] == "99029"]))
        if path.startswith("/api/v1/diy/designs/"):
            try: design = DESIGNS.get(int(path.rsplit("/", 1)[1]))
            except ValueError: design = None
            return self.respond(design or {}, 200 if design else 404)
        return super().do_GET()

    def do_POST(self):
        path = urlparse(self.path).path
        if path.endswith("/copy") and path.startswith("/api/v1/diy/designs/"):
            source = DESIGNS.get(int(path.split("/")[-2]))
            if not source: return self.respond({}, 404)
            result = {**source, "id": max(DESIGNS) + 1, "sourceDesignId": source["id"], "userId": "99029", "status": "private", "revision": 1, "name": source["name"] + " 副本"}
            DESIGNS[result["id"]] = result
            return self.respond(result)
        return super().do_POST()

    def do_PUT(self):
        path = urlparse(self.path).path
        if path.endswith("/status") and path.startswith("/api/v1/diy/designs/"):
            design = DESIGNS.get(int(path.split("/")[-2]))
            body = json.loads(self.rfile.read(int(self.headers.get("Content-Length", 0))))
            if not design or design["userId"] != "99029": return self.respond({}, 403)
            if body.get("revision") != design["revision"]: return self.respond({}, 409)
            if body.get("status") not in ["public", "private"]: return self.respond({}, 400)
            design["status"] = body["status"]; design["revision"] += 1
            return self.respond(design)
        return self.respond({}, 405)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--catalog", required=True)
    parser.add_argument("--port", default=8913, type=int)
    args = parser.parse_args()
    CATALOG = json.loads(Path(args.catalog).read_text())["data"]
    for kind in ["temples", "masters", "products"]:
        rows = json.loads(json.dumps(base.DATA[kind]["list"]))
        extra = {**rows[0], "id": "3" if kind != "products" else 9902703}
        if kind == "temples": extra.update(name="末页台湾祈福禅院", region="台湾", regionCode="taiwan", traditionCodes=["chan"], serviceCodes=["S001"])
        elif kind == "masters": extra.update(dharmaName="末页台湾祈福师傅", regionCode="taiwan", manageBy="temple", traditionCodes=["chan"])
        else: extra.update(name="末页繁体莲花手串", description="详细介绍" * 100 + "末尾关键词")
        SEARCH_ROWS["/api/v1/" + kind] = rows + [extra]
        if kind == "masters":
            SEARCH_ROWS["/api/v1/" + kind].append({**extra, "id": "4", "dharmaName": "末页台湾祈福平台师傅", "manageBy": "platform"})
    material = next(m for m in CATALOG["list"] if m["name"] == "小叶紫檀圆珠")
    bead = {"slotId": "native-fixture-bead", "position": 0, "materialId": material["id"], "materialName": material["name"], "spec": material["spec"], "unitPrice": material["unitPrice"], "subtype": material["category"], "image": "", "diameterMm": 10, "shape": "round", "colorHex": "6E3030"}
    document = {"version": 2, "wristSizeMm": 160, "fitAllowanceMm": 8, "beads": [bead], "items": []}
    DESIGNS[9001] = {"id": 9001, "revision": 1, "userId": "99029", "name": "本地公开验收作品", "designData": json.dumps(document), "totalPrice": material["unitPrice"], "status": "public", "description": "", "createTime": "2026-10-20"}
    print(f"Native DIY in-memory fixture on 127.0.0.1:{args.port}", flush=True)
    ThreadingHTTPServer(("127.0.0.1", args.port), Handler).serve_forever()
