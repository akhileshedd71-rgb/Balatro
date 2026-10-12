"""Optional browser integration test. Requires Playwright and a Chromium binary.

Run tools/serve_web.sh first, then: python3 tools/test_web.py [base-url]
The browser contexts and IndexedDB saves are isolated from the player's browser.
"""
from __future__ import annotations

import json
from io import BytesIO
import os
from pathlib import Path
import shutil
import sys
import time

from PIL import Image, ImageChops
from playwright.sync_api import sync_playwright

BASE_URL = sys.argv[1] if len(sys.argv) > 1 else "http://127.0.0.1:8060"
CAPTURES = Path(__file__).resolve().parents[1] / "captures/web"
READ_SAVE = """() => new Promise((resolve, reject) => {
    const request = indexedDB.open('/userfs');
    request.onerror = () => reject(request.error);
    request.onsuccess = () => {
        const db = request.result;
        const cursor = db.transaction('FILE_DATA', 'readonly').objectStore('FILE_DATA').openCursor();
        cursor.onsuccess = () => {
            const item = cursor.result;
            if (!item) { db.close(); resolve(null); return; }
            if (String(item.key).endsWith('run_save.json')) {
                const data = JSON.parse(new TextDecoder().decode(new Uint8Array(item.value.contents)));
                db.close();
                resolve({phase: data.phase, score: data.round_score, hands: data.hands_left,
                         money: data.money, offers: data.shop_items.length});
            } else { item.continue(); }
        };
        cursor.onerror = () => reject(cursor.error);
    };
})"""

HAND_PROBES = {
    "desktop": {"x": 1262, "y": 611, "width": 31, "height": 53},
    "portrait": {"x": 336, "y": 677, "width": 21, "height": 35},
    "landscape": {"x": 598, "y": 270, "width": 24, "height": 39},
}
SHOP_PROBES = {"desktop": (900, 810), "portrait": (220, 785), "landscape": (500, 350)}


def probe_image(page, clip):
    return Image.open(BytesIO(page.screenshot(clip=clip))).convert("RGB")


def wait_for_hand_completion(page, label, expected_score, previous_card) -> None:
    # Saving happens before animation. Observe both persistence and visible redraw.
    save_deadline = time.monotonic() + 30
    while time.monotonic() < save_deadline:
        saved = page.evaluate(READ_SAVE)
        if saved and saved["score"] == expected_score:
            break
        page.wait_for_timeout(150)
    else:
        raise AssertionError(f"{label}: expected saved score {expected_score}, got {saved}")
    deadline = time.monotonic() + 30
    while time.monotonic() < deadline:
        if expected_score == 180:
            current = probe_image(page, HAND_PROBES[label])
            difference = ImageChops.difference(previous_card, current)
            # Last card was not selected: it changes from 10♦ to J♠ only after
            # the cascade ends and TableView refreshes the replacement hand.
            if sum(max(pixel) > 35 for pixel in list(difference.get_flattened_data())) > 10:
                return
        else:
            x, y = SHOP_PROBES[label]
            color = probe_image(page, {"x": x, "y": y, "width": 1, "height": 1}).getpixel((0, 0))
            # The gold Next blind button appears only once the shop is shown.
            if color[0] > 160 and color[1] > 120 and color[2] < 170:
                return
        page.wait_for_timeout(150)
    raise AssertionError(f"{label}: scoring saved but the next interactive view did not appear")


def main() -> None:
    CAPTURES.mkdir(parents=True, exist_ok=True)
    binary = os.environ.get("CHROMIUM_BIN") or shutil.which("chromium") or shutil.which("google-chrome")
    if binary is None:
        raise RuntimeError("Set CHROMIUM_BIN to an installed Chromium executable.")
    results = []
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(
            executable_path=binary, headless=True,
            args=["--no-sandbox", "--use-angle=swiftshader", "--enable-unsafe-swiftshader", "--disable-dev-shm-usage"],
        )
        for label, width, height, touch in [
            ("desktop", 1440, 900, False), ("portrait", 390, 844, True), ("landscape", 844, 390, True),
        ]:
            context = browser.new_context(
                viewport={"width": width, "height": height},
                is_mobile=touch, has_touch=touch, device_scale_factor=1,
            )
            page = context.new_page()
            errors: list[str] = []
            page.on("pageerror", lambda error: errors.append(str(error)))
            page.on("console", lambda message: errors.append(message.text) if message.type == "error" else None)
            response = page.goto(BASE_URL, wait_until="networkidle", timeout=60000)
            assert response is not None and response.ok, f"HTTP request failed: {label}"
            page.wait_for_function("!document.querySelector('#status')", timeout=60000)
            page.wait_for_timeout(1000)
            canvas = page.locator("canvas").bounding_box()
            assert canvas and canvas["width"] == width and canvas["height"] == height, canvas
            page.screenshot(path=str(CAPTURES / f"{label}.png"))
            if label == "desktop":
                # MIDNIGHT starts with Queens in positions 4/5, then Jacks in 2/8.
                for step, keys in enumerate([("4", "5"), ("2", "8")]):
                    previous_card = probe_image(page, HAND_PROBES[label])
                    for key in keys:
                        page.keyboard.press(key)
                        page.wait_for_timeout(120)
                    page.keyboard.press("Space")
                    wait_for_hand_completion(page, label, 180 * (step + 1), previous_card)
                before = page.evaluate(READ_SAVE)
                expected = {"phase": "shop", "score": 360, "hands": 2, "money": 9, "offers": 5}
                assert before == expected, f"Two pairs should defeat the first blind: {before}"
                page.screenshot(path=str(CAPTURES / "shop.png"))
                page.reload(wait_until="networkidle")
                page.wait_for_function("!document.querySelector('#status')", timeout=60000)
                page.wait_for_timeout(1000)
                assert page.evaluate(READ_SAVE) == before, "Browser reload changed the saved run."
            else:
                # Exercise actual touch hit areas at both fixed phone viewports.
                centers = ([33 + 46 * index for index in range(8)] if label == "portrait"
                           else [223 + 57 * index for index in range(8)])
                card_y, play_y = (708, 797) if label == "portrait" else (305, 365)
                for step, indices in enumerate([(3, 4), (1, 7)]):
                    previous_card = probe_image(page, HAND_PROBES[label])
                    for index in indices:
                        page.touchscreen.tap(centers[index], card_y)
                        page.wait_for_timeout(120)
                    page.touchscreen.tap(60, play_y)
                    wait_for_hand_completion(page, label, 180 * (step + 1), previous_card)
                saved = page.evaluate(READ_SAVE)
                assert saved and saved["phase"] == "shop" and saved["score"] == 360, saved
                page.screenshot(path=str(CAPTURES / f"{label}-shop.png"))
            assert not errors, {"viewport": label, "errors": errors}
            results.append({"viewport": label, "canvas": canvas, "errors": errors})
            context.close()
        browser.close()
    print(json.dumps({"checks": results, "gameplay_touch_and_reload": "passed", "screenshots": str(CAPTURES)}, indent=2))


if __name__ == "__main__":
    main()
