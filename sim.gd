extends Node
class_name Sim
## Gerenciador de simulação com 3 níveis (LOD):
##  0 = perto do jogador: IA completa a cada quadro, desenhado
##  1 = região: IA a cada ~0,4 s, desenhado
##  2 = distante: IA a cada ~2 s (passos grandes, sem desenhar)

const LOD0 := 450.0
const LOD1 := 1100.0

var npcs: Array = []
var caravans: Array = []
var player: Node2D


func _process(delta: float) -> void:
    if GameState.ui_open or player == null:
        return
    var p := player.position
    for n in npcs:
        var d: float = p.distance_to(n.position)
        n.lod = 0 if d < LOD0 else (1 if d < LOD1 else 2)
        n.visible = n.lod < 2
        n.acc += delta
        var iv := 0.0 if n.lod == 0 else (0.4 if n.lod == 1 else 2.0)
        if n.acc >= iv:
            n.tick(n.acc)
            n.acc = 0.0
    for c in caravans:
        var d: float = p.distance_to(c.position)
        c.lod = 0 if d < LOD0 else (1 if d < LOD1 else 2)
        c.visible = c.lod < 2
        c.acc += delta
        var iv := 0.0 if c.lod == 0 else (0.4 if c.lod == 1 else 2.0)
        if c.acc >= iv:
            c.tick(c.acc)
            c.acc = 0.0
