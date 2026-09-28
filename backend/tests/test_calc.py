from aureum_api.calc import (
    estimated_value,
    fine_weight,
    gold_value,
    net_weight,
    unrealized,
)


def test_net_weight_subtracts_stones():
    assert round(net_weight(46.8, 4.2), 3) == 42.6


def test_fine_weight_applies_purity_and_wastage():
    fine = fine_weight(10, 22, 6)
    assert round(fine, 4) == round(10 * (22 / 24) * 1.06, 4)


def test_value_adds_making_and_compares_with_purchase():
    metal = gold_value(9.1666667, 9860)
    total = estimated_value(metal, 18500)
    assert unrealized(total, 100000) == total - 100000
