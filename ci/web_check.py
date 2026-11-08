"""Three fresh mobile browser runs against the built site, without a service."""

from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import shutil
import sys
from threading import Thread
import time

from playwright.sync_api import sync_playwright


def main(directory, output):
    server = ThreadingHTTPServer(("127.0.0.1", 0), partial(SimpleHTTPRequestHandler, directory=directory))
    worker = Thread(target=server.serve_forever, daemon=True)
    worker.start()
    rows = []
    try:
        with sync_playwright() as p:
            browser = p.chromium.launch(executable_path=os.environ.get("TESSERA_CHROMIUM") or shutil.which("chromium"),
                                        headless=True, args=["--no-sandbox", "--disable-dev-shm-usage"])
            try:
                for index in range(3):
                    page = browser.new_page(viewport={"width": 390, "height": 844})
                    errors = []
                    page.on("pageerror", lambda error: errors.append(str(error)))
                    try:
                        started = time.monotonic()
                        page.goto(f"http://127.0.0.1:{server.server_port}/?ci={index}", timeout=15000)
                        page.locator("h1").wait_for(state="visible", timeout=5000)
                        page.locator('a[href$="Tessera.dmg"]:visible').first.wait_for(state="visible", timeout=5000)
                        elapsed = (time.monotonic() - started) * 1000
                        metrics = page.evaluate("""() => ({
                            title:document.title, clientWidth:document.documentElement.clientWidth,
                            scrollWidth:document.documentElement.scrollWidth,
                            fcpMS:performance.getEntriesByName('first-contentful-paint')[0]?.startTime ?? null
                        })""")
                        if not metrics["title"].startswith("Tessera") or metrics["scrollWidth"] > metrics["clientWidth"] + 1:
                            raise ValueError("Mobile page identity or overflow check failed")
                        if elapsed > 5000 or metrics["fcpMS"] is None or not 0 < metrics["fcpMS"] <= 5000 or errors:
                            raise ValueError("Browser performance or JavaScript regression")
                        rows.append(metrics | {"visibleMS": elapsed, "run": index + 1})
                        page.screenshot(path=str(Path(output) / f"web-{index}.png"))
                    finally:
                        page.close()
            finally:
                browser.close()
        (Path(output) / "browser.json").write_text(json.dumps(rows, indent=2) + "\n")
    finally:
        server.shutdown()
        server.server_close()
        worker.join(timeout=5)


if __name__ == "__main__":
    main(*sys.argv[1:])
