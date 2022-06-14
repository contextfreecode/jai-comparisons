package invaders

import "core:math/linalg"
import SDL "vendor:sdl2"

Entity_Manager :: struct {
    entities_to_clean_up: [dynamic]^Entity,
}

Entity :: struct {
    using position: linalg.Vector2f32,
    velocity: linalg.Vector2f32,

    texture: ^SDL.Texture, // TODO Test mistype on both!!
    entity_manager: ^Entity_Manager,
    entity_flags: u32,
}

Pickup_Type :: enum u32 {
    UNINITIALIZED,
    EXTRA_BULLET,
    SHIELD,
    V_SHOT,
}

Pickup :: struct {
    using entity: Entity,
    type: Pickup_Type,
}

Invader :: struct {
    using entity: Entity,

    target_position: linalg.Vector2f32,
    sleep_countdown: f32,

    update_proc: proc(self: ^Invader),
}

default_invader :: Invader {
    sleep_countdown = -1.0,
}

Bullet :: struct {
    using entity: Entity,

    color: linalg.Vector4f32,
    emitter: ^Particle_Emitter,
    player_friendly: bool,
}

default_bullet :: Bullet {
    player_friendly = true,
}
