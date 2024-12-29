package frogBuster

import rl "vendor:raylib"
import "core:math/rand"
import "core:fmt"
import "core:strings"

SCREENWIDTH :: 320
SCREENHEIGHT :: 180
PLAYERSIZE :: 16
BULLETSIZE :: 8
BULLETSPEED :: 128
BULLETRETURNSPEED :: 256
PLAYERYPOS :: 32
PLAYERANIMSPEED :: 64
PLAYERANIMCAP :: 16
ENEMYSIZE :: 16
ENEMYSPEED :: 32
ENEMYRETURNSPEED :: 256
ENEMYTIMESPEED :: 64
ENEMYTIMECAP :: 64
STUNSPEED :: 16
ENEMYSCALESPEED :: 0.8
ENEMYSCALECAP :: 1.2
BULLETROTATESPEED :: 512
STUNTIMERSPEED :: 64
STUNTIMERCAP :: 16
ENEMYSHADOWSIZE :: 10
PLAYERSTARTLANE :: Lanes.THREE
LANESCAP :: 5

Game :: struct {
    start: bool,
    screenwidth: i32,
    screenheight: i32,
    score: int,
    health: int,
    dt: f32,
    enemy_timer: f32,
    scene: Scenes,
    player: Player,
    textures: Textures,
    bullets: [5][dynamic]Entity,
    enemies: [5][dynamic]Entity
}

Textures :: struct {
    sky, grass, grass2, dirt, player_n, player_t, player_g, player_h, enemy, bullet, heart, main, over : rl.Texture2D
}

Player :: struct {
    ammo: i32,
    timer: f32,
    lane: Lanes,
    entity_flag: EntityFlag,
    using rect: rl.Rectangle
}

Entity :: struct {
    timer: f32,
    scag: f32, // scale and angle, scale for enemy, angle for bullet
    dir: Dir,
    entity_flag: EntityFlag,
    using rect: rl.Rectangle
}

EntityFlag :: enum {
    NEUTRAL,
    REMOVAL,
    RETURNAL,
    STUN
}

Lanes :: enum {
    ONE,
    TWO,
    THREE,
    FOUR,
    FIVE
}

Dir :: enum {
    LEFT,
    RIGHT
}

Scenes :: enum {
    MAIN,
    GAME,
    OVER
}

make_textures :: proc() -> Textures {
    return Textures {
	sky = rl.LoadTexture("./sprites/sky.png"),
	grass = rl.LoadTexture("./sprites/grass-1.png"),
	grass2 = rl.LoadTexture("./sprites/grass-2.png"),
	player_g = rl.LoadTexture("./sprites/player-grab.png"),
	player_n = rl.LoadTexture("./sprites/player-neutral.png"),
	player_t = rl.LoadTexture("./sprites/player-throw.png"),
	player_h = rl.LoadTexture("./sprites/player-hurt.png"),
	enemy = rl.LoadTexture("./sprites/enemy.png"),
	bullet = rl.LoadTexture("./sprites/bullet.png"),
	dirt = rl.LoadTexture("./sprites/dirt.png"),
	heart = rl.LoadTexture("./sprites/heart.png"),
	main = rl.LoadTexture("./sprites/main.png"),
	over = rl.LoadTexture("./sprites/over.png")
    }
}

make_game :: proc() -> Game {
    return Game {
	dt = 0,
	screenwidth = SCREENWIDTH,
	screenheight = SCREENHEIGHT,
	enemy_timer = 0,
	textures = make_textures(),
	player = {
	    ammo = 1,
	    timer = 0,
	    lane = PLAYERSTARTLANE,
	    entity_flag = .NEUTRAL,
	    x = get_lane_x(PLAYERSTARTLANE),
	    y = PLAYERYPOS,
	    width = PLAYERSIZE,
	    height = PLAYERSIZE	
	},
	bullets = {{}, {}, {}, {}, {}},
	enemies = {{}, {}, {}, {}, {}},
	health = 3,
	score = 0,
	scene = .MAIN,
	start = false
    }
}

