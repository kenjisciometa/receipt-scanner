#!/usr/bin/env python3
"""
Generate test receipt image with Tax Breakdown table
"""
from PIL import Image, ImageDraw, ImageFont
import os

# Receipt dimensions
WIDTH = 400
HEIGHT = 600
BG_COLOR = (255, 255, 255)  # White
TEXT_COLOR = (0, 0, 0)  # Black

# Create image
img = Image.new('RGB', (WIDTH, HEIGHT), BG_COLOR)
draw = ImageDraw.Draw(img)

# Try to use a font, fallback to default if not available
try:
    # Try to use a monospace font
    font_large = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 16)
    font_medium = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 14)
    font_small = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 12)
except:
    font_large = ImageFont.load_default()
    font_medium = ImageFont.load_default()
    font_small = ImageFont.load_default()

y_position = 30

# Helper function to draw text
def draw_text(text, x, y, font=font_medium, color=TEXT_COLOR):
    draw.text((x, y), text, fill=color, font=font)
    return y + 20

# Header
y_position = draw_text("SUPERMARKET ABC", 120, y_position, font_large)
y_position = draw_text("123 Main Street", 130, y_position, font_small)
y_position = draw_text("Helsinki, FI", 150, y_position, font_small)
y_position += 10

# Date and Time
y_position = draw_text("Date: 2026-01-02", 50, y_position)
y_position = draw_text("Time: 13:30:15", 50, y_position)
y_position = draw_text("Receipt # 001234", 50, y_position)
y_position += 10

# Items section
y_position = draw_text("Items:", 50, y_position)
y_position = draw_text("Bread                    €2.50", 50, y_position, font_small)
y_position = draw_text("Milk 1L                  €1.89", 50, y_position, font_small)
y_position = draw_text("Apples 1kg               €3.20", 50, y_position, font_small)
y_position = draw_text("Coffee                   €4.99", 50, y_position, font_small)
y_position += 10

# Subtotal
y_position = draw_text("Subtotal:                €12.58", 50, y_position)
y_position += 10

# Tax Breakdown Table
y_position += 5
table_y_start = y_position

# Table header
header_bg = (240, 240, 240)
table_width = 320
table_x_start = 40
table_x_end = table_x_start + table_width

# Draw table border
draw.rectangle([table_x_start, y_position, table_x_end, y_position + 50], outline=(0, 0, 0), width=2)

# Header row
draw.rectangle([table_x_start, y_position, table_x_end, y_position + 25], fill=header_bg)
draw_text("Tax rate", 50, y_position + 5, font_small)
draw_text("Tax", 130, y_position + 5, font_small)
draw_text("Subtotal", 200, y_position + 5, font_small)
draw_text("Total", 280, y_position + 5, font_small)

# Draw vertical lines
draw.line([120, y_position, 120, y_position + 50], fill=(0, 0, 0), width=1)
draw.line([190, y_position, 190, y_position + 50], fill=(0, 0, 0), width=1)
draw.line([270, y_position, 270, y_position + 50], fill=(0, 0, 0), width=1)

# Draw horizontal line between header and data
draw.line([table_x_start, y_position + 25, table_x_end, y_position + 25], fill=(0, 0, 0), width=1)

y_position += 25

# Table data row
draw_text("14%", 50, y_position + 5, font_small)
draw_text("€1.76", 130, y_position + 5, font_small)  # Tax amount (14% of 12.58)
draw_text("€12.58", 200, y_position + 5, font_small)  # Subtotal
draw_text("€14.34", 280, y_position + 5, font_small)  # Total (12.58 + 1.76)

y_position += 30

# Total
y_position = draw_text("TOTAL:                   €14.34", 50, y_position)
y_position += 10

# Payment
y_position = draw_text("Payment: CARD", 50, y_position)
y_position += 10

# Footer
y_position = draw_text("Thank you!", 150, y_position)

# Save image
output_path = os.path.join(os.path.dirname(__file__), "test_receipt_v2.png")
img.save(output_path)
print(f"Test receipt image saved to: {output_path}")

