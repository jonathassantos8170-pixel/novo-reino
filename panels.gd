extends Control
class_name Panels
## Telas modais: menu inicial, mercado, bolsa/personagem e mapa.
## Enquanto uma tela está aberta, GameState.ui_open = true e o mundo pausa.

signal new_game_requested(pname: String, origin: String, tunic: Color)
signal continue_requested
signal save_requested
signal title_requested

const ORIGIN_TEXT := {
    "camponês": "Camponês: poucas moedas (45), pão e uma ferramenta. Pode crescer pelo comércio e pelo trabalho.",
    "mercenário": "Mercenário: 30 moedas, uma espada e experiência de combate.",
}

var world: Node
var content: VBoxContainer
var market_id := ""
var market_rows := {}
var market_info: Label


func _ready() -> void:
    set_anchors_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    visible = false


func close() -> void:
    for c in get_children():
        c.queue_free()
    visible = false
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    GameState.ui_open = false


func _btn(text: String, cb: Callable) -> Button:
    var b := Button.new()
    b.text = text
    b.custom_minimum_size = Vector2(0, 40)
    b.pressed.connect(cb)
    return b


func _open(title: String, closable := true) -> VBoxContainer:
    for c in get_children():
        c.queue_free()
    visible = true
    mouse_filter = Control.MOUSE_FILTER_STOP
    GameState.ui_open = true
    var dim := ColorRect.new()
    dim.color = Color(0, 0, 0, 0.6)
    dim.set_anchors_preset(Control.PRESET_FULL_RECT)
    add_child(dim)
    var pc := PanelContainer.new()
    pc.anchor_right = 1.0
    pc.anchor_bottom = 1.0
    pc.offset_left = 50
    pc.offset_right = -50
    pc.offset_top = 20
    pc.offset_bottom = -20
    add_child(pc)
    var vb := VBoxContainer.new()
    pc.add_child(vb)
    var head := HBoxContainer.new()
    vb.add_child(head)
    var t := Label.new()
    t.text = title
    t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    t.add_theme_font_size_override("font_size", 22)
    head.add_child(t)
    if closable:
        head.add_child(_btn("Fechar", close))
    var sc := ScrollContainer.new()
    sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
    sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    vb.add_child(sc)
    content = VBoxContainer.new()
    content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    sc.add_child(content)
    return content


# ---------------- Tela inicial / menu ----------------
func show_main_menu() -> void:
    var in_game := GameState.started
    var c := _open("Reinos de Ferro" if not in_game else "Menu", false)
    var sub := Label.new()
    sub.text = "Um mundo medieval vivo, feito para o seu iPhone." if not in_game else "Jogo em andamento (o mundo está pausado)."
    sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    c.add_child(sub)
    if in_game:
        c.add_child(_btn("Continuar jogando", close))
        c.add_child(_btn("Configurações", show_settings))
        c.add_child(_btn("Salvar e voltar ao título", _to_title))
    else:
        c.add_child(_btn("Entrar no jogo", show_start))
        c.add_child(_btn("Configurações", show_settings))
    c.add_child(_btn("Sair do jogo", _quit))


func _to_title() -> void:
    save_requested.emit()
    title_requested.emit()


func _quit() -> void:
    save_requested.emit()
    get_tree().quit()


func show_settings() -> void:
    var c := _open("Configurações", false)
    var fps := int(GameState.settings["fps"])
    var l1 := Label.new()
    l1.text = "Taxa de quadros: %d FPS (30 economiza bateria e esquenta menos)" % fps
    l1.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    c.add_child(l1)
    var r1 := HBoxContainer.new()
    c.add_child(r1)
    for v in [30, 60]:
        var b := _btn("%d FPS%s" % [v, " (atual)" if v == fps else ""], _set_setting.bind("fps", v))
        b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        r1.add_child(b)
    var z := float(GameState.settings["zoom"])
    var l2 := Label.new()
    l2.text = "Câmera (zoom): %.1fx" % z
    c.add_child(l2)
    var r2 := HBoxContainer.new()
    c.add_child(r2)
    for opt in [["Longe", 1.3], ["Normal", 1.6], ["Perto", 2.0]]:
        var b2 := _btn("%s%s" % [opt[0], " (atual)" if is_equal_approx(z, float(opt[1])) else ""], _set_setting.bind("zoom", opt[1]))
        b2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        r2.add_child(b2)
    c.add_child(_btn("Voltar", show_main_menu))


