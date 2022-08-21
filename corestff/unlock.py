import os
import platform
import re
import requests
import subprocess
import shutil
import ssl

ssl._create_default_https_context = ssl._create_unverified_context

if platform.system() == "Windows":
	adb_program = "..\\data\\adb.exe"
	emmcdl_program = "..\\data\\emmcdl.exe"
	fastboot_program = "..\\data\\fastboot.exe"
else:
	adb_program = "../data/adb"
	emmcdl_program = "../data/emmcdl"
	fastboot_program = "../data/fastboot"

if not os.path.exists(adb_program):
	adb_program = "adb"
if not os.path.exists(fastboot_program):
	fastboot_program = "fastboot"
if not os.path.exists(emmcdl_program):
	emmcdl_program = "emmcdl"


def userdata(port, firehose_loader, storage):
    print("Erasing all data...", end = "")
    try:
        erase_userdata = \
            [emmcdl_program, "-p", port, "-f", firehose_loader, "-e", "userdata", "-memoryname", storage] \
            if platform.system() == "Windows" else \
            [emmcdl_program + " -p " + port + " -f " + firehose_loader + " -e userdata -memoryname " + storage]

        subprocess.call(erase_userdata, shell=True)
        print("  [OK]")
    except:
        print("  [ERROR]")
        return

def safe_storage(port, firehose_loader, storage):
    print("Getting GPT partition...", end = "")
    try:
        partitionxml = open(log_path + "/partition.xml", "w")
        check_gpt = \
            [emmcdl_program, "-p", port, "-f", firehose_loader, "-gpt", "-memoryname", storage] \
            if platform.system() == "Windows" else \
            [emmcdl_program + " -p " + port + " -f " + firehose_loader + " -gpt -memoryname " + storage]

        subprocess.call(check_gpt, stdout = partitionxml, stderr = subprocess.DEVNULL)
        print("  [OK]")
    except:
        print("  [ERROR]")
        return

    xml_path = currentdir + "/data/xml"
    patchxml = "/patch.xml"
    if os.path.exists(xml_path + patchxml):
        shutil.copyfile(xml_path + patchxml, log_path + patchxml)
        patchxml = log_path + patchxml
    else:
        repo_patch = repos + "/raw/additional/data/xml/patch.xml"
        request.urlretrieve(repo_patch, temp_path + patchxml)
        patchxml = temp_path + patchxml

    for lines in open(partitionxml).readlines():
        if re.search("SECTOR_SIZE_IN_BYTES=", lines):
            sector_size = re.findall(".*SECTOR_SIZE_IN_BYTES=\"([0-9]*)\".*", lines)[0]
        if re.search("misc", lines):
            lba_size = re.findall(".*Start LBA:.([0-9]*).*", lines)[0]

    with open(patchxml, "r+") as newfile:
        text = newfile.read()
        text = re.sub("(SECTOR_SIZE_IN_BYTES=)\".*?\"(.*>)", r'\1"' + sector_size + r'"\2', text)
        text = re.sub("(start_sector=)\".*?\"(.*>)", r'\1"' + lba_size + r'"\2', text)
        newfile.seek(0)
        newfile.write(text)
        newfile.truncate()

    print("Erasing userdata without losing internal storage...", end = "")
    try:
        safe_storage = \
            [emmcdl_program, "-p", port, "-f", firehose_loader, "-x", patchxml, "-memoryname", storage] \
            if platform.system() == "Windows" else \
            [emmcdl_program + " -p " + port + " -f " + firehose_loader + " -x ", patchxml, " -memoryname " + storage]

        subprocess.call(safe_storage, shell=True)
        print("  [OK]")
    except:
        print("  [ERROR]")
        return

