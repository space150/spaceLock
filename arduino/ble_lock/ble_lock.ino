//  Copyright (c) 2015 space150, Inc.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
//  associated documentation files (the "Software"), to deal in the Software without restriction, including
//  without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the
//  following conditions:
//
//  The above copyright notice and this permission notice shall be included in all copies or substantial
//  portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT
//  LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO
//  EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
//  IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR
//  THE USE OR OTHER DEALINGS IN THE SOFTWARE.

#include <SimbleeBLE.h>
#include <AES.h>

// LOCK SPECIFIC CONFIG

//#define LOCK_NAME "s150-senate"
//byte key[] = { 0x55, 0xc8, 0x66, 0x1c, 0x7b, 0x58, 0xae, 0xbf, 0x93, 0x73, 0x32, 0x40, 0x54, 0x47, 0xd2, 0xcd };
//char hello[] = { 0xb3, 0xfe, 0x38, 0xfe, 0x26, 0xbb, 0x64, 0x68, 0x0a, 0x1e, 0x3d, 0x1a, 0x74, 0x78, 0xa3, 0x00 };

//#define LOCK_NAME "s150-sl"
//byte key[] = { 0xce, 0xe3, 0x59, 0x8e, 0xa4, 0x9b, 0xa4, 0xd8, 0x87, 0x2b, 0x20, 0x8e, 0x03, 0xd9, 0x9f, 0xcd };
//char hello[] = { 0x8c, 0x25, 0xfb, 0xb9, 0x7b, 0x35, 0x2a, 0x48, 0x82, 0xaa, 0xc9, 0xaa, 0x79, 0x45, 0x4c, 0x40 };

//#define LOCK_NAME "s150-vault"
//byte key[] = { 0x14, 0xbc, 0x28, 0xbc, 0xcf, 0x60, 0xb6, 0x30, 0x74, 0x71, 0x9d, 0x97, 0x4f, 0xa7, 0x92, 0x3e };
//char hello[] = { 0x73, 0xb1, 0x2c, 0xeb, 0x58, 0x88, 0x08, 0xb5, 0xd6, 0xca, 0x9e, 0x21, 0xad, 0x08, 0x30, 0x65 };

#define LOCK_NAME "s150-vip"
byte key[] = { 0xb1, 0x5b, 0x42, 0xbf, 0x77, 0x30, 0x3d, 0xc8, 0x9c, 0x96, 0x6f, 0x54, 0x33, 0x73, 0x1a, 0xab };
char hello[] = { 0x5d, 0xe2, 0x5b, 0xf1, 0xfc, 0x84, 0x2a, 0x42, 0x02, 0xd3, 0xf5, 0x53, 0x69, 0xbb, 0x5a, 0x69 };


// END LOCK SPECIFIC CONFIG

#define COMMAND_NONE   0
#define COMMAND_LOCK   1
#define COMMAND_UNLOCK 2

#define UNLOCK_COOLDOWN_MILLIS 7000

#define LOCK_PIN  6
#define LED_PIN_R 2
#define LED_PIN_G 3
#define LED_PIN_B 4

bool locked = true;
unsigned long last_command_millis = 0;
int current_command = COMMAND_LOCK;

#define MAX_HELLO_ATTEMPTS 10

bool send_hello = false;
int hello_attempts = 0;

AES aes;

void setup()
{
  Serial.begin(9600);

  // setup the leds for output
  pinMode(LED_PIN_R, OUTPUT);
  pinMode(LED_PIN_G, OUTPUT);
  pinMode(LED_PIN_B, OUTPUT);
  pinMode(LOCK_PIN, OUTPUT);

  SimbleeBLE.deviceName = "sl-lock";
  SimbleeBLE.advertisementData = LOCK_NAME;
  SimbleeBLE.customUUID = "876d7008-890e-4d28-9b19-bfabee9f0e24";

  // start the BLE stack
  SimbleeBLE.begin();
  Serial.println("Starting to listen");
}

void loop()
{
  attempt_send_hello();
  check_for_unlock_timeout();
  process_current_command();

  // switch to lower power mode
  Simblee_ULPDelay(350);
}

// COMMAND HANDLERS

