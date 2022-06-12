#import "Basic";
#import "Hash_Table";
#import "Math";
#import "Random";
#import "Sound_Player";
#import "Wav_File";
#import "stb_vorbis";
#import "Window_Creation";
#import "File";
#import "String"; // For path_strip_filename.
#import "Thread";
#import "Input";
#import "System";

Simp    :: #import "Simp";
Texture :: Simp.Texture;

#load "entities.jai";
#load "levels.jai";
#load "particles.jai";

window_width  : s32 = 1280; 
window_height : s32 = 720;

WAV :: "wav";
OGG :: "ogg";

key_left  : u32;
key_right : u32;
key_up    : u32;
key_down  : u32;

should_ignore_input := false;
should_quit_game    := false;


sound_alien_dies:          *Mixer_Sound_Data;
sound_fire_bullet1:        *Mixer_Sound_Data;
sound_fire_bullet2:        *Mixer_Sound_Data;
sound_fire_bullet3:        *Mixer_Sound_Data;
sound_invader_fire_bullet: *Mixer_Sound_Data;
sound_new_wave:            *Mixer_Sound_Data;
sound_pickup_fail:         *Mixer_Sound_Data;
sound_pickup_succeed:      *Mixer_Sound_Data;
sound_player_dies:         *Mixer_Sound_Data;
sound_shield_begin:        *Mixer_Sound_Data;
sound_shield_end:          *Mixer_Sound_Data;
sound_shield_loop:         *Mixer_Sound_Data;  // Currently unused?! @Cleanup
sound_bullet_reset:        *Mixer_Sound_Data;

sound_player : *Sound_Player;

current_dt: float = 0.016667;
last_time:  float64;
DT_MAX : float : 0.15;

live_y_max := 1.1;
live_y_min := -0.1;

num_desired_invaders : int = 3;

INVADER_RADIUS :: .03;
BULLET_RADIUS  :: .01;
SHIP_RADIUS    :: .038;
PICKUP_RADIUS  :: .014;

PICKUP_SPEED :: -.2;
SHIP_INVINCIBILITY_TIME :: 8.0;
SHIP_V_SHOT_TIME :: 12.0;

PARTICLES_PER_SECOND_MULTIPLIER :: 1;
ALIENS_MULTIPLIER :: 1;
PLAY_SOUND_WHEN_ALIEN_SHOOTS_BULLET :: true;

NUM_UPDATE_PROCS :: 3;

entity_manager: Entity_Manager;

Shot_Type :: enum u32 {
    STRAIGHT_SINGLE :: 0;
    STRAIGHT_DOUBLE :: 1;
    STRAIGHT_TRIPLE :: 2;
}


live_invaders : [..] *Invader;
live_pickups  : [..] *Pickup;
live_bullets  : [..] *Bullet;
live_emitters : [..] *Particle_Emitter;

shot_index             := 0;
num_invaders_destroyed := 0;
level_index            := 0;
end_game_countdown     := -1.0;

my_font: *Simp.Dynamic_Font;

ship_position: Vector2;

ship_destroyed                := false;
ship_shot_type                := Shot_Type.STRAIGHT_SINGLE;               
ship_shot_cooldown            := 0.0;
ship_shot_cooldown_base       := 0.08;
ship_shot_cooldown_per_bullet := 0.15;
ship_invincibility_countdown  := 0.0;
ship_v_shot_countdown         := 0.0;

invader_maps : [..] Texture;

sky_map                 : Texture;
ship_map                : Texture;
ship_bullet_map         : Texture;
invader_bullet_map      : Texture;
contrail_map            : Texture;
pickup_map_v_shot       : Texture;
pickup_map_shield       : Texture;
pickup_map_extra_bullet : Texture;

update_proc_side :: (self: *Invader) {
    rate :: 1.5;
    theta := last_time * TAU64 * rate;
    y := cos(cast(float) theta);

    self.position.x += y * 0.5 * current_dt;
}

update_proc_circle :: (self: *Invader) { 
    rate :: 1.5;
    theta := last_time * TAU64 * rate;

    x := cos(cast(float) theta);
    y := sin(cast(float) theta);

    r := 0.5 * current_dt;
    self.position.x += x * r;
    self.position.y += y * r;
}

