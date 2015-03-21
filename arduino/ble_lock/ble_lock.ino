#include <AES.h>
#include <RFduinoBLE.h>

// pin 2 on the RGB shield is the red led
int led1 = 2;
// pin 3 on the RGB shield is the green led
int led2 = 3;
// pin 4 on the RGB shield is the blue led
int led3 = 4;

AES aes;

byte key[] = 
{
  0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44,
  0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44,
};

void setup() 
{
  // for testing only, RFDuino prefers 9600 baud for performance reasons
  override_uart_limit = true;
  Serial.begin(57600);
  
  // production
  //Serial.begin(9600);
  
  // setup the leds for output
  pinMode(led1, OUTPUT);
  pinMode(led2, OUTPUT);  
  pinMode(led3, OUTPUT);

  // this is the data we want to appear in the advertisement
  // (if the deviceName and advertisementData are too long to fix into the 31 byte
  // ble advertisement packet, then the advertisementData is truncated first down to
  // a single byte, then it will truncate the deviceName)
  RFduinoBLE.advertisementData = "rgb";
  
  // start the BLE stack
  RFduinoBLE.begin();
}

void loop() 
{
  // switch to lower power mode
  RFduino_ULPDelay(INFINITE);
}

void RFduinoBLE_onConnect() 
{
  // the default starting color on the iPhone is white
  analogWrite(led1, 255);
  analogWrite(led2, 255);
  analogWrite(led3, 255);
}

void RFduinoBLE_onDisconnect() 
{
  // turn all leds off on disconnect and stop pwm
  digitalWrite(led1, LOW);
  digitalWrite(led2, LOW);
  digitalWrite(led3, LOW);
}

void RFduinoBLE_onReceive(char *data, int len) 
{
  if ( len >= 16 )
  {
    Serial.print("data received! "); 
    Serial.print("len: "); Serial.println(len);
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
        for (byte i = 0 ; i < len ; i++)
        {
          byte val = decrypted[i];
          Serial.print( (char)val ); Serial.println(" ");
        }
      }
      else
      {
        Serial.println("failed to decrypt string!");
      }
    }
    else
    {
      Serial.println("failed to set key!");
    }
    
  } // if len >= 16

 
  // each transmission should contain an RGB triple
  if ( len >= 3 )
  {
    // get the RGB values
    uint8_t r = data[0];
    uint8_t g = data[1];
    uint8_t b = data[2];

    // set PWM for each led
    analogWrite(led1, r);
    analogWrite(led2, g);
    analogWrite(led3, b);
  }
}