reset_game :: proc(game: ^Game) {
    game.player.x = get_lane_x(PLAYERSTARTLANE)
    game.health = 3
    game.scene = .MAIN
    game.score = 0
    game.player.timer = 0
    game.enemy_timer = 0
    game.player.entity_flag = .NEUTRAL
    for i in 0..<len(game.bullets) {
	game.bullets[i] = {}
    }
    for i in 0..<len(game.enemies) {
	game.enemies[i] = {}
    }
}

game_tick :: proc(game: ^Game) {
    game.dt = rl.GetFrameTime()
    game.screenwidth = rl.GetScreenWidth()
    game.screenheight = rl.GetScreenHeight()
}

get_lane_x :: proc(lane: Lanes) -> f32{
    switch lane {
    case .ONE:
	return 1 * 64 - 32
    case .TWO:
	return 2 * 64 - 32
    case .THREE:
	return 3 * 64 - 32
    case .FOUR:
	return 4 * 64 - 32
    case .FIVE:
	return 5 * 64 - 32
    }
    return 3 * 64 - 32
}

change_lane :: proc(lane: Lanes, dir: Dir) -> Lanes {
    switch lane {
    case .ONE:
	switch dir {
	case .RIGHT:
	    return .TWO
	case .LEFT:
	    return .ONE
	}
    case .TWO:
	switch dir {
	case .RIGHT:
	    return .THREE
	case .LEFT:
	    return .ONE
	}
    case .THREE:
	switch dir {
	case .RIGHT:
	    return .FOUR
	case .LEFT:
	    return .TWO
	}
    case .FOUR:
	switch dir {
	case .RIGHT:
	    return .FIVE
	case .LEFT:
	    return .THREE
	}
    case .FIVE:
	switch dir {
	case .RIGHT:
	    return .FIVE
	case .LEFT:
	    return .FOUR
	}
    }
    return lane    
}

lanes_to_int :: proc(lane: Lanes) -> int {
    switch lane {
    case .ONE:
	return 1
    case .TWO:
	return 2
    case .THREE:
	return 3
    case .FOUR:
	return 4
    case .FIVE:
	return 5
    }
    return 0
}

int_to_lanes :: proc(num: int) -> Lanes {    
    switch num {
    case 1:
	return .ONE
    case 2:
	return .TWO
    case 3:
	return .THREE
    case 4:
	return .FOUR
    case 5:
	return .FIVE		
    }
    return .THREE
}

player_lane_change :: proc(game: ^Game) {
    lane := game.player.lane
    if rl.IsKeyPressed(.A) || rl.IsKeyPressed(.LEFT) {
	if lane == .ONE { return }	
	lane = change_lane(lane, .LEFT)
	game.player.lane = lane
    } else if rl.IsKeyPressed(.D) || rl.IsKeyPressed(.RIGHT) {
	if lane == .FIVE { return }
	lane = change_lane(lane, .RIGHT)
	game.player.lane = lane
    } else {
	return
    }
}

make_bullet_on_lane :: proc(game: ^Game, lane: Lanes) {
    append(&game.bullets[lanes_to_int(lane) - 1], Entity {
	timer = 0,
	dir = .LEFT,
	entity_flag = .NEUTRAL,
	scag = 0,
	x = get_lane_x(lane) + PLAYERSIZE / 2,
	y = PLAYERYPOS + PLAYERSIZE,
	width = BULLETSIZE,
	height = BULLETSIZE,
    })
}

move_bullets_on_lane :: proc(game: ^Game, lane: Lanes) {
    if len(game.bullets[lanes_to_int(lane) - 1]) == 0 {
	return
    }
    for i in 0..<len(game.bullets[lanes_to_int(lane) - 1]) {
	game.bullets[lanes_to_int(lane) - 1][i].scag += BULLETROTATESPEED * game.dt
	#partial switch game.bullets[lanes_to_int(lane) - 1][i].entity_flag {
	    case .NEUTRAL:
	    game.bullets[lanes_to_int(lane) - 1][i].y += BULLETSPEED * game.dt
	    case .RETURNAL:
	    game.bullets[lanes_to_int(lane) - 1][i].y -= BULLETRETURNSPEED * game.dt
	}

    }
}

