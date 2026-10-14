# Tokyo Street — Menu List & Allergen Table

**Organization**: Tokyo Street Restaurants Oy (`b9d33e3b-926c-4943-b240-64953199edea`)
**Locations**: Hietalahden Kauppahalli (Lönnrotinkatu 34) / Vallila (Bruno Granholmin kuja 2)
**Created**: 2026-09-25
**Source**: POS DB `products` / `categories` / `product_availabilities` / `product_option_choices` (active records only — 129 consolidated)

> 🇯🇵 Japanese version: [menu-allergens.md](menu-allergens.md)

---

## How This List Was Built (Deduplication Rules)

For operational reasons, the POS stores **the same dish as multiple records**. The following were merged into single entries.

| Type of duplicate | Example | How it was merged |
|---|---|---|
| **Time-of-day variants** | Ginger-Pork €15.00 in `Lunch Main` vs. €16.70 in `After 3PM&Sat&Sun Main` | Merged into **one item** with both Lunch / Dinner prices |
| **Per-store variants** | Little Tokyo Kids Set (Hietalahati) / (Vallila) | Merged into **one item**, availability shown in a column |
| **Size variants** | Kizan 8cl / 12cl / 16cl / 75cl | Merged into **one item** with per-size pricing |
| **Orphan records with no category** | `Ginger Pork Salad` ×2 (€17 / €15, `category = null`) | Merged into the **existing Salads entry** |

> **Lunch pricing**: Weekdays until 15:00. Includes miso soup, coffee, and tea.
> **Dinner pricing**: Weekdays from 15:00 onward, and all day Saturday & Sunday.

---

## 1. Main Dishes

| # | Dish | Finnish | Lunch | Dinner | Available at | Allergens |
|---|---|---|---:|---:|---|---|
| 1 | Grilled Salmon Rice | Grillattu lohi riisillä | €14.50 | €16.00 | Hietalahti | 🐟 Fish, 🌰 Sesame, 🫘 Soy |
| 2 | Grilled Salmon Noodle | Grillattu lohi nuudeleilla | €14.50 | €16.00 | Hietalahti | 🐟 Fish, 🌰 Sesame, 🫘 Soy, 🌾 Gluten* |
| 3 | Teriyaki Salmon Rice | Teriyaki-lohi riisillä | €14.50 | €16.00 | Both | 🐟 Fish, 🌰 Sesame, 🫘 Soy |
| 4 | Teriyaki Salmon Noodles | Teriyaki-lohinuudelit | €14.50 | €16.00 | Both | 🐟 Fish, 🌰 Sesame, 🫘 Soy, 🌾 Gluten* |
| 5 | Salmon Ramen | Lohiramen | €14.00 | €15.70 | Both | 🐟 Fish*, 🌾 Gluten*, 🫘 Soy*, 🥚 Egg* |
| 6 | Karaage with Rice | Karaage riisillä | €15.00 | €16.70 | Both | 🫘 Soy*　🅶 **GF available** |
| 7 | Ginger-Pork | Inkivääripossu | €15.00 | €16.70 | Hietalahti | 🫘 Soy*, 🌾 Gluten*, 🌰 Sesame* |
| 8 | Sweet Soy Braised Pork Belly Bowl | Makean-suolainen possunkylki | €15.00 | €16.50 | Vallila | 🥚 Egg, 🌰 Sesame, 🫘 Soy |
| 9 | Chicken Dumpling Soup | Kanadumplingskeitto | €14.50 | €16.50 | Both | 🥚 Egg, 🌰 Sesame, 🌾 Gluten, 🫘 Soy |
| 10 | Noodle Salad (chicken) | Kananuudelisalaatti | €14.00 | €15.70 | Both | 🥚 Egg, 🌰 Sesame, 🌾 Gluten, 🫘 Soy |
| 11 | Rice Salad (chicken) | Kanariisisalaatti | €14.00 | €15.70 | Both | 🥚 Egg, 🌰 Sesame, 🫘 Soy |
| 12 | Chicken Meatballs with Organic Noodles | Kanalihapullat luomunuudeleilla | €13.00 | €15.00 | Both | 🌾 Gluten*, 🥚 Egg*, 🫘 Soy* |
| 13 | Chicken Meatballs with Rice | Kanalihapullat riisillä | €13.00 | — | Vallila | 🌾 Gluten*, 🥚 Egg*, 🫘 Soy* |
| 14 | Meatballs with Rice | Lihapullat riisillä | €11.00 | — | Both | 🌾 Gluten*, 🥚 Egg*, 🫘 Soy* |
| 15 | Little Tokyo Kids Set | Little Tokyo -lasten setti | €8.50 | €8.50 | Both | Varies by topping† |

