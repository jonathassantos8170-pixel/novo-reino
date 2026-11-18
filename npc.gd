extends Node2D
class_name Npc
## NPC genérico (camponês, mercador, guarda, bandido, lobo, cervo).
## Não usa física: o movimento é manual e a IA roda via tick(dt), chamado pelo Sim
## com frequência diferente conforme a distância do jogador (LOD de simulação).

var id := 0
var role := "peasant"
var npc_name := "Alguém"
var settlement := "town"
var age := 30
var gold := 10
var hp := 30.0
var max_hp := 30.0
var speed := 40.0
var alive := true
var asleep := false
var died_day := 0
var home := Vector2.ZERO
var work_area := Rect2()
var patrol: Array = []
var patrol_i := 0
var camp := Vector2.ZERO
var roam_radius := 80.0
var dest := Vector2.ZERO
var has_dest := false
var wait := 0.0
var atk_cd := 0.0
var acc := 0.0
var lod := 0
var spawn_pos := Vector2.ZERO
var tint := Color.WHITE
var walk_t := 0.0
var flash := 0.0
var moving := false


func setup(p_role: String, p_name: String, p_settlement: String, pos: Vector2) -> void:
    role = p_role
    npc_name = p_name
    settlement = p_settlement
    position = pos
    spawn_pos = pos
    home = pos
    camp = pos
    age = randi_range(18, 60)
    add_to_group("npcs")
    add_to_group("damageable")
    match role:
        "peasant":
            hp = 25.0
            speed = 38.0
            tint = Color("8a6a4a")
            gold = randi_range(2, 20)
        "merchant":
            hp = 30.0
            speed = 30.0
            tint = Color("7a4a8a")
            gold = 200
        "guard":
            hp = 70.0
            speed = 50.0
            tint = Color("5a6f8f")
            gold = 15
            add_to_group("guards")
        "bandit":
            hp = 45.0
            speed = 52.0
            tint = Color("7a2a2a")
            gold = randi_range(10, 40)
            add_to_group("hostile")
        "wolf":
            hp = 30.0
            speed = 70.0
            tint = Color("77777a")
            add_to_group("hostile")
        "deer":
            hp = 20.0
            speed = 80.0
            tint = Color("a98458")
    max_hp = hp


func kingdom_id() -> int:
    return int(Kingdoms.settlement_owner.get(settlement, 0))


func tick(dt: float) -> void:
    if not alive:
        return
    atk_cd = maxf(0.0, atk_cd - dt)
    flash = maxf(0.0, flash - dt)
    moving = false
    match role:
        "peasant", "merchant":
            _civilian(dt)
        "guard":
            _guard(dt)
        "bandit":
            _bandit(dt)
        "wolf":
            _wolf(dt)
        "deer":
            _deer(dt)
    if moving:
        walk_t += dt * 10.0
    if visible:
        queue_redraw()


func _move_to(p: Vector2, dt: float, spd: float) -> bool:
    var d := p - position
    var l := d.length()
    var step := spd * dt
    moving = true
    if l <= step or l < 1.0:
        position = p
        return true
    position += d / l * step
    return false


func _nearest_in_group(g: String, r: float) -> Node2D:
    var best: Node2D = null
    var bd := r
    for n in get_tree().get_nodes_in_group(g):
        if n == self or not n.alive:
            continue
        var d: float = position.distance_to(n.position)
        if d < bd:
            bd = d
            best = n
    return best


func _wander(center: Vector2, radius: float, dt: float, spd: float) -> void:
    if wait > 0.0:
        wait -= dt
        return
    if not has_dest:
        dest = center + Vector2(randf_range(-radius, radius), randf_range(-radius, radius))
        has_dest = true
    if _move_to(dest, dt, spd):
        has_dest = false
        wait = randf_range(1.5, 5.0)


func _civilian(dt: float) -> void:
    var threat := _nearest_in_group("hostile", 130.0)
    if threat != null:
        asleep = false
        position += (position - threat.position).normalized() * speed * 1.4 * dt   # foge
        moving = true
        return
    var h := GameState.hour()
    if h < 6.0 or h >= 19.0:
        if _move_to(home, dt, speed):
            asleep = true
        return
    asleep = false
    if wait > 0.0:
        wait -= dt
        return
    if not has_dest:
        dest = Vector2(randf_range(work_area.position.x, work_area.end.x), randf_range(work_area.position.y, work_area.end.y))
        has_dest = true
    if _move_to(dest, dt, speed * 0.8):
        has_dest = false
        wait = randf_range(2.0, 6.0)


func _guard(dt: float) -> void:
    var target: Node2D = _nearest_in_group("hostile", 220.0)
    var pl: Node2D = get_tree().get_first_node_in_group("player")
    var k := kingdom_id()
    if target == null and pl != null and int(GameState.bounty.get(k, 0)) > 0 and position.distance_to(pl.position) < 220.0:
        target = pl
    if target != null:
        if position.distance_to(target.position) > 20.0:
            _move_to(target.position, dt, speed * 1.2)
        elif atk_cd <= 0.0:
            atk_cd = 1.0
            target.take_damage(8.0 if target == pl else 12.0, self)
            if target == pl and GameState.hp < 30.0 and GameState.hp > 0.0:
                get_tree().call_group("world", "arrest_player", k)
        return
    if patrol.is_empty():
        return
    if wait > 0.0:
        wait -= dt
        return
    if _move_to(patrol[patrol_i], dt, speed * 0.6):
        patrol_i = (patrol_i + 1) % patrol.size()
        wait = randf_range(1.0, 4.0)


