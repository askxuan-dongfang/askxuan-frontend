#!/usr/bin/env python3
"""Local synthetic AI-report cashier; never forwards requests or moves real money."""
import importlib.util
import json
from pathlib import Path
from http.server import ThreadingHTTPServer
from time import time
from urllib.parse import urlparse

spec = importlib.util.spec_from_file_location("parity", Path(__file__).with_name("native-parity-fixture.py"))
parity = importlib.util.module_from_spec(spec)
spec.loader.exec_module(parity)
state = {}


def reset(body):
    state.clear()
    state.update(price=body.get("price", 990), balance=body.get("balance", 5000), mode=body.get("mode", "live"),
                 stale=body.get("stale", False), unlocked=False, payments=[], requests=[], charges=0)


def report():
    return dict(id=1, reportNo="LOCAL-AI-1", skillCode="bazi", title="本地钱包报告",
                version="1", question="", chapters=["完整分析"], priceCents=state["price"],
                status="ready", summary="免费摘要始终保留", content="本地完整分析内容" if state["unlocked"] else "",
                errorMessage="", unlocked=state["unlocked"], createdAt="2026-10-26T00:00:00Z")


class Handler(parity.Handler):
    def respond(self, data, status=200, code=0, message="Local synthetic wallet fixture"):
        body = json.dumps(dict(code=code if status == 200 else status, message=message, data=data), ensure_ascii=False).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        path = urlparse(self.path).path
        if path == "/fixture/state":
            return self.respond(state)
        state["requests"].append(path)
        if path == "/api/v1/ai/topics":
            return self.respond([])
        if path == "/api/v1/ai/reports":
            return self.respond([report()])
        if path == "/api/v1/ai/reports/1":
            return self.respond(report())
        if path == "/api/v1/payments/wallet/balance":
            return self.respond(dict(mode=state["mode"], availableCents=state["balance"], heldCents=0, enabled=True,
                                     channels=[], entries=[], recharges=[], hasMore=False))
        return super().do_GET()

    def do_POST(self):
        path = urlparse(self.path).path
        body = json.loads(self.rfile.read(int(self.headers.get("Content-Length", 0))) or b"{}")
        if path == "/fixture/reset":
            reset(body)
            return self.respond({})
        if path == "/fixture/balance":
            state["balance"] = body["balance"]
            return self.respond({})
        state["requests"].append(path)
        if path == "/api/v1/payments/checkout/quote":
            assert body == dict(orderType="ai_report", orderNo="LOCAL-AI-1"), body
            # Advertise legacy mock deliberately: native reports must still expose balance only.
            return self.respond(dict(amountCents=state["price"], availableCents=state["balance"],
                                     balanceEnabled=True, mockEnabled=True, experience=False,
                                     balanceChannel="demo_balance" if state["mode"] == "demo" else "balance", mode=state["mode"]))
        if path == "/api/v1/payments/checkout":
            state["payments"].append(body)
            if body != dict(orderType="ai_report", orderNo="LOCAL-AI-1", expectedCents=state["price"], channel="demo_balance" if state["mode"] == "demo" else "balance"):
                return self.respond({}, code=40902, message="本地校验：订单金额或渠道不正确")
            if state["stale"]:
                state["stale"] = False
                return self.respond({}, code=40902, message="价格或订单状态已变化，请重新获取报价")
            if state["balance"] < state["price"]:
                return self.respond({}, code=40901, message="余额不足")
            if not state["unlocked"]:
                state["balance"] -= state["price"]
                state["unlocked"] = True
                state["charges"] += 1
            return self.respond(dict(id=1, paymentNo="LOCAL-PAY-1", status="success", channel=body["channel"]))
        if path == "/api/v1/payments/growth/catalog/preview":
            cents = state["price"]
            offer = dict(kind="normal", couponId=0, discountCents=0, payableCents=cents, estimatedGrowth=0,
                         lines=[dict(id="LOCAL", name="本地钱包报告", amountCents=cents, discountCents=0,
                                     netCents=cents, eligible=False, growthEligible=False)])
            now = int(time())
            return self.respond(dict(grossCents=cents, reason="按专题定价", expiresAt=now + 30, serverTime=now,
                                     snapshot=dict(ruleVersion="LOCAL", level=parity.LEVELS[0], offers=[offer], selected=offer)))
        if path == "/api/v1/payments/growth/notice/claim":
            return self.respond(dict(notice=None))
        return self.respond({}, 405)


if __name__ == "__main__":
    reset({})
    print("Synthetic wallet fixture: http://127.0.0.1:8926", flush=True)
    ThreadingHTTPServer(("127.0.0.1", 8926), Handler).serve_forever()
