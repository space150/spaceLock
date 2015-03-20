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

byte encrypted[] = 
{
  0x3b, 0x7f, 0x27, 0x3a, 0xb9, 0x2d, 0x5d, 0xbd, 0xb7, 0x8c, 0xc7, 0x10, 0xdd, 0x77, 0x06, 0xa3, 
  0x8b, 0x0b, 0x0e, 0x41, 0x07, 0xbc, 0xf1, 0xe8, 0x61, 0x68, 0xce, 0x6f, 0x3e, 0x00, 0x15, 0xd2
};

byte out[32];

void setup() 
{
  // for testing only, RFDuino prefers 9600 baud for performance reasons
  override_uart_limit = true;
  Serial.begin(57600);
  
  // production
  //Serial.begin(9600);
  
  Serial.println("testng mode");

  byte success = aes.set_key (key, 128);
  Serial.print("set key success: ");
  Serial.println( success );
  
  success = aes.decrypt( encrypted, out );
  Serial.print("descrypt success: ");
  Serial.println( success );
  
  Serial.print("Descrypted string: ");
  for (byte i = 0 ; i < 32 ; i++)
  {
    byte val = out[i];
    Serial.print( (char)val );
  }
  
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