func _set_setting(key: String, value) -> void:
    GameState.set_setting(key, value)
    show_settings()


# ---------------- Criação de personagem ----------------
func show_start() -> void:
    var c := _open("Reinos de Ferro", false)
    var name_edit := LineEdit.new()
    name_edit.text = "Viajante"
    name_edit.placeholder_text = "Nome do personagem"
    name_edit.custom_minimum_size = Vector2(0, 40)
    c.add_child(name_edit)
    var sel := {"origin": "camponês", "tunic": Color("6f8f4e")}
    var info := Label.new()
    info.text = ORIGIN_TEXT["camponês"]
    info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    var row := HBoxContainer.new()
    c.add_child(row)
    for o in ["camponês", "mercenário"]:
        var b := _btn(String(o).capitalize(), _set_origin.bind(sel, info, o))
        b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        row.add_child(b)
    c.add_child(info)
    var row2 := HBoxContainer.new()
    c.add_child(row2)
    var cols := {"Verde": Color("6f8f4e"), "Azul": Color("4a6fa5"), "Vermelho": Color("a5504a"), "Cinza": Color("8a8a8a")}
    for n in cols:
        var b2 := _btn("Roupa: " + n, _set_tunic.bind(sel, cols[n]))
        b2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        row2.add_child(b2)
    c.add_child(_btn("Novo jogo", _start_new.bind(name_edit, sel)))
    if GameState.has_save():
        c.add_child(_btn("Continuar jogo salvo", _start_continue))
    c.add_child(_btn("Voltar", show_main_menu))
    var help := Label.new()
    help.text = "Controles: joystick à esquerda; Atacar / Defesa / Esquiva / Ação (mercado) à direita. No computador: setas, Espaço, Shift, E, R."
    help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    c.add_child(help)


func _set_origin(sel: Dictionary, info: Label, o: String) -> void:
    sel["origin"] = o
    info.text = ORIGIN_TEXT[o]


func _set_tunic(sel: Dictionary, col: Color) -> void:
    sel["tunic"] = col


func _start_new(name_edit: LineEdit, sel: Dictionary) -> void:
    var n := name_edit.text
    close()
    new_game_requested.emit(n, sel["origin"], sel["tunic"])


func _start_continue() -> void:
    close()
    continue_requested.emit()


# ---------------- Mercado ----------------
func show_market(mid: String) -> void:
    market_id = mid
    market_rows.clear()
    var k := int(Kingdoms.settlement_owner[mid])
    var c := _open("Mercado de %s (%s)" % [Kingdoms.settlement_names[mid], Kingdoms.kingdom_name(k)])
    market_info = Label.new()
    c.add_child(market_info)
    var bounty := int(GameState.bounty.get(k, 0))
    if bounty > 0:
        c.add_child(_btn("Pagar multa de %d moedas" % bounty, _pay_fine.bind(k)))
    for g in Economy.GOODS:
        var row := HBoxContainer.new()
        c.add_child(row)
        var l := Label.new()
        l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        row.add_child(l)
        market_rows[g] = l
        row.add_child(_btn("Comprar 1", _trade.bind(g, 1, true)))
        row.add_child(_btn("Comprar 5", _trade.bind(g, 5, true)))
        row.add_child(_btn("Vender 1", _trade.bind(g, 1, false)))
        row.add_child(_btn("Vender 5", _trade.bind(g, 5, false)))
    _refresh_market()


func _refresh_market() -> void:
    market_info.text = "Ouro: %d   Carga: %.1f kg   (preços variam com estoque e eventos)" % [GameState.gold, GameState.weight()]
    for g in market_rows:
        market_rows[g].text = "%s | estoque %d | você tem %d | compra %d / venda %d" % [GameState.ITEMS[g]["name"], Economy.stock(market_id, g), GameState.count(g), Economy.buy_price(market_id, g), Economy.sell_price(market_id, g)]


func _trade(g: String, n: int, buying: bool) -> void:
    var ok := Economy.buy(market_id, g, n) if buying else Economy.sell(market_id, g, n)
    if not ok:
        GameState.say("Negócio não realizado (ouro, estoque ou itens insuficientes).")
    _refresh_market()