draw_bullets_on_lane :: proc(game: ^Game, lane: Lanes) {
    if len(game.bullets[lanes_to_int(lane) - 1]) == 0 {
	return
    }
    for i in 0..<len(game.bullets[lanes_to_int(lane) - 1]) {
	// rl.DrawRectangleRec(game.bullets[lanes_to_int(lane) - 1][i], rl.BLACK)
	bullet := game.bullets[lanes_to_int(lane) - 1][i]
	rl.DrawTexturePro(game.textures.bullet, {0, 0, BULLETSIZE, BULLETSIZE}, bullet, {bullet.width / 2, bullet.height / 2}, bullet.scag, rl.WHITE)
    }    
}

delete_entity_on_index :: proc(entity: ^[dynamic]Entity, index: int) {
    temp := entity[index]
    entity[index] = entity[len(entity) - 1]
    entity[len(entity) - 1] = temp
    pop(entity)  
}

delete_bullets_on_lane :: proc(game: ^Game, ground: rl.Rectangle, lane: Lanes) {
    for i in 0..<len(game.bullets[lanes_to_int(lane) - 1]) {
	if rl.CheckCollisionRecs(game.bullets[lanes_to_int(lane) - 1][i], ground) {
	    game.player.ammo += 1
	    delete_entity_on_index(&game.bullets[lanes_to_int(lane) - 1], i)
	}
    }
}

delete_bullets_on_returnal_lane :: proc(game: ^Game, ground: rl.Rectangle, lane: Lanes) {
    for i in 0..<len(game.bullets[lanes_to_int(lane) - 1]) {
	if rl.CheckCollisionRecs(game.bullets[lanes_to_int(lane) - 1][i], ground) {
	    game.player.timer = 0
	    game.player.entity_flag = .RETURNAL
	    game.player.ammo += 1
	    delete_entity_on_index(&game.bullets[lanes_to_int(lane) - 1], i)
	}
    }
}

delete_enemies_on_lane :: proc(game: ^Game, ground: rl.Rectangle, lane: Lanes) {
    for i in 0..<len(game.enemies[lanes_to_int(lane) - 1]) {
	if rl.CheckCollisionRecs(game.enemies[lanes_to_int(lane) - 1][i], ground) {
	    game.player.entity_flag = .STUN
	    game.health -= 1
	    delete_entity_on_index(&game.enemies[lanes_to_int(lane) - 1], i)
	}
    }
}

delete_enemies_returnal_on_lane :: proc(game: ^Game, ground: rl.Rectangle, lane: Lanes) {
    for i in 0..<len(game.enemies[lanes_to_int(lane) - 1]) {
	if game.enemies[lanes_to_int(lane) - 1][i].entity_flag != .RETURNAL {
	    continue
	}
	if rl.CheckCollisionRecs(game.enemies[lanes_to_int(lane) - 1][i], ground) {
	    delete_entity_on_index(&game.enemies[lanes_to_int(lane) - 1], i)
	}
    }
}


gen_random_lane :: proc() -> Lanes {
    num := rand.int_max(5)
    for num == 0 {
	num = rand.int_max(5)
    }
    return int_to_lanes(num)
}

get_random_dir :: proc() -> Dir {
    num := rand.int_max(3)
    for num == 0 {
	num = rand.int_max(2)
    }
    switch num {
    case 1:
	return .RIGHT
    case 2:
	return .LEFT
    }
    return .LEFT
}