def frp(port, firehose_loader, storage, partition):
    print("Resetting FRP...", end = "")
    try:
        erase_frp = \
            [emmcdl_program, "-p", port, "-f", firehose_loader, "-e", partition, "-memoryname", storage] \
            if platform.system() == "Windows" else \
            [emmcdl_program + " -p " + port + " -f " + firehose_loader + " -e " + partition + " -memoryname " + storage]

        subprocess.call(erase_frp, shell=True)
        print("  [OK]")
    except:
        print("  [ERROR]")
        return

def efs(port, firehose_loader, storage):
    print("Backing up EFS IMEI...", end = "")
    try:
        for partition in ["fsg", "modemst1", "modemst2"]:
            backup_file = temp_path + "/" + datetime.now().strftime("%d%m%Y_%H%M%S") + "_" + partition + ".img"
            backup_efs = \
                [emmcdl_program, "-p", port, "-f", firehose_loader, "-d", partition, "-o", backup_file, "-memoryname", storage] \
                if platform.system() == "Windows" else \
                [emmcdl_program + " -p " + port + " -f " + firehose_loader + " -d " + partition + " -o " + backup_file + " -memoryname " + storage]

            subprocess.call(backup_efs, shell=True)
        print("  [OK]")
    except:
        print("  [ERROR]")
        return

    print("Resetting EFS IMEI...", end = "")
    try:
        for partition in ["fsg", "modemst1", "modemst2"]:
            erase_efs = \
                [emmcdl_program, "-p", port, "-f", firehose_loader, "-e", partition, "-memoryname", storage] \
                if platform.system() == "Windows" else \
                [emmcdl_program + " -p " + port + " -f " + firehose_loader + " -e " + partition + " -memoryname " + storage]

            subprocess.call(erase_efs, shell=True)
        print("  [OK]")
    except:
        print("  [ERROR]")
        return

def unlock_bl(port, firehose_loader, storage, brand_name):
    print("Getting GPT partition...", end = "")
    try:
        partitionxml = open(log_path + "/partition.xml", "w")
        check_gpt = \
            [emmcdl_program, "-p", port, "-f", firehose_loader, "-gpt", "-memoryname", storage] \
            if platform.system() == "Windows" else \
            [emmcdl_program + " -p " + port + " -f " + firehose_loader + " -gpt -memoryname " + storage]

        subprocess.call(check_gpt, stdout = partitionxml, stderr = subprocess.DEVNULL)
        print("  [OK]")
    except:
        print("  [ERROR]")
        return

    xml_path = currentdir + "/data/xml"
    old_patchxml = "/" + brand_name + "-unlock-bl-patch.xml"
    patchxml = "/patch.xml"
    if os.path.exists(xml_path + old_patchxml):
        shutil.copyfile(xml_path + old_patchxml, log_path + patchxml)
        patchxml = log_path + patchxml
    else:
        repo_patch = repos + "/raw/additional/data/xml/" + brand_name + "-unlock-bl-patch.xml"
        request.urlretrieve(repo_patch, temp_path + patchxml)
        patchxml = temp_path + patchxml

    for lines in open(partitionxml).readlines():
        if re.search("SECTOR_SIZE_IN_BYTES=", lines):
            sector_size = re.findall(".*SECTOR_SIZE_IN_BYTES=\"([0-9]*)\".*", lines)[0]
        if re.search("devinfo", lines):
            lba_size = re.findall(".*Start LBA:.([0-9]*).*", lines)[0]

    with open(patchxml, "r+") as newfile:
        text = newfile.read()
        text = re.sub("(SECTOR_SIZE_IN_BYTES=)\".*?\"(.*>)", r'\1"' + sector_size + r'"\2', text)
        text = re.sub("(start_sector=)\".*?\"(.*>)", r'\1"' + lba_size + r'"\2', text)
        newfile.seek(0)
        newfile.write(text)
        newfile.truncate()

    print("Unlocking Bootloader...", end = "")
    try:
        unlock_bootloader = \
            [emmcdl_program, "-p", port, "-f", firehose_loader, "-x", patchxml, "-memoryname", storage] \
            if platform.system() == "Windows" else \
            [emmcdl_program + " -p " + port + " -f " + firehose_loader + " -x ", patchxml, " -memoryname " + storage]

        subprocess.call(unlock_bootloader, shell=True)
        print("  [OK]")
    except:
        print("  [ERROR]")
        return