### Dumplings (by piece count)

| Dish | Finnish | Lunch | Dinner | Available at | Allergens |
|---|---|---:|---:|---|---|
| Chicken Dumplings ×1 | Kanadumpling (1 kpl) | €1.75 | €1.90 | Both | 🌾 Gluten*, 🫘 Soy*, 🌰 Sesame* |
| Chicken Dumplings ×4 | Kanadumplingsit (4 kpl) | €7.00 | €7.60 | Both | Same as above |
| Chicken Dumplings ×6 | Kanadumplingsit (6 kpl) | €10.50 | €11.40 | Both | Same as above |
| Chicken Dumplings ×8 | Kanadumplingsit (8 kpl) | €14.00 | €15.20 | Both | Same as above |

---

## 2. Salads

| Dish | Finnish | Lunch | Dinner | Available at | Allergens |
|---|---|---:|---:|---|---|
| Chicken Salad | Kanasalaatti | €15.00 | €17.00 | Both | 🌰 Sesame, 🥬 Celery, 🫘 Soy |
| Karaage Salad | Karaage-salaatti | €15.00 | €17.00 | Both | 🌰 Sesame, 🥬 Celery, 🫘 Soy　🅶 **GF available** |
| Salmon Salad | Lohisalaatti | €15.00 | €17.00 | Both | 🐟 Fish, 🌰 Sesame, 🥬 Celery, 🫘 Soy |
| Tofu Salad | Tofusalaatti | €15.00 | €17.00 | Both | 🌰 Sesame, 🥬 Celery, 🫘 Soy |
| Ginger-Pork Salad | Inkivääri-porsaanlihasalaatti | €15.00 | €17.00 | Hietalahti | 🌰 Sesame, 🥬 Celery, 🫘 Soy |

---

## 3. Vegetarian & Vegan

| Dish | Finnish | Lunch | Dinner | Available at | Diet | Allergens |
|---|---|---:|---:|---|---|---|
| Tofu with Rice | Tofu riisillä | €13.00 | €15.00 | Both | Vegetarian | 🌰 Sesame, 🫘 Soy |
| Tofu Noodles | Tofunuudelit | €13.00 | €15.00 | Both | Vegetarian | 🌰 Sesame, 🌾 Gluten, 🫘 Soy |
| Vegan Teriyaki Rice Bowl | Vegaaninen teriyaki-riisikulho | €14.50 | €16.00 | Vallila | Vegan | 🫘 Soy, 🌾 Gluten* (seitan) |

> Vegan Teriyaki Rice Bowl contains: teriyaki-glazed seitan, steamed rice, sesame seeds, spring onion, nori.
> ⚠️ **Seitan is wheat gluten**, so the DB record (soy only) is incomplete. Adding gluten is strongly recommended.

---

## 4. Snacks & Izakaya Bites (Vallila only)