main :: () {
    last_time = get_time();

    width  := window_width;
    height := window_height;

    render_width  := width;
    render_height := height;

    window := create_window(window_name="Invaders", width=window_width, height=window_height);
    Simp.set_render_target(window);

    sound_player = New(Sound_Player);
    sound_player.update_history = true;

    //
    // Load sound effects
    //
    load_sound :: (basename: string) -> *Mixer_Sound_Data {
        name := tprint("data/%.wav", basename);
        data := load_audio_file(name);

        if !data {
            print("Error: Could not load wav file: %\n", name);
            exit(1); // Hard-exit for now.
            return null;
        }

        return data;
    }

    // You might think, "hey, we can auto-generate this kind of
    // thing from a list of strings with metaprogramming." We could,
    // but this wouldn't allow us the freedom to change filenames,
    // or renaming a variable would break the game in an unintuitive
    // way because there would be no corresponding sound file.
    // So we do it the simple / dumb way. A shipping game would have
    // some kind of asset catalog where you would use handles (or
    // maybe just the string name) when you play sound effects.

    sound_alien_dies          = load_sound("alien_dies");
    sound_fire_bullet1        = load_sound("fire_bullet1");
    sound_fire_bullet2        = load_sound("fire_bullet2");
    sound_fire_bullet3        = load_sound("fire_bullet3");
    sound_invader_fire_bullet = load_sound("invader_fire_bullet");
    sound_new_wave            = load_sound("new_wave");
    sound_pickup_fail         = load_sound("pickup_fail");
    sound_pickup_succeed      = load_sound("pickup_succeed");
    sound_player_dies         = load_sound("player_dies");
    sound_shield_begin        = load_sound("shield_begin");
    sound_shield_end          = load_sound("shield_end");
    sound_shield_loop         = load_sound("shield_loop");
    sound_bullet_reset        = load_sound("too_many_bullets");
    
    //
    // Create the music stream.
    //
    {
        name := "data/commando.ogg";

        data := load_audio_file(name);

        if !data {
            print("Could not load theme music: %\n", name);
            exit(1); // Hard-exit for now.
        }

        stream := play_sound(data, false);

        if stream {
            stream.flags   |= .REPEATING;
            stream.category = .MUSIC;
            stream.user_volume_scale *= 0.2;
        }
    }

    success := init(sound_player, xx window, true, true);
    // assert(success); // @Incomplete We need an audio pass. Low priority (for now).

    my_init_fonts();

    init_textures();

    ship_position.x = .5;
    ship_position.y = .05;

    level_index = 0;
    init_new_level(level_index);

    //
    // Setup editable properties for the sprites.
    //
    unit_color := Vector4.{1, 1, 1, 1};
    ship_color, invader_color, pickup_color, bullet_color := unit_color;

    ship_size    := make_vector2(SHIP_RADIUS*2,    SHIP_RADIUS*2);
    pickup_size  := make_vector2(PICKUP_RADIUS*2,  PICKUP_RADIUS*2);
    invader_size := make_vector2(INVADER_RADIUS*2, INVADER_RADIUS*2);
    bullet_size  := make_vector2(BULLET_RADIUS*2,  BULLET_RADIUS*2);

    while !should_quit_game {
        Simp.clear_render_target(.2, .3, .3, 1);

        update_window_events();

        // @Incomplete: Handle resizes in the actual scene drawing, which we currently don't.
        for get_window_resizes() {
            Simp.update_window(it.window);
            if it.window == window {
                should_reinit := (it.width != window_width) || (it.height != window_height);
                
                window_width  = it.width;
                window_height = it.height;

                if should_reinit my_init_fonts();
            }
        }
        
        invaders_simulate();

        { // Draw the sky background.
            Simp.set_shader_for_images(*sky_map);

            sky_color := Vector4.{1,1,1,1};

            Simp.immediate_quad(0, 0, xx render_width, xx render_height, sky_color);
        }
        
        for live_bullets
            render_sprite_quad_centered(it.map, it.position, bullet_size, bullet_color);

        if !ship_destroyed
            draw_ship_at(ship_map, ship_position, ship_size, ship_color);
        for live_pickups
            render_sprite_quad_centered(it.map, it.position, pickup_size, pickup_color);
        for live_invaders
            render_sprite_quad_centered(it.map, it.position, invader_size, invader_color);

        for live_emitters draw_emitter(it);

        if fader_alpha > 0 {
            text_width := Simp.prepare_text(my_font, fader_text);
            text_x := (window_width - text_width) / 2;
            text_y := window_height*.7 - my_font.character_height;
            color  := make_vector4(0.5, 0.8, 0.2, fader_alpha);

            Simp.draw_prepared_text(my_font, xx text_x, xx text_y, color);
            
            if fader_alpha > 0 {
                dt := current_dt;
                fader_alpha -= dt * 0.5;
                if fader_alpha < 0  fader_alpha = 0;
            }
        }

        text := sprint("Score: %", num_invaders_destroyed);
        defer free(text);
        text_w := Simp.prepare_text(my_font, text);
        scale := 0.5;

        Simp.draw_prepared_text(my_font, window_width/30, window_height-my_font.character_height, .{.5, .8, .2, 1});

        Simp.swap_buffers(window);
    }
}

