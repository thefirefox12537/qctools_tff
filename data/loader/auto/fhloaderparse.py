#!/usr/bin/env python3
import os
import sys
from os import walk
import hashlib
from struct import unpack, pack
from shutil import copyfile
import os, sys, inspect
current_dir = os.path.dirname(os.path.abspath(inspect.getfile(inspect.currentframe())))
parent_dir = os.path.dirname(current_dir)
sys.path.insert(0, parent_dir)
from edl.Library.utils import elf
from edl.Library.sahara import convertmsmid
from edl.Config.qualcomm_config import vendor

class MBN:
    def __init__(self, memory):
        self.imageid, self.flashpartitionversion, self.imagesrc, self.loadaddr, self.imagesz, self.codesz, \
        self.sigptr, self.sigsz, self.certptr, self.certsz = unpack("<IIIIIIIIII", memory[0xC:0xC + 40])


class Signed:
    filename = ''
    filesize = 0
    oem_id = ''
    model_id = ''
    hw_id = ''
    sw_id = ''
    app_id = ''
    sw_size = ''
    qc_version = ''
    image_variant = ''
    oem_version = ''
    pk_hash = ''
    hash = b''


def grabtext(data):
    i = len(data)
    j = 0
    text = ''
    while i > 0:
        if data[j] == 0:
            break
        text += chr(data[j])
        j += 1
        i -= 1
    return text


def extract_hdr(memsection, sign_info, mem_section, code_size, signature_size):
    try:
        md_size = \
            unpack("<I", mem_section[memsection.file_start_addr + 0x2C:memsection.file_start_addr + 0x2C + 0x4])[0]
        md_offset = memsection.file_start_addr + 0x2C + 0x4
        major, minor, sw_id, hw_id, oem_id, model_id, app_id = unpack("<IIIIIII",
                                                                      mem_section[md_offset:md_offset + (7 * 4)])
        sign_info.hw_id = "%08X" % hw_id
        sign_info.sw_id = "%08X" % sw_id
        sign_info.oem_id = "%04X" % oem_id

        sign_info.model_id = "%04X" % model_id
        sign_info.hw_id += sign_info.oem_id + sign_info.model_id
        sign_info.app_id = "%08X" % app_id
        md_offset += (7 * 4)

        # v=unpack("<I", mem_section[md_offset:md_offset + 4])[0]
        '''
        rot_en=(v >> 0) & 1
        in_use_soc_hw_version=(v >> 1) & 1
        use_serial_number_in_signing=(v >> 2) & 1
        oem_id_independent=(v >> 3) & 1
        root_revoke_activate_enable=(v >> 4) & 0b11
        uie_key_switch_enable=(v >> 6) & 0b11
        debug=(v >> 8) & 0b11
        md_offset+=4
        soc_vers=hexlify(mm[md_offset:md_offset + (12*4)])
        md_offset+=12*4
        multi_serial_numbers=hexlify(mm[md_offset:md_offset + (8*4)])
        md_offset += 8 * 4
        mrc_index=unpack("<I", mm[md_offset:md_offset + 4])[0]
        md_offset+=4
        anti_rollback_version=unpack("<I", mm[md_offset:md_offset + 4])[0]
        '''

        signatureoffset = memsection.file_start_addr + 0x30 + md_size + code_size + signature_size
        try:
            if mem_section[signatureoffset] != 0x30:
                print("Error on " + sign_info.filename + ", unknown signaturelength")
                return None
        except:
            return None
        if len(mem_section) < signatureoffset + 4:
            print("Signature error on " + sign_info.filename)
            return None
        len1 = unpack(">H", mem_section[signatureoffset + 2:signatureoffset + 4])[0] + 4
        casignature2offset = signatureoffset + len1
        len2 = unpack(">H", mem_section[casignature2offset + 2:casignature2offset + 4])[0] + 4
        rootsignature3offset = casignature2offset + len2
        len3 = unpack(">H", mem_section[rootsignature3offset + 2:rootsignature3offset + 4])[0] + 4
        sign_info.pk_hash = hashlib.sha384(mem_section[rootsignature3offset:rootsignature3offset + len3]).hexdigest()
    except:
        return None
    return sign_info


