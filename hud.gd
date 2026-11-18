extends Control
class_name Hud
## HUD e controles de toque: joystick flutuante à esquerda, botões à direita.
## Todo o toque é tratado por índice de dedo, então mover e atacar ao mesmo tempo funciona.

signal inventory_pressed
signal map_pressed
signal save_pressed
signal menu_pressed

const STICK_R := 56.0

var player: Player
var hint := ""
var stick_idx := -1
var stick_origin := Vector2.ZERO
var stick_pos := Vector2.ZERO
var held := {}          # índice do dedo -> id do botão
var msgs: Array = []    # [texto, tempo restante]
var font: Font


func _ready() -> void:
    set_anchors_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    font = ThemeDB.fallback_font
    GameState.message.connect(_on_message)


func _on_message(t: String) -> void:
    msgs.append([t, 6.0])
    if msgs.size() > 4:
        msgs.pop_front()


func _buttons() -> Dictionary:
    var s := get_viewport_rect().size
    return {
        "atk": [Vector2(s.x - 100, s.y - 100), 48.0, "Atacar"],
        "def": [Vector2(s.x - 205, s.y - 70), 34.0, "Defesa"],
        "dodge": [Vector2(s.x - 195, s.y - 165), 32.0, "Esquiva"],
        "use": [Vector2(s.x - 95, s.y - 195), 32.0, "Ação"],
        "run": [Vector2(s.x - 290, s.y - 60), 28.0, "Correr"],
        "inv": [Vector2(s.x - 50, 40), 24.0, "Bolsa"],
        "map": [Vector2(s.x - 110, 40), 24.0, "Mapa"],
        "save": [Vector2(s.x - 170, 40), 24.0, "Salvar"],
        "menu": [Vector2(s.x - 230, 40), 24.0, "Menu"],
    }


func _input(e: InputEvent) -> void:
    if GameState.ui_open or player == null:
        return
    if e is InputEventScreenTouch:
        var t := e as InputEventScreenTouch
        if t.pressed:
            _press(t.index, t.position)
        else:
            _release(t.index)
    elif e is InputEventScreenDrag:
        var d := e as InputEventScreenDrag
        if d.index == stick_idx:
            _stick(d.position)


func _press(idx: int, pos: Vector2) -> void:
    var b := _buttons()
    for k in b:
        var info: Array = b[k]
        var c: Vector2 = info[0]
        var r: float = info[1]
        if pos.distance_to(c) <= r + 8.0:
            held[idx] = k
            _activate(k, true)
            return
    var s := get_viewport_rect().size
    if stick_idx == -1 and pos.x < s.x * 0.5:
        stick_idx = idx
        stick_origin = pos
        stick_pos = pos


func _release(idx: int) -> void:
    if idx == stick_idx:
        stick_idx = -1
        if player:
            player.move_vec = Vector2.ZERO
    elif held.has(idx):
        _activate(held[idx], false)
        held.erase(idx)


func _stick(pos: Vector2) -> void:
    var v := pos - stick_origin
    if v.length() > STICK_R:
        v = v.normalized() * STICK_R
    stick_pos = stick_origin + v
    var m := v / STICK_R
    player.move_vec = m if m.length() > 0.15 else Vector2.ZERO


func _activate(k: String, down: bool) -> void:
    match k:
        "atk":
            if down:
                player.attack()
        "def":
            player.blocking = down
        "dodge":
            if down:
                player.dodge()
        "use":
            if down:
                player.interact_requested.emit()
        "run":
            if down:
                player.run = not player.run
        "inv":
            if down:
                inventory_pressed.emit()
        "map":
            if down:
                map_pressed.emit()
        "save":
            if down:
                save_pressed.emit()
        "menu":
            if down:
                menu_pressed.emit()


func _process(delta: float) -> void:
    if GameState.ui_open and (stick_idx != -1 or not held.is_empty()):
        stick_idx = -1
        held.clear()
        if player:
            player.move_vec = Vector2.ZERO
            player.blocking = false
    for m in msgs:
        m[1] = float(m[1]) - delta
    while not msgs.is_empty() and float(msgs[0][1]) <= 0.0:
        msgs.pop_front()
    queue_redraw()


