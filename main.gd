extends Node2D
## Cena principal. Monta o mundo por código (leve, sem assets obrigatórios).
## Os gráficos atuais são formas primitivas (placeholders); troque por spritesheets depois.

const WORLD_SIZE := Vector2(3200, 1800)
const BANDIT_CAMP := Vector2(1700, 1060)
const FOREST := Rect2(1300, 1000, 900, 600)
const LAKE_C := Vector2(1000, 1350)
const LAKE_R := 150.0
const CASTLE_POS := Vector2(3010, 380)
const NAMES := ["Ana", "Bruno", "Clara", "Davi", "Elena", "Fábio", "Gaia", "Hugo", "Inês", "João",
    "Lia", "Mateus", "Nara", "Otto", "Pia", "Rui", "Sol", "Tomás", "Vera", "Yuri"]

var road := PackedVector2Array([Vector2(520, 730), Vector2(900, 760), Vector2(1300, 830),
    Vector2(1700, 900), Vector2(2100, 960), Vector2(2560, 1010)])
var settlements := {
    "town": {"pos": Vector2(520, 700), "stall": Vector2(470, 690)},
    "village": {"pos": Vector2(2600, 1000), "stall": Vector2(2600, 1045)},
}
# 0-3 casas da cidade, 4 salão, 5-8 vila, 9 castelo
var buildings: Array[Rect2] = [
    Rect2(360, 540, 100, 80), Rect2(520, 520, 110, 80), Rect2(360, 780, 100, 80), Rect2(600, 790, 120, 90),
    Rect2(680, 620, 110, 90),
    Rect2(2480, 880, 90, 70), Rect2(2650, 870, 90, 70), Rect2(2480, 1110, 90, 70), Rect2(2680, 1100, 100, 80),
    Rect2(2900, 300, 220, 160)]
var fields: Array[Rect2] = [Rect2(640, 430, 260, 150), Rect2(2760, 760, 220, 100)]
var trees := PackedVector2Array()
var forest_rect := FOREST
var lake_center := LAKE_C
var lake_radius := LAKE_R
var castle_pos := CASTLE_POS
var camp_pos := BANDIT_CAMP

var sim: Sim
var player: Player
var hud: Hud
var panels: Panels
var entities: Node2D
var last_season := -1
var hint_t := 0.0


func _ready() -> void:
    add_to_group("world")
    _gen_trees()
    _make_colliders()
    entities = Node2D.new()
    entities.y_sort_enabled = true
    add_child(entities)
    sim = Sim.new()
    add_child(sim)
    player = Player.new()
    player.position = settlements["town"]["pos"] + Vector2(0, 60)
    entities.add_child(player)
    sim.player = player
    _spawn_population()
    var layer := CanvasLayer.new()
    add_child(layer)
    hud = Hud.new()
    hud.player = player
    layer.add_child(hud)
    panels = Panels.new()
    panels.world = self
    layer.add_child(panels)
    hud.inventory_pressed.connect(panels.show_inventory)
    hud.map_pressed.connect(panels.show_map)
    hud.save_pressed.connect(_save.bind(false))
    panels.new_game_requested.connect(_on_new_game)
    panels.continue_requested.connect(_on_continue)
    player.interact_requested.connect(_on_interact)
    GameState.day_passed.connect(_on_day)
    Kingdoms.ownership_changed.connect(queue_redraw)
    hud.menu_pressed.connect(panels.show_main_menu)
    panels.save_requested.connect(_save.bind(true))
    panels.title_requested.connect(_back_to_title)
    panels.show_main_menu()


func _process(delta: float) -> void:
    if GameState.ui_open:
        return
    GameState.advance(delta)
    var s := GameState.season_index()
    if s != last_season:
        last_season = s
        queue_redraw()
    hint_t -= delta
    if hint_t <= 0.0:
        hint_t = 0.2
        hud.hint = _compute_hint()
    if GameState.hp <= 0.0:
        _on_died()


