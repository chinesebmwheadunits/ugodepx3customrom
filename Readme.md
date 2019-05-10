# Build script and sources for UGode PX3 Custom rom.

To build a custom ROM run ./makerom.sh from a linux (ubuntu) bash shell. Suggested is to place the px3 unpatched rom into an img/ folder and run

./makerom.sh -f img/px3.img

## Requirements

* 32-bit runtime on a 64 bit system.
* wget
* e2fsprogs
* extended attributes support (xattr).

On ubuntu:

```
sudo dpkg --add-architecture i386
sudo apt-get update
sudo apt-get install libc6:i386 libncurses5:i386 libstdc++6:i386
sudo apt-get install wget attr e2fsprogs
```
