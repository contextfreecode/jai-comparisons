package invaders

fader_alpha: f32 = 0;
fader_text := "";

level_one :: proc() {
    num_desired_invaders = 5;
}

level_two :: proc() {
    num_desired_invaders = 9;
}

level_three :: proc() {
    num_desired_invaders = 14;
}

level_thereafter :: proc() {
    num_desired_invaders = 20;
}

init_new_level :: proc(index: int) {
    if index == 0 { level_one() }
    else if index == 1 { level_two() }
    else if index == 2 { level_three() }
    else { level_thereafter() }

    for _ in 1..=num_desired_invaders*ALIENS_MULTIPLIER { add_invader() }

    // play_sound(*entity_manager, "new_wave");

    if fader_text { free(fader_text.data) }

    fader_text = sprint("Stage %", index+1);
    fader_alpha = 1;

    play_sound(sound_new_wave, false);
}