| Dish | Finnish | Price | Allergens |
|---|---|---:|---|
| 1 Crispy Karaage & Fries Set | Rapea karaage & ranskalaiset | €8.90 | 🫘 Soy　🅶 **GF available** |
| 2 Izakaya Chicken Bites Set | Izakaya-kanapalojen setti | €8.90 | 🫘 Soy, 🌾 Gluten* |
| 3 Loaded Izakaya Platter | Izakaya-herkkulautanen | €10.90 | 🫘 Soy, 🌾 Gluten* |
| 4 Vegan Bar Bites | 4 vegaanista naposteltavaa | €8.90 | 🫘 Soy, 🌾 Gluten* (seitan) |
| Edamame | Edamame | €4.50 | 🫘 Soy |
| French Fries | Ranskalaiset | €5.50 | None 🅶 **Gluten-free** |
| Yakitori ×3 | Yakitori (3 kpl) | €4.50 | 🫘 Soy*, 🌾 Gluten* |
| Yakitori ×5 | Yakitori (5 kpl) | €7.50 | 🫘 Soy*, 🌾 Gluten* |

> 4 Vegan Bar Bites contains: edamame, crispy seitan, french fries.
> ⚠️ Contains seitan (wheat gluten) — this set alone is **not gluten-free**.

### Beer Sets (snack + Kirin draft beer)

| Set | Finnish | Price | Contents |
|---|---|---:|---|
| Karaage Fries Beer Set | Karaage & ranskalais -ateria | €15.40 | 1 Crispy Karaage & Fries + draft beer |
| Chicken Bites Beer Set | Kanan napostelulautanen ateria | €15.40 | 2 Izakaya Chicken Bites + draft beer |
| Izakaya Platter Beer Set | Izakaya-lautanen ateria | €17.40 | 3 Loaded Izakaya Platter + draft beer |
| Vegan Bites Beer Set | Vegaaninen naposteluateria | €15.40 | 4 Vegan Bar Bites + draft beer |

> Allergens follow the component items (beer = 🌾 **barley gluten**).

---

## 5. Sushi

| Dish | Finnish | Price | Available at | Allergens |
|---|---|---:|---|---|
| Salmon Nigiri 5pcs | Lohinigiri (5 kpl) | €7.00 | Both | 🐟 Fish*, 🫘 Soy* (soy sauce) |
| Salmon Nigiri 6pcs + Chef's Selection 7pcs | Lohinigiri 6 kpl + kokin valinta 7 kpl | €14.00 | Both | 🐟 Fish*, 🦐 Crustaceans*, 🫘 Soy* |
| Sushi Small | Sushi (pieni) | €5.00 | Both | 🐟 Fish*, 🫘 Soy* |
| Sushi Large | Sushi (iso) | €10.00 | Both | 🐟 Fish*, 🫘 Soy* |

> ⚠️ The DB holds two `sushi-small` records (€5.00 and €25.00) while `sushi-large` is €10.00 — meaning **small is priced above large**. Needs verification (see "Data Quality Findings" below).

---

## 6. Beers

| Product | Finnish | Price | Available at | Allergens |
|---|---|---:|---|---|
| Kirin Ichiban Draft Beer | Kirin Ichiban hanaolut | from €7.00 | Both | 🌾 Barley gluten |
| Asahi Super Dry 33cl | Asahi Super Dry 33cl | €8.00 | Both | 🌾 Barley gluten |
| Kirin Ichiban 33cl | Kirin Ichiban 33cl | €8.00 | Both | 🌾 Barley gluten |
| Sapporo 33cl | Sapporo 33cl | €8.00 | Both | 🌾 Barley gluten |

> Draft beer size options: 25cl (+€0) / 50cl (+€4.00)

---

## 7. Non-Alcoholic Beverages

| Product | Finnish | Price | Allergens |
|---|---|---:|---|
| Asahi Super Dry Alcohol Free | Asahi alkoholiton olut | €4.80 | 🌾 Barley gluten |
| Kirin Ichiban Alcohol Free | Kirin alkoholiton olut | €4.80 | 🌾 Barley gluten |
| Heineken Alcohol Free | Heineken alkoholiton olut | €4.80 | 🌾 Barley gluten |
| Coca-Cola Classic 250ml | Coca-Cola Classic 250ml | €3.20 | None |
| Coca-Cola Zero 250ml | Coca-Cola Zero 250ml | €3.20 | None |
| Vichy Sparkling Water | Vichy kivennäisvesi | €2.50 | None |
| Green Tea 330ml | Vihreä tee | €2.50 | None |
| Ramune | Ramune | €3.50 | None |
| Mehukatti Trip Juice | Trip mehu | €1.50 | None |