func _back_to_title() -> void:
    GameState.started = false
    GameState.ui_open = false
    get_tree().reload_current_scene()


# ---------------- Interação ----------------
func _nearest_stall() -> String:
    for mid in settlements:
        if player.position.distance_to(settlements[mid]["stall"]) < 70.0:
            return mid
    return ""


func _compute_hint() -> String:
    var mid := _nearest_stall()
    if mid == "":
        return ""
    if GameState.is_night():
        return "Mercado de %s (fechado à noite)" % Kingdoms.settlement_names[mid]
    return "Toque em Ação: mercado de %s" % Kingdoms.settlement_names[mid]


func _on_interact() -> void:
    var mid := _nearest_stall()
    if mid == "":
        GameState.say("Nada para interagir aqui. Procure o mercado nas vilas.")
    elif GameState.is_night():
        GameState.say("O mercado só abre de dia.")
    else:
        panels.show_market(mid)


func _on_died() -> void:
    GameState.hp = 60.0
    GameState.hunger = maxf(GameState.hunger, 40.0)
    GameState.gold = int(GameState.gold * 0.8)
    player.position = settlements["town"]["pos"] + Vector2(0, 60)
    GameState.say("Você desmaiou e acordou em Aldória. Perdeu 20% do ouro.")


func arrest_player(k: int) -> void:
    var fine := int(GameState.bounty.get(k, 0))
    GameState.gold = maxi(0, GameState.gold - fine)
    GameState.bounty[k] = 0
    GameState.hp = 40.0
    player.position = settlements["town"]["pos"] + Vector2(0, 60)
    GameState.say("Preso! Multa de %d moedas paga e você foi solto." % fine)


func _on_day(day: int) -> void:
    for n in sim.npcs:
        if not n.alive and n.role in ["bandit", "wolf", "deer"] and day - n.died_day >= 3:
            n.respawn()
    if GameState.started:
        _save(true)


# ---------------- Salvamento ----------------
func _save(silent: bool) -> void:
    if not GameState.started:
        return
    var npc_data := []
    for n in sim.npcs:
        npc_data.append([n.alive, n.position.x, n.position.y, n.hp, n.died_day])
    var cv := []
    for c in sim.caravans:
        cv.append(c.to_array())
    GameState.write_save({"v": 1, "game": GameState.to_dict(), "econ": Economy.to_dict(),
        "king": Kingdoms.to_dict(), "npcs": npc_data, "caravans": cv})
    if not silent:
        GameState.say("Jogo salvo.")


func _on_new_game(pname: String, origin: String, tunic: Color) -> void:
    GameState.new_game(pname, origin, tunic)
    Economy.reset()
    Kingdoms.reset()
    queue_redraw()
    GameState.say("Bem-vindo, %s! Visite o mercado e ganhe a vida." % GameState.player_name)


func _on_continue() -> void:
    var d := GameState.read_save()
    if d.is_empty():
        GameState.say("Nenhum jogo salvo.")
        return
    GameState.from_dict(d["game"])
    Economy.from_dict(d["econ"])
    Kingdoms.from_dict(d["king"])
    player.position = GameState.player_pos
    var arr: Array = d["npcs"]
    for i in mini(arr.size(), sim.npcs.size()):
        var a: Array = arr[i]
        var n: Npc = sim.npcs[i]
        n.alive = bool(a[0])
        n.position = Vector2(float(a[1]), float(a[2]))
        n.hp = float(a[3])
        n.died_day = int(a[4])
        n.queue_redraw()
    var cv: Array = d["caravans"]
    for i in mini(cv.size(), sim.caravans.size()):
        sim.caravans[i].from_array(cv[i])
    last_season = -1
    GameState.say("Jogo carregado.")


# ---------------- População ----------------
func _door(i: int) -> Vector2:
    var r := buildings[i]
    return Vector2(r.position.x + r.size.x * 0.5, r.end.y + 14.0)


