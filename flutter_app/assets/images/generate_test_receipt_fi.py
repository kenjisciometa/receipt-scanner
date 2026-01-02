#!/usr/bin/env python3
"""
Generate Finnish test receipt image (test_receipt_fi.png)
Based on test_receipt.png structure but with Finnish translations
"""
from PIL import Image, ImageDraw, ImageFont
import os

# Receipt dimensions
WIDTH = 400
HEIGHT = 550
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
y_position = draw_text("123 Pääkatu", 130, y_position, font_small)
y_position = draw_text("Helsinki, FI", 150, y_position, font_small)
y_position += 10

# Date and Time (Finnish)
y_position = draw_text("Päivämäärä: 2026-01-02", 50, y_position)
y_position = draw_text("Aika: 13:30:15", 50, y_position)
y_position = draw_text("Kuitti nro 001234", 50, y_position)
y_position += 10

# Items section (Finnish)
y_position = draw_text("Tuotteet:", 50, y_position)
y_position = draw_text("Leipä                    €2.50", 50, y_position, font_small)
y_position = draw_text("Maito 1L                  €1.89", 50, y_position, font_small)
y_position = draw_text("Omenat 1kg               €3.20", 50, y_position, font_small)
y_position = draw_text("Kahvi                     €4.99", 50, y_position, font_small)
y_position += 10

# Subtotal (Finnish)
y_position = draw_text("Välisumma:                €12.58", 50, y_position)
y_position += 10

# VAT/ALV (Finnish - ALV is the Finnish term for VAT)
y_position = draw_text("ALV 24%:                  €3.02", 50, y_position)
y_position += 10

# Total (Finnish)
y_position = draw_text("YHTEENSÄ:                 €15.60", 50, y_position)
y_position += 10

# Payment (Finnish)
y_position = draw_text("Maksutapa: KORTTI", 50, y_position)
y_position += 10

# Footer (Finnish)
y_position = draw_text("Kiitos!", 150, y_position)

# Save image
output_path = os.path.join(os.path.dirname(__file__), "test_receipt_fi.png")
img.save(output_path)
print(f"Finnish test receipt image saved to: {output_path}")

