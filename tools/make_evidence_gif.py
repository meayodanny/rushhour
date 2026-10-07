#!/usr/bin/env python3
"""Assemble the QA evidence artifacts produced by the golden tests.

Turns the drag-sequence golden frames (test/goldens/drag_frame_*.png) into an
animated GIF (docs/qa/hitbox_drag.gif) and copies the two map screenshots
into docs/qa/. Runs on CI after `flutter test --update-goldens`.

Requires Pillow: python3 -m pip install pillow
"""

import re
import shutil
import sys
from pathlib import Path

GOLDENS = Path("test/goldens")
DOCS = Path("docs/qa")
FRAME_PATTERN = re.compile(r"^drag_frame_(\d+)\.png$")
FRAME_MS = 220  # per frame
MAX_WIDTH = 390  # downscale to keep the GIF small


def main() -> int:
    try:
        from PIL import Image
    except ImportError:
        print("Pillow is required: python3 -m pip install pillow", file=sys.stderr)
        return 1

    DOCS.mkdir(parents=True, exist_ok=True)

    for name in ("hitbox_map.png", "hitbox_map_zoomed.png", "river_map.png", "river_painter.png"):
        source = GOLDENS / name
        if source.exists():
            shutil.copyfile(source, DOCS / name)
            print(f"copied {source} -> {DOCS / name}")

    frames_paths = sorted(
        (p for p in GOLDENS.glob("drag_frame_*.png") if FRAME_PATTERN.match(p.name)),
        key=lambda p: FRAME_PATTERN.match(p.name).group(1),
    )
    final = GOLDENS / "drag_frame_final.png"
    if final.exists():
        frames_paths.append(final)

    if not frames_paths:
        print("no drag frames found", file=sys.stderr)
        return 1

    frames = []
    for path in frames_paths:
        image = Image.open(path).convert("RGB")
        if image.width > MAX_WIDTH:
            ratio = MAX_WIDTH / image.width
            image = image.resize((MAX_WIDTH, round(image.height * ratio)), Image.LANCZOS)
        # Hold each frame a little longer so the motion is readable.
        repeats = 2
        for _ in range(repeats):
            frames.append(image)

    if not frames:
        print("no frames decoded", file=sys.stderr)
        return 1

    out = DOCS / "hitbox_drag.gif"
    frames[0].save(
        out,
        save_all=True,
        append_images=frames[1:],
        duration=FRAME_MS / 2,
        loop=0,
        optimize=True,
    )
    print(f"wrote {out} ({len(frames_paths)} frames, {out.stat().st_size} bytes)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