def extract_old_hdr(signatureoffset, sign_info, mem_section, code_size, signature_size):
    signature = {}
    if mem_section[signatureoffset] != 0x30:
        print("Error on " + sign_info.filename + ", unknown signaturelength")
        return None
    if signatureoffset != -1:
        if len(mem_section) < signatureoffset + 4:
            print("Signature error on " + sign_info.filename)
            return None
        len1 = unpack(">H", mem_section[signatureoffset + 2:signatureoffset + 4])[0] + 4
        casignature2offset = signatureoffset + len1
        len2 = unpack(">H", mem_section[casignature2offset + 2:casignature2offset + 4])[0] + 4
        rootsignature3offset = casignature2offset + len2
        len3 = unpack(">H", mem_section[rootsignature3offset + 2:rootsignature3offset + 4])[0] + 4
        sign_info.pk_hash = hashlib.sha256(mem_section[rootsignature3offset:rootsignature3offset + len3]).hexdigest()
        idx = signatureoffset

        while idx != -1:
            if idx >= len(mem_section):
                break
            idx = mem_section.find('\x04\x0B'.encode(), idx)
            if idx == -1:
                break
            length = mem_section[idx + 3]
            if length > 60:
                idx += 1
                continue
            try:
                text = mem_section[idx + 4:idx + 4 + length].decode().split(' ')
                signature[text[2]] = text[1]
            except:
                text = ""
            idx += 1
        idx = mem_section.find('QC_IMAGE_VERSION_STRING='.encode(), 0)
        if idx != -1:
            sign_info.qc_version = grabtext(mem_section[idx + len("QC_IMAGE_VERSION_STRING="):])
        idx = mem_section.find('OEM_IMAGE_VERSION_STRING='.encode(), 0)
        if idx != -1:
            sign_info.oem_version = grabtext(mem_section[idx + len("OEM_IMAGE_VERSION_STRING="):])
        idx = mem_section.find('IMAGE_VARIANT_STRING='.encode(), 0)
        if idx != -1:
            sign_info.image_variant = grabtext(mem_section[idx + len("IMAGE_VARIANT_STRING="):])
        if "MODEL_ID" in signature:
            sign_info.model_id = signature["MODEL_ID"]
        if "OEM_ID" in signature:
            sign_info.oem_id = signature["OEM_ID"]
        if "HW_ID" in signature:
            sign_info.hw_id = signature["HW_ID"]
        if "SW_ID" in signature:
            sign_info.sw_id = signature["SW_ID"]
        if "SW_SIZE" in signature:
            sign_info.sw_size = signature["SW_SIZE"]
    return sign_info


def init_loader_db():
    loaderdb = {}
    for (dirpath, dirnames, filenames) in os.walk(current_dir):
        for filename in filenames:
            file_name = os.path.join(dirpath, filename)
            found = False
            for ext in [".bin", ".mbn", ".elf", ""]:
                if ext in filename[-4:]:
                    found = True
                    break
            if not found:
                continue
            try:
                hwid = filename.split("_")[0].lower()
                msmid = hwid[:8]
                devid = hwid[8:]
                pkhash = filename.split("_")[1].lower()
                msmdb = convertmsmid(msmid)
                for msmid in msmdb:
                    mhwid = (msmid + devid).lower()
                    if mhwid not in loaderdb:
                        loaderdb[mhwid] = {}
                    if pkhash not in loaderdb[mhwid]:
                        loaderdb[mhwid][pkhash] = file_name
                    else:
                        loaderdb[mhwid][pkhash].append(file_name)
            except:
                continue
    return loaderdb


def is_duplicate(loaderdb, sign_info):
    lhash = sign_info.pk_hash[:16].lower()
    msmid = sign_info.hw_id[:8].lower()
    devid = sign_info.hw_id[8:].lower()
    hwid = sign_info.hw_id.lower()
    for msmid in convertmsmid(msmid):
        rid = (msmid + devid).lower()
        if hwid in loaderdb:
            loader = loaderdb[hwid]
            if lhash in loader:
                return True
        if rid in loaderdb:
            loader = loaderdb[rid]
            if lhash in loader:
                return True
    return False


