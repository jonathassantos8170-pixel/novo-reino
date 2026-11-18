extends CharacterBody2D
class_name Player
## Jogador: movimento, ataque, defesa, esquiva e stamina.

signal interact_requested
signal died

const WALK := 85.0

var move_vec := Vector2.ZERO   # preenchido pelo joystick virtual
var facing := Vector2.DOWN
var run := false
var blocking := false
var stamina := 100.0
var atk_cd := 0.0
var swing_t := 0.0
var dodge_t := 0.0
var dodge_cd := 0.0
var hurt_t := 0.0
var world_size := Vector2(3200, 1800)
var cam: Camera2D


func _ready() -> void:
    add_to_group("player")
    motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
    var cs := CollisionShape2D.new()
    var sh := CircleShape2D.new()
    sh.radius = 6.0
    cs.shape = sh
    add_child(cs)
    cam = Camera2D.new()
    cam.zoom = Vector2.ONE * float(GameState.settings["zoom"])
    GameState.settings_changed.connect(_apply_zoom)
    cam.position_smoothing_enabled = true
    cam.position_smoothing_speed = 8.0
    cam.limit_left = 0
    cam.limit_top = 0
    cam.limit_right = int(world_size.x)
    cam.limit_bottom = int(world_size.y)
    add_child(cam)


func _apply_zoom() -> void:
    cam.zoom = Vector2.ONE * float(GameState.settings["zoom"])


func _unhandled_input(e: InputEvent) -> void:
    # Atalhos de teclado para testar no computador
    if e is InputEventKey:
        var ke := e as InputEventKey
        if not ke.pressed or ke.echo:
            return
        match ke.keycode:
            KEY_SPACE:
                attack()
            KEY_SHIFT:
                dodge()
            KEY_E:
                interact_requested.emit()
            KEY_R:
                run = not run


func _physics_process(delta: float) -> void:
    if GameState.ui_open:
        velocity = Vector2.ZERO
        return
    atk_cd = maxf(0.0, atk_cd - delta)
    swing_t = maxf(0.0, swing_t - delta)
    dodge_t = maxf(0.0, dodge_t - delta)
    dodge_cd = maxf(0.0, dodge_cd - delta)
    hurt_t = maxf(0.0, hurt_t - delta)
    var dir := move_vec
    var k := Vector2(Input.get_axis("ui_left", "ui_right"), Input.get_axis("ui_up", "ui_down"))
    if k != Vector2.ZERO:
        dir = k
    if dir.length() > 1.0:
        dir = dir.normalized()
    if dodge_t > 0.0:
        velocity = facing * 240.0
    else:
        var spd := WALK
        if GameState.hunger < 15.0:
            spd *= 0.8
        if blocking:
            spd *= 0.5
        var running := run and stamina > 5.0 and dir.length() > 0.1 and not blocking
        if running:
            spd *= 1.6
            stamina -= 14.0 * delta
        else:
            stamina = minf(100.0, stamina + (6.0 if blocking else 18.0) * delta)
        velocity = dir * spd
        if dir.length() > 0.1:
            facing = dir.normalized()
    move_and_slide()
    position = position.clamp(Vector2(10, 10), world_size - Vector2(10, 10))
    GameState.player_pos = position
    queue_redraw()


func attack() -> void:
    if GameState.ui_open or blocking or atk_cd > 0.0 or stamina < 10.0 or dodge_t > 0.0:
        return
    stamina -= 10.0
    atk_cd = 0.45
    swing_t = 0.15
    var ws := GameState.weapon_stats()
    var reach: float = ws["reach"]
    var dmg: float = float(ws["dmg"]) * (1.0 + GameState.skill_level("combat") * 0.05)
    for n in get_tree().get_nodes_in_group("damageable"):
        if not n.alive or n.get("asleep") == true:
            continue
        var to: Vector2 = n.global_position - global_position
        var l := to.length()
        if l <= reach + 6.0 and (l < 12.0 or to.normalized().dot(facing) > 0.1):
            n.take_damage(dmg, self)


func dodge() -> void:
    if GameState.ui_open or dodge_cd > 0.0 or stamina < 20.0:
        return
    stamina -= 20.0
    dodge_t = 0.22
    dodge_cd = 1.0


func take_damage(amount: float, _src = null) -> void:
    if dodge_t > 0.0 or GameState.hp <= 0.0:
        return
    if blocking and stamina > 0.0:
        stamina = maxf(0.0, stamina - amount * 2.0)
        amount *= 0.3
    GameState.hp -= amount
    hurt_t = 0.2
    if GameState.hp <= 0.0:
        died.emit()


func _draw() -> void:
    var a := 0.5 if dodge_t > 0.0 else 1.0
    draw_circle(Vector2(0, 5), 6, Color(0, 0, 0, 0.25))
    var body := Color.WHITE if hurt_t > 0.0 else GameState.tunic
    body.a = a
    draw_rect(Rect2(-5, -9, 10, 13), body)
    draw_circle(Vector2(0, -12), 4, Color(0.91, 0.76, 0.62, a))
    if swing_t > 0.0:
        var reach: float = GameState.weapon_stats()["reach"]
        draw_line(facing * 6.0, facing * reach, Color(1, 1, 1, 0.9), 2.0)
    if blocking:
        draw_arc(Vector2(0, -2), 12.0, facing.angle() - 0.9, facing.angle() + 0.9, 8, Color(0.7, 0.7, 0.8), 3.0)
