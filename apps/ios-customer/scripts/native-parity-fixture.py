#!/usr/bin/env python3
"""Deterministic localhost data for both H5ParityUITests suites. No writes/network forwarding."""
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
        {"code": "chan", "group": "tradition", "name": "禅宗", "value": "禅宗"},
        {"code": "theravada", "group": "tradition", "name": "南传佛教", "value": "南传佛教"}]),
    "beliefs": page([{"code": "han_buddhism", "name": "汉传佛教", "summary": "本地验收",
                      "description": "合成数据", "coverImage": "", "icon": "", "sort": 1, "status": "enabled"}]),
    "service-types": page([{"code": "S001", "name": "祈福", "category": "service", "priceRange": "¥200 起"}]),
    "home/promotions": page([]), "intentions/tags": page([]),
    "temples": page([{"id": "1", "name": "本地验收寺院", "region": "浙江杭州", "regionCode": "mainland",
                      "beliefCode": "han_buddhism", "traditionCodes": ["chan"], "serviceCodes": ["S001"]}]),
    "masters": page([{"id": "1", "dharmaName": "本地验收师傅", "templeName": "本地验收寺院",
                      "regionCode": "mainland", "beliefCode": "han_buddhism", "traditionCodes": ["chan"],
                      "serviceTags": [{"serviceCode": "S001", "price": 200, "status": "enabled"}]}]),
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
        if "list" in data and parse_qs(url.query).get("page", ["1"])[0] != "1":
            data["list"] = []
        self.respond(data)

    def do_POST(self):
        self.respond({}, 405)

    do_PUT = do_PATCH = do_DELETE = do_POST


if __name__ == "__main__":
    print("Native parity fixture: http://127.0.0.1:5399 (all mutations rejected)", flush=True)
    ThreadingHTTPServer(("127.0.0.1", 5399), Handler).serve_forever()