func _add_npc(role: String, settlement: String, pos: Vector2) -> Npc:
    var n := Npc.new()
    n.id = sim.npcs.size()
    n.setup(role, NAMES[n.id % NAMES.size()], settlement, pos)
    entities.add_child(n)
    sim.npcs.append(n)
    return n


func _spawn_population() -> void:
    var town_stall: Vector2 = settlements["town"]["stall"]
    var vill_stall: Vector2 = settlements["village"]["stall"]
    for i in 6:
        var n := _add_npc("peasant", "town", _door(i % 4))
        n.home = _door(i % 4)
        n.work_area = fields[0]
    for i in 3:
        var g := _add_npc("guard", "town", town_stall + Vector2(i * 20, 40))
        g.patrol = [Vector2(470, 650), Vector2(600, 760), Vector2(700, 770), Vector2(450, 760)]
        g.patrol_i = i
    var m1 := _add_npc("merchant", "town", town_stall + Vector2(0, 18))
    m1.home = _door(4)
    m1.work_area = Rect2(town_stall.x - 25, town_stall.y + 10, 50, 20)
    for i in 5:
        var n2 := _add_npc("peasant", "village", _door(5 + i % 4))
        n2.home = _door(5 + i % 4)
        n2.work_area = fields[1]
    for i in 2:
        var g2 := _add_npc("guard", "village", vill_stall + Vector2(i * 20, 30))
        g2.patrol = [Vector2(2560, 960), Vector2(2680, 1050), Vector2(2560, 1080)]
        g2.patrol_i = i
    var m2 := _add_npc("merchant", "village", vill_stall + Vector2(0, 18))
    m2.home = _door(8)
    m2.work_area = Rect2(vill_stall.x - 25, vill_stall.y + 10, 50, 20)
    for i in 5:
        var b := _add_npc("bandit", "wild", BANDIT_CAMP + Vector2(randf_range(-50, 50), randf_range(-50, 50)))
        b.camp = BANDIT_CAMP
        b.roam_radius = 70.0
    for i in 4:
        var w := _add_npc("wolf", "wild", Vector2(randf_range(FOREST.position.x, FOREST.end.x), randf_range(FOREST.position.y, FOREST.end.y)))
        w.camp = w.position
    for i in 4:
        var dr := _add_npc("deer", "wild", Vector2(randf_range(1250, 1850), randf_range(900, 1150)))
        dr.camp = dr.position
    for i in 2:
        var c := Caravan.new()
        c.setup(road, BANDIT_CAMP, "Caravana %d" % (i + 1))
        if i == 0:
            c.cargo = {"tools": 8}
        else:
            c.progress = c.total * 0.5
            c.dir = -1
            c.cargo = {"grain": 10}
        c.position = c.point_at(c.progress)
        entities.add_child(c)
        sim.caravans.append(c)


# ---------------- Mundo estático ----------------
func _road_dist(p: Vector2) -> float:
    var best := 99999.0
    for i in road.size() - 1:
        var q := Geometry2D.get_closest_point_to_segment(p, road[i], road[i + 1])
        best = minf(best, p.distance_to(q))
    return best


func _blocked(p: Vector2) -> bool:
    if p.distance_to(settlements["town"]["pos"]) < 300.0 or p.distance_to(settlements["village"]["pos"]) < 260.0:
        return true
    if Rect2(2850, 250, 320, 260).has_point(p) or p.distance_to(BANDIT_CAMP) < 130.0:
        return true
    if p.distance_to(LAKE_C) < LAKE_R + 25.0 or _road_dist(p) < 45.0:
        return true
    for f in fields:
        if f.grow(15.0).has_point(p):
            return true
    return false


func _gen_trees() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 7
    var tries := 0
    while trees.size() < 300 and tries < 4000:
        tries += 1
        var p := Vector2(rng.randf_range(40, WORLD_SIZE.x - 40), rng.randf_range(40, WORLD_SIZE.y - 40))
        if trees.size() < 170:
            p = Vector2(rng.randf_range(FOREST.position.x, FOREST.end.x), rng.randf_range(FOREST.position.y, FOREST.end.y))
        if not _blocked(p):
            trees.append(p)