func _bar(pos: Vector2, w: float, frac: float, col: Color, label: String) -> void:
    draw_rect(Rect2(pos, Vector2(w, 12)), Color(0, 0, 0, 0.5))
    draw_rect(Rect2(pos, Vector2(w * clampf(frac, 0.0, 1.0), 12)), col)
    draw_string(font, pos + Vector2(4, 11), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)


func _draw() -> void:
    var s := get_viewport_rect().size
    # Escuridão da noite (barato: um retângulo, sem iluminação dinâmica)
    var h := GameState.hour()
    var night := 0.0
    if h < 5.0 or h >= 21.0:
        night = 0.55
    elif h < 7.0:
        night = lerpf(0.55, 0.0, (h - 5.0) / 2.0)
    elif h >= 18.0:
        night = lerpf(0.0, 0.55, (h - 18.0) / 3.0)
    if night > 0.0:
        draw_rect(Rect2(Vector2.ZERO, s), Color(0.02, 0.03, 0.12, night))
    if player == null:
        return
    # Barras
    _bar(Vector2(16, 14), 150, GameState.hp / GameState.max_hp, Color("c0392b"), "Vida")
    _bar(Vector2(16, 30), 150, player.stamina / 100.0, Color("d4a017"), "Fôlego")
    _bar(Vector2(16, 46), 150, GameState.hunger / 100.0, Color("c0702b"), "Fome")
    var line := "Ouro %d | Dia %d, %s | %02d:%02d" % [GameState.gold, GameState.day, GameState.SEASONS[GameState.season_index()], int(h), int(fmod(GameState.minutes, 60.0))]
    draw_string(font, Vector2(16, 76), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
    var y := 92
    if Kingdoms.at_war:
        var a := Kingdoms.aggressor
        draw_string(font, Vector2(16, y), "GUERRA: %s x %s" % [Kingdoms.kingdom_name(a), Kingdoms.kingdom_name(1 - a)], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("ff8a80"))
        y += 15
    for k in [0, 1]:
        if int(GameState.bounty.get(k, 0)) > 0:
            draw_string(font, Vector2(16, y), "Procurado em %s: %d" % [Kingdoms.kingdom_name(k), GameState.bounty[k]], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("ffd54f"))
            y += 15
    # Mensagens
    for i in msgs.size():
        var a2 := clampf(float(msgs[i][1]), 0.0, 1.0)
        draw_string(font, Vector2(0, 26 + i * 17), String(msgs[i][0]), HORIZONTAL_ALIGNMENT_CENTER, s.x - 240, 14, Color(1, 1, 1, a2))
    if hint != "":
        draw_string(font, Vector2(0, s.y - 24), hint, HORIZONTAL_ALIGNMENT_CENTER, s.x, 16, Color("ffe082"))
    # Joystick
    var base := stick_origin if stick_idx != -1 else Vector2(110, s.y - 100)
    var knob := stick_pos if stick_idx != -1 else base
    var al := 0.2 if stick_idx != -1 else 0.08
    draw_circle(base, STICK_R, Color(1, 1, 1, al))
    draw_arc(base, STICK_R, 0, TAU, 32, Color(1, 1, 1, al * 2.0), 2.0)
    draw_circle(knob, 22, Color(1, 1, 1, al * 2.5))
    # Botões
    var pressed_ids := held.values()
    var b := _buttons()
    for k in b:
        var info: Array = b[k]
        var c: Vector2 = info[0]
        var r: float = info[1]
        var on: bool = pressed_ids.has(k) or (k == "run" and player.run) or (k == "def" and player.blocking)
        draw_circle(c, r, Color(1, 1, 1, 0.38 if on else 0.16))
        draw_arc(c, r, 0, TAU, 24, Color(1, 1, 1, 0.5), 2.0)
        draw_string(font, Vector2(c.x - r, c.y + 4), String(info[2]), HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, 12, Color.WHITE)