init_textures :: () {
    ship_map                = make_texture("data/ship.png");

    sky_map                 = make_texture("data/sky.png");
    
    ship_bullet_map         = make_texture("data/bullet.png");
    invader_bullet_map      = make_texture("data/invader_bullet.png");
    contrail_map            = make_texture("data/contrail.png");
    pickup_map_v_shot       = make_texture("data/pickup_v_shot.png");
    pickup_map_shield       = make_texture("data/pickup_shield.png");
    pickup_map_extra_bullet = make_texture("data/pickup_extra_bullet.png");

    bug1 := make_texture("data/bug1.png");
    bug2 := make_texture("data/bug2.png");
    bug3 := make_texture("data/bug3.png");
    bug4 := make_texture("data/bug4.png");

    array_add(*invader_maps, bug1);
    array_add(*invader_maps, bug2);
    array_add(*invader_maps, bug3);
    array_add(*invader_maps, bug4);
}

make_texture :: (filename: string) -> Texture, bool {
    result: Texture;
    success := Simp.texture_load_from_file(*result, filename);

    return result, success;
}

MIDFIELD :: 5.0/8.0;

init_invader :: (invader : * Invader) {
    init_target(invader);

    invader.x = random_get_within_range(0, 1);
    invader.y = random_get_within_range(1.1, 1.3) * MIDFIELD;
}

init_target :: (invader: * Invader) {
    invader.target_position.x = random_get_within_range(0, 1);
    invader.target_position.y = random_get_within_range(MIDFIELD*.5, MIDFIELD*.8);
}

add_invader :: () {
    invader := New(Invader);
    which := random_get() % cast(u32) invader_maps.count;
    invader.map = *invader_maps[which];

    init_invader(invader);
    array_add(*live_invaders, invader);

    // Update procs:

    update_roll := random_get() % NUM_UPDATE_PROCS;

    if update_roll == 1 invader.update_proc = update_proc_side;
    if update_roll == 2 invader.update_proc = update_proc_circle;
}

