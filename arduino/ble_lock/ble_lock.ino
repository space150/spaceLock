#include <AES.h>
#include <RFduinoBLE.h>

byte key[] = 
{
  0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44,
  0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44,
};

#define COMMAND_NONE   0
#define COMMAND_LOCK   1
#define COMMAND_UNLOCK 2

#define UNLOCK_COOLDOWN_MILLIS 7000

#define LED_PIN_R 2
#define LED_PIN_G 3
#define LED_PIN_B 4

bool locked = true;
unsigned long last_command_millis = 0;
int current_command = COMMAND_LOCK;

AES aes;

void setup() 
{
  Serial.begin(9600);
  
  // setup the leds for output
  pinMode(LED_PIN_R, OUTPUT);
  pinMode(LED_PIN_G, OUTPUT);  
  pinMode(LED_PIN_B, OUTPUT);

  // this is the data we want to appear in the advertisement
  // (if the deviceName and advertisementData are too long to fix into the 31 byte
  // ble advertisement packet, then the advertisementData is truncated first down to
  // a single byte, then it will truncate the deviceName)
  RFduinoBLE.advertisementData = "s150-msp-f3";
  
  // start the BLE stack
  RFduinoBLE.begin();
}

void loop() 
{  
  check_for_unlock_timeout();
  process_current_command();
  
  // switch to lower power mode
  RFduino_ULPDelay(350);
}

// COMMAND HANDLERS

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
}

void unlock_door()
{
  locked = false;
  last_command_millis = millis();
  
  analogWrite(LED_PIN_R, 0);
  analogWrite(LED_PIN_G, 255);
  analogWrite(LED_PIN_B, 0);
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

// RFDUINO BLE HANDLERS

void RFduinoBLE_onConnect() 
{
  // nothing
}

void RFduinoBLE_onDisconnect() 
{
  // nothing
}

void RFduinoBLE_onReceive(char *data, int len) 
{
  if ( len >= 16 ) 
    current_command = decrypt_command(data, len);
}