func _aggressive(dt: float, aggro_r: float, leash: float, dmg: float, cd: float) -> bool:
    var pl: Node2D = get_tree().get_first_node_in_group("player")
    if pl == null:
        return false
    var d := position.distance_to(pl.position)
    if d < aggro_r and position.distance_to(camp) < leash:
        if d > 16.0:
            _move_to(pl.position, dt, speed)
        elif atk_cd <= 0.0:
            atk_cd = cd
            pl.take_damage(dmg, self)
        return true
    return false


func _bandit(dt: float) -> void:
    if _aggressive(dt, 170.0, 420.0, 7.0, 1.1):
        return
    if position.distance_to(camp) > 120.0:
        _move_to(camp, dt, speed)   # volta ao acampamento
        return
    _wander(camp, roam_radius, dt, speed * 0.5)


func _wolf(dt: float) -> void:
    if _aggressive(dt, 150.0, 500.0, 6.0, 1.0):
        return
    _wander(camp, 160.0, dt, speed * 0.4)


func _deer(dt: float) -> void:
    var pl: Node2D = get_tree().get_first_node_in_group("player")
    if pl != null and position.distance_to(pl.position) < 110.0:
        position += (position - pl.position).normalized() * speed * 1.3 * dt
        moving = true
        return
    _wander(camp, 160.0, dt, speed * 0.3)


func take_damage(amount: float, src = null) -> void:
    if not alive:
        return
    hp -= amount
    flash = 0.15
    asleep = false
    var by_player: bool = src != null and src.is_in_group("player")
    if by_player:
        GameState.add_xp("combat", 1.0)
        if role in ["peasant", "merchant", "guard"]:
            _crime(hp <= 0.0)
    if hp <= 0.0:
        _die(by_player)
    queue_redraw()


func _crime(killed: bool) -> void:
    var k := kingdom_id()
    var seen := role == "guard"
    for g in get_tree().get_nodes_in_group("guards"):
        if g != self and g.alive and g.position.distance_to(position) < 300.0:
            seen = true
    GameState.reputation[k] = int(GameState.reputation.get(k, 0)) - (15 if killed else 3)
    if seen:
        GameState.bounty[k] = int(GameState.bounty.get(k, 0)) + (80 if killed else 20)
        GameState.say("Um guarda testemunhou o crime! Você é procurado em %s." % Kingdoms.kingdom_name(k))


func _die(by_player: bool) -> void:
    alive = false
    asleep = false
    died_day = GameState.day
    if by_player:
        match role:
            "bandit":
                GameState.gold += gold + 12
                GameState.say("Bandido derrotado: +%d moedas." % (gold + 12))
            "wolf":
                GameState.add_item("pelt", 1)
                GameState.say("Você obteve uma pele de lobo.")
            "deer":
                GameState.add_item("meat", 2)
                GameState.add_item("pelt", 1)
                GameState.say("Caça: 2 carnes e 1 pele.")
    queue_redraw()


func respawn() -> void:
    alive = true
    hp = max_hp
    position = spawn_pos
    has_dest = false
    queue_redraw()


func _draw() -> void:
    if asleep:
        return
    if not alive:
        draw_rect(Rect2(-6, -2, 12, 5), Color(0.25, 0.1, 0.1, 0.8))
        return
    var bob := sin(walk_t) * 1.2 if moving else 0.0
    var col := Color.WHITE if flash > 0.0 else tint
    draw_circle(Vector2(0, 5), 5, Color(0, 0, 0, 0.25))
    match role:
        "wolf":
            draw_rect(Rect2(-8, -4 + bob, 16, 8), col)
            draw_rect(Rect2(6, -7 + bob, 6, 6), col.darkened(0.2))
        "deer":
            draw_rect(Rect2(-8, -5 + bob, 16, 8), col)
            draw_rect(Rect2(6, -10 + bob, 4, 7), col)
            draw_line(Vector2(8, -10 + bob), Vector2(11, -15 + bob), Color("5a4020"), 1.0)
        _:
            draw_rect(Rect2(-5, -9 + bob, 10, 13), col)
            draw_circle(Vector2(0, -12 + bob), 4, Color("e8c39e"))
            if role == "guard":
                draw_rect(Rect2(-4, -17 + bob, 8, 4), Color("aab"))
            elif role == "bandit":
                draw_rect(Rect2(-4, -16 + bob, 8, 3), Color("222"))
    if hp < max_hp:
        draw_rect(Rect2(-8, -20, 16, 2), Color(0, 0, 0, 0.6))
        draw_rect(Rect2(-8, -20, 16.0 * hp / max_hp, 2), Color(0.9, 0.2, 0.2))
