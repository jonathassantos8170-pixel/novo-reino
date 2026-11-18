extends Node
## Economia: estoques, produção/consumo diário e preços por oferta e demanda.

const GOODS := ["grain", "bread", "meat", "wood", "iron", "tools", "pelt", "cloth", "sword"]
const TARGET := 40.0   # estoque "normal": preço = preço base

var markets := {}


func _ready() -> void:
    reset()
    GameState.day_passed.connect(_on_day)


func reset() -> void:
    markets = {
        "town": {
            "stock": {"grain": 15, "bread": 40, "meat": 25, "wood": 20, "iron": 8, "tools": 60, "pelt": 10, "cloth": 40, "sword": 30},
            "prod": {"tools": 3, "bread": 4, "sword": 2, "cloth": 2},
            "cons": {"grain": 4, "iron": 2, "wood": 3, "pelt": 1, "meat": 2},
        },
        "village": {
            "stock": {"grain": 80, "bread": 10, "meat": 40, "wood": 60, "iron": 20, "tools": 8, "pelt": 30, "cloth": 10, "sword": 5},
            "prod": {"grain": 6, "wood": 4, "pelt": 2, "meat": 3, "iron": 1},
            "cons": {"tools": 2, "bread": 2, "sword": 1, "cloth": 2},
        },
    }


func _on_day(_d: int) -> void:
    for mid in markets:
        var m: Dictionary = markets[mid]
        for g in GOODS:
            var s: int = int(m["stock"].get(g, 0)) + int(m["prod"].get(g, 0)) - int(m["cons"].get(g, 0))
            m["stock"][g] = clampi(s, 0, 200)
    if randf() < 0.06:   # evento aleatório: escassez
        var ids := markets.keys()
        var mid: String = ids[randi() % ids.size()]
        var g: String = GOODS[randi() % GOODS.size()]
        markets[mid]["stock"][g] = int(markets[mid]["stock"][g] * 0.3)
        GameState.say("Escassez de %s em %s!" % [GameState.ITEMS[g]["name"], Kingdoms.settlement_names[mid]])


func base_price(g: String) -> int:
    return int(GameState.ITEMS[g]["value"])


func price(mid: String, g: String) -> float:
    var s := float(markets[mid]["stock"].get(g, 0))
    var r := TARGET / maxf(s, 1.0)
    var war := 1.0
    if Kingdoms.at_war and g == "sword":
        war = 1.4
    return base_price(g) * clampf(pow(r, 0.6), 0.4, 3.0) * war


func buy_price(mid: String, g: String) -> int:
    return maxi(1, ceili(price(mid, g) * 1.1 * GameState.trade_mod()))


func sell_price(mid: String, g: String) -> int:
    return maxi(1, floori(price(mid, g) * 0.9 / GameState.trade_mod()))


func stock(mid: String, g: String) -> int:
    return int(markets[mid]["stock"].get(g, 0))


func add_stock(mid: String, g: String, n: int) -> void:
    markets[mid]["stock"][g] = clampi(stock(mid, g) + n, 0, 200)


func buy(mid: String, g: String, n: int) -> bool:
    var p := buy_price(mid, g)
    n = mini(n, stock(mid, g))
    n = mini(n, int(GameState.gold / float(p)))
    if n <= 0:
        return false
    add_stock(mid, g, -n)
    GameState.gold -= n * p
    GameState.add_item(g, n)
    GameState.add_xp("trade", 0.4 * n)
    return true


func sell(mid: String, g: String, n: int) -> bool:
    n = mini(n, GameState.count(g))
    if n <= 0:
        return false
    var p := sell_price(mid, g)
    GameState.remove_item(g, n)
    GameState.gold += n * p
    add_stock(mid, g, n)
    GameState.add_xp("trade", 0.4 * n)
    return true


func to_dict() -> Dictionary:
    return {"markets": markets}


func from_dict(d: Dictionary) -> void:
    for mid in d.get("markets", {}):
        for g in d["markets"][mid]["stock"]:
            markets[mid]["stock"][g] = int(d["markets"][mid]["stock"][g])
