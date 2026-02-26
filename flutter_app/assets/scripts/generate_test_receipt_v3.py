#!/usr/bin/env python3
"""
Generate test receipt image with Tax Breakdown table containing 2 different tax rates
"""
from PIL import Image, ImageDraw, ImageFont
import os

# Receipt dimensions
WIDTH = 400
HEIGHT = 650  # Increased height for 2 tax rate rows
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
y_position = draw_text("Receipt # 001235", 50, y_position)
y_position += 10

# Items section - items with different tax rates
y_position = draw_text("Items:", 50, y_position)
# Items with 14% tax rate
y_position = draw_text("Bread                    €2.50", 50, y_position, font_small)
y_position = draw_text("Milk 1L                  €1.89", 50, y_position, font_small)
y_position = draw_text("Apples 1kg               €3.20", 50, y_position, font_small)
# Items with 24% tax rate
y_position = draw_text("Coffee                   €4.99", 50, y_position, font_small)
y_position = draw_text("Wine 750ml              €8.50", 50, y_position, font_small)
y_position += 10

# Subtotal (before tax)
subtotal_14 = 2.50 + 1.89 + 3.20  # €7.59
subtotal_24 = 4.99 + 8.50  # €13.49
total_subtotal = subtotal_14 + subtotal_24  # €21.08

y_position = draw_text(f"Subtotal:                €{total_subtotal:.2f}", 50, y_position)
y_position += 10

# Tax Breakdown Table with 2 tax rates
y_position += 5
table_y_start = y_position

# Table header
header_bg = (240, 240, 240)
table_width = 320
table_x_start = 40
table_x_end = table_x_start + table_width
row_height = 25

# Draw table border
table_height = 25 + (row_height * 2) + 5  # Header + 2 data rows + spacing
draw.rectangle([table_x_start, y_position, table_x_end, y_position + table_height], outline=(0, 0, 0), width=2)

# Header row
draw.rectangle([table_x_start, y_position, table_x_end, y_position + row_height], fill=header_bg)
draw_text("Tax rate", 50, y_position + 5, font_small)
draw_text("Tax", 130, y_position + 5, font_small)
draw_text("Subtotal", 200, y_position + 5, font_small)
draw_text("Total", 280, y_position + 5, font_small)

# Draw vertical lines
draw.line([120, y_position, 120, y_position + table_height], fill=(0, 0, 0), width=1)
draw.line([190, y_position, 190, y_position + table_height], fill=(0, 0, 0), width=1)
draw.line([270, y_position, 270, y_position + table_height], fill=(0, 0, 0), width=1)

# Draw horizontal line between header and data
draw.line([table_x_start, y_position + row_height, table_x_end, y_position + row_height], fill=(0, 0, 0), width=1)

y_position += row_height

# First data row: 14% tax rate
tax_14 = subtotal_14 * 0.14  # €1.06
total_14 = subtotal_14 + tax_14  # €8.65

draw_text("14%", 50, y_position + 5, font_small)
draw_text(f"€{tax_14:.2f}", 130, y_position + 5, font_small)
draw_text(f"€{subtotal_14:.2f}", 200, y_position + 5, font_small)
draw_text(f"€{total_14:.2f}", 280, y_position + 5, font_small)

# Draw horizontal line between rows
draw.line([table_x_start, y_position + row_height, table_x_end, y_position + row_height], fill=(0, 0, 0), width=1)

y_position += row_height

# Second data row: 24% tax rate
tax_24 = subtotal_24 * 0.24  # €3.24
total_24 = subtotal_24 + tax_24  # €16.73

draw_text("24%", 50, y_position + 5, font_small)
draw_text(f"€{tax_24:.2f}", 130, y_position + 5, font_small)
draw_text(f"€{subtotal_24:.2f}", 200, y_position + 5, font_small)
draw_text(f"€{total_24:.2f}", 280, y_position + 5, font_small)

y_position += row_height + 5

# Grand totals
total_tax = tax_14 + tax_24  # €4.30
grand_total = total_subtotal + total_tax  # €25.38

y_position += 5
y_position = draw_text(f"Total Tax:               €{total_tax:.2f}", 50, y_position)
y_position = draw_text(f"TOTAL:                   €{grand_total:.2f}", 50, y_position)
y_position += 10

# Payment
y_position = draw_text("Payment: CARD", 50, y_position)
y_position += 10

# Footer
y_position = draw_text("Thank you!", 150, y_position)

# Save image
output_path = os.path.join(os.path.dirname(__file__), "test_receipt_v3.png")
img.save(output_path)
print(f"Test receipt image saved to: {output_path}")
print(f"  - 14% tax rate: Subtotal €{subtotal_14:.2f}, Tax €{tax_14:.2f}, Total €{total_14:.2f}")
print(f"  - 24% tax rate: Subtotal €{subtotal_24:.2f}, Tax €{tax_24:.2f}, Total €{total_24:.2f}")
print(f"  - Grand Total: Subtotal €{total_subtotal:.2f}, Tax €{total_tax:.2f}, Total €{grand_total:.2f}")