func _pay_fine(k: int) -> void:
    var b := int(GameState.bounty.get(k, 0))
    if GameState.gold >= b:
        GameState.gold -= b
        GameState.bounty[k] = 0
        GameState.say("Multa paga. Você não é mais procurado.")
        show_market(market_id)
    else:
        GameState.say("Ouro insuficiente para pagar a multa.")


# ---------------- Bolsa / personagem ----------------
func show_inventory() -> void:
    var c := _open("Bolsa e Personagem")
    var wname := "Punhos"
    if GameState.ITEMS.has(GameState.weapon):
        wname = GameState.ITEMS[GameState.weapon]["name"]
    var info := Label.new()
    info.text = "%s (%s) | Ouro %d | Vida %d | Fome %d | Carga %.1f kg | Arma: %s" % [GameState.player_name, GameState.origin, GameState.gold, int(GameState.hp), int(GameState.hunger), GameState.weight(), wname]
    info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    c.add_child(info)
    c.add_child(_btn("Desarmar (punhos)", _equip.bind("fists")))
    for id in GameState.inventory:
        var n: int = GameState.inventory[id]
        var it: Dictionary = GameState.ITEMS[id]
        var row := HBoxContainer.new()
        c.add_child(row)
        var l := Label.new()
        l.text = "%s x%d  [%s | %.1f kg | valor %d]" % [it["name"], n, it["cat"], it["weight"], it["value"]]
        l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        row.add_child(l)
        if it.has("food"):
            row.add_child(_btn("Comer", _eat.bind(id)))
        if it.has("dmg"):
            row.add_child(_btn("Equipada" if GameState.weapon == id else "Equipar", _equip.bind(id)))
    var sk := Label.new()
    sk.text = "Combate nv %d | Comércio nv %d (descontos em compras e vendas)" % [GameState.skill_level("combat"), GameState.skill_level("trade")]
    c.add_child(sk)
    for k in [0, 1]:
        var r := Label.new()
        r.text = "%s: reputação %d | procurado: %d | exército: %d" % [Kingdoms.kingdom_name(k), int(GameState.reputation.get(k, 0)), int(GameState.bounty.get(k, 0)), int(Kingdoms.kingdoms[k]["army"])]
        c.add_child(r)


func _eat(id: String) -> void:
    if GameState.remove_item(id, 1):
        GameState.hunger = minf(100.0, GameState.hunger + float(GameState.ITEMS[id]["food"]))
    show_inventory()


func _equip(id: String) -> void:
    GameState.weapon = id
    show_inventory()


# ---------------- Mapa ----------------
func show_map() -> void:
    var c := _open("Mapa do Reino")
    var mv := MapView.new()
    mv.world = world
    mv.custom_minimum_size = Vector2(640, 360)
    c.add_child(mv)
    var l := Label.new()
    l.text = "Azul = Aldória, Vermelho = Valdren. Amarelo = caravanas. Vermelho escuro = bandidos."
    c.add_child(l)


class MapView extends Control:
    var world: Node
    const SC := 0.2

    func _process(_d: float) -> void:
        queue_redraw()

    func _draw() -> void:
        var f := ThemeDB.fallback_font
        draw_rect(Rect2(Vector2.ZERO, Vector2(3200, 1800) * SC), Color("4f7a3c"))
        draw_rect(Rect2(world.forest_rect.position * SC, world.forest_rect.size * SC), Color("2f5a2c"))
        draw_circle(world.lake_center * SC, world.lake_radius * SC, Color("3b6ea5"))
        var pts := PackedVector2Array()
        for p in world.road:
            pts.append(p * SC)
        draw_polyline(pts, Color("c9a86a"), 3.0)
        for mid in world.settlements:
            var pos: Vector2 = world.settlements[mid]["pos"] * SC
            draw_circle(pos, 8, Kingdoms.kingdom_color(int(Kingdoms.settlement_owner[mid])))
            draw_string(f, pos + Vector2(-20, -12), Kingdoms.settlement_names[mid], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
        var cp: Vector2 = world.castle_pos * SC
        draw_circle(cp, 8, Kingdoms.kingdom_color(1))
        draw_string(f, cp + Vector2(-30, -12), Kingdoms.settlement_names["castle"], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
        draw_circle(world.camp_pos * SC, 6, Color("7a1a1a"))
        for c in world.sim.caravans:
            draw_circle(c.position * SC, 4, Color("ffd54f"))
        draw_circle(world.player.position * SC, 4, Color.WHITE)