---

## 8. Sake

| Product | Finnish | 8cl | 12cl | 16cl | 75cl bottle |
|---|---|---:|---:|---:|---:|
| Kido Ginjo (junmai ginjo) | Kido Ginjo (junmai-sake) | €8.00 | €11.00 | €14.00 | €45.00 |
| Kizan (junmai) | Kizan (junmai-sake) | €8.00 | €11.00 | €14.00 | €45.00 |

> Allergens: 🍶 Rice-based, therefore gluten-free. **Sulphite** content needs verification.

---

## 9. Wines

| Product | Region / Note | 12cl | 16cl | 24cl | 75cl bottle | ABV |
|---|---|---:|---:|---:|---:|---:|
| Chardonnay | — | €9.00 | — | €15.00 | €40.00 | — |
| Umani Ronchi | Italy | €9.00 | €11.00 | €15.00 | €40.00 | — |
| Matthias Gaul Riesling | Germany, Pfalz — 100% Riesling | €9.00 | — | — | — | 13.0% |
| Kaiken Estate Malbec Rosé | Argentina, Mendoza | €9.00 | — | — | — | 13.0% |
| D'Arenberg The Stump Jump GSM | Australia — full-bodied red | €9.00 | — | — | — | 14.5% |
| Prosecco Extra Dry | Italy (bottle only) | — | — | — | €32.00 | 11.0% |

> Allergens: 🍷 **Sulphites** — mandatory EU declaration. Safest to treat all wines as containing them.

---

## 10. Cocktails & Spirits (Vallila only)

| Product | Price | Base | Allergens |
|---|---:|---|---|
| Highball | €7.40 | Whisky + soda | 🌾 Barley* (from whisky) |
| Lemon Sour | €7.40 | Vodka + lemon + soda | None |
| Mojito | €7.40 | Rum + lime + mint | None |
| Gin Rickey | €7.40 | Gin + lime + soda | None |
| Screwdriver | €7.40 | Vodka + orange juice | None |
| Bulldog | €7.40 | Vodka + grapefruit | None |
| Salty Dog | €7.40 | Vodka + grapefruit + salted rim | None |
| Cassis Soda | €7.40 | Cassis + soda | None |
| Cassis Orange | €7.40 | Cassis + orange juice | None |
| **Kahlúa Milk** | €7.40 | Coffee liqueur + milk | 🥛 **Milk** |
| Umeshu Soda | €7.40 | Plum wine + soda | None |
| Yuzu Soda | €7.40 | Yuzu liqueur + soda | None |
| Umeshu | €9.00 | Japanese ume plums | None |
| Kyoto Yuzu 12% | €9.00 | Yuzu | None |
| Jim Beam 40% | €9.70 | Bourbon | 🌾 Barley*, corn |
| Johnnie Walker Red Label 40% | €9.70 | Scotch | 🌾 Barley* |

> Whisky size options: 5cl (+€0) / 7.5cl (+€5.50)

---

## 11. Options & Extras

| Item | Price | Note |
|---|---:|---|
| Protein choice | €0 | Chicken / Pork / Salmon / Tofu / Karaage |
| Noodle / Rice choice | €0 | 🌾 Choosing noodles introduces gluten |
| Mayonnaise | €0 | 🥚 **Egg** |
| No Mayonnaise | €0 | — |
| **Gluten-free soy sauce** | €0 | 🅶 Available on request |
| **Gluten-free teriyaki sauce** | €0 | 🅶 Available on request |
| Extra gluten-free shirataki noodles | €1.50 | 🅶 Hietalahti only |
| Extra portion (salmon / dumplings / meatballs) | €1.50 | Follows the component item |
| Mini portion | €8.70 | — |
| Kids Set Toppings | €0 | Salmon / Karaage / Pork Belly / Tofu / Vegan Teriyaki |

