package invaders

Particle_Emitter :: struct {
    position: Vector2,
    velocity: Vector2,

    particles: [dynamic]Particle,
    fadeout_period: float,
    particles_per_second: float,

    speed0: float,
    speed1: float,

    size0: float,
    size1: float,

    drag0: float,
    drag1: float,

    lifetime0: float,
    lifetime1: float,

    emitter_lifetime: float,

    theta0: float,
    theta1: float,

    color0: Vector4,
    color1: Vector4,

    elapsed: float,
    remainder: float,

    producing: bool,
}

default_particle_emitter :: Particle_Emitter {
    fadeout_period = 0.1,
    particles_per_second = 150,
    speed1 = 0.1,
    size0 = 0.001,
    size1 = 0.005,
    drag0 = 0.9999,
    drag1 = 0.9,
    lifetime0 = 0.4,
    lifetime1 = 1.0,
    emitter_lifetime = -1.0,
    theta1 = TAU,
    producing = true,
}

Particle :: struct {
    position: Vector2,
    velocity: Vector2,

    size: float,
    lifetime: float,
    drag: float,

    elapsed: float,

    color: Vector4,
}

default_particle :: Particle {
    lifetime = 2.0,
    drag = 1.0,
}

deinit :: proc(emitter: ^Particle_Emitter) {
    array_free(emitter.particles);
}

update_emitter :: proc(emitter: ^Particle_Emitter, dt: float) {
    for i := 0; i < len(emitter.particles); i += 1 {
        p := emitter.particles[i]
        sim_particle(p, dt);

        if p.elapsed > p.lifetime {
            unordered_remove(&emitter.particles, i);
            i -= 1
        }
    }

    dt_per_particle := 1.0 / emitter.particles_per_second;

    emitter.elapsed += dt;
    emitter.remainder += dt;

    if emitter.emitter_lifetime >= 0 {
        emitter.emitter_lifetime -= dt;
        if emitter.emitter_lifetime < 0 { emitter.producing = false }
    }

    if emitter.producing {
        for emitter.remainder > dt_per_particle {
            emitter.remainder -= dt_per_particle;
            p := spawn_particle(emitter);
            sim_particle(p, emitter.remainder);
        }
    } else {
        if emitter.particles.count == 0 {
            array_ordered_remove_by_value(&live_emitters, emitter);  // Ordered remove, because we spawn some emitters in specific orders.
            deinit(emitter);
            free(emitter);
        }
    }
  
    //
    // Helper functions:
    //
    spawn_particle :: proc(emitter: ^Particle_Emitter) -> ^Particle {
        p := array_add(&emitter.particles);
        
        p.position = emitter.position;
        p.velocity = emitter.velocity;

        p.size = random_get_within_range(emitter.size0, emitter.size1);
        p.drag = random_get_within_range(emitter.drag0, emitter.drag1);
        p.lifetime = random_get_within_range(emitter.lifetime0, emitter.lifetime1);

        color_t := random_get_within_range(0, 1);
        p.color = lerp(emitter.color0, emitter.color1, color_t);

        speed := random_get_within_range(emitter.speed0, emitter.speed1);
        theta := random_get_within_range(emitter.theta0, emitter.theta1);

        ct := cos(theta);
        st := sin(theta);
        
        v_rel: Vector2 = ---;
        v_rel.x = speed * ct;
        v_rel.y = speed * st;

        p.velocity += v_rel;

        return p;
    }

    sim_particle :: proc(p: ^Particle, dt: float) {
        linear_move(&p.position, &p.velocity, dt);

        // @Incomplete: Apply correct drag over time.
        p.velocity *= p.drag;
        p.elapsed  += dt;
    }
}


draw_emitter :: proc(emitter: ^Particle_Emitter) {
    Simp.set_shader_for_images(&contrail_map);
    
    for it in emitter.particles {            
        alpha := 1.0;

        // Fade particle if it's time to do so.
        tail_time := it.lifetime - it.elapsed;
        if tail_time < emitter.fadeout_period {
            t := tail_time / emitter.fadeout_period;
            if t < 0 { t = 0 }
            if t > 1 { t = 1 }
            
            alpha = t;
        }

        c := it.color;
        c.w *= alpha;

        pos := it.position * cast(float) window_width;
        s := it.size * window_width * .5;
        Simp.immediate_quad(pos.x-s, pos.y-s, pos.x+s, pos.y+s, c);
    }
}