make_enemy_on_lane :: proc(game: ^Game, lane: Lanes) { 
    append(&game.enemies[lanes_to_int(lane) - 1], Entity{
	timer = 0,
	dir = .RIGHT,
	x = get_lane_x(lane),
	scag = 1,
	y = SCREENHEIGHT - ENEMYSIZE,
	width = ENEMYSIZE,
	height = ENEMYSIZE,
	entity_flag = .NEUTRAL
    })
}

move_enemy_on_lane :: proc(game: ^Game, lane: Lanes) {
    if len(game.enemies[lanes_to_int(lane) - 1]) == 0 {
	return
    }
    for i in 0..<len(game.enemies[lanes_to_int(lane) - 1]) {
	#partial switch game.enemies[lanes_to_int(lane) - 1][i].entity_flag {
	    case .NEUTRAL:
	    game.enemies[lanes_to_int(lane) - 1][i].y -= ENEMYSPEED * game.dt
	    game.enemies[lanes_to_int(lane) - 1][i].scag += ENEMYSCALESPEED * game.dt
	    if game.enemies[lanes_to_int(lane) - 1][i].scag >= ENEMYSCALECAP {
		game.enemies[lanes_to_int(lane) - 1][i].scag = 1
	    }
	    case .RETURNAL:
	    switch game.enemies[lanes_to_int(lane) - 1][i].dir {
	    case .LEFT:
		game.enemies[lanes_to_int(lane) - 1][i].x -= ENEMYRETURNSPEED / 2 * game.dt
	    case .RIGHT:
		game.enemies[lanes_to_int(lane) - 1][i].x += ENEMYRETURNSPEED / 2 * game.dt
	    }
	    game.enemies[lanes_to_int(lane) - 1][i].y += ENEMYRETURNSPEED * game.dt
	    case .STUN:
	    switch game.enemies[lanes_to_int(lane) - 1][i].dir {
	    case .LEFT:
		game.enemies[lanes_to_int(lane) - 1][i].x -= STUNSPEED * game.dt
	    case .RIGHT:
		game.enemies[lanes_to_int(lane) - 1][i].x += STUNSPEED * game.dt
	    }
	    game.enemies[lanes_to_int(lane) - 1][i].scag += ENEMYSCALESPEED * game.dt
	    game.enemies[lanes_to_int(lane) - 1][i].y -= STUNSPEED * game.dt
	}
    }    
}

draw_enemies_on_lane :: proc(game: ^Game, lane: Lanes) {
    if len(game.enemies[lanes_to_int(lane) - 1]) == 0 {
	return
    }
    for i in 0..<len(game.enemies[lanes_to_int(lane) - 1]) {
	enemy := game.enemies[lanes_to_int(lane) - 1][i]
	// rl.DrawRectangleRec({enemy.x - 1, enemy.y - 1, enemy.width + 2, enemy.height + 2}, {0x18, 0x10, 0x10, 0xff})
	rl.DrawCircleV({enemy.x + enemy.width / 2, enemy.y + enemy.height / 2}, ENEMYSHADOWSIZE,  {0x18, 0x10, 0x10, 0xff})
	rl.DrawTextureEx(game.textures.enemy, {enemy.x, enemy.y}, 0, enemy.scag, rl.WHITE)
    }    
}

entity_mark_when_collide_on_lane :: proc(game: ^Game, lane: Lanes) {
    if len(game.bullets[lanes_to_int(lane) - 1]) == 0 { return }
    if len(game.enemies[lanes_to_int(lane) - 1]) == 0 { return }
    
    for i in 0..<len(game.bullets[lanes_to_int(lane) - 1]) {
	for j in 0..<len(game.enemies[lanes_to_int(lane) - 1]) {
	    if game.enemies[lanes_to_int(lane) - 1][j].entity_flag == .NEUTRAL {
		if rl.CheckCollisionRecs(game.bullets[lanes_to_int(lane) - 1][i], game.enemies[lanes_to_int(lane) - 1][j]) {
		    game.score += 1
		    game.bullets[lanes_to_int(lane) - 1][i].entity_flag = .RETURNAL
		    game.enemies[lanes_to_int(lane) - 1][j].dir = get_random_dir()
		    game.enemies[lanes_to_int(lane) - 1][j].entity_flag = .STUN
		}
	    }
	}
    }
}