---

## Allergen Summary (EU 14 Declarable Allergens)

Allergens **confirmed or inferred** across the Tokyo Street menu:

| Allergen | Icon | Main dishes affected |
|---|---|---|
| **Soybeans** | 🫘 | Nearly all dishes using soy sauce, teriyaki, or miso; tofu; edamame |
| **Cereals containing gluten** | 🌾 | Noodles, dumpling wrappers, beer, seitan, soy sauce　※ **Karaage excluded / GF soy sauce available** |
| **Sesame** | 🌰 | Salads, rice bowls, dressings |
| **Fish** | 🐟 | All salmon dishes, sushi, dashi (bonito) |
| **Eggs** | 🥚 | Mayonnaise, dumplings, ramen noodles & marinated egg |
| **Celery** | 🥬 | Salad dressings |
| **Milk** | 🥛 | Kahlúa Milk |
| **Sulphites** | 🍷 | All wines |
| **Crustaceans** | 🦐 | Chef's selection sushi (may include shrimp) |

### Allergens Not Expected
Peanuts, tree nuts, milk (not used in food), mustard, lupin, molluscs.
※ However, **supplier-prepared items (dumplings, meatballs, etc.)** should be re-verified against the manufacturer's ingredient declarations.

---

## 🅶 Gluten-Free Capability (Confirmed with the Restaurant)

Tokyo Street can serve **a wide range of the menu gluten-free**, thanks to three measures:

| Measure | Detail |
|---|---|
| **① Karaage coating** | Uses **potato starch (katakuriko) only** — no wheat flour |
| **② Frying oil** | **Kept separate** to prevent wheat-flour cross-contamination |
| **③ Sauces** | **Gluten-free soy sauce and teriyaki sauce are stocked separately** (swapped on request) |

### Dishes Available Gluten-Free

| Dish | Condition |
|---|---|
| Karaage with Rice | Swap to GF soy sauce / GF sauce |
| Karaage Salad | Swap to GF dressing / GF soy sauce |
| 1 Crispy Karaage & Fries Set | As served (request GF sauce) |
| French Fries | As served |
| Grilled Salmon Rice | Swap to GF soy sauce; choose rice |
| Teriyaki Salmon Rice | Swap to GF teriyaki sauce |
| Ginger-Pork | Swap to GF soy sauce |
| Sweet Soy Braised Pork Belly Bowl | Swap to GF soy sauce |
| Tofu with Rice | Swap to GF soy sauce |
| Any rice bowl except Vegan Teriyaki | Choose **rice** instead of noodles |
| Noodle dishes generally | Swap to **shirataki noodles** (+€1.50 / Hietalahti) |

> ✅ **Key point**: Swapping noodles for rice or gluten-free shirataki, plus swapping to GF soy sauce / GF teriyaki sauce, covers most of the menu.

### Dishes That **Cannot** Be Made Gluten-Free

| Dish | Reason |
|---|---|
| Dumplings (Chicken Dumplings / Dumpling Soup) | Wheat wrapper |
| Vegan Teriyaki Rice Bowl | **Seitan = wheat gluten** is the main ingredient |
| 4 Vegan Bar Bites | Contains crispy seitan |
| All beers, incl. alcohol-free | Barley gluten |
| Salmon Ramen | Wheat ramen noodles (may be possible with shirataki swap) |

> ⚠️ **Vegan ≠ gluten-free** — this needs to be communicated clearly.
> Both vegan dishes (Vegan Teriyaki, Vegan Bar Bites) **contain seitan and therefore gluten**.
> For guests who want vegan *and* gluten-free, **Tofu with Rice + GF soy sauce** is the alternative.

---

## ⚠️ Data Quality Findings (Action Required)

Issues found in the POS records while compiling this list.

