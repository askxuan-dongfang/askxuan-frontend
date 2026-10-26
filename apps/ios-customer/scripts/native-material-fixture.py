#!/usr/bin/env python3
"""Read-only local USDZ + studio metadata fixture; never mutates production.
Run on port 8927 before DiyStudioUITests/testGeneratedModelLoadsAndRotates.
"""
import argparse
import importlib.util
import json
from http.server import ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlparse

spec = importlib.util.spec_from_file_location("parity_fixture", Path(__file__).with_name("native-parity-fixture.py"))
base = importlib.util.module_from_spec(spec)
spec.loader.exec_module(base)
MODEL = Path(__file__).parent.parent / "DongFangAppTests/Fixtures/MaterialStudio.usdz"
REQUESTS = []


def material(identity, name, part, motion):
    studio = dict(version=1, part=part, motion=motion, source="generated" if part == "hanging" else "template",
                  templateId="custom" if part == "hanging" else "round", dimensionsMm=[12, 6, 24] if part == "hanging" else [10, 10, 10],
                  rotation=[0, 90, 0], mount=[0.2, -0.1, -0.4], connectorMm=3 if part == "hanging" else 0,
                  rigidFraction=0.4, photos=[], previewConfirmed=True)
    if part == "hanging":
        studio["model"] = dict(jobId="native-fixture", glbUrl="/assets/fixture.glb", usdzUrl="/assets/material-studio.usdz?v=2")
    return dict(id=identity, name=name, spec="12mm", unitPrice=10, unit="个", category="buddha_head" if part == "hanging" else "pendant",
                fiveElements="木", image="", stock=100, status="on_shelf", renderAssets=json.dumps(dict(studio=studio)))


base.DATA["diy/materials"] = base.page([material(6001, "固定孔位珠", "bead", "fixed"), material(6002, "建模验证挂件", "hanging", "rigid")])


class Handler(base.Handler):
    def do_GET(self):
        path = urlparse(self.path).path
        if path == "/_test/model-requests":
            return self.respond(REQUESTS)
        if path == "/assets/material-studio.usdz":
            REQUESTS.append(path)
            data = MODEL.read_bytes()
            self.send_response(200)
            self.send_header("Content-Type", "model/vnd.usdz+zip")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)
            return
        return super().do_GET()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", default=8927, type=int)
    args = parser.parse_args()
    print(f"Native material fixture on 127.0.0.1:{args.port}", flush=True)
    ThreadingHTTPServer(("127.0.0.1", args.port), Handler).serve_forever()