entity_remove_marked_on_lane :: proc(game: ^Game, lane: Lanes) {
    if len(game.bullets[lanes_to_int(lane) - 1]) == 0 { return }
    if len(game.enemies[lanes_to_int(lane) - 1]) == 0 { return }

    for i in 0..<len(game.bullets[lanes_to_int(lane) - 1]) {
	if game.bullets[lanes_to_int(lane) - 1][i].entity_flag == .REMOVAL { delete_entity_on_index(&game.bullets[lanes_to_int(lane) - 1], i) }
    }
    for i in 0..<len(game.enemies[lanes_to_int(lane) - 1]) {
	if game.enemies[lanes_to_int(lane) - 1][i].entity_flag == .REMOVAL { delete_entity_on_index(&game.enemies[lanes_to_int(lane) - 1], i) }	
    }
}

enemy_timer_run :: proc(game: ^Game) {
    game.enemy_timer += f32(ENEMYTIMESPEED) * game.dt
}

player_state_changer :: proc(game: ^Game, lane: Lanes) {
    #partial switch game.player.entity_flag {
	
    }

}

enemies_state_changer :: proc(game: ^Game, lane: Lanes) {
    if len(game.enemies[lanes_to_int(lane) - 1]) == 0 { return }

    for i in 0..<len(game.enemies[lanes_to_int(lane) - 1]) {
	#partial switch game.enemies[lanes_to_int(lane) - 1][i].entity_flag {
	    case .STUN:
	    game.enemies[lanes_to_int(lane) - 1][i].timer += STUNTIMERSPEED * game.dt
	    if game.enemies[lanes_to_int(lane) - 1][i].timer >= STUNTIMERCAP {
		game.enemies[lanes_to_int(lane) - 1][i].entity_flag = .RETURNAL
	    }
	}
    }
}

lane_tick :: proc(game: ^Game, lane: Lanes) {
    enemies_state_changer(game, lane)
    delete_bullets_on_lane(game, bullet_limit, lane)
    delete_enemies_on_lane(game, enemy_limit, lane)
    delete_bullets_on_lane(game, sky_limit, lane)
    delete_enemies_returnal_on_lane(game, bullet_limit, lane)
    
    entity_mark_when_collide_on_lane(game, lane)
    entity_remove_marked_on_lane(game, lane)

    if game.enemy_timer >= ENEMYTIMECAP {
	game.enemy_timer = 0
	make_enemy_on_lane(game, gen_random_lane())
    }

    move_enemy_on_lane(game, lane)
    move_bullets_on_lane(game, lane)
}

lanes_tick :: proc(game: ^Game) {
    for i in 0..<LANESCAP {
	lane_tick(game, int_to_lanes(i + 1))
    }
}

draw_entities_on_lane :: proc(game: ^Game, lane: Lanes) {
    draw_bullets_on_lane(game, lane)
    draw_enemies_on_lane(game, lane)
}

draw_entities :: proc(game: ^Game) {
    for i in 0..<LANESCAP {
	draw_entities_on_lane(game, int_to_lanes(i + 1))
    }
}

player_texture_get :: proc(game: ^Game) -> rl.Texture2D {
    switch game.player.entity_flag {
    case .NEUTRAL:
	return game.textures.player_n
    case .REMOVAL:
	return game.textures.player_t
    case .RETURNAL:
	return game.textures.player_g
    case .STUN:
	return game.textures.player_h
    }
    return game.textures.player_n
}

