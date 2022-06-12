Entity_Manager :: struct {
    entities_to_clean_up: [..] *Entity;
}

Entity :: struct {
    using position : Vector2;
    velocity : Vector2;

    map: *Texture;
    entity_manager: *Entity_Manager;
    entity_flags: u32;
}

Pickup_Type :: enum u32 {
    UNINITIALIZED;
    EXTRA_BULLET;
    SHIELD;
    V_SHOT;
}

Pickup :: struct {
    using entity: Entity;
    type := Pickup_Type.UNINITIALIZED;
}

Invader :: struct {
    using entity: Entity;

    target_position : Vector2;
    sleep_countdown := -1.0;

    update_proc : (self : *Invader);
}

Bullet :: struct {
    using entity: Entity;

    color: Vector4;
    emitter: *Particle_Emitter;
    player_friendly := true;
}