invaders_simulate :: () {
    now := get_time();
    delta : float64 = now - last_time;
    current_dt = cast(float) delta;

    if current_dt > DT_MAX current_dt = DT_MAX;

    last_time = now;

    update_sound_player(current_dt);

    countdown :: (value : float) -> float {
        value -= current_dt;
        if value < 0 value = 0;
        return value;
    }

    old_invincibility := ship_invincibility_countdown;

    ship_shot_cooldown           = countdown(ship_shot_cooldown);
    ship_invincibility_countdown = countdown(ship_invincibility_countdown);
    ship_v_shot_countdown        = countdown(ship_v_shot_countdown);

    if ship_invincibility_countdown <= 0 && old_invincibility > 0 {
        play_sound(sound_shield_end);
    }

    if end_game_countdown >= 0 {
        end_game_countdown -= current_dt;
        if end_game_countdown < 0 should_quit_game = true;
    }

    if live_invaders.count == 0 {
        level_index += 1;
        init_new_level(level_index);
    }

    for event : events_this_frame {
        if event.type == .QUIT {
            should_quit_game = true;
            break;
        }

        if event.key_code == .ESCAPE 
            if event.key_pressed should_quit_game = true;

        if event.type == .KEYBOARD {
            key := event.key_code;

            if key == .ARROW_LEFT   key_left  = event.key_pressed;
            if key == .ARROW_RIGHT  key_right = event.key_pressed;
            if key == .ARROW_DOWN   key_down  = event.key_pressed;
            if key == .ARROW_UP     key_up    = event.key_pressed;

            if key == .SHIFT        if event.key_pressed maybe_fire_bullets();
        }
    }

    // Put direction into a vector, then normalize, so that
    // you don't move faster diagonally!
    dx: Vector2;
    
    if key_up     dx.y += 1;
    if key_left   dx.x -= 1;
    if key_down   dx.y -= 1;
    if key_right  dx.x += 1;

    if length(dx) > 1 {
        dx = unit_vector(dx);
    }
    
    ship_position += dx * .5 * current_dt;
    
    x0 := 0.03;
    x1 := 1 - x0;
    y0 := 0.03;
    y1 := 0.35;
    
    Clamp(*ship_position.x, x0, x1);
    Clamp(*ship_position.y, y0, y1);
    
    simulate_bullets();
    simulate_invaders();
    simulate_pickups();

    for live_emitters update_emitter(it, current_dt);
}

do_fire_bullets :: () {

    fire_bullet :: () -> * Bullet {
        bullet := New(Bullet);

        bullet.position = ship_position;

        bullet.velocity = .{0, .5};
        bullet.map = *ship_bullet_map;

        {
            bullet.emitter = New(Particle_Emitter);
            bullet.emitter.theta0 = TAU * 0.6;
            bullet.emitter.theta1 = TAU * 0.9;
            bullet.emitter.drag0 = 0.9;
            bullet.emitter.drag1 = 0.97;

            array_add(*live_emitters, bullet.emitter);

            k0 := 1.0;
            k1 := 0.1;

            bullet.emitter.color0 = make_vector4(k0, k0*.3, k0*.3, 1);
            bullet.emitter.color1 = make_vector4(k1, k1*.3, k1*.3, 1);
        }
        
        array_add(*live_bullets, bullet);

        return bullet;
    }

    num_shots_fired := 0;
    shot_index += 1;

    if ship_shot_type == .STRAIGHT_SINGLE || ship_shot_type == .STRAIGHT_TRIPLE {
        front := fire_bullet();
        front.position.y += 0.015;
        
        num_shots_fired += 1;

        if ship_v_shot_countdown && ship_shot_type == .STRAIGHT_SINGLE {
            LATERAL := 0.05;
            if shot_index % 2 front.velocity.x = LATERAL;
            else front.velocity.x = -LATERAL;
        }
    }

    if ship_shot_type == .STRAIGHT_DOUBLE || ship_shot_type == .STRAIGHT_TRIPLE {
        left  := fire_bullet();
        right := fire_bullet();

        offset := 0.023;

        left.position.x -= offset;
        right.position.x += offset;

        if ship_v_shot_countdown {
            LATERAL := 0.08;
            left.velocity.x  = -LATERAL;
            right.velocity.x = LATERAL;
        }

        num_shots_fired += 2;
    }

    ship_shot_cooldown += ship_shot_cooldown_base + (cast(float) num_shots_fired) * ship_shot_cooldown_per_bullet;

    if num_shots_fired == {
        case 1; play_sound(sound_fire_bullet1);
        case 2; play_sound(sound_fire_bullet2);
        case 3; play_sound(sound_fire_bullet3);
    }
}

maybe_fire_bullets :: () {
    if ship_shot_cooldown > 0  return;
    if ship_destroyed          return;
    
    do_fire_bullets();
}