change_player_state :: proc(game: ^Game) {
    #partial switch game.player.entity_flag {
	case .REMOVAL:
	game.player.timer += PLAYERANIMSPEED * game.dt
	if game.player.timer >= PLAYERANIMCAP {
	    game.player.timer = 0
	    game.player.entity_flag = .NEUTRAL
	}
	case .RETURNAL:
	game.player.timer += PLAYERANIMSPEED * game.dt
	if game.player.timer >= PLAYERANIMCAP {
	    game.player.timer = 0
	    game.player.entity_flag = .NEUTRAL
	}
	case .STUN:
	game.player.timer += PLAYERANIMSPEED * game.dt
	if game.player.timer >= PLAYERANIMCAP {
	    game.player.timer = 0
	    game.player.entity_flag = .NEUTRAL
	}
    }
}

background := rl.Rectangle {
    x = 0,
    y = 0,
    width = SCREENWIDTH,
    height = SCREENHEIGHT
}

sky_limit := rl.Rectangle {
    x = 0,
    y = 0,
    width = SCREENWIDTH,
    height = 2
}

sky := rl.Rectangle {
    x = 0,
    y = 0,
    width = SCREENWIDTH,
    height = 45
}

grass := rl.Rectangle {
    x = 0,
    y = 45,
    width = SCREENWIDTH,
    height = 3
}

dirt := rl.Rectangle {
    x = 0,
    y = 48,
    width = SCREENWIDTH,
    height = SCREENHEIGHT - 48
}

bullet_limit := rl.Rectangle {
    x = 0,
    y = SCREENHEIGHT - 2,
    width = SCREENWIDTH,
    height = 2
}

enemy_limit := rl.Rectangle {
    x = 0,
    y = 42,
    width = SCREENWIDTH,
    height = 2
}