void attempt_send_hello()
{
  if ( send_hello == true )
  {
    Serial.print("sending hello, attempt #"); Serial.println(hello_attempts);
    SimbleeBLE.send(hello, 16);

    hello_attempts += 1;
    if ( hello_attempts >= MAX_HELLO_ATTEMPTS )
    {
      send_hello = false;
      hello_attempts = 0;
    }
  }
}

void check_for_unlock_timeout()
{
  if ( locked == false )
  {
    // check to see if we are unlocked and the lock timeout acurred
    unsigned long current_millis = millis();
    if ( (current_millis - last_command_millis) > UNLOCK_COOLDOWN_MILLIS )
      current_command = COMMAND_LOCK;
  }
}

void process_current_command()
{
  if ( current_command != COMMAND_NONE)
  {
    if ( current_command == COMMAND_UNLOCK )
      unlock_door();
    else if ( current_command == COMMAND_LOCK )
      lock_door();

    current_command = COMMAND_NONE;
  }
}

void lock_door()
{
  locked = true;
  last_command_millis = millis();

  analogWrite(LED_PIN_R, 255);
  analogWrite(LED_PIN_G, 0);
  analogWrite(LED_PIN_B, 0);

  SimbleeBLE.send('l');

  digitalWrite(LOCK_PIN, LOW);
}

void unlock_door()
{
  locked = false;
  last_command_millis = millis();

  analogWrite(LED_PIN_R, 0);
  analogWrite(LED_PIN_G, 255);
  analogWrite(LED_PIN_B, 0);

  SimbleeBLE.send('u');

  digitalWrite(LOCK_PIN, HIGH);
}

void show_error()
{
  analogWrite(LED_PIN_R, 0);
  analogWrite(LED_PIN_G, 0);
  analogWrite(LED_PIN_B, 255);
}

// SECURITY

int decrypt_command(char *data, int len)
{
  Serial.println("-----------------------------");
  Serial.print("data received, len: "); Serial.println(len);
  Serial.print("data: ");

  byte encrypted[len];
  byte decrypted[len];

  for (byte i = 0 ; i < len ; i++)
  {
    byte val = (byte)data[i];
    encrypted[i] = val;
    Serial.print( (char)val );
  }

  Serial.println(" ");

  byte success = aes.set_key( key, 128 );
  if ( success == 0 )
  {
    success = aes.decrypt( encrypted, decrypted );
    if ( success == 0 )
    {
      Serial.print("Decrypted string: ");

      char command_char;
      String time_string = "";
      for (byte i = 0 ; i < len ; i++)
      {
        byte val = decrypted[i];
        Serial.print( (char)val );

        if ( i == 0 )
          command_char = (char)val;
        else
          time_string += (char)val;
      }

      Serial.println("");

      // convert time string to timestamp
      unsigned int timestamp = time_string.toInt();

      Serial.print("Timestamp: "); Serial.println(timestamp);
      Serial.print("Command: "); Serial.println(command_char);

      // VERIFY THE TIMESTAMP
      // we will probably need some additional hardware (wifi?) for this
      // TODO

      if ( command_char == 'u' || command_char == 'U' )
        return COMMAND_UNLOCK;
      else if ( command_char == 'l' || command_char == 'L' )
        return COMMAND_LOCK;
    }
    else
      Serial.println("failed to decrypt string!");
  }
  else
    Serial.println("failed to set key!");

  show_error();

  return COMMAND_NONE;
}

// Simblee BLE HANDLERS

void SimbleeBLE_onConnect()
{
  send_hello = true;
  hello_attempts = 0;
  Serial.println("Recieved connect");
}

void SimbleeBLE_onDisconnect()
{
  // reset the hello handshake on disconnect, they don't want to talk to us anyway :(
  send_hello = false;
  hello_attempts = 0;
  Serial.println("Recieved disconnect");
}

void SimbleeBLE_onReceive(char *data, int len)
{
  // once we receive data, the hello handshake probably worked!
  send_hello = false;
  hello_attempts = 0;

  Serial.println("Recieved data");

  if ( len >= 16 )
    current_command = decrypt_command(data, len);
}

void SimbleeBLE_onAdvertisement(bool start)
{
  // turn the green led on if we start advertisement, and turn it
  // off if we stop advertisement
  Serial.println("Advertisement");
 /*   if (start)
    digitalWrite(advertisement_led, HIGH);
  else
    digitalWrite(advertisement_led, LOW); */
}
