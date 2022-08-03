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


## Changelog
### 1.0

1. Initial released
1. Added feature: Erase userdata
1. Added feature: Erase FRP
1. Added feature: Safe format data
1. Added feature: Erase EFS
1. Added feature: Erase MiCloud

**Device commited:**
#### Oppo / Realme:

   | Codename               | Description  |
   |:----------------------:|:------------:|
   | a33_cph2137            | Oppo A33     |
   | a53_cph2127            | Oppo A53     |
   | a53s_cph2139           | Oppo A53S    |
   | a73_cph2099            | Oppo A73     |
   | a74_cph2219            | Oppo A74     |
   | a95_cph2365            | Oppo A95     |
   | f17_cph2095            | Oppo F17     |
   | f19_cph2219            | Oppo F19     |
   | reno4_cph2113          | Oppo Reno4   |
   | reno5_cph2159          | Oppo Reno5   |
   | reno6_cph2235          | Oppo Reno6   |

   | Codename               | Description   |
   |:----------------------:|:-------------:|
   | realme7i_rmx2103       | Realme 7i     |
   | realme8pro_rmx3091     | Realme 8 Pro  |
   | realmec15_rmx2195      | Realme C15    |
   | realmec17_rmx2101      | Realme C17    |

#### Vivo:

   | Codename               | Description    |
   |:----------------------:|:--------------:|
   | vivo_y91               | Vivo Y91/i     |
   | vivo_y93               | Vivo Y93       |
   | vivo_y95               | Vivo Y95       |
   | vivo_v9                | Vivo V9        |
   | vivo_v9yth             | Vivo V9 Youth  |
   | vivo_v11pro            | Vivo V11 Pro   |

#### Xiaomi / Poco:

   | Codename               | Description              |
   |:----------------------:|:------------------------:|
   | mi8ee_ursa             | Xiaomi Mi 8 EE           |
   | mi8se_sirius           | Xiaomi Mi 8 SE           |
   | mi8ud_equuleus         | Xiaomi Mi 8 UD           |
   | mia2_jasmine           | Xiaomi Mi A2             |
   | mia2lite_daisy         | Xiaomi Mi A2 Lite        |
   | mimax2_chiron          | Xiaomi Mi Max 2          |
   | mimax3_nitrogen        | Xiaomi Mi Max 3          |
   | mimix_lithium          | Xiaomi Mi Mix            |
   | mimix2s_polaris        | Xiaomi Mi Mix 2s         |
   | mimix3_perseus         | Xiaomi Mi Mix 3          |
   | minote2_scorpio        | Xiaomi Mi Note 2         |
   | minote3_jason          | Xiaomi Mi Note 3         |
   | mipad4_clover          | Xiaomi Mi Pad 4          |
   | pocof1_beryllium       | Xiaomi Pocophone F1      |
   | redmi6pro_sakura       | Xiaomi Redmi 6 Pro       |
   | redmi7_onclite         | Xiaomi Redmi 7           |
   | note5_whyred           | Xiaomi Redmi Note 5      |
   | note5pro_whyred        | Xiaomi Redmi Note 5 Pro  |
   | note5a_ugglite         | Xiaomi Redmi Note 5a     |

#### Samsung:

   | Codename               | Description             |
   |:----------------------:|:-----------------------:|
   | sm_a015f               | Samsung Galaxy A01      |
   | sm_a025f               | Samsung Galaxy A02s     |
   | sm_a115a               | Samsung Galaxy A11      |
   | sm_a115f               | Samsung Galaxy A11      |
   | sm_a115u               | Samsung Galaxy A11      |
   | sm_a705f               | Samsung Galaxy A70      |
   | sm_j415f               | Samsung Galaxy J4 Plus  |
   | sm_j610f               | Samsung Galaxy J6 Plus  |
   | sm_m025f               | Samsung Galaxy M02s     |
   | sm_m115f               | Samsung Galaxy M11      |

### 1.0 revision 1

1. Fix code
1. Added feature:  ADB and Fastboot
1. Added feature:  Reboot to EDL

**Device update commited:**
#### Oppo / Realme:

   | Codename               | Description     |
   |:----------------------:|:---------------:|
   | a76_cph2375            | Oppo A76        |
   | f21pro_cph2219         | Oppo F21 Pro    |
   | reno4old_cph2113       | Oppo Reno4      |
   | reno4new_cph2113       | Oppo Reno4      |
   | reno4pro_cph2109       | Oppo Reno4 Pro  |
   | reno7_cph2363          | Oppo Reno7      |

   | Codename               | Description   |
   |:----------------------:|:-------------:|
   | realme6pro_rmx2061     | Realme 6 Pro  |
   | realme7pro_rmx2170     | Realme 7 Pro  |
   | realme9_rmx3521        | Realme 9      |

#### Vivo:

   | Codename               | Description   |
   |:----------------------:|:-------------:|
   | vivo_iq00              | Vivo IQ00 UI  |
   | vivo_y20_oldsec        | Vivo Y20      |
   | vivo_y20_newsec        | Vivo Y20      |
   | vivo_y50t              | Vivo Y50T     |
   | vivo_y53               | Vivo Y53      |
   | vivo_y55               | Vivo Y55/L    |
   | vivo_y65               | Vivo Y65      |
   | vivo_y71               | Vivo Y71      |
   | vivo_v20_newsec        | Vivo V20      |
   | vivo_v21e              | Vivo V21E     |

#### Xiaomi / Poco:

   | Codename               | Description              |
   |:----------------------:|:------------------------:|
   | mi9t_raphael           | Xiaomi Mi 9T             |
   | mi10lite_toco          | Xiaomi Mi 10 Lite        |
   | mi11tpro_vili          | Xiaomi 11T Pro           |
   | pocom2pro_gramin       | Xiaomi Pocophone M2 Pro  |
   | pocom3_citrus          | Xiaomi Pocophone M3      |
   | redmi5a_riva           | Xiaomi Redmi 5A          |
   | redmi9t_lime           | Xiaomi Redmi 9T          |
   | redmik20pro_raphael    | Xiaomi Redmi K20 Pro     |
   | note6pro_tulip         | Xiaomi Redmi Note 6 Pro  |
   | note8_ginkgo           | Xiaomi Redmi Note 8      |
   | note9s_curtana         | Xiaomi Redmi Note 9S     |
   | note9pro_joyeuse       | Xiaomi Redmi Note 9 Pro  |