def main(argv):
    file_list = []
    path = ""
    if len(argv) < 3:
        print("Usage: ./fhloaderparse.py [FHLoaderDir] [OutputDir]")
        exit(0)
    else:
        path = argv[1]
        outputdir = argv[2]
        if not os.path.exists(outputdir):
            os.mkdir(outputdir)

    # First hash all loaders in Loader directory
    hashes = {}
    loaderdb = init_loader_db()
    for mhwid in loaderdb:
        for pkhash in loaderdb[mhwid]:
            fname = loaderdb[mhwid][pkhash]
            with open(fname, 'rb') as rhandle:
                data = rhandle.read()
                sha256 = hashlib.sha256()
                sha256.update(data)
                hashes[sha256.digest()] = fname

    # Now lets hash all files in the output directory
    for (dirpath, dirnames, filenames) in walk(outputdir):
        for filename in filenames:
            fname = os.path.join(dirpath, filename)
            with open(fname, 'rb') as rhandle:
                data = rhandle.read()
                sha256 = hashlib.sha256()
                sha256.update(data)
                hashes[sha256.digest()] = fname

    # Now lets search the input path for loaders
    extensions = ["txt", "idb", "i64", "py"]
    for (dirpath, dirnames, filenames) in walk(path):
        for filename in filenames:
            basename = os.path.basename(filename).lower()
            ext = basename[basename.rfind(".") + 1:]
            if ext not in extensions:
                file_list.append(os.path.join(dirpath, filename))

    if not os.path.exists(os.path.join(outputdir, "Unknown")):
        os.makedirs(os.path.join(outputdir, "Unknown"))
    if not os.path.exists(os.path.join(outputdir, "Duplicate")):
        os.mkdir(os.path.join(outputdir, "Duplicate"))

    # Lets hash all the input files and extract the signature
    filelist = []
    rt = open(os.path.join(outputdir, argv[1] + ".log"), "w")
    for filename in file_list:
        with open(filename, 'rb') as rhandle:
            mem_section = rhandle.read()
            sha256 = hashlib.sha256()
            sha256.update(mem_section)

            signinfo = Signed()
            signinfo.hash = sha256.digest()
            signinfo.filename = filename
            signinfo.filesize = os.stat(filename).st_size
            if len(mem_section) < 4:
                continue
            hdr = unpack("<I", mem_section[0:4])[0]

            if hdr == 0x464C457F:
                elfheader = elf(mem_section, signinfo.filename)
                if 'memorylayout' in dir(elfheader):
                    memsection = elfheader.memorylayout[1]
                    try:
                        version = unpack("<I", mem_section[
                                               memsection.file_start_addr + 0x04:memsection.file_start_addr + 0x04 + 0x4])[
                            0]
                        code_size = \
                            unpack("<I", mem_section[
                                         memsection.file_start_addr + 0x14:memsection.file_start_addr + 0x14 + 0x4])[
                                0]
                        signature_size = \
                            unpack("<I", mem_section[
                                         memsection.file_start_addr + 0x1C:memsection.file_start_addr + 0x1C + 0x4])[
                                0]
                        # cert_chain_size=unpack("<I", mem_section[memsection.file_start_addr + 0x24:memsection.file_start_addr + 0x24 + 0x4])[0]
                    except:
                        continue
                    if signature_size == 0:
                        print("%s has no signature." % filename)
                        copyfile(filename,
                                 os.path.join(outputdir, "Unknown", filename[filename.rfind("/") + 1:].lower()))
                        continue
                    if version < 6:  # MSM,MDM
                        signatureoffset = memsection.file_start_addr + 0x28 + code_size + signature_size
                        signinfo = extract_old_hdr(signatureoffset, signinfo, mem_section, code_size, signature_size)
                        if signinfo is None:
                            continue
                        filelist.append(signinfo)
                    elif version >= 6:  # SDM
                        signinfo = extract_hdr(memsection, signinfo, mem_section, code_size, signature_size)
                        if signinfo is None:
                            continue
                        filelist.append(signinfo)
                    else:
                        print("Unknown version for " + filename)
                        continue
            elif hdr == 0x844BDCD1:
                mbn = MBN(mem_section)
                if mbn.sigsz == 0:
                    print("%s has no signature." % filename)
                    copyfile(filename, os.path.join(outputdir, "Unknown", filename[filename.rfind("/") + 1:].lower()))
                    continue
                signatureoffset = mbn.imagesrc + mbn.codesz + mbn.sigsz
                signinfo = extract_old_hdr(signatureoffset, signinfo, mem_section, mbn.codesz, mbn.sigsz)
                if signinfo is None:
                    continue
                filelist.append(signinfo)
            else:
                print("Error on " + filename)
                continue

    sorted_x = sorted(filelist, key=lambda x: (x.hw_id, -x.filesize))

    class loaderinfo:
        hw_id = ''
        item = ''

    loaderlists = {}
    for item in sorted_x:
        if item.oem_id != '':
            oemid=int(item.oem_id,16)
            if oemid in vendor:
                oeminfo = vendor[oemid]
            else:
                oeminfo=item.oem_id
            if len(item.sw_id)<16:
                item.sw_id="0"*(16-len(item.sw_id))+item.sw_id
            info = f"OEM:{oeminfo}\tMODEL:{item.model_id}\tHWID:{item.hw_id}\tSWID:{item.sw_id}\tSWSIZE:{item.sw_size}\tPK_HASH:{item.pk_hash}\t{item.filename}\t{str(item.filesize)}"
            if item.oem_version != '':
                info += "\tOEMVER:" + item.oem_version + "\tQCVER:" + item.qc_version + "\tVAR:" + item.image_variant
            loader_info = loaderinfo()
            loader_info.hw_id = item.hw_id
            loader_info.pk_hash = item.pk_hash
            if item.hash not in hashes:
                if loader_info not in loaderlists:
                    if not is_duplicate(loaderdb, item):
                        loaderlists[loader_info] = item.filename
                        print(info)
                        msmid = loader_info.hw_id[:8]
                        devid = loader_info.hw_id[8:]
                        for msmid in convertmsmid(msmid):
                            hwid = (msmid + devid).lower()
                            auth = ""
                            with open(item.filename, "rb") as rf:
                                data = rf.read()
                                if b"sig tag can" in data:
                                    auth = "_EDLAuth"
                                if b"peek\x00" in data:
                                    auth += "_peek"
                            fna = os.path.join(outputdir, (
                                        hwid + "_" + loader_info.pk_hash[0:16] + "_FHPRG" + auth + ".bin").lower())
                            if not os.path.exists(fna):
                                copyfile(item.filename,
                                         os.path.join(outputdir, hwid + "_" + (
                                                     loader_info.pk_hash[0:16] + "_FHPRG" + auth + ".bin").lower()))
                            elif item.filesize > os.stat(fna).st_size:
                                copyfile(item.filename, os.path.join(outputdir,
                                                                     (hwid + "_" + loader_info.pk_hash[
                                                                                   0:16] + "_FHPRG" + auth + ".bin").lower()))
                    else:
                        print("Duplicate: " + info)
                        copyfile(item.filename, os.path.join(outputdir, "Duplicate",
                                                             (loader_info.hw_id + "_" + loader_info.pk_hash[
                                                                                        0:16] + "_FHPRG.bin").lower()))
                else:
                    copyfile(item.filename, os.path.join(outputdir, "Unknown", os.path.basename(item.filename).lower()))
            else:
                copyfile(item.filename,
                         os.path.join(outputdir, "Duplicate",
                                      (loader_info.hw_id + "_" + loader_info.pk_hash[0:16] + "_FHPRG.bin").lower()))
                print(item.filename + " does already exist. Skipping")
            try:
                rt.write(info + "\n")
            except:
                continue
        else:
            print("Unknown :"+item.filename)
            copyfile(item.filename, os.path.join(outputdir, "Unknown", os.path.basename(item.filename).lower()))

    for item in filelist:
        if item.oem_id == '' and (".bin" in item.filename or ".mbn" in item.filename or ".hex" in item.filename):
            info = "Unsigned:" + item.filename + "\t" + str(item.filesize)
            if item.oem_version != '':
                info += "\tOEMVER:" + item.oem_version + "\tQCVER:" + item.qc_version + "\tVAR:" + item.image_variant
            print(info)
            rt.write(info + "\n")
            if not os.path.exists(os.path.join(outputdir, "Unknown", item.filename)):
                copyfile(item.filename,
                         os.path.join(outputdir, "Unknown", os.path.basename(item.filename).lower()))

    rt.close()


main(sys.argv)