invader_fire_bullet :: (invader : * Invader) {
    fire_bullet :: () -> * Bullet {
        bullet := New(Bullet);
        bullet.velocity.x = 0;

        if random_get() % 2 bullet.velocity.y = -.3;
        else bullet.velocity.y = -.15; 

        bullet.map = *invader_bullet_map;

        array_add(*live_bullets, bullet);

        {
            bullet.emitter = New(Particle_Emitter);
            bullet.emitter.theta0 = TAU * 0.6;
            bullet.emitter.theta1 = TAU * 0.9;
            bullet.emitter.drag0 = 0.9;
            bullet.emitter.drag1 = 0.97;

            bullet.emitter.size0 *= 0.5;
            bullet.emitter.size1 *= 0.5;

            bullet.emitter.speed1 = 0.05;

            bullet.emitter.lifetime0 = 0.2;
            bullet.emitter.lifetime1 = 0.5;

            array_add(*live_emitters, bullet.emitter);

            k0 := 0.7;
            k1 := 0.1;

            bullet.emitter.color0 = make_vector4(k0, k0, k0, 1);
            bullet.emitter.color1 = make_vector4(0.2, 1.0, 0.1, 1);
        }
        
        return bullet;
    }


    bullet := fire_bullet();
    bullet.player_friendly = false;
    bullet.position = invader.position;

    if PLAY_SOUND_WHEN_ALIEN_SHOOTS_BULLET {
        play_sound(sound_invader_fire_bullet);
    }
}

simulate_bullets :: () {
    simulate_bullet :: (bullet : * Bullet) -> bool {
        linear_move(*bullet.position, *bullet.velocity, current_dt);

        if bullet.position.y > live_y_max return true;
        if bullet.position.y < live_y_min return true;

        bullet.emitter.position = bullet.position;
        bullet.emitter.velocity = bullet.velocity;

        if bullet.player_friendly {
            if test_against_invaders(bullet) return true;
        } else {
            if test_against_ship(bullet.position, BULLET_RADIUS) {
                if !ship_is_shielded() destroy_ship();
                return true;
            }
        }

        return false;
    }

    for live_bullets {
        done := simulate_bullet(it);
        if done {
            it.emitter.producing = false;
            remove it;
            free(it);
        }
    }
}

simulate_invaders :: () {
    for live_invaders {
        if it.sleep_countdown < 0 {
            speed := 0.2;
            delta := speed * current_dt;

            dx := it.target_position.x - it.position.x;
            dy := it.target_position.y - it.position.y;

            denom := ilength(dx, dy);
            dx *= denom;
            dy *= denom;

            if distance(it.position, it.target_position) <= delta {
                it.sleep_countdown = random_get_within_range(0.1, 1.5);

                it.position.x = it.target_position.x;
                it.position.y = it.target_position.y;
            } else {
                it.position.x += dx * delta;
                it.position.y += dy * delta;
            }
        }

        if it.sleep_countdown >= 0 {
            it.sleep_countdown -= current_dt;
            if it.sleep_countdown < 0 {
                roll := random_get() % 100;
                if roll < 60 {
                    invader_fire_bullet(it);
                    init_target(it);
                }
            }
        }

        if it.update_proc then (it.update_proc)(it);
    }
}

simulate_pickups :: () {

    simulate_pickup :: (pickup: *Pickup) -> bool {
        linear_move(*pickup.position, *pickup.velocity, current_dt);

        if pickup.position.y > live_y_max 
            return true;
        if pickup.position.y < live_y_min 
            return true;

        if test_against_ship(pickup.position, PICKUP_RADIUS) {
            if ship_is_shielded() {
                play_sound(sound_pickup_fail);
            } else {
                player_got_pickup(pickup);
                play_sound(sound_pickup_succeed);
            }

            return true;
        }

        return false;
    }


    for live_pickups {
        done := simulate_pickup(it);
        if done {
            remove it;
            free(it);
        }
    }
}

ilength :: (x: float, y: float) -> float {
    length := x * x + y * y;
    denom := 1.0 / sqrt(length);
    return denom;
}

test_against_ship :: (position: Vector2, radius: float) -> bool {
    if ship_destroyed return false;
    return distance(position, ship_position) < radius + SHIP_RADIUS;
}

