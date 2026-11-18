extends Node
## Reinos, diplomacia e guerra. A IA decide; a guerra é resolvida por simulação estratégica.

signal ownership_changed

var kingdoms: Array = []
var settlement_owner := {}
var settlement_names := {"town": "Aldória", "village": "Brevik", "castle": "Castelo Valdren"}
var at_war := false
var war_days := 0
var aggressor := 0


func _ready() -> void:
    reset()
    GameState.day_passed.connect(_on_day)


func reset() -> void:
    kingdoms = [
        {"name": "Reino de Aldória", "color": Color("3b6fd1"), "army": 120.0},
        {"name": "Reino de Valdren", "color": Color("c8433a"), "army": 110.0},
    ]
    settlement_owner = {"town": 0, "village": 1, "castle": 1}
    at_war = false
    war_days = 0
    aggressor = 0


func kingdom_name(i: int) -> String:
    return kingdoms[i]["name"]


func kingdom_color(i: int) -> Color:
    return kingdoms[i]["color"]


func owned_count(i: int) -> int:
    var c := 0
    for s in settlement_owner:
        if int(settlement_owner[s]) == i:
            c += 1
    return c


func _on_day(_d: int) -> void:
    for i in 2:
        kingdoms[i]["army"] = minf(400.0, float(kingdoms[i]["army"]) + 3.0 + owned_count(i) * 2.0)
    if at_war:
        _war_day()
    elif GameState.day > 4 and randf() < 0.15:
        _declare()


func _declare() -> void:
    var a := 0
    if float(kingdoms[1]["army"]) > float(kingdoms[0]["army"]):
        a = 1
    if randf() < 0.25:
        a = 1 - a
    aggressor = a
    at_war = true
    war_days = 0
    GameState.say("GUERRA! %s declarou guerra a %s." % [kingdom_name(a), kingdom_name(1 - a)])


func _war_day() -> void:
    war_days += 1
    var a := aggressor
    var d := 1 - a
    var sa: float = float(kingdoms[a]["army"]) * randf_range(0.9, 1.1)
    var sd: float = float(kingdoms[d]["army"]) * 1.15 * randf_range(0.9, 1.1)   # bônus de defesa
    kingdoms[d]["army"] = maxf(10.0, float(kingdoms[d]["army"]) - sa * 0.07)
    kingdoms[a]["army"] = maxf(10.0, float(kingdoms[a]["army"]) - sd * 0.07)
    if int(settlement_owner["village"]) == d and sa > sd * 1.4 and randf() < 0.3:
        settlement_owner["village"] = a
        at_war = false
        ownership_changed.emit()
        GameState.say("%s conquistou Brevik de %s! Fim da guerra." % [kingdom_name(a), kingdom_name(d)])
    elif war_days >= 5 and randf() < 0.2:
        at_war = false
        GameState.say("Os reinos assinaram a paz.")


func to_dict() -> Dictionary:
    return {"armies": [kingdoms[0]["army"], kingdoms[1]["army"]], "owner": settlement_owner,
        "war": at_war, "days": war_days, "agg": aggressor}


func from_dict(d: Dictionary) -> void:
    kingdoms[0]["army"] = float(d["armies"][0])
    kingdoms[1]["army"] = float(d["armies"][1])
    for k in d["owner"]:
        settlement_owner[k] = int(d["owner"][k])
    at_war = bool(d["war"])
    war_days = int(d["days"])
    aggressor = int(d["agg"])
    ownership_changed.emit()
