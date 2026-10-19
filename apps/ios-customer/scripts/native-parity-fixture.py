#!/usr/bin/env python3
"""Synthetic localhost UI data. No writes, production accounts or network forwarding.

The notice/claim POST is a stateless read returning no notice. All mutations are rejected.
"""
import argparse
import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse


def page(rows):
    return {"list": rows, "total": len(rows), "page": 1, "size": 100}


DATA = {
    "regions": page([{"code": code, "name": name} for code, name in [
        ("mainland", "大陆"), ("hong_kong", "香港"), ("macau", "澳门"),
        ("taiwan", "台湾"), ("southeast_asia", "东南亚")]]),
    "beliefs/directory-tags": page([
        {"code": code, "group": "tradition", "name": name, "value": name, "beliefCode": belief, "status": "enabled"}
        for code, name, belief in [
            ("chan", "禅宗", "han_buddhism"), ("pure_land", "净土宗", "han_buddhism"),
            ("gelug", "格鲁派", "tibetan_buddhism"), ("theravada", "南传上座部", "theravada_buddhism"),
            ("quanzhen", "全真派", "daoism"), ("zhengyi", "正一派", "daoism"), ("mazu", "妈祖信俗", "folk")]]),
    "beliefs": page([{"code": code, "name": name, "summary": "本地验收", "description": "合成数据",
                      "coverImage": "", "icon": "", "sort": index, "status": "enabled"}
                     for index, (code, name) in enumerate([
                         ("han_buddhism", "汉传佛教"), ("tibetan_buddhism", "藏传佛教"),
                         ("theravada_buddhism", "南传佛教"), ("daoism", "道教"), ("folk", "民间信仰")])]),
    "service-types": page([{"code": "S001", "name": "祈福", "category": "service", "priceRange": "¥200 起"}]),
    "home/promotions": page([]), "intentions/tags": page([]),
    "temples": page([{"id": "1", "name": "本地验收寺院", "region": "浙江杭州", "regionCode": "mainland",
                      "beliefCode": "han_buddhism", "traditionCodes": ["chan"], "serviceCodes": ["S001"]},
                     {"id": "2", "name": "本地验收道观", "region": "浙江杭州", "regionCode": "mainland",
                      "beliefCode": "daoism", "traditionCodes": ["quanzhen"], "serviceCodes": ["S001"]}]),
    "masters": page([{"id": "1", "dharmaName": "本地验收师傅", "templeName": "本地验收寺院",
                      "regionCode": "mainland", "beliefCode": "han_buddhism", "traditionCodes": ["chan"],
                      "serviceTags": [{"serviceCode": "S001", "price": 200, "status": "enabled"}]},
                     {"id": "2", "dharmaName": "本地验收道长", "templeName": "本地验收道观", "position": "独立道长",
                      "regionCode": "mainland", "beliefCode": "daoism", "traditionCodes": ["quanzhen"],
                      "serviceTags": [{"serviceCode": "S001", "price": 200, "status": "enabled"}]}]),
    "products/categories": page([{"id": 1, "name": "本地分类", "level": 1, "sort": 1, "children": []}]),
    "products": page([{"id": 9902701, "name": "本地验收手串", "categoryId": 1, "description": "隔离 UI 验收商品",
                       "mainImage": "", "status": "on_shelf", "price": 99, "stock": 10},
                      {"id": 9902702, "name": "本地验收线香", "categoryId": 1, "description": "隔离 UI 验收商品",
                       "mainImage": "", "status": "on_shelf", "price": 29, "stock": 10}]),
    "users/profile": {"userId": 99027, "nickname": "本地验收用户", "avatar": "", "mobile": "", "gender": "unknown"},
    "users/addresses": page([]), "marketing/my-coupons": page([]), "bookings": page([]),
    "bookings/journeys": {**page([]), "counts": {key: 0 for key in ["active", "pending", "confirmed", "executing", "receipt", "complete", "revision"]}},
    "points": {"balance": 87},
    "diy/creator-wallet": {
        "account": {"availableCents": 123456, "heldCents": 0, "paidCents": 0}, "pendingCents": 0,
        "policy": {"enabled": True, "kind": "cash", "rateBps": 500, "capCents": 2000, "waitDays": 7, "minWithdrawCents": 1000},
        "rewards": [], "withdrawals": [], "total": 0, "withdrawalTotal": 0},
    "admin/masters/profile": {
        "id": "1", "dharmaName": "本地验收师傅", "layName": "", "templeId": "LOCAL", "position": "",
        "sect": "禅宗", "type": "monk", "authStatus": "approved", "specialties": [], "avatar": "", "bio": "",
        "pricing": "", "rating": 5, "manageBy": "platform", "serviceTags": []},
    "admin/masters/community/posts": page([]),
    "live/capabilities": {"enabled": False, "provider": "fixture", "configured": False, "canStart": False},
}