destroy_invader :: (invader: *Invader) {
    num_invaders_destroyed += 1;

    array_unordered_remove_by_value(*live_invaders, invader);

    {
        emitter := New(Particle_Emitter);
        array_add(*live_emitters, emitter);

        emitter.size0 = 0.0008;
        emitter.size1 = 0.01;
    
        emitter.speed0 = 0.1;
        emitter.speed1 = 0.3;

        emitter.color0 = make_vector4(1, 1, 0.3, 1);
        emitter.color1 = make_vector4(1, 1, 1, 1);

        emitter.fadeout_period = 0.1;
        emitter.emitter_lifetime = 0.2;

        emitter.position = invader.position;
    }

    {
        emitter := New(Particle_Emitter);
        array_add(*live_emitters, emitter);

        emitter.size0 = 0.015;
        emitter.size1 = 0.06;
    
        emitter.color0 = make_vector4(1, 1, 1, 1);
        emitter.color1 = make_vector4(1, 0.7, 0.1, 1);

        emitter.fadeout_period = 0.3;
        emitter.emitter_lifetime = 0.3;

        emitter.position = invader.position;
    }

    drop_roll := random_get() % 100;
    if drop_roll < 30 {
        pickup := New(Pickup);
        array_add(*live_pickups, pickup);


        roll := random_get() % 100;

        pickup.position = invader.position;
        pickup.velocity = make_vector2(0, PICKUP_SPEED * random_get_within_range(0.7, 1.7));

        if roll < 20 {
            pickup.type = .V_SHOT;
            pickup.map = *pickup_map_v_shot;
        } else if roll < 45 {
            pickup.type = .EXTRA_BULLET;
            pickup.map = *pickup_map_extra_bullet;
        } else {
            pickup.type = .SHIELD;
            pickup.map = *pickup_map_shield;
        }
    }

    play_sound(sound_alien_dies);
}

destroy_ship :: () {
    ship_destroyed = true;
    end_game_countdown = 3.0;

    position := ship_position;

    {
        emitter := New(Particle_Emitter);
        array_add(*live_emitters, emitter);

        emitter.size0 = 0.0004;
        emitter.size1 = 0.005;
    
        emitter.speed0 = 0.15;
        emitter.speed1 = 0.45;

        emitter.color0 = make_vector4(1, 1, 0.3, 1);
        emitter.color1 = make_vector4(1, 1, 1, 1);

        emitter.fadeout_period = 0.1;
        emitter.emitter_lifetime = 0.2;

        emitter.position = position;
    }

    {
        emitter := New(Particle_Emitter);
        array_add(*live_emitters, emitter);

        emitter.size0 = 0.015;
        emitter.size1 = 0.06;
    
        emitter.color0 = make_vector4(1, 1, 1, 1);
        emitter.color1 = make_vector4(.94, 1, 0.05, 1);

        emitter.fadeout_period = 0.3;
        emitter.emitter_lifetime = 0.3;

        emitter.position = position;
    }


    play_sound(sound_player_dies);
}

test_against_invaders :: (bullet: *Bullet) -> bool {
    for live_invaders {
        if distance(bullet.position, it.position) < INVADER_RADIUS {
            destroy_invader(it);
            return true;
        }
    }

    return false;                              
}

player_got_pickup :: (pickup: *Pickup) {
    if pickup.type == .EXTRA_BULLET {
        if ship_shot_type == .STRAIGHT_SINGLE then ship_shot_type = .STRAIGHT_DOUBLE;
        else if ship_shot_type == .STRAIGHT_DOUBLE then ship_shot_type = .STRAIGHT_TRIPLE;
        else if ship_shot_type == .STRAIGHT_TRIPLE then {
            ship_shot_type = .STRAIGHT_SINGLE;
            play_sound(sound_bullet_reset);
        }
    } else if pickup.type == .SHIELD {
        if ship_invincibility_countdown <= 0   {
            play_sound(sound_shield_begin);
        }
        ship_invincibility_countdown = SHIP_INVINCIBILITY_TIME;
    } else if pickup.type == .V_SHOT {
        ship_v_shot_countdown += SHIP_V_SHOT_TIME;
    }
}

linear_move :: (position : *Vector2, velocity : *Vector2, dt : float) {
    position.x += velocity.x * dt;
    position.y += velocity.y * dt;
}

ship_is_shielded :: () -> bool {
    if ship_invincibility_countdown > 0 return true;
    return false;
}