def relock_bl(port, firehose_loader, storage, brand_name):
    print("Getting GPT partition...", end = "")
    try:
        partitionxml = open(log_path + "/partition.xml", "w")
        check_gpt = \
            [emmcdl_program, "-p", port, "-f", firehose_loader, "-gpt", "-memoryname", storage] \
            if platform.system() == "Windows" else \
            [emmcdl_program + " -p " + port + " -f " + firehose_loader + " -gpt -memoryname " + storage]

        subprocess.call(check_gpt, stdout = partitionxml, stderr = subprocess.DEVNULL)
        print("  [OK]")
    except:
        print("  [ERROR]")
        return

    xml_path = currentdir + "/data/xml"
    old_patchxml = "/" + brand_name + "-relock-bl-patch.xml"
    patchxml = "/patch.xml"
    if os.path.exists(xml_path + old_patchxml):
        shutil.copyfile(xml_path + old_patchxml, log_path + patchxml)
        patchxml = log_path + patchxml
    else:
        repo_patch = repos + "/raw/additional/data/xml/" + brand_name + "-relock-bl-patch.xml"
        request.urlretrieve(repo_patch, temp_path + patchxml)
        patchxml = temp_path + patchxml

    for lines in open(partitionxml).readlines():
        if re.search("SECTOR_SIZE_IN_BYTES=", lines):
            sector_size = re.findall(".*SECTOR_SIZE_IN_BYTES=\"([0-9]*)\".*", lines)[0]
        if re.search("devinfo", lines):
            lba_size = re.findall(".*Start LBA:.([0-9]*).*", lines)[0]

    with open(patchxml, "r+") as newfile:
        text = newfile.read()
        text = re.sub("(SECTOR_SIZE_IN_BYTES=)\".*?\"(.*>)", r'\1"' + sector_size + r'"\2', text)
        text = re.sub("(start_sector=)\".*?\"(.*>)", r'\1"' + lba_size + r'"\2', text)
        newfile.seek(0)
        newfile.write(text)
        newfile.truncate()

    print("Backing up devinfo...", end = "")
    try:
        backup_file = temp_path + "/" + datetime.now().strftime("%d%m%Y_%H%M%S") + "_devinfo.img"
        backup_devinfo = \
            [emmcdl_program, "-p", port, "-f", firehose_loader, "-d", "devinfo", "-o", backup_file, "-memoryname", storage] \
            if platform.system() == "Windows" else \
            [emmcdl_program + " -p " + port + " -f " + firehose_loader + " -d devinfo -o " + backup_file + " -memoryname " + storage]

        subprocess.call(backup_devinfo, shell=True)
        print("  [OK]")
    except:
        print("  [ERROR]")
        return
    print("Locking Bootloader...", end = "")
    try:
        lock_bootloader = \
            [emmcdl_program, "-p", port, "-f", firehose_loader, "-x", patchxml, "-memoryname", storage] \
            if platform.system() == "Windows" else \
            [emmcdl_program + " -p " + port + " -f " + firehose_loader + " -x ", patchxml, " -memoryname " + storage]

        subprocess.call(lock_bootloader, shell=True)
        print("  [OK]")
    except:
        print("  [ERROR]")
        return


