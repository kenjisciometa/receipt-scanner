#!/usr/bin/env python3
"""
ArUco Marker Generator
A4用紙に25mm四方のArUcoマーカーを連番で配置しPDF出力する。
"""

import argparse
import sys

import cv2
import numpy as np
from reportlab.lib.pagesizes import A4
from reportlab.lib.units import mm
from reportlab.pdfgen import canvas
from reportlab.lib.utils import ImageReader
from io import BytesIO
from PIL import Image

# ArUco辞書マッピング
ARUCO_DICTS = {
    "DICT_4X4_50": cv2.aruco.DICT_4X4_50,
    "DICT_4X4_100": cv2.aruco.DICT_4X4_100,
    "DICT_4X4_250": cv2.aruco.DICT_4X4_250,
    "DICT_4X4_1000": cv2.aruco.DICT_4X4_1000,
    "DICT_5X5_50": cv2.aruco.DICT_5X5_50,
    "DICT_5X5_100": cv2.aruco.DICT_5X5_100,
    "DICT_5X5_250": cv2.aruco.DICT_5X5_250,
    "DICT_5X5_1000": cv2.aruco.DICT_5X5_1000,
    "DICT_6X6_50": cv2.aruco.DICT_6X6_50,
    "DICT_6X6_100": cv2.aruco.DICT_6X6_100,
    "DICT_6X6_250": cv2.aruco.DICT_6X6_250,
    "DICT_6X6_1000": cv2.aruco.DICT_6X6_1000,
    "DICT_7X7_50": cv2.aruco.DICT_7X7_50,
    "DICT_7X7_100": cv2.aruco.DICT_7X7_100,
    "DICT_7X7_250": cv2.aruco.DICT_7X7_250,
    "DICT_7X7_1000": cv2.aruco.DICT_7X7_1000,
}

# レイアウト定数
PAGE_W, PAGE_H = A4  # 595.28pt x 841.89pt
MARGIN = 15 * mm
LABEL_HEIGHT = 5 * mm
LABEL_GAP = 3 * mm


def generate_marker_image(dictionary, marker_id, size_px=200):
    """ArUcoマーカー画像を生成する。"""
    marker_img = cv2.aruco.generateImageMarker(dictionary, marker_id, size_px)
    return marker_img


def create_pdf(start_id, count, output_path, dict_name, marker_size_mm):
    """マーカーをA4 PDFに配置して出力する。"""
    aruco_dict_id = ARUCO_DICTS.get(dict_name)
    if aruco_dict_id is None:
        print(f"Error: Unknown dictionary '{dict_name}'")
        print(f"Available: {', '.join(sorted(ARUCO_DICTS.keys()))}")
        sys.exit(1)

    dictionary = cv2.aruco.getPredefinedDictionary(aruco_dict_id)

    marker_size = marker_size_mm * mm
    cell_w = marker_size + 10 * mm
    cell_h = marker_size + LABEL_HEIGHT + LABEL_GAP + 5 * mm

    printable_w = PAGE_W - 2 * MARGIN
    printable_h = PAGE_H - 2 * MARGIN

    cols = int(printable_w // cell_w)
    rows = int(printable_h // cell_h)
    per_page = cols * rows

    # セル間の余白を均等配分
    gap_x = (printable_w - cols * marker_size) / (cols + 1) if cols > 1 else (printable_w - marker_size) / 2
    gap_y = (printable_h - rows * (marker_size + LABEL_HEIGHT + LABEL_GAP)) / (rows + 1) if rows > 1 else (printable_h - marker_size - LABEL_HEIGHT - LABEL_GAP) / 2

    c = canvas.Canvas(output_path, pagesize=A4)
    c.setTitle(f"ArUco Markers ({dict_name}) ID {start_id}-{start_id + count - 1}")

    marker_px = 200  # 生成時のピクセルサイズ

    for i in range(count):
        marker_id = start_id + i
        page_idx = i // per_page
        pos_in_page = i % per_page

        if pos_in_page == 0 and i > 0:
            c.showPage()

        col = pos_in_page % cols
        row = pos_in_page // cols

        x = MARGIN + gap_x * (col + 1) + col * marker_size
        # reportlabは左下原点なので上から配置
        y = PAGE_H - MARGIN - gap_y * (row + 1) - row * (marker_size + LABEL_HEIGHT + LABEL_GAP) - marker_size

        # マーカー画像生成
        marker_img = generate_marker_image(dictionary, marker_id, marker_px)

        # OpenCV画像 → PIL → reportlab ImageReader
        pil_img = Image.fromarray(marker_img)
        img_buffer = BytesIO()
        pil_img.save(img_buffer, format="PNG")
        img_buffer.seek(0)
        img_reader = ImageReader(img_buffer)

        # マーカー描画
        c.drawImage(img_reader, x, y, width=marker_size, height=marker_size)

        # ラベル描画
        c.setFont("Helvetica", 7)
        label = f"ID: {marker_id:03d}"
        label_w = c.stringWidth(label, "Helvetica", 7)
        label_x = x + (marker_size - label_w) / 2
        label_y = y - LABEL_HEIGHT - 1 * mm
        c.drawString(label_x, label_y, label)

    c.save()

    total_pages = (count + per_page - 1) // per_page
    print(f"Generated {count} markers (ID {start_id}-{start_id + count - 1})")
    print(f"Dictionary: {dict_name}")
    print(f"Marker size: {marker_size_mm}mm")
    print(f"Layout: {cols} cols x {rows} rows = {per_page} per page")
    print(f"Total pages: {total_pages}")
    print(f"Output: {output_path}")


def main():
    parser = argparse.ArgumentParser(
        description="ArUcoマーカーをA4 PDFに連番で生成する"
    )
    parser.add_argument(
        "--start", type=int, required=True, help="開始マーカーID"
    )
    parser.add_argument(
        "--count", type=int, required=True, help="生成するマーカー数"
    )
    parser.add_argument(
        "--output", type=str, default="aruco_markers.pdf", help="出力PDFファイル名"
    )
    parser.add_argument(
        "--dict",
        type=str,
        default="DICT_4X4_250",
        choices=sorted(ARUCO_DICTS.keys()),
        help="ArUco辞書タイプ (default: DICT_4X4_250)",
    )
    parser.add_argument(
        "--size",
        type=int,
        default=25,
        help="マーカーサイズ(mm) (default: 25)",
    )

    args = parser.parse_args()

    if args.start < 0:
        parser.error("--start must be >= 0")
    if args.count < 1:
        parser.error("--count must be >= 1")
    if args.size < 5:
        parser.error("--size must be >= 5mm")

    create_pdf(args.start, args.count, args.output, args.dict, args.size)


if __name__ == "__main__":
    main()