func _block_rect(r: Rect2) -> void:
    var body := StaticBody2D.new()
    body.position = r.get_center()
    var cs := CollisionShape2D.new()
    var sh := RectangleShape2D.new()
    sh.size = r.size
    cs.shape = sh
    body.add_child(cs)
    add_child(body)


func _make_colliders() -> void:
    for r in buildings:
        _block_rect(r)
    var lake := StaticBody2D.new()
    lake.position = LAKE_C
    var cs := CollisionShape2D.new()
    var sh := CircleShape2D.new()
    sh.radius = LAKE_R
    cs.shape = sh
    lake.add_child(cs)
    add_child(lake)


func _roof_color(i: int) -> Color:
    if i < 5:
        return Kingdoms.kingdom_color(int(Kingdoms.settlement_owner["town"]))
    if i < 9:
        return Kingdoms.kingdom_color(int(Kingdoms.settlement_owner["village"]))
    return Kingdoms.kingdom_color(1)


func _draw() -> void:
    var s := GameState.season_index()
    var ground_cols := [Color("4f8a3c"), Color("5a9a3a"), Color("a0802f"), Color("dfe8ee")]
    var tree_cols := [Color("2f6b2a"), Color("2a7a2a"), Color("b0541c"), Color("9fb8a8")]
    draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), ground_cols[s])
    draw_circle(LAKE_C, LAKE_R, Color("3b6ea5"))
    draw_polyline(road, Color("8a6b43"), 26.0)
    draw_polyline(road, Color("a58558"), 12.0)
    for f in fields:
        draw_rect(f, Color("7a5a2a") if s != 3 else Color("c8d0d4"))
        var x := f.position.x + 6.0
        while x < f.end.x:
            draw_line(Vector2(x, f.position.y), Vector2(x, f.end.y), Color("5a8a2a") if s < 3 else Color("aab"), 2.0)
            x += 12.0
    for mid in settlements:
        var st: Vector2 = settlements[mid]["stall"]
        draw_rect(Rect2(st - Vector2(60, 40), Vector2(120, 80)), Color("8c8c84"))
        draw_rect(Rect2(st - Vector2(14, 12), Vector2(28, 16)), Color("b4543a"))
        draw_rect(Rect2(st - Vector2(14, 12), Vector2(28, 5)), Color("e8e0c0"))
    for i in buildings.size():
        var r := buildings[i]
        if i == 9:
            draw_rect(r, Color("7d7d86"))
            for cx in [r.position.x, r.end.x - 40.0]:
                draw_rect(Rect2(cx, r.position.y - 30, 40, 60), Color("6a6a74"))
            draw_rect(Rect2(r.position.x + 90, r.end.y - 40, 40, 40), Color("2a2a30"))
        else:
            draw_rect(r, Color("c9b28a"))
            draw_rect(Rect2(r.position, Vector2(r.size.x, r.size.y * 0.4)), _roof_color(i))
            draw_rect(Rect2(r.position.x + r.size.x * 0.5 - 6, r.end.y - 18, 12, 18), Color("4a3220"))
    # acampamento bandido
    for off in [Vector2(-40, -20), Vector2(30, -25), Vector2(0, 35)]:
        var p: Vector2 = BANDIT_CAMP + off
        draw_colored_polygon(PackedVector2Array([p + Vector2(-16, 12), p + Vector2(16, 12), p + Vector2(0, -16)]), Color("5a2a2a"))
    draw_circle(BANDIT_CAMP + Vector2(0, 5), 5, Color("ff8a2a"))
    for t in trees:
        draw_rect(Rect2(t.x - 1.5, t.y - 2, 3, 8), Color("4a3220"))
        draw_circle(t + Vector2(0, -6), 7, tree_cols[s])
