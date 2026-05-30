#!/usr/bin/env python3
"""水色フチと内側のクリーム帯を縁からの洪水塗りで除き、中央アイコンを正方形 1024 に切り出す。"""

from __future__ import annotations

from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "assets" / "app_icon.png"
OUT = ROOT / "assets" / "app_icon.png"
WORK_SIZE = 384

# 第1パス（外周のシアン）・第2パス（シアン縁＋クリーム帯）の許容距離（RGB ユークリッド）
TOL_OUTER = 70.0
TOL_CYAN = 28.0
TOL_CREAM = 32.0
MARGIN_WORK = 2
# inner がこれ以上キャンバスを占める＝外フチ無しの再実行とみなし、第2パスだけ全面に掛ける
INNER_FULL_FRAC = 0.88


def edge_median_color(a: np.ndarray) -> np.ndarray:
    h, w = a.shape[:2]
    edge = np.vstack([a[0, :], a[-1, :], a[:, 0], a[:, -1]])
    return np.median(edge, axis=0)


def corner_mean_rgb(a: np.ndarray) -> np.ndarray:
    return (
        a[0, 0].astype(np.float32)
        + a[0, -1].astype(np.float32)
        + a[-1, 0].astype(np.float32)
        + a[-1, -1].astype(np.float32)
    ) / 4.0


def flood_from_edges(a: np.ndarray, ref: np.ndarray, tol: float) -> np.ndarray:
    h, w = a.shape[:2]
    ref = np.asarray(ref, dtype=np.float32)
    visited = np.zeros((h, w), dtype=bool)
    bg = np.zeros((h, w), dtype=bool)
    q: deque[tuple[int, int]] = deque()
    for x in range(w):
        q.append((0, x))
        q.append((h - 1, x))
    for y in range(h):
        q.append((y, 0))
        q.append((y, w - 1))
    while q:
        y, x = q.popleft()
        if y < 0 or y >= h or x < 0 or x >= w or visited[y, x]:
            continue
        visited[y, x] = True
        if float(np.linalg.norm(a[y, x].astype(np.float32) - ref)) > tol:
            continue
        bg[y, x] = True
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            q.append((y + dy, x + dx))
    return bg


def largest_fg_bbox(fg: np.ndarray) -> tuple[int, int, int, int] | None:
    """前景 True の 8 連結成分のうち最大面積のバウンディングボックス（含む端）。"""
    h, w = fg.shape
    best_area = 0
    best: tuple[int, int, int, int] | None = None
    seen = np.zeros((h, w), dtype=bool)
    for y in range(h):
        for x in range(w):
            if not fg[y, x] or seen[y, x]:
                continue
            q: deque[tuple[int, int]] = deque([(y, x)])
            seen[y, x] = True
            minx = maxx = x
            miny = maxy = y
            count = 0
            while q:
                cy, cx = q.popleft()
                count += 1
                minx = min(minx, cx)
                maxx = max(maxx, cx)
                miny = min(miny, cy)
                maxy = max(maxy, cy)
                for dy, dx in ((-1, -1), (-1, 0), (-1, 1), (0, -1), (0, 1), (1, -1), (1, 0), (1, 1)):
                    ny, nx = cy + dy, cx + dx
                    if 0 <= ny < h and 0 <= nx < w and fg[ny, nx] and not seen[ny, nx]:
                        seen[ny, nx] = True
                        q.append((ny, nx))
            if count > best_area:
                best_area = count
                best = (minx, miny, maxx, maxy)
    return best


def pass1_inner_bbox(small: np.ndarray) -> tuple[int, int, int, int]:
    ref_outer = edge_median_color(small)
    bg = flood_from_edges(small, ref_outer, TOL_OUTER)
    fg = ~bg
    bb = largest_fg_bbox(fg)
    if bb is None:
        raise RuntimeError("外周の背景除去に失敗しました。")
    return bb


def pass2_icon_bbox(inner: np.ndarray) -> tuple[int, int, int, int]:
    ih, iw = inner.shape[:2]
    ref_cyan = corner_mean_rgb(inner)
    ref_cream = inner[0, iw // 2].astype(np.float32)
    bg = flood_from_edges(inner, ref_cyan, TOL_CYAN) | flood_from_edges(inner, ref_cream, TOL_CREAM)
    fg = ~bg
    bb = largest_fg_bbox(fg)
    if bb is None:
        raise RuntimeError("内側の切り抜きに失敗しました。")
    return bb


def work_to_full_rect(
    gx0: int, gy0: int, gx1: int, gy1: int, full_w: int, full_h: int, work: int
) -> tuple[int, int, int, int]:
    sx = full_w / float(work)
    sy = full_h / float(work)
    x0 = max(0, int(gx0 * sx))
    y0 = max(0, int(gy0 * sy))
    x1 = min(full_w - 1, int((gx1 + 1) * sx) - 1)
    y1 = min(full_h - 1, int((gy1 + 1) * sy) - 1)
    return x0, y0, x1, y1


def main() -> None:
    full = Image.open(SRC).convert("RGB")
    fw, fh = full.size
    small = full.resize((WORK_SIZE, WORK_SIZE), Image.Resampling.LANCZOS)
    a = np.array(small)

    ix0, iy0, ix1, iy1 = pass1_inner_bbox(a)
    ix0 = max(0, ix0 - MARGIN_WORK)
    iy0 = max(0, iy0 - MARGIN_WORK)
    ix1 = min(WORK_SIZE - 1, ix1 + MARGIN_WORK)
    iy1 = min(WORK_SIZE - 1, iy1 + MARGIN_WORK)
    inner_area = (ix1 - ix0 + 1) * (iy1 - iy0 + 1)
    canvas = WORK_SIZE * WORK_SIZE
    if inner_area >= INNER_FULL_FRAC * canvas:
        inner = a.copy()
        ix0, iy0, ix1, iy1 = 0, 0, WORK_SIZE - 1, WORK_SIZE - 1
    else:
        inner = a[iy0 : iy1 + 1, ix0 : ix1 + 1].copy()

    jx0, jy0, jx1, jy1 = pass2_icon_bbox(inner)
    gx0 = ix0 + jx0
    gy0 = iy0 + jy0
    gx1 = ix0 + jx1
    gy1 = iy0 + jy1

    x0, y0, x1, y1 = work_to_full_rect(gx0, gy0, gx1, gy1, fw, fh, WORK_SIZE)
    cropped = full.crop((x0, y0, x1 + 1, y1 + 1))
    cw, ch = cropped.size
    side = min(cw, ch)
    l = (cw - side) // 2
    t = (ch - side) // 2
    square = cropped.crop((l, t, l + side, t + side))
    out = square.resize((1024, 1024), Image.Resampling.LANCZOS)
    out.save(OUT, "PNG", optimize=True)

    b = np.array(out)
    br = np.vstack([b[0, :], b[-1, :], b[:, 0], b[:, -1]])
    print(
        f"trim_app_icon: work inner ({ix0},{iy0})-({ix1},{iy1}) "
        f"icon ({jx0},{jy0})-({jx1},{jy1}) -> full ({x0},{y0})-({x1},{y1}) "
        f"square {side}px; out border RGB ≈ {br.mean(0)}"
    )


if __name__ == "__main__":
    main()
