/// -*- tab-width: 4; Mode: C++; c-basic-offset: 4; indent-tabs-mode: nil -*-


static void init_arm_motors()
{
    if(ap.armed)
        return;

    if(ap.home_is_set)
        init_home();

    set_armed(true);
}


static void init_disarm_motors()
{
    if(!ap.armed)
        return;
    // all I terms are invalid
    // -----------------------
    reset_I_all();

    set_armed(false);

    //compass.save_offsets();

#if SECONDARY_DMP_ENABLED == ENABLED
    ahrs2.set_fast_gains(true);
#endif
}



/*****************************************
 * Set the flight control servos based on the current calculated values
 *****************************************/
static void
update_servos()
{
	if(!ap.armed){
		hal.rcout->write(CH_1, 0);
		hal.rcout->write(CH_2, 0);
		hal.rcout->write(CH_3, 1500);
		reset_I_all();
		return;
	}

    uint8_t dir_left, dir_right;

//#if USE_WHEEL_LUT == ENABLED
	/*
    motor_out[LEFT_MOT_CH]  = get_pwm_from_speed_wheel_mixer_left(); // left motor
    motor_out[RIGHT_MOT_CH] = get_pwm_from_speed_wheel_mixer_right(); // righ motor

    motor_out[LEFT_MOT_CH]  = constrain(motor_out[LEFT_MOT_CH],  -2000, 2000);
    motor_out[RIGHT_MOT_CH] = constrain(motor_out[RIGHT_MOT_CH], -2000, 2000);

    dir_left 	= (motor_out[LEFT_MOT_CH]  < 0) ? LOW : HIGH;
    dir_right 	= (motor_out[RIGHT_MOT_CH] < 0) ? LOW : HIGH;

	hal.rcout->write(CH_1, abs(motor_out[LEFT_MOT_CH])); // left motor
	hal.rcout->write(CH_2, abs(motor_out[RIGHT_MOT_CH])); // right motor
	*/
//#else
    motor_out[LEFT_MOT_CH]  = (float)(pitch_out + yaw_out) * g.pid_wheel_left_mixer.kP(); // left motor
    motor_out[RIGHT_MOT_CH] = (float)(pitch_out - yaw_out) * g.pid_wheel_right_mixer.kP(); // righ motor

    motor_out[LEFT_MOT_CH]  = constrain(motor_out[LEFT_MOT_CH],  -2000, 2000);
    motor_out[RIGHT_MOT_CH] = constrain(motor_out[RIGHT_MOT_CH], -2000, 2000);


	if(motor_out[LEFT_MOT_CH] != 0){
		hal.rcout->write(CH_1, abs(motor_out[LEFT_MOT_CH])  + g.dead_zone); // left motor
	}else{
		hal.rcout->write(CH_1, abs(motor_out[LEFT_MOT_CH])); // left motor
	}

	if(motor_out[RIGHT_MOT_CH] != 0){
		hal.rcout->write(CH_2, abs(motor_out[RIGHT_MOT_CH])  + g.dead_zone); // right motor
	}else{
		hal.rcout->write(CH_2, abs(motor_out[RIGHT_MOT_CH])); // right motor
	}

//#endif


	hal.rcout->write(CH_3, 1500); // balance servo

    dir_left 	= (motor_out[LEFT_MOT_CH]  < 0) ? LOW : HIGH;	// reverse : forward
    dir_right 	= (motor_out[RIGHT_MOT_CH] < 0) ? HIGH : LOW;	// reverse : forward
    hal.gpio->write(LEFT_DIR, dir_left);
    hal.gpio->write(RIGHT_DIR, dir_right);

    /*cliSerial->printf_P(PSTR("p:%d, y:%d, l:%d r:%d, %d, %d\n"),
    	pitch_out,
    	yaw_out,
    	motor_out[LEFT_MOT_CH],
    	motor_out[RIGHT_MOT_CH],
    	dir_left,
    	dir_right);
    	*/
}



static void
set_servos_direct(int16_t pwm)
{
    uint8_t dir_left, dir_right;

#if USE_WHEEL_LUT == ENABLED
    motor_out[0] = get_pwm_from_speed_wheel_mixer_left();
    motor_out[1] = get_pwm_from_speed_wheel_mixer_right();
#else
    motor_out[0] = pwm;
    motor_out[1] = pwm;
#endif


	hal.rcout->write(CH_1, abs(motor_out[LEFT_MOT_CH])); // left motor
	hal.rcout->write(CH_2, abs(motor_out[RIGHT_MOT_CH])); // right motor

    dir_left 	= (motor_out[LEFT_MOT_CH]  < 0) ? LOW : HIGH;	// reverse : forward
    dir_right 	= (motor_out[RIGHT_MOT_CH] < 0) ? HIGH : LOW;	// reverse : forward
    hal.gpio->write(LEFT_DIR, dir_left);
    hal.gpio->write(RIGHT_DIR, dir_right);
}

