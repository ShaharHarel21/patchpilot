#!/usr/bin/env python3
import struct
from pathlib import Path

ICON_MAP = [
    ("icp4", "icon_16x16.png"),
    ("icp5", "icon_32x32.png"),
    ("icp6", "icon_32x32@2x.png"),
    ("ic07", "icon_128x128.png"),
    ("ic08", "icon_256x256.png"),
    ("ic09", "icon_512x512.png"),
    ("ic10", "icon_512x512@2x.png"),
]


def build_icns(iconset_dir: Path, output_path: Path) -> None:
    chunks = []
    total_size = 8

    for tag, filename in ICON_MAP:
        path = iconset_dir / filename
        if not path.exists():
            continue
        data = path.read_bytes()
        size = 8 + len(data)
        chunk = tag.encode("ascii") + struct.pack(">I", size) + data
        chunks.append(chunk)
        total_size += size

    header = b"icns" + struct.pack(">I", total_size)
    output_path.write_bytes(header + b"".join(chunks))


if __name__ == "__main__":
    import sys

    if len(sys.argv) != 3:
        print("Usage: build_icns.py <iconset_dir> <output_icns>")
        raise SystemExit(1)

    build_icns(Path(sys.argv[1]), Path(sys.argv[2]))
