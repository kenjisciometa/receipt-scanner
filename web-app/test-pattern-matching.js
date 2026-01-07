/**
 * Test script to understand the pattern matching issue
 */

const testText = "SUBTOTAL $208.98";
const testText2 = "TOTAL $222.35";

// Test the problematic patterns

// Original regex that's causing the issue
const totalPattern = /(?:total|sum|yhteensä|summa|gesamt|totalt|montant total|totale|importe)\s*:?\s*([€$£¥₹]?\s*\d+[.,]\d{2}|\d+[.,]\d{2}\s*[€$£¥₹])/gi;

// Fixed regex with negative lookahead
const fixedTotalPattern = /^(?!.*(?:subtotal|sub[\s\-]total|välisumma|zwischensumme|delsumma|sous[\s\-]total|subtotale|base\s+imponible)).*\b(?:total|sum|yhteensä|summa|gesamt|totalt|montant\s+total|totale|importe)\s*:?\s*([€$£¥₹]?\s*\d+[.,]\d{2}|\d+[.,]\d{2}\s*[€$£¥₹])/gi;

// Subtotal pattern
const subtotalPattern = /(?:subtotal|välisumma|zwischensumme|delsumma|sous-total|subtotale|base imponible)\s*:?\s*([€$£¥₹]?\s*\d+[.,]\d{2}|\d+[.,]\d{2}\s*[€$£¥₹])/gi;

console.log("🔍 Testing pattern matching...\n");

console.log("Test text 1: 'SUBTOTAL $208.98'");
console.log("- Original total pattern matches:", totalPattern.test(testText));
totalPattern.lastIndex = 0; // Reset regex
console.log("- Fixed total pattern matches:", fixedTotalPattern.test(testText));
fixedTotalPattern.lastIndex = 0; // Reset regex
console.log("- Subtotal pattern matches:", subtotalPattern.test(testText));
subtotalPattern.lastIndex = 0; // Reset regex

console.log("\nTest text 2: 'TOTAL $222.35'");
console.log("- Original total pattern matches:", totalPattern.test(testText2));
totalPattern.lastIndex = 0; // Reset regex
console.log("- Fixed total pattern matches:", fixedTotalPattern.test(testText2));
fixedTotalPattern.lastIndex = 0; // Reset regex
console.log("- Subtotal pattern matches:", subtotalPattern.test(testText2));

console.log("\n🎯 Expected behavior:");
console.log("- 'SUBTOTAL $208.98' should only match subtotal pattern");
console.log("- 'TOTAL $222.35' should only match total pattern");