main :: proc() {
    rl.SetConfigFlags({.WINDOW_RESIZABLE}) 
    rl.InitWindow(SCREENWIDTH, SCREENHEIGHT, "As aboveground so underground")
    defer rl.CloseWindow()
    game := make_game()
    camera := rl.Camera2D {
	offset = {0, 0},
	target = {0, 0},
	rotation = 0,
	zoom = 1
    }
    score_sb := strings.builder_make()
    health_sb := strings.builder_make()
    
    for !rl.WindowShouldClose() {
	game_tick(&game)
	camera.zoom = f32(f32(game.screenheight) / f32(SCREENHEIGHT))
	camera.offset.x = (f32(game.screenwidth) - (f32(SCREENWIDTH) * f32(camera.zoom))) / 2

	switch game.scene {
	case .MAIN:
	    if rl.IsKeyPressed(.SPACE) {
		game.scene = .GAME
	    }
	    strings.builder_destroy(&score_sb)
	    strings.builder_destroy(&health_sb)
	case .GAME:
	    if game.start == true {
		strings.builder_destroy(&score_sb)
		strings.builder_destroy(&health_sb)
		player_lane_change(&game)
		game.player.x = get_lane_x(game.player.lane)

		enemy_timer_run(&game)

		if rl.IsKeyPressed(.SPACE) && game.player.ammo > 0{
		    game.player.timer = 0
		    game.player.entity_flag = .REMOVAL
		    game.player.ammo -= 1
		    make_bullet_on_lane(&game, game.player.lane)
		}

		if len(game.bullets[lanes_to_int(game.player.lane) - 1]) > 0 {
		    delete_bullets_on_returnal_lane(&game, grass, game.player.lane)		    	   
		}


		lanes_tick(&game)
		change_player_state(&game)
		if game.health <= 0 {
		    game.scene = .OVER
		}
	    } else if game.start == false{
		strings.builder_destroy(&score_sb)
		strings.builder_destroy(&health_sb)
		if rl.IsKeyPressed(.SPACE) {
		    game.start = true
		}
		player_lane_change(&game)
		game.player.x = get_lane_x(game.player.lane)

		if rl.IsKeyPressed(.SPACE) && game.player.ammo > 0{
		    game.player.timer = 0
		    game.player.entity_flag = .REMOVAL
		    game.player.ammo -= 1
		    make_bullet_on_lane(&game, game.player.lane)
		}

		if len(game.bullets[lanes_to_int(game.player.lane) - 1]) > 0 {
		    delete_bullets_on_returnal_lane(&game, grass, game.player.lane)		    	   
		}

		lanes_tick(&game)
		change_player_state(&game)
	    }
	    strings.write_int(&score_sb, game.score)
	    strings.write_int(&health_sb, game.health)
	case .OVER:
	    if rl.IsKeyPressed(.SPACE) {
		game.scene = .MAIN
		reset_game(&game)
	    }
	}

	rl.BeginDrawing()
	{
	    rl.BeginMode2D(camera)
	    {
		switch game.scene {
		case .MAIN:
		    rl.ClearBackground(rl.BLACK)
		    rl.DrawTextureV(game.textures.main, {0, 0}, rl.WHITE)
		    rl.DrawText("Press SPACE to START", i32(get_lane_x(.ONE)) + 32, SCREENHEIGHT - SCREENHEIGHT / 4 + 16, 16,rl.BLACK)
		    rl.DrawText("By Ivulai", 2, SCREENHEIGHT - 12, 12, rl.PINK)
		case .GAME:
		    rl.ClearBackground(rl.BLACK)
		    rl.DrawRectangleRec(background, rl.RAYWHITE)
		    rl.DrawTextureV(game.textures.sky, {sky.x, sky.y}, rl.WHITE)
		    // rl.DrawRectangleRec(grass, rl.GREEN)
		    rl.DrawTextureV(game.textures.grass, {grass.x, grass.y}, rl.WHITE)
		    rl.DrawTextureV(game.textures.dirt, {dirt.x, dirt.y}, rl.WHITE)
		    // rl.DrawRectangleRec(game.player, rl.RED)
		    rl.DrawTextureV(player_texture_get(&game), {game.player.x, game.player.y}, rl.WHITE)
		    rl.DrawTextureV(game.textures.grass2, {grass.x, grass.y}, rl.WHITE)
		    // rl.DrawRectangleRec(bullet_limit, rl.PURPLE)
		    draw_entities(&game)
		    rl.DrawTextureV(game.textures.heart, {2, 2}, rl.WHITE)
		    rl.DrawText(strings.to_cstring(&score_sb), SCREENWIDTH / 2, 0, 16, rl.BLACK)
		    rl.DrawText(strings.to_cstring(&health_sb), 20, 4, 16, rl.BLACK)
		    if !game.start {
			rl.DrawText("ARROW KEYS to move", i32(get_lane_x(.ONE)) + 48, SCREENHEIGHT / 2 + 16, 16,rl.WHITE)
			rl.DrawText("SPACE to shoot", i32(get_lane_x(.ONE)) + 64, SCREENHEIGHT / 4 + 16, 16,rl.WHITE)
			rl.DrawText("Press SPACE to START", i32(get_lane_x(.ONE)) + 32, SCREENHEIGHT - SCREENHEIGHT / 4 + 16, 16,rl.WHITE)	
		    }
		case .OVER:
		    rl.ClearBackground(rl.BLACK)
		    rl.DrawTextureV(game.textures.over, {0, 0}, rl.WHITE)
		    rl.DrawText("SCORE", i32(get_lane_x(.THREE)) - 32, SCREENHEIGHT / 4 - 16, 16, rl.WHITE)
		    rl.DrawText(strings.to_cstring(&score_sb), i32(get_lane_x(.THREE)) - 24, SCREENHEIGHT / 4, 64, rl.WHITE)
		    rl.DrawText("YOU FAILED", i32(get_lane_x(.ONE)) + 72, SCREENHEIGHT - SCREENHEIGHT / 4 - 8, 16, rl.RED)
		    rl.DrawText("Press SPACE to RETRY", i32(get_lane_x(.ONE)) + 32, SCREENHEIGHT - SCREENHEIGHT / 4 + 16, 16, rl.BLACK)
		}
	    }
	    rl.EndMode2D()
	}
	rl.EndDrawing()
    }
}
