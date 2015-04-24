# spaceLock

The goal of this project is to use the new Apple Watch to interact and open doors in the physical space. This project includes the iOS app and WatchKit extension, and a RFduino application and solenoid circuit. Using the combination of these, you can turn any door into a “smart” door, and a seamless physical to digital connection.

This project is a product of spaceLab, space150’s research and development division.

# Directory Structure

* <code>arduino</code> contains the physical lock arduino sketch and library dependencies. The lock itself is running on a RFDuino, other platforms will be supported in the future.

* <code>docs</code> contains an EAGL schematic for a reference implementation of the RFDuino integrated with a solenoid lock. Works with a 12VDC solenoid up to 1 amp.

* <code>ios</code> contains the iOS iPhone application with WatchKit extension.

# Security & Known Issues

This project is more of a "proof of concept" in its current state. A few key items need to be addressed to ensure a secure implementation:

* The AES encryption keys are stored in a plist file within the application bundle. This will in the future be changed so that the keys only reside on a secure server. Once downloaded the application will instead store them in the system Keychain.
* The arduino lock currently has no way of updating its internal clock to match wall-clock time. This prevents us from verifying the timestamp of the encrypted commands. An addition of a Wifi module and NTP client will be added in the future so that the unlock/lock commands are time-sensitive, this will prevent replay attacks.
* There are probably many more security issues, if you do find one or have a suggestion, feel free to send a pull request or email to shawn.roske@space150.com.
