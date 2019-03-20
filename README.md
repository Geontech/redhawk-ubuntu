# REDHAWK in Ubuntu

The purpose of this build script is to download, compile and install version 2.2.1 of REDHAWK SDR's core framework, IDE, and default SDRROOT (i.e., Waveforms and Components) on an Ubuntu -based host.  The current tested Ubuntu version is 16.04.

## Installation

You will need to have super user permissions to use this script.  

 Simply run:

 ```
 # ./build.sh
 ```

 Where the `#` signifies running as a super user.

### Compiled Dependencies

It will compile and install the following dependencies:

 * omniORB 4.2.3
 * omniORBpy 4.2.3
 * OmniEvents 2.8.1
 * UHD 3.10.01
 * libnmea 0.5.3

 > UHD Note: The USRP_UHD Device can work with some newer versions of UHD, however this is the most recent one we have tested.  If you have a newer version, install the development libraries and comment out the call to `install_uhd_` at the bottom of the build script.

 ### Packaged Dependencies

 A number of other dependencies are also installed using a combination of `apt` and `pip`.  Please see the `install_build_deps` function for more information.