# Deliberately synthetic overview; it exercises presentation, not server-side growth awards or pricing.
LEVELS = [{"code": i + 1, "name": name, "threshold": threshold, "goodsRateBps": 10000,
           "serviceRateBps": 10000, "couponMinimumCents": 0, "couponValueCents": 0, "benefit": "本地验收权益"}
          for i, (name, threshold) in enumerate([("初识", 0), ("同行", 200), ("深耕", 1000), ("致远", 3000), ("恒久", 10000)])]
DATA["payments/growth/overview"] = {
    "total": 320, "level": LEVELS[1], "levels": LEVELS, "nextThreshold": 1000, "remaining": 680,
    "pending": 0, "monthlyEarned": 20, "monthlyLimit": 300, "badgeVisible": False, "discountsEnabled": False,
    "coupons": [], "tasks": [], "ruleVersion": "local-ui-fixture", "revision": 1,
}
DATA["payments/growth/records"] = {"entries": [], "pending": [], "hasMore": False}
for key in ["temples", "masters"]:
    for row in DATA[key]["list"]:
        row["rating"] = 5
        row["status"] = "enabled"
        row["coverImage"] = ""
        row["avatar"] = ""
for key in ["rules", "public/rules", "provider/rules"]:
    DATA["payments/growth/" + key] = {"items": [], "hasMore": False, "currentVersion": "local-ui-fixture"}
for key in ["contents", "activities", "notes", "support"]:
    DATA["payments/growth/" + key] = []


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *_args):
        pass

    def respond(self, data, status=200):
        body = json.dumps({"code": 0 if status == 200 else status,
                           "message": "Local read-only UI fixture", "data": data}, ensure_ascii=False).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        url = urlparse(self.path)
        if not url.path.startswith("/api/v1/"):
            return self.respond({}, 404)
        key = url.path[len("/api/v1/"):]
        # Unrelated badge/list reads return empty scaffolding; no production API is contacted.
        data = json.loads(json.dumps(DATA.get(key, {**page([]), "count": 0, "unreadCount": 0})))
        params = parse_qs(url.query)
        if key in ("temples", "masters"):
            for field in ["beliefCode", "regionCode"]:
                if params.get(field):
                    data["list"] = [row for row in data["list"] if row.get(field) == params[field][0]]
            if params.get("traditionCode"):
                data["list"] = [row for row in data["list"] if params["traditionCode"][0] in row.get("traditionCodes", [])]
            data["total"] = len(data["list"])
        if key == "products" and params.get("keyword"):
            data["list"] = [row for row in data["list"] if params["keyword"][0] in row["name"]]
            data["total"] = len(data["list"])
        if "list" in data and params.get("page", ["1"])[0] != "1":
            data["list"] = []
        self.respond(data)

    def do_POST(self):
        if urlparse(self.path).path == "/api/v1/payments/growth/notice/claim":
            return self.respond({"notice": None})
        self.respond({}, 405)

    def reject_mutation(self):
        self.respond({}, 405)

    do_PUT = do_PATCH = do_DELETE = reject_mutation


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", type=int, default=5399)
    port = parser.parse_args().port
    print(f"Native parity fixture: http://127.0.0.1:{port} (synthetic UI data, all mutations rejected)", flush=True)
    ThreadingHTTPServer(("127.0.0.1", port), Handler).serve_forever()
