# spaceLock

The goal of this project is to use the new Apple Watch to interact and open doors in the physical space. This project includes the iOS app and WatchKit extension, and a RFduino application and solenoid circuit. Using the combination of these, you can turn any door into a “smart” door, and a seamless physical to digital connection.

This project is a product of spaceLab, space150’s research and development division.

# Directory Structure

* <code>arduino</code> contains the physical lock arduino sketch and library dependencies. The lock itself is running on a RFDuino, other platforms will be supported in the future.

* <code>docs</code> contains an EAGL schematic for a reference implementation of the RFDuino integrated with a selenoid lock. Works with a 12VDC solenoid up to 1 amp.

* <code>ios</code> contains the iOS iPhone application with WatchKit extension.


