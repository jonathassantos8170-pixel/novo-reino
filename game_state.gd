extends Node
## Estado global: tempo, jogador, inventário, habilidades e salvamento.

signal day_passed(day: int)
signal message(text: String)

const SAVE_PATH := "user://save.json"
const MINUTES_PER_SECOND := 2.0   # 1 s real = 2 min de jogo (um dia = 12 min reais)
const DAYS_PER_SEASON := 15
const SEASONS := ["Primavera", "Verão", "Outono", "Inverno"]

const ITEMS := {
    "grain": {"name": "Grão", "cat": "Mercadoria", "weight": 0.5, "value": 8},
    "bread": {"name": "Pão", "cat": "Alimento", "weight": 0.3, "value": 12, "food": 35.0},
    "meat": {"name": "Carne", "cat": "Alimento", "weight": 0.4, "value": 14, "food": 30.0},
    "wood": {"name": "Madeira", "cat": "Material", "weight": 1.5, "value": 6},
    "iron": {"name": "Ferro", "cat": "Material", "weight": 2.0, "value": 20},
    "tools": {"name": "Ferramentas", "cat": "Ferramenta", "weight": 1.5, "value": 30},
    "pelt": {"name": "Pele", "cat": "Mercadoria", "weight": 0.8, "value": 18},
    "cloth": {"name": "Tecido", "cat": "Mercadoria", "weight": 0.6, "value": 16},
    "sword": {"name": "Espada", "cat": "Arma", "weight": 2.0, "value": 90, "dmg": 15.0, "reach": 40.0},
    "dagger": {"name": "Adaga", "cat": "Arma", "weight": 0.8, "value": 35, "dmg": 9.0, "reach": 28.0},
}

var started := false
var ui_open := false
var player_name := "Viajante"
var origin := "camponês"
var tunic := Color("6f8f4e")
var gold := 45
var inventory := {}
var weapon := "fists"
var max_hp := 100.0
var hp := 100.0
var hunger := 80.0
var minutes := 7.0 * 60.0
var day := 1
var bounty := {0: 0, 1: 0}
var reputation := {0: 0, 1: 0}
var skill_xp := {"combat": 0.0, "trade": 0.0}
var player_pos := Vector2.ZERO

const SETTINGS_PATH := "user://settings.json"
signal settings_changed
var settings := {"fps": 60, "zoom": 1.6}


func _ready() -> void:
    if FileAccess.file_exists(SETTINGS_PATH):
        var f := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
        var d = JSON.parse_string(f.get_as_text())
        if d is Dictionary:
            settings["fps"] = int(d.get("fps", 60))
            settings["zoom"] = float(d.get("zoom", 1.6))
    apply_settings()


func set_setting(key: String, value) -> void:
    settings[key] = value
    var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
    if f:
        f.store_string(JSON.stringify(settings))
    apply_settings()


func apply_settings() -> void:
    Engine.max_fps = int(settings["fps"])
    settings_changed.emit()


func say(text: String) -> void:
    message.emit(text)


func new_game(pname: String, org: String, col: Color) -> void:
    player_name = pname.strip_edges()
    if player_name == "":
        player_name = "Viajante"
    origin = org
    tunic = col
    minutes = 7.0 * 60.0
    day = 1
    hp = max_hp
    hunger = 80.0
    bounty = {0: 0, 1: 0}
    reputation = {0: 0, 1: 0}
    skill_xp = {"combat": 0.0, "trade": 0.0}
    inventory = {}
    if org == "mercenário":
        gold = 30
        weapon = "sword"
        add_item("sword", 1)
        add_item("bread", 2)
    else:
        gold = 45
        weapon = "fists"
        add_item("bread", 3)
        add_item("tools", 1)
    started = true


func advance(delta: float) -> void:
    minutes += delta * MINUTES_PER_SECOND
    if minutes >= 1440.0:
        minutes -= 1440.0
        day += 1
        day_passed.emit(day)
    var drain := 0.12
    if season_index() == 3:
        drain *= 1.5   # inverno gasta mais
    hunger = maxf(0.0, hunger - delta * drain)
    if hunger <= 0.0:
        hp -= delta * 0.8
    elif hp < max_hp and hunger > 50.0:
        hp = minf(max_hp, hp + delta * 0.3)


func hour() -> float:
    return minutes / 60.0


func is_night() -> bool:
    return hour() < 6.0 or hour() >= 19.0


func season_index() -> int:
    return int((day - 1) / float(DAYS_PER_SEASON)) % 4


func add_item(id: String, n: int) -> void:
    inventory[id] = int(inventory.get(id, 0)) + n


func remove_item(id: String, n: int) -> bool:
    if int(inventory.get(id, 0)) < n:
        return false
    inventory[id] = int(inventory[id]) - n
    if int(inventory[id]) <= 0:
        inventory.erase(id)
    return true


func count(id: String) -> int:
    return int(inventory.get(id, 0))


func weight() -> float:
    var w := 0.0
    for id in inventory:
        w += float(ITEMS[id]["weight"]) * int(inventory[id])
    return w


func weapon_stats() -> Dictionary:
    if ITEMS.has(weapon) and ITEMS[weapon].has("dmg"):
        return ITEMS[weapon]
    return {"dmg": 5.0, "reach": 28.0}


func skill_level(s: String) -> int:
    return int(float(skill_xp[s]) / 40.0)


func add_xp(s: String, amount: float) -> void:
    var before := skill_level(s)
    skill_xp[s] = float(skill_xp[s]) + amount
    if skill_level(s) > before:
        say("Habilidade %s subiu para o nível %d!" % [s, skill_level(s)])


func trade_mod() -> float:
    return 1.0 - minf(0.15, skill_level("trade") * 0.01)


# ---------------- Salvamento ----------------
func to_dict() -> Dictionary:
    return {"name": player_name, "origin": origin, "tunic": tunic.to_html(), "gold": gold,
        "inv": inventory, "weapon": weapon, "hp": hp, "hunger": hunger, "minutes": minutes,
        "day": day, "bounty": bounty, "rep": reputation, "xp": skill_xp,
        "pos": [player_pos.x, player_pos.y]}


func from_dict(d: Dictionary) -> void:
    player_name = d.get("name", "Viajante")
    origin = d.get("origin", "camponês")
    tunic = Color.html(d.get("tunic", "6f8f4e"))
    gold = int(d.get("gold", 0))
    inventory = {}
    for k in d.get("inv", {}):
        inventory[k] = int(d["inv"][k])
    weapon = d.get("weapon", "fists")
    hp = float(d.get("hp", 100.0))
    hunger = float(d.get("hunger", 80.0))
    minutes = float(d.get("minutes", 420.0))
    day = int(d.get("day", 1))
    bounty = {}
    for k in d.get("bounty", {}):
        bounty[int(k)] = int(d["bounty"][k])
    reputation = {}
    for k in d.get("rep", {}):
        reputation[int(k)] = int(d["rep"][k])
    skill_xp = {"combat": float(d.get("xp", {}).get("combat", 0.0)), "trade": float(d.get("xp", {}).get("trade", 0.0))}
    var p: Array = d.get("pos", [0, 0])
    player_pos = Vector2(float(p[0]), float(p[1]))
    started = true


func has_save() -> bool:
    return FileAccess.file_exists(SAVE_PATH)


func write_save(data: Dictionary) -> void:
    var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if f:
        f.store_string(JSON.stringify(data))


func read_save() -> Dictionary:
    if not has_save():
        return {}
    var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
    var parsed = JSON.parse_string(f.get_as_text())
    if parsed is Dictionary:
        return parsed
    return {}
