extends Node2D
class_name Caravan
## Caravana comercial. Anda ao longo da estrada (cálculo por distância, sem física),
## negocia nos mercados e pode sofrer emboscadas (resolvidas estatisticamente).

var path := PackedVector2Array()
var total := 0.0
var progress := 0.0
var dir := 1
var speed := 38.0
var cargo := {}
var gold := 120
var guards := 3
var wait := 0.0
var cname := "Caravana"
var acc := 0.0
var lod := 0
var danger_done := false
var aggro := 0.0
var atk_cd := 0.0
var alive := true
var camp := Vector2.ZERO
var ends := ["town", "village"]
var hit_pool := 0.0
var flash := 0.0


func setup(p_path: PackedVector2Array, p_camp: Vector2, p_name: String) -> void:
    path = p_path
    camp = p_camp
    cname = p_name
    total = 0.0
    for i in path.size() - 1:
        total += path[i].distance_to(path[i + 1])
    add_to_group("damageable")
    add_to_group("caravans")


func point_at(d: float) -> Vector2:
    var rem := clampf(d, 0.0, total)
    for i in path.size() - 1:
        var l := path[i].distance_to(path[i + 1])
        if rem <= l:
            return path[i].lerp(path[i + 1], rem / maxf(l, 0.001))
        rem -= l
    return path[path.size() - 1]


func tick(dt: float) -> void:
    atk_cd = maxf(0.0, atk_cd - dt)
    aggro = maxf(0.0, aggro - dt)
    flash = maxf(0.0, flash - dt)
    if aggro > 0.0:
        _fight()
    if wait > 0.0:
        wait -= dt
        if visible:
            queue_redraw()
        return
    var mod := 0.8 if GameState.season_index() == 3 else 1.0
    progress += dir * speed * dt * mod
    if progress >= total:
        progress = total
        _arrive(ends[1])
        dir = -1
    elif progress <= 0.0:
        progress = 0.0
        _arrive(ends[0])
        dir = 1
    position = point_at(progress)
    var dc := position.distance_to(camp)
    if dc < 220.0 and not danger_done:
        danger_done = true
        _ambush()
    elif dc > 320.0:
        danger_done = false
    if visible:
        queue_redraw()


func _arrive(mid: String) -> void:
    wait = 15.0
    var other := "village" if mid == "town" else "town"
    for g in cargo:
        var n: int = cargo[g]
        gold += n * Economy.sell_price(mid, g)
        Economy.add_stock(mid, g, n)
    cargo.clear()
    gold -= guards * 3
    if guards < 3 and gold >= 40:
        guards += 1
        gold -= 40
    if gold < 60:
        gold = 60   # o patrocinador reabastece o capital da caravana
    var best := ""
    var best_margin := 0.0
    for g in Economy.GOODS:
        var m := float(Economy.sell_price(other, g) - Economy.buy_price(mid, g))
        if m > best_margin and Economy.stock(mid, g) > 8:
            best = g
            best_margin = m
    if best != "":
        var unit := Economy.buy_price(mid, best)
        var n := mini(10, mini(int(gold * 0.8 / unit), Economy.stock(mid, best) - 6))
        if n > 0:
            Economy.add_stock(mid, best, -n)
            gold -= n * unit
            cargo[best] = n


func _ambush() -> void:
    var bandits: Array = []
    for b in get_tree().get_nodes_in_group("hostile"):
        if b.role == "bandit" and b.alive:
            bandits.append(b)
    if bandits.is_empty() or randf() > 0.6:
        return
    var bs := bandits.size() * 10.0
    var gs := guards * 12.0 + randf_range(0.0, 10.0)
    if randf() < bs / (bs + gs):
        cargo.clear()
        gold = int(gold * 0.3)
        guards = maxi(0, guards - 2)
        GameState.say("%s foi saqueada por bandidos!" % cname)
    else:
        guards = maxi(0, guards - 1)
        bandits[0].take_damage(999.0, null)
        GameState.say("%s repeliu uma emboscada de bandidos." % cname)


func take_damage(amount: float, src = null) -> void:
    if src == null or not src.is_in_group("player"):
        return
    aggro = 12.0
    flash = 0.15
    if guards > 0:
        hit_pool += amount
        while hit_pool >= 15.0 and guards > 0:
            guards -= 1
            hit_pool -= 15.0
        return
    # sem guardas: o jogador saqueia a caravana
    var k := int(Kingdoms.settlement_owner[ends[0] if progress < total * 0.5 else ends[1]])
    var loot := 0
    for g in cargo:
        GameState.add_item(g, int(cargo[g]))
        loot += int(cargo[g])
    GameState.gold += gold
    GameState.say("Você saqueou %s: %d moedas e %d mercadorias." % [cname, gold, loot])
    cargo.clear()
    gold = 60
    guards = 2
    wait = 20.0
    GameState.reputation[k] = int(GameState.reputation.get(k, 0)) - 20
    var seen := false
    for g in get_tree().get_nodes_in_group("guards"):
        if g.alive and g.position.distance_to(position) < 300.0:
            seen = true
    if seen:
        GameState.bounty[k] = int(GameState.bounty.get(k, 0)) + 60
        GameState.say("Testemunhas! Você é procurado em %s." % Kingdoms.kingdom_name(k))


func _fight() -> void:
    var pl: Node2D = get_tree().get_first_node_in_group("player")
    if guards > 0 and atk_cd <= 0.0 and pl != null and position.distance_to(pl.position) < 40.0:
        atk_cd = 1.0
        pl.take_damage(4.0 * mini(guards, 3), self)


func to_array() -> Array:
    return [progress, dir, cargo, gold, guards, wait]


func from_array(a: Array) -> void:
    progress = float(a[0])
    dir = int(a[1])
    cargo = {}
    for g in a[2]:
        cargo[g] = int(a[2][g])
    gold = int(a[3])
    guards = int(a[4])
    wait = float(a[5])
    position = point_at(progress)


func _draw() -> void:
    draw_circle(Vector2(0, 8), 10, Color(0, 0, 0, 0.2))
    var body := Color.WHITE if flash > 0.0 else Color("9b7653")
    draw_rect(Rect2(-9, -6, 18, 12), body)
    draw_rect(Rect2(-9, -10, 18, 4), Color("d8cfa8"))
    draw_circle(Vector2(-6, 7), 3, Color("3a2a1a"))
    draw_circle(Vector2(6, 7), 3, Color("3a2a1a"))
    draw_rect(Rect2(10, -3, 8, 6), Color("5a3a22"))
    for i in guards:
        draw_circle(Vector2(-8 + i * 6, -14), 2.5, Color("5a6f8f"))