def micloud(port, firehose_loader, storage):
    print("Backing up persist and persistbak...", end = "")
    try:
        for partition in ["persist", "persistbak"]:
            backup_file = temp_path + "/" + datetime.now().strftime("%d%m%Y_%H%M%S") + "_" + partition + ".img"
            backup_persist = \
                [emmcdl_program, "-p", port, "-f", firehose_loader, "-d", partition, "-o", backup_file, "-memoryname", storage] \
                if platform.system() == "Windows" else \
                [emmcdl_program + " -p " + port + " -f " + firehose_loader + " -d " + partition + " -o " + backup_file + " -memoryname " + storage]

            subprocess.call(backup_persist, shell=True)
        print("  [OK]")
    except:
        print("  [ERROR]")
        return

    print("Resetting MiCloud...", end = "")
    try:
        for partition in ["persist", "persistbak"]:
            erase_persist = \
                [emmcdl_program, "-p", port, "-f", firehose_loader, "-e", partition, "-memoryname", storage] \
                if platform.system() == "Windows" else \
                [emmcdl_program + " -p " + port + " -f " + firehose_loader + " -e " + partition + " -memoryname " + storage]

            subprocess.call(erase_persist, shell=True)
        print("  [OK]")
    except:
        print("  [ERROR]")
        return



def fastboot_unlock_bl_oem(port):
    print("Unlocking bootloader...", end = "")
    try:
        fastboot_oem_unlock = \
            [fastboot_program, "-s", port, "oem", "unlock"] \
            if platform.system() == "Windows" else \
            [fastboot_program + " -s " + port + " oem unlock"]

        subprocess.call(fastboot_oem_unlock, shell=True)
        print("  [OK]")
    except:
        print("  [ERROR]")
        return

def fastboot_unlock_bl_flashing(port):
    print("Unlocking bootloader...", end = "")
    try:
        fastboot_oem_unlock = \
            [fastboot_program, "-s", port, "flashing", "unlock"] \
            if platform.system() == "Windows" else \
            [fastboot_program + " -s " + port + " flashing unlock"]

        subprocess.call(fastboot_oem_unlock, shell=True)
        print("  [OK]")
    except:
        print("  [ERROR]")
        return

def fastboot_lock_bl_oem(port):
    print("Locking bootloader...", end = "")
    try:
        fastboot_oem_lock = \
            [fastboot_program, "-s", port, "oem", "lock"] \
            if platform.system() == "Windows" else \
            [fastboot_program + " -s " + port + " oem lock"]

        subprocess.call(fastboot_oem_lock, shell=True)
        print("  [OK]")
    except:
        print("  [ERROR]")
        return

def fastboot_unlock_bl_flashing(port):
    print("Locking bootloader...", end = "")
    try:
        fastboot_oem_lock = \
            [fastboot_program, "-s", port, "flashing", "lock"] \
            if platform.system() == "Windows" else \
            [fastboot_program + " -s " + port + " flashing lock"]

        subprocess.call(fastboot_oem_lock, shell=True)
        print("  [OK]")
    except:
        print("  [ERROR]")
        return

def erasefrp_fastboot(port):
    pass

def demo_fastboot_1(port):
    pass

def demo_fastboot_2(port):
    pass

def bypassfrp_samadb(port):
    print("Resetting FRP...", end = "")
    try:
        adb_am = \
            [adb_program, "-s", port, "shell", "am", "start", "-n"] \
            if platform.system() == "Windows" else \
            [adb_program + " -s " + port + " shell am start -n"]

        for pkg in ["com.google.android.gsf.login/", "com.google.android.gsf.login.LoginActivity"]:
            reset_frp = adb_am + [pkg]
            subprocess.call(reset_frp, shell=True)

        reset_frp = \
            [adb_program, "-s", port, "shell", "content", "insert", "--uri", "content://settings/secure", "--bind", "name:s:user_setup_complete", "--bind", "value:s:1"] \
            if platform.system() == "Windows" else \
            [adb_program + " -s " + port + " shell content insert --uri content://settings/secure --bind name:s:user_setup_complete --bind value:s:1"]

        subprocess.call(reset_frp, shell=True)
        print("  [OK]")
    except:
        print("  [ERROR]")
        return

def adb_erasefrp(port):
    pass

def adb_pushfrp(port):
    pass

def oppo_demo(port):
    pass
