"""Valuation for a single piece of gold jewellery.

Fine gold (grams) = (gross − stones) × (karat ÷ 24) × (1 + wastage ÷ 100)
Gold value = fine gold × the 24K rate per gram
Vault value = gold value + making charge
"""

from __future__ import annotations


def net_weight(gross_g: float, stone_g: float) -> float:
    return gross_g - stone_g


def fine_weight(net_g: float, karat: float, wastage_percent: float) -> float:
    purity = karat / 24.0
    wastage = 1.0 + (wastage_percent / 100.0)
    return net_g * purity * wastage


def gold_value(fine_g: float, rate_24k: float) -> float:
    return fine_g * rate_24k


def estimated_value(metal_value: float, making_charge: float) -> float:
    return metal_value + making_charge


def unrealized(estimated: float, purchase_price: float) -> float:
    return estimated - purchase_price


def round_grams(value: float) -> float:
    return round(value, 3)


def round_money(value: float) -> float:
    return round(value, 2)
