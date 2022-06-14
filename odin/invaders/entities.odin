package invaders

Entity_Manager :: struct {
    entities_to_clean_up: [dynamic]^Entity,
}

Entity :: struct {
    using position: Vector2,
    velocity: Vector2,

    texture: ^Texture,
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

    target_position: Vector2,
    sleep_countdown: float,

    update_proc: proc(self: ^Invader),
}

default_invader :: Invader {
    sleep_countdown = -1.0,
}

Bullet :: struct {
    using entity: Entity,

    color: Vector4,
    emitter: ^Particle_Emitter,
    player_friendly: bool,
}

default_bullet :: Invader {
    player_friendly = true,
}
