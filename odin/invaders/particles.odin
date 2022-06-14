package invaders

import "core:math"
import "core:math/linalg"

Particle_Emitter :: struct {
    position: linalg.Vector2f32,
    velocity: linalg.Vector2f32,

    particles: [dynamic]Particle,
    fadeout_period: f32,
    particles_per_second: f32,

    speed0: f32,
    speed1: f32,

    size0: f32,
    size1: f32,

    drag0: f32,
    drag1: f32,

    lifetime0: f32,
    lifetime1: f32,

    emitter_lifetime: f32,

    theta0: f32,
    theta1: f32,

    color0: linalg.Vector4f32,
    color1: linalg.Vector4f32,

    elapsed: f32,
    remainder: f32,

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
    theta1 = math.τ, // or math.TAU,
    producing = true,
}

Particle :: struct {
    position: linalg.Vector2f32,
    velocity: linalg.Vector2f32,

    size: f32,
    lifetime: f32,
    drag: f32,

    elapsed: f32,

    color: linalg.Vector4f32,
}

default_particle :: Particle {
    lifetime = 2.0,
    drag = 1.0,
}

deinit :: proc(emitter: ^Particle_Emitter) {
    array_free(emitter.particles);
}

update_emitter :: proc(emitter: ^Particle_Emitter, dt: f32) {
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
        
        v_rel: linalg.Vector2f32 = ---;
        v_rel.x = speed * ct;
        v_rel.y = speed * st;

        p.velocity += v_rel;

        return p;
    }

    sim_particle :: proc(p: ^Particle, dt: f32) {
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

        pos := it.position * cast(f32) window_width;
        s := it.size * window_width * .5;
        Simp.immediate_quad(pos.x-s, pos.y-s, pos.x+s, pos.y+s, c);
    }
}
