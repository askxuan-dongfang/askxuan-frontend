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
INITIAL_DESIGNS = {}
PUBLICATIONS = {}
INITIAL_PUBLICATIONS = {}
REQUESTS = []
CATALOG = {}
SEARCH_ROWS = {}
POST_FAILURES = 1

def clone(value):
    return json.loads(json.dumps(value))

def eligibility(reason):
    messages = {
        "ready": "订单已付款且款式、用料和价格已确认，可以发布",
        "order_required": "完成设计并下单，付款且确认款式、用料和价格后可发布",
        "payment_required": "订单完成付款后才可发布",
        "confirmation_required": "订单已付款，待确认款式、用料和价格后可发布",
        "design_changed": "草稿已修改，请为当前款式下单并完成付款与定稿确认后发布新定稿",
    }
    return {"canPublish": reason == "ready", "reason": reason, "message": messages[reason]}

class Handler(base.Handler):
    def failure(self, code, message):
        body = json.dumps({"code": code, "message": message, "data": None}, ensure_ascii=False).encode()
        self.send_response(409)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        global POST_FAILURES
        url = urlparse(self.path)
        path = url.path
        params = parse_qs(url.query)
        if path == "/_test/state":
            return self.respond({"designs": DESIGNS, "publications": PUBLICATIONS, "requests": REQUESTS})
        if path.startswith("/api/v1/payments/growth/"):
            REQUESTS.append({"method": "GET", "path": self.path})
            if path.endswith("/rules"):
                value = clone(base.DATA[path[len("/api/v1/"):]])
                if params.get("page", ["1"])[0] != "1":
                    value["items"] = [{**value["items"][-1], "version": "local-history-v0"}]
                    value["hasMore"] = False
                return self.respond(value)
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
        if path == "/api/v1/diy/designs":
            return self.respond(base.page([PUBLICATIONS[d["id"]] for d in DESIGNS.values() if d["status"] == "public" and d["id"] in PUBLICATIONS]))
        if path == "/api/v1/diy/my-designs": return self.respond(base.page([d for d in DESIGNS.values() if d["userId"] == "99029"]))
        if path.startswith("/api/v1/diy/designs/"):
            REQUESTS.append({"method": "GET", "path": self.path})
            try: design = DESIGNS.get(int(path.rsplit("/", 1)[1]))
            except ValueError: design = None
            if design and params.get("view") == ["published"]:
                design = PUBLICATIONS.get(design["id"]) if design["status"] == "public" else None
            return self.respond(design or {}, 200 if design else 404)
        return super().do_GET()

    def do_POST(self):
        path = urlparse(self.path).path
        if path == "/_test/reset":
            DESIGNS.clear(); DESIGNS.update({key: clone(value) for key, value in INITIAL_DESIGNS.items()})
            PUBLICATIONS.clear(); PUBLICATIONS.update({key: clone(value) for key, value in INITIAL_PUBLICATIONS.items()})
            REQUESTS.clear()
            return self.respond({"reset": True})
        if path.endswith("/copy") and path.startswith("/api/v1/diy/designs/"):
            source = PUBLICATIONS.get(int(path.split("/")[-2]))
            if not source: return self.respond({}, 404)
            REQUESTS.append({"method": "POST", "path": path, "sourcePublicationId": source["publication"]["id"]})
            result = {**source, "id": max(int(key) for key in DESIGNS) + 1, "sourceDesignId": source["id"], "sourcePublicationId": source["publication"]["id"], "publication": None, "publicationEligibility": eligibility("order_required"), "draftChanged": False, "userId": "99029", "status": "private", "revision": 1, "name": source["name"] + " 副本"}
            DESIGNS[result["id"]] = result
            return self.respond(result)
        if path == "/api/v1/diy/designs":
            body = json.loads(self.rfile.read(int(self.headers.get("Content-Length", 0))))
            design = DESIGNS.get(body.get("id"))
            if not design: return self.respond({}, 404)
            if body.get("revision") != design["revision"]: return self.failure(40914, "设计已被更新，请重新加载")
            REQUESTS.append({"method": "POST", "path": path, "id": design["id"]})
            for field in ["name", "description", "designData", "totalPrice"]:
                if field in body: design[field] = body[field]
            design["revision"] += 1
            design["draftChanged"] = design["id"] in PUBLICATIONS
            design["publicationEligibility"] = eligibility("design_changed")
            return self.respond({"id": design["id"], "revision": design["revision"]})
        if path == "/api/v1/diy/orders/availability":
            return self.respond({"orderable": True, "issues": [], "materialFee": 28, "originalMaterialFee": 28, "priceChanged": False})
        return super().do_POST()

    def do_PUT(self):
        path = urlparse(self.path).path
        if path.endswith("/status") and path.startswith("/api/v1/diy/designs/"):
            design = DESIGNS.get(int(path.split("/")[-2]))
            body = json.loads(self.rfile.read(int(self.headers.get("Content-Length", 0))))
            if not design or design["userId"] != "99029": return self.respond({}, 403)
            if body.get("revision") != design["revision"]: return self.respond({}, 409)
            if body.get("status") not in ["public", "private"]: return self.respond({}, 400)
            REQUESTS.append({"method": "PUT", "path": path, "status": body.get("status")})
            if body["status"] == "public" and not design["publicationEligibility"]["canPublish"]:
                return self.failure(40915, design["publicationEligibility"]["message"])
            design["status"] = body["status"]; design["revision"] += 1
            if body["status"] == "public":
                design["publication"] = {"id": 7100 + design["id"], "designRevision": design["revision"], "materialFee": design["totalPrice"], "publishedAt": "2026-10-20T10:00:00Z"}
                design["draftChanged"] = False
                PUBLICATIONS[design["id"]] = clone(design)
            return self.respond(design)
        return self.respond({}, 405)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--catalog", required=True)
    parser.add_argument("--port", default=8913, type=int)
    args = parser.parse_args()
    CATALOG = json.loads(Path(args.catalog).read_text())["data"]
    base.DATA["intentions/tags"] = base.page([
        {"code": code, "name": name, "description": "本地验收心愿", "icon": "", "landingType": "service", "landingValue": "S001", "actionTitle": "查看服务", "sort": index, "status": "enabled"}
        for index, (code, name) in enumerate([("peace", "求平安"), ("wealth", "求财运"), ("love", "求姻缘"), ("career", "求事业"), ("study", "求学业"), ("taisui", "化太岁"), ("rite", "做法事")])
    ])
    rule_config = {"levels": base.LEVELS, "tasks": [{"kind": "note", "award": 5, "used": 0, "limit": 1, "available": True, "period": "day"}], "monthlyGrowthLimit": 300, "monthlyDiscountLimitCents": 10000, "goodsDiscountCapCents": 2000, "serviceDiscountCapCents": 3000, "observationDays": 7, "couponDays": 30}
    active_rule = {"version": "local-current-v2", "summary": "本地当前规则验收", "effectiveAt": 1792454400, "createdAt": 1792454400, "status": "current", "config": rule_config}
    old_rule = {**active_rule, "version": "local-history-v1", "summary": "本地历史规则验收", "status": "historical"}
    for rules_path in ["rules", "public/rules"]:
        base.DATA["payments/growth/" + rules_path] = {"items": [active_rule, old_rule], "hasMore": True, "currentVersion": active_rule["version"]}
    for kind in ["temples", "masters", "products"]:
        rows = json.loads(json.dumps(base.DATA[kind]["list"]))
        extra = {**rows[0], "id": "3" if kind != "products" else 9902703}
        if kind == "temples": extra.update(name="末页台湾祈福禅院", region="台湾", regionCode="taiwan", traditionCodes=["chan"], serviceCodes=["S001"])
        elif kind == "masters": extra.update(dharmaName="末页台湾祈福师傅", regionCode="taiwan", manageBy="temple", traditionCodes=["chan"])
        else: extra.update(name="末页繁体莲花手串", description="详细介绍" * 100 + "末尾关键词")
        SEARCH_ROWS["/api/v1/" + kind] = rows + [extra]
        if kind == "masters":
            SEARCH_ROWS["/api/v1/" + kind].append({**extra, "id": "4", "dharmaName": "末页台湾祈福平台师傅", "manageBy": "platform", "specialties": ["禅修"]})
    material = next(m for m in CATALOG["list"] if m["name"] == "小叶紫檀圆珠")
    bead = {"slotId": "native-fixture-bead", "position": 0, "materialId": material["id"], "materialName": material["name"], "spec": material["spec"], "unitPrice": material["unitPrice"], "subtype": material["category"], "image": "", "diameterMm": 10, "shape": "round", "colorHex": "6E3030"}
    document = {"version": 2, "wristSizeMm": 160, "fitAllowanceMm": 8, "beads": [bead], "items": []}
    DESIGNS[9001] = {"id": 9001, "revision": 1, "userId": "99029", "name": "本地公开验收作品", "designData": json.dumps(document), "totalPrice": material["unitPrice"], "status": "public", "description": "", "createTime": "2026-10-20", "draftChanged": False, "publicationEligibility": eligibility("ready"), "publication": {"id": 16101, "designRevision": 1, "materialFee": material["unitPrice"], "publishedAt": "2026-10-20T10:00:00Z"}}
    PUBLICATIONS[9001] = clone(DESIGNS[9001])
    for design_id, name, reason in [(9002, "待付款验收作品", "payment_required"), (9003, "待确认验收作品", "confirmation_required"), (9004, "已定稿验收作品", "ready")]:
        DESIGNS[design_id] = {**clone(DESIGNS[9001]), "id": design_id, "name": name, "status": "private", "publication": None, "publicationEligibility": eligibility(reason)}
    INITIAL_DESIGNS = {key: clone(value) for key, value in DESIGNS.items()}
    INITIAL_PUBLICATIONS = {key: clone(value) for key, value in PUBLICATIONS.items()}
    print(f"Native DIY in-memory fixture on 127.0.0.1:{args.port}", flush=True)
    ThreadingHTTPServer(("127.0.0.1", args.port), Handler).serve_forever()
