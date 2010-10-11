/*
 www.ArduCopter.com - www.DIYDrones.com
 Copyright (c) 2010.  All rights reserved.
 An Open Source Arduino based multicopter.
 
 File     : ArducopterNG.pde
 Version  : v1.0, 11 October 2010
 Author(s): ArduCopter Team
             Ted Carancho (AeroQuad), Jose Julio, Jordi Muñoz,
             Jani Hirvinen, Ken McEwans, Roberto Navoni,          
             Sandro Benigno, Chris Anderson
 
 This program is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
 
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 GNU General Public License for more details.
 
 You should have received a copy of the GNU General Public License
 along with this program. If not, see <http://www.gnu.org/licenses/>.

/* ********************************************************************** */
/* Hardware : ArduPilot Mega + Sensor Shield (Production versions)        */
/* Mounting position : RC connectors pointing backwards                   */
/* This code use this libraries :                                         */
/*   APM_RC : Radio library (with InstantPWM)                             */
/*   APM_ADC : External ADC library                                       */
/*   DataFlash : DataFlash log library                                    */
/*   APM_BMP085 : BMP085 barometer library                                */
/*   APM_Compass : HMC5843 compass library [optional]                     */
/*   GPS_MTK or GPS_UBLOX or GPS_NMEA : GPS library    [optional]         */
/* ********************************************************************** */

/* ************************************************************ */
/* **************** MAIN PROGRAM - MODULES ******************** */
/* ************************************************************ */

/* User definable modules */
// Comment out with   // modules that you are not using

//#define IsGPS       // Do we have a GPS connected
//#define IsNEWMTEK   // Do we have MTEK with new firmware
//#define IsMAG         // Do we have a Magnetometer connected, if have remember to activate it from Configurator
//#define IsTEL       // Do we have a telemetry connected, eg. XBee connected on Telemetry port
//#define IsAM          // Do we have motormount LED's. AM = Atraction Mode
//#define UseAirspeed
//#define UseBMP
//#define BATTERY_EVENT 1   // (boolean) 0 = don't read battery, 1 = read battery voltage (only if you have it wired up!)

#define CONFIGURATOR

// Serial data, do we have FTDI cable or Xbee on Telemetry port as our primary command link
#define Ser0          // FTDI/USB Port  Either one
//#define Ser3          // Telemetry port

// Frame build condiguration
#define FLIGHT_MODE_+    // Traditional "one arm as nose" frame configuration
//#define FLIGHT_MODE_X  // Frame orientation 45 deg to CCW, nose between two arms

/* ************************************************************ */
/* **************** MAIN PROGRAM - INCLUDES ******************* */
/* ************************************************************ */

#include <avr/io.h>
#include <avr/eeprom.h>
#include <avr/pgmspace.h>
#include <math.h>
#include <APM_RC.h> 		// ArduPilot Mega RC Library
#include <APM_ADC.h>		// ArduPilot Mega Analog to Digital Converter Library 
#include <APM_BMP085.h> 	// ArduPilot Mega BMP085 Library 
#include <DataFlash.h>		// ArduPilot Mega Flash Memory Library
#include <APM_Compass.h>	// ArduPilot Mega Magnetometer Library
#include <Wire.h>               // I2C Communication library
#include <APM_BMP085.h> 	// ArduPilot Mega BMP085 Library 
#include <EEPROM.h>             // EEPROM 
#include "Arducopter.h"
#include "ArduUser.h"

// GPS
#include <GPS_MTK.h>		// ArduPilot MTK GPS Library
//#include <GPS_IMU.h>		// ArduPilot IMU/SIM GPS Library
//#include <GPS_UBLOX.h>	// ArduPilot Ublox GPS Library
//#include <GPS_NMEA.h> 	// ArduPilot NMEA GPS library

/* Software version */
#define VER 0.1    // Current software version (only numeric values)

/* ************************************************************ */
/* ************* MAIN PROGRAM - DECLARATIONS ****************** */
/* ************************************************************ */

byte flightMode;

unsigned long currentTime, previousTime, deltaTime;
unsigned long mainLoop = 0;
unsigned long sensorLoop = 0;
unsigned long controlLoop = 0;
unsigned long radioLoop = 0;
unsigned long motorLoop = 0;

/* ************************************************************ */
/* **************** MAIN PROGRAM - SETUP ********************** */
/* ************************************************************ */
void setup() {
  
  APM_Init();    // APM Hardware initialization (in System.pde)
  
  previousTime = millis();
  motorArmed = 0;
  Read_adc_raw();                   // Initialize ADC readings...
  delay(20);
  digitalWrite(LED_Green,HIGH);     // Ready to go...  
}



/* ************************************************************ */
/* ************** MAIN PROGRAM - MAIN LOOP ******************** */
/* ************************************************************ */

// fast rate
// read sensors
// IMU : update attitude
// motor control

// medium rate
// read transmitter
// magnetometer
// barometer

// slow rate
// external command/telemetry
// GPS

void loop()
{
  int aux;
  int i;
  float aux_float;

  currentTime = millis();
  //deltaTime = currentTime - previousTime;
  //G_Dt = deltaTime / 1000.0;
  //previousTime = currentTime;

  // Sensor reading loop is inside APM_ADC and runs at 400Hz
  // Main loop at 200Hz (IMU + control)
  if (currentTime > (mainLoop + 5))    // 200Hz (every 5ms)
    {
    G_Dt = (currentTime-mainLoop) / 1000.0;   // Microseconds!!!
    mainLoop = currentTime;

    //IMU DCM Algorithm
    Read_adc_raw();       // Read sensors raw data
    Matrix_update(); 
    // Optimization: we don´t need to call this functions all the times
    //if (IMU_cicle==0)
    //  {
      Normalize();          
      Drift_correction();
    //  IMU_cicle = 1;
    //  }
    //else
    //  IMU_cicle = 0;
    Euler_angles();

    // Read radio values (if new data is available)
    if (APM_RC.GetState() == 1)   // New radio frame?
      read_radio();

    // Attitude control
    if(flightMode == STABLE_MODE) {    // STABLE Mode
      gled_speed = 1200;
      if (AP_mode == 0)           // Normal mode
        Attitude_control_v3(command_rx_roll,command_rx_pitch,command_rx_yaw);
      else                        // Automatic mode : GPS position hold mode
        Attitude_control_v3(command_rx_roll+command_gps_roll,command_rx_pitch+command_gps_pitch,command_rx_yaw);
      }
    else {   // ACRO Mode
      gled_speed = 400;
      Rate_control_v2();
      // Reset yaw, so if we change to stable mode we continue with the actual yaw direction
      command_rx_yaw = ToDeg(yaw);
      }

    // Send output commands to motor ESCs...
    motor_output();

    // Performance optimization: Magnetometer sensor and pressure sensor are slowly to read (I2C)
    // so we read them at the end of the loop (all work is done in this loop run...)
    #ifdef IsMAG
    if (MAGNETOMETER == 1) {
      if (MAG_counter > 20)  // Read compass data at 10Hz...
      {
        MAG_counter=0;
        APM_Compass.Read();     // Read magnetometer
        APM_Compass.Calculate(roll,pitch);  // Calculate heading
      }
    }
    #endif
    #ifdef UseBMP
    #endif
    
    // Slow loop (10Hz)
    if((currentTime-tlmTimer)>=100) {
    //#if BATTERY_EVENT == 1
    //  read_battery();         // Battery monitor
    //#endif
    #ifdef CONFIGURATOR
      readSerialCommand();
      sendSerialTelemetry();
    #endif
      tlmTimer = currentTime;   
    } 
  }
}
 
