# TFF/QC Tools
Unlock and flash the Android phone device

<img alt="GUI mode" src="assets/resources/images/gui_mode.png" alt="GUI mode (Beta version)" width="50%"/>
<img alt="CLI mode" src="assets/resources/images/command_line.png" alt="Command Line mode" width="50%"/>

<noscript><a href="https://liberapay.com/thefirefox12537/donate"><img alt="Donate using Liberapay" src="https://liberapay.com/assets/widgets/donate.svg"></a></noscript>

## Download:
[Click here](https://github.com/thefirefox12537/qctools_tff/archive/refs/heads/master.zip)

## How to using this script:
CLI mode:
```
$ ./qctools --help
USAGE:  ./qctools <device> [OPTION]...

    -E, --reboot-edl         reboot device in EDL mode
    -h, --help               show help usage
    -M, --method=<METHOD>    choose what do you execute
    -P, --port=<PORT>        set port connection
    -s, --serial-adb=<sn>    set ADB serial number connection
    -v, --verbose            explain what is being done
        --version            show script file version and credits

To see device list, type  ./qctools --list-available
```

GUI mode:
```
$ ./qctools
```

List command:
```
$ ./qctools --method=help
Do erase or reset partition:
    userdata
    frp
    efs
    misc
    micloud
    unlock-bl
    relock-bl
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
$ ./qctools oppo_a53_cph2127 --method=frp

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

## Changelog:stop

See changelog [here](https://github.com/thefirefox12537/qctools_tff/blob/master/CHANGELOG)

## Credits:
```
$ ./qctools --version
TFF/QC Tools
Unlock and flash the Android phone devices.
Version report:  1.0 revision 3

This script developed by Faizal Hamzah [The Firefox Flasher].
Licensed under the MIT License.

Credits:
    nijel8            Developer of emmcdl
    bkerler           Developer of Qualcomm Firehose Attacker
    Hari Sulteng      Owner of Qualcomm GSM Sulteng
    Hadi Khoirudin    Software engineer
```
