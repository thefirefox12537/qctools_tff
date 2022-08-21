import os
import platform
import subprocess

if platform.system() == "Windows":
	adb_program = "..\\data\\adb.exe"
	fastboot_program = "..\\data\\fastboot.exe"
else:
	adb_program = "../data/adb"
	fastboot_program = "../data/fastboot"

if not os.path.exists(adb_program):
	adb_program = "adb"
if not os.path.exists(fastboot_program):
	fastboot_program = "fastboot"


def rebootrecovery_fastboot(port):
    print("Rebooting to recovery...", end = "")
    try:
        reboot_recovery = \
            [fastboot_program, "-s", port, "reboot-recovery"] \
            if platform.system() == "Windows" else \
            [fastboot_program + " -s " + port + " reboot-recovery"]

        subprocess.call(reboot_recovery, shell=True)
        print("  [OK]")
    except:
        print("  [ERROR]")
        return 1

def rebootbl_fastboot(port):
    print("Rebooting to bootloader...", end = "")
    try:
        reboot_bootloader = \
            [fastboot_program, "-s", port, "reboot-bootloader"] \
            if platform.system() == "Windows" else \
            [fastboot_program + " -s " + port + " reboot-bootloader"]

        subprocess.call(reboot_bootloader, shell=True)
        print("  [OK]")
    except:
        print("  [ERROR]")
        return 1

def rebootedl_fastboot_oem(port):
    print("Rebooting to EDL mode...", end = "")
    try:
        reboot_edl = \
            [fastboot_program, "-s", port, "oem", "edl"] \
            if platform.system() == "Windows" else \
            [fastboot_program + " -s " + port + " oem edl"]

        subprocess.call(reboot_edl, shell=True)
        print("  [OK]")
    except:
        print("  [ERROR]")
        return 1

def rebootedl_fastboot(port):
    print("Rebooting to EDL mode...", end = "")
    try:
        reboot_edl = \
            [fastboot_program, "-s", port, "reboot-edl"] \
            if platform.system() == "Windows" else \
            [fastboot_program + " -s " + port + " reboot-edl"]

        subprocess.call(reboot_edl, shell=True)
        print("  [OK]")
    except:
        print("  [ERROR]")
        return 1

def rebootrecovery_adb(port):
    print("Rebooting to recovery...", end = "")
    try:
        reboot_recovery = \
            [adb_program, "-s", port, "reboot", "recovery"] \
            if platform.system() == "Windows" else \
            [adb_program + " -s " + port + " reboot recovery"]

        subprocess.call(reboot_recovery, shell=True)
        print("  [OK]")
    except:
        print("  [ERROR]")
        return 1

def rebootbl_adb(port):
    print("Rebooting to bootloader...", end = "")
    try:
        reboot_bootloader = \
            [adb_program, "-s", port, "reboot", "bootloader"] \
            if platform.system() == "Windows" else \
            [adb_program + " -s " + port + " reboot bootloader"]

        subprocess.call(reboot_bootloader, shell=True)
        print("  [OK]")
    except:
        print("  [ERROR]")
        return 1

def rebootedl_adb(port):
    print("Rebooting to EDL mode...", end = "")
    try:
        reboot_edl = \
            [adb_program, "-s", port, "reboot", "edl"] \
            if platform.system() == "Windows" else \
            [adb_program + " -s " + port + " reboot edl"]

        subprocess.call(reboot_edl, shell=True)
        print("  [OK]")
    except:
        print("  [ERROR]")
        return 1

