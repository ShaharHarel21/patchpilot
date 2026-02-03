#!/usr/bin/env python3
import math
import struct
import zlib
from pathlib import Path

WIDTH = 1024
HEIGHT = 1024

TOP = (94, 209, 193)
BOTTOM = (47, 138, 163)

RING_COLOR = (250, 252, 255)
PATCH_COLOR = (243, 217, 163)
PATCH_ACCENT = (209, 168, 104)
SPARKLE_COLOR = (255, 246, 210)


def clamp(value, low=0, high=255):
    return max(low, min(high, int(value)))


def in_round_rect(x, y, w, h, r):
    if x < 0 or y < 0 or x >= w or y >= h:
        return False
    if (r <= x < w - r) or (r <= y < h - r):
        return True
    cx = r if x < r else w - r - 1
    cy = r if y < r else h - r - 1
    dx = x - cx
    dy = y - cy
    return dx * dx + dy * dy <= r * r


def draw_rounded_rect(pixels, x0, y0, w, h, r, color):
    x1 = x0 + w
    y1 = y0 + h
    for y in range(y0, y1):
        for x in range(x0, x1):
            if in_round_rect(x - x0, y - y0, w, h, r):
                set_pixel(pixels, x, y, color)


def set_pixel(pixels, x, y, color, alpha=255):
    if x < 0 or y < 0 or x >= WIDTH or y >= HEIGHT:
        return
    idx = (y * WIDTH + x) * 4
    pixels[idx] = color[0]
    pixels[idx + 1] = color[1]
    pixels[idx + 2] = color[2]
    pixels[idx + 3] = alpha


def draw_circle(pixels, cx, cy, radius, color):
    r2 = radius * radius
    for y in range(cy - radius, cy + radius + 1):
        for x in range(cx - radius, cx + radius + 1):
            dx = x - cx
            dy = y - cy
            if dx * dx + dy * dy <= r2:
                set_pixel(pixels, x, y, color)


def draw_triangle(pixels, p1, p2, p3, color):
    xs = [p1[0], p2[0], p3[0]]
    ys = [p1[1], p2[1], p3[1]]
    min_x = max(min(xs), 0)
    max_x = min(max(xs), WIDTH - 1)
    min_y = max(min(ys), 0)
    max_y = min(max(ys), HEIGHT - 1)

    def sign(px, py, ax, ay, bx, by):
        return (px - bx) * (ay - by) - (ax - bx) * (py - by)

    for y in range(min_y, max_y + 1):
        for x in range(min_x, max_x + 1):
            b1 = sign(x, y, p1[0], p1[1], p2[0], p2[1]) < 0.0
            b2 = sign(x, y, p2[0], p2[1], p3[0], p3[1]) < 0.0
            b3 = sign(x, y, p3[0], p3[1], p1[0], p1[1]) < 0.0
            if (b1 == b2) and (b2 == b3):
                set_pixel(pixels, x, y, color)


def draw_diamond(pixels, cx, cy, size, color):
    for y in range(cy - size, cy + size + 1):
        for x in range(cx - size, cx + size + 1):
            if abs(x - cx) + abs(y - cy) <= size:
                set_pixel(pixels, x, y, color)


def write_png(path, w, h, pixels):
    raw = bytearray()
    stride = w * 4
    for y in range(h):
        raw.append(0)
        start = y * stride
        raw.extend(pixels[start:start + stride])

    compressed = zlib.compress(bytes(raw), level=9)

    def chunk(tag, data):
        return (
            struct.pack("!I", len(data)) + tag + data +
            struct.pack("!I", zlib.crc32(tag + data) & 0xffffffff)
        )

    ihdr = struct.pack("!IIBBBBB", w, h, 8, 6, 0, 0, 0)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", compressed) + chunk(b"IEND", b"")
    Path(path).write_bytes(png)


def main():
    pixels = bytearray(WIDTH * HEIGHT * 4)
    radius = 220
    cx = WIDTH // 2
    cy = HEIGHT // 2
    max_dist = math.hypot(cx, cy)

    for y in range(HEIGHT):
        t = y / (HEIGHT - 1)
        base_r = TOP[0] * (1 - t) + BOTTOM[0] * t
        base_g = TOP[1] * (1 - t) + BOTTOM[1] * t
        base_b = TOP[2] * (1 - t) + BOTTOM[2] * t
        for x in range(WIDTH):
            if not in_round_rect(x, y, WIDTH, HEIGHT, radius):
                continue
            dist = math.hypot(x - cx, y - cy) / max_dist
            highlight = 1.08 - (dist * 0.18)
            r = clamp(base_r * highlight)
            g = clamp(base_g * highlight)
            b = clamp(base_b * highlight)
            set_pixel(pixels, x, y, (r, g, b), 255)

    ring_outer = 320
    ring_inner = 250
    for y in range(cy - ring_outer, cy + ring_outer + 1):
        for x in range(cx - ring_outer, cx + ring_outer + 1):
            if not in_round_rect(x, y, WIDTH, HEIGHT, radius):
                continue
            dx = x - cx
            dy = y - cy
            dist2 = dx * dx + dy * dy
            if ring_inner * ring_inner <= dist2 <= ring_outer * ring_outer:
                set_pixel(pixels, x, y, RING_COLOR)

    angle = math.radians(-40)
    tip_radius = ring_outer + 18
    base_radius = ring_outer - 10
    spread = math.radians(16)

    tip = (
        int(cx + math.cos(angle) * tip_radius),
        int(cy + math.sin(angle) * tip_radius)
    )
    base1 = (
        int(cx + math.cos(angle + spread) * base_radius),
        int(cy + math.sin(angle + spread) * base_radius)
    )
    base2 = (
        int(cx + math.cos(angle - spread) * base_radius),
        int(cy + math.sin(angle - spread) * base_radius)
    )
    draw_triangle(pixels, tip, base1, base2, RING_COLOR)

    patch_w = 300
    patch_h = 190
    patch_x = cx - patch_w // 2
    patch_y = cy - patch_h // 2
    draw_rounded_rect(pixels, patch_x, patch_y, patch_w, patch_h, 44, PATCH_COLOR)

    hole_spacing = 70
    hole_radius = 14
    for i in (-1, 0, 1):
        draw_circle(pixels, cx + i * hole_spacing, cy, hole_radius, PATCH_ACCENT)

    draw_diamond(pixels, cx + 210, cy - 210, 24, SPARKLE_COLOR)
    draw_diamond(pixels, cx + 210, cy - 210, 10, RING_COLOR)

    write_png("Sources/PatchPilot/Resources/AppIcon-1024.png", WIDTH, HEIGHT, pixels)


if __name__ == "__main__":
    main()