draw_ship_at :: (texture: Texture, pos: Vector2, size: Vector2, color: Vector4) {
    ship_color := color;

    if ship_is_shielded() {
        rate : float64 = 1.5;
        if ship_invincibility_countdown < 1.7 rate = 4.5;

        theta := last_time * TAU64 * rate;
        y := cos(cast(float) theta);

        k := (y + 1.0) * 0.5;

        if k < 0 k = 0;
        if k > 1 k = 1;

        k *= 0.8;

        ship_color.x = 1;
        ship_color.y = k;
        ship_color.z = k;
    }

    render_sprite_quad_centered(*texture, pos, size, ship_color);
}

render_sprite_quad_centered :: (texture: *Texture, _pos: Vector2, size: Vector2, color: Vector4) {
    Simp.set_shader_for_images(texture);
    
    pos := _pos * cast(float) window_width;
    h := make_vector2(size.x*.5*window_width, 0);
    v := make_vector2(0, size.y*.5*window_width);

    p0 := pos - h - v;
    p1 := pos + h - v;
    p2 := pos + h + v;
    p3 := pos - h + v;

    Simp.immediate_quad(p0, p1, p2, p3,  color);
}

play_sound :: (data: *Mixer_Sound_Data, perturb: bool = true) -> *Sound_Stream {
    stream := make_stream(sound_player, data);

    if stream {
        stream.sound_data = data;
    }

    if perturb && stream {
        stream.user_volume_scale = random_get_within_range(0.7, 1);
        stream.desired_rate = random_get_within_range(0.7, 1.22);
    }

    stream.repeat_end_position = cast(int)(data.sampling_rate * 234.475);  // @Temporary @Hack! We do not get the duration by default from an ogg file...
    
    return stream;
}

load_audio_file :: (name : string) -> *Mixer_Sound_Data {
    data : *Mixer_Sound_Data = null;

    file_data, success := read_entire_file(name);
    if !success return data;

    has_extension :: (name: string, extension: string) -> bool {
        if name.count < extension.count  return false;
        test := name;
        advance(*test, name.count - extension.count);
        return test == extension;
    }

    if has_extension(name, WAV) {
        data = New(Mixer_Sound_Data);
        data.name = copy_string(name);
        data.buffer = file_data;

        format, samples, success2, extra := get_wav_header(data.buffer);
        if !success2 {
            log_error("Unable to parse '%' as wav.\n", data.full_path);
            return data;
        }

        if format.wFormatTag == WAVE_FORMAT_PCM {
            data.type                     = .LINEAR_SAMPLE_ARRAY;
            data.nchannels                = cast(u16) format.nChannels;
            data.nsamples_times_nchannels = samples.count/2;
        } else if format.wFormatTag == WAVE_FORMAT_DVI_ADPCM {
            data.type             = .ADPCM_COMPRESSED;
            data.wSamplesPerBlock = extra.wSamplesPerBlock;
            data.nBlockAlign      = format.nBlockAlign;

            data.nchannels = cast(u16) format.nChannels;
            // The value in the FACT chunk is number of samples by time. 
            data.nsamples_times_nchannels = extra.wSamplesAccordingToFactChunk * data.nchannels;
        } else {
            assert(false);
        }

        data.samples       = cast(*s16) samples.data;
        data.sampling_rate = cast(u32) format.nSamplesPerSec;
    } else if has_extension(name, OGG) {
        data = New(Mixer_Sound_Data);
        data.name   = copy_string(name);
        data.buffer = file_data;
        data.type   = .OGG_COMPRESSED;
    } else {
        // Unsupported format.
    }

    return data;
}

update_sound_player :: (dt: float) {
    //
    // Move sound streams forward by dt.
    //
    lock(*sound_player.sound_mutex);
    defer unlock(*sound_player.sound_mutex);

    pre_entity_update(sound_player);

    //
    // @Incomplete We're not removing sound streams once they're consumed.
    //
    for sound_player.streams {
        it.marked = true;
    }

    post_entity_update(sound_player, current_dt);
}    


my_init_fonts :: () {
    // So that we can load our font, set to path of running executable.
    // @Incomplete: Pack a default font into Simp.
    path := path_strip_filename(get_path_of_running_executable());

    set_working_directory(path);
    pixel_height := window_height / 24;

    // @Cleanup: Don't have path + name be separate.
    my_font = Simp.get_font_at_size("data", "Anonymous Pro.ttf", pixel_height);
    assert(my_font != null);
}
