#!/usr/bin/env python3
"""
Generate German test receipt image (test_receipt_de.png)
Based on test_receipt.png structure but with German translations
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
y_position = draw_text("123 Hauptstraße", 130, y_position, font_small)
y_position = draw_text("Berlin, DE", 150, y_position, font_small)
y_position += 10

# Date and Time (German)
y_position = draw_text("Datum: 2026-01-02", 50, y_position)
y_position = draw_text("Uhrzeit: 13:30:15", 50, y_position)
y_position = draw_text("Rechnung Nr. 001234", 50, y_position)
y_position += 10

# Items section (German)
y_position = draw_text("Artikel:", 50, y_position)
y_position = draw_text("Brot                      €2.50", 50, y_position, font_small)
y_position = draw_text("Milch 1L                  €1.89", 50, y_position, font_small)
y_position = draw_text("Äpfel 1kg                €3.20", 50, y_position, font_small)
y_position = draw_text("Kaffee                    €4.99", 50, y_position, font_small)
y_position += 10

# Subtotal (German)
y_position = draw_text("Zwischensumme:            €12.58", 50, y_position)
y_position += 10

# VAT/MWST (German - MWST is the German term for VAT)
y_position = draw_text("MWST 24%:                 €3.02", 50, y_position)
y_position += 10

# Total (German)
y_position = draw_text("GESAMT:                   €15.60", 50, y_position)
y_position += 10

# Payment (German)
y_position = draw_text("Zahlung: KARTE", 50, y_position)
y_position += 10

# Footer (German)
y_position = draw_text("Vielen Dank!", 150, y_position)

# Save image
output_path = os.path.join(os.path.dirname(__file__), "test_receipt_de.png")
img.save(output_path)
print(f"German test receipt image saved to: {output_path}")