### 1. Most products have no allergen data
Of 129 active products, only **35 (27%)** have allergens recorded. The following are clearly affected but left **blank**:

- All karaage items (Karaage with Rice, Karaage Salad) → soy sauce in the marinade (soy); *gluten does not apply*
- All dumplings (1–8 pcs, €1.75–€15.20) → wheat in the wrapper
- Salmon Ramen → fish, gluten, egg
- Ginger-Pork (both bowl and salad) → soy sauce (soy)
- All sushi → fish, soy
- All beers → barley gluten
- Edamame → soy

> 🔴 **EU Regulation 1169/2011 makes declaration of the 14 allergens mandatory.** The missing wheat on dumplings and missing fish on sushi — both high-volume items — represent compliance risk.

### 1-b. Gluten-free capability is recorded nowhere
The restaurant operates a **three-layer gluten-free setup — ① potato-starch coating ② separated frying oil ③ GF soy sauce & GF teriyaki sauce** — yet **none of it exists in the POS database**.

- `products.tags` … empty array for every product (no `gluten-free` tag)
- `product_option_groups` … no GF soy sauce / GF sauce choice registered (currently handled verbally only)

> 🟡 This is **the inverse of a compliance risk — it is lost revenue.** The capability exists but is invisible to customers.
>
> **Recommended minimum implementation**:
> 1. Add `gluten-free` to `products.tags` (Karaage with Rice, Karaage Salad, French Fries, etc.)
> 2. Add a "Sauce choice (Regular / Gluten-free)" option group at €0
>    → the request then reaches the kitchen reliably via KDS, eliminating verbal-handoff errors

### 2. Missing gluten on Vegan Teriyaki Rice Bowl
Despite using seitan (wheat gluten), the only recorded allergen is `Soybean`.
**Vegan guests are easily mistaken for gluten-avoiding guests**, making this the highest-priority correction.

### 3. Incorrect `is_alcoholic` flags
These are alcoholic products but are stored with `is_alcoholic = false`:

- Kirin Ichiban Draft Beer
- All 16 cocktails (Highball, Mojito, Jim Beam, Johnnie Walker, etc.)
- Wines: Chardonnay, Umani Ronchi, Kaiken Rosé, D'Arenberg GSM, Prosecco
- Sake: Kido Ginjo, Kizan (all sizes)

> Only 4 records are correctly set to `true`: Asahi 33cl / Kirin 33cl / Sapporo 33cl / Riesling.
> This may affect age verification and alcohol sales reporting.

### 4. Sushi pricing inverted
`sushi-small` exists as two records (€5.00 and €25.00) while `sushi-large` is €10.00.
**Small at €25 > large at €10** — one of these is presumably a data-entry error.

### 5. 22 products have no category
Sushi, sake, wines (Chardonnay / Umani Ronchi), and the meatball dishes have `category = null`.
They do not appear on the POS category screen and can only be reached via search.

### 6. Inconsistent naming
Slug-style names such as `chicken-meatballs-with-rice` and `kizan-(100%-pure-rice-wine),-8cl` are mixed in with proper names, reducing legibility on receipts and KDS.

### 7. Products not assigned to any store
No `product_availabilities` rows, so they **appear at no location**:
Green Tea 330ml, Heineken Alcohol Free, kirin-non-alc-campaign, kirin-beer-campaign, chicken-meatballs-noodles

---

## Legend

- `*` … Not recorded in the POS, but **strongly inferred** from the dish composition (needs verification and registration)
- `†` … Varies depending on the options selected
- 🅶 … **Gluten-free available** (confirmed with the restaurant)
- Karaage uses **potato starch only, with separately managed frying oil**, so it does not carry the wheat allergen
- **Gluten-free soy sauce and teriyaki sauce are stocked** and can be swapped in on request, at no extra charge
- "Both" … served at both Hietalahden Kauppahalli and Vallila
- All prices include VAT (€, ALV 14% food / 25.5% alcohol)
