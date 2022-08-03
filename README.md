# Qualcomm Flasher Tools
Unlock and flash the Android phone devices

## How to using this script:
```
$ ./qctools --help
USAGE:  ./qctools <device> [OPTION]...

    -d, --install-drivers    install driver
    -h, --help               show help usage
    -M, --method             choose what do you execute
    -v, --verbose            explain what is being done
        --version            show script file version and credits

To see device list, type  ./qctools --list-available
```

List command:
```
Do erase or reset partition:
    userdata
    frp
    efs
    misc
    micloud
```

Example:
```
$ ./qctools note5pro_whyred --method=micloud

Selected Model:    Xiaomi Redmi Note 5 Pro (Whyred)
Selected Brand:    Xiaomi
Operation:         Erase MiCloud

Error:  Qualcomm HS-USB port not detected.

```
```
$ ./qctools a53_cph2127 --method=frp

Selected Model:    Oppo A53 (CPH-2127)
Selected Brand:    Oppo/Realme
Operation:         Erase FRP

Error:  Qualcomm HS-USB port not detected.

```
```
$ ./qctools note8_ginkgo --reboot-edl

Selected Model:    Xiaomi Redmi Note 8 (Ginkgo)
Selected Brand:    Xiaomi
Operation:         Reboot to EDL mode

[ * ]   Rebooting device to EDL mode . . .
```


See changelog [here](https://github.com/thefirefox12537/qctools_tff/blob/master/CHANGELOG.md)