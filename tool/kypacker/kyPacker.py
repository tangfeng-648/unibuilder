import hashlib
import os
import struct
from datetime import datetime
from dataclasses import dataclass
import argparse
import re

# python_ver < 3.9
from typing import Type, Tuple, Dict

# ______________________________________________________________________________
# PS:
# 处理大文件时，纯python实现，相当耗时，最好转换成动态库。
#
# (1) `cat rkcrc32.cpp`
#
# #include <stdint.h>
#
# extern "C" {
#     uint32_t rkcrc_crc32(const unsigned char *data, int length, uint32_t crc);
# }
#
# uint32_t _crc32_table[256] = {...};
#
# uint32_t rkcrc_crc32(const unsigned char *data, int length, uint32_t crc) {
#     crc = crc & 0xFFFFFFFF;
#     for (int i = 0; i < length; i++) {
#         crc = _crc32_table[data[i] ^ (crc >> 24)] ^ ((crc << 8) & 0xFFFFFFFF);
#     }
#     return crc & 0xFFFFFFFF;
# }
#
# (2) `g++ -shared -o librkcrc32.so -fPIC rkcrc32.cpp`
#
#

if os.path.isfile("./librkcrc32.so"):
    import ctypes

    lib = ctypes.CDLL("./librkcrc32.so")

    def rkcrc_crc32_so(data: bytes, crc: int = 0) -> int:
        return lib.rkcrc_crc32(bytes(data), len(data), crc) & 0xFFFFFFFF

    rkcrc_crc32 = rkcrc_crc32_so

    print("Use python --> so  rk_crc32!")
else:
    # fmt: off
    _crc32_table = [
        0x00000000, 0x04c10db7, 0x09821b6e, 0x0d4316d9, 0x130436dc, 0x17c53b6b, 0x1a862db2, 0x1e472005,
        0x26086db8, 0x22c9600f, 0x2f8a76d6, 0x2b4b7b61, 0x350c5b64, 0x31cd56d3, 0x3c8e400a, 0x384f4dbd,
        0x4c10db70, 0x48d1d6c7, 0x4592c01e, 0x4153cda9, 0x5f14edac, 0x5bd5e01b, 0x5696f6c2, 0x5257fb75,
        0x6a18b6c8, 0x6ed9bb7f, 0x639aada6, 0x675ba011, 0x791c8014, 0x7ddd8da3, 0x709e9b7a, 0x745f96cd,
        0x9821b6e0, 0x9ce0bb57, 0x91a3ad8e, 0x9562a039, 0x8b25803c, 0x8fe48d8b, 0x82a79b52, 0x866696e5,
        0xbe29db58, 0xbae8d6ef, 0xb7abc036, 0xb36acd81,	0xad2ded84, 0xa9ece033, 0xa4aff6ea, 0xa06efb5d,
        0xd4316d90, 0xd0f06027, 0xddb376fe, 0xd9727b49,	0xc7355b4c, 0xc3f456fb, 0xceb74022, 0xca764d95,
        0xf2390028, 0xf6f80d9f, 0xfbbb1b46, 0xff7a16f1,	0xe13d36f4, 0xe5fc3b43, 0xe8bf2d9a, 0xec7e202d,
        0x34826077, 0x30436dc0, 0x3d007b19, 0x39c176ae,	0x278656ab, 0x23475b1c, 0x2e044dc5, 0x2ac54072,
        0x128a0dcf, 0x164b0078, 0x1b0816a1, 0x1fc91b16,	0x018e3b13, 0x054f36a4, 0x080c207d, 0x0ccd2dca,
        0x7892bb07, 0x7c53b6b0, 0x7110a069, 0x75d1adde,	0x6b968ddb, 0x6f57806c, 0x621496b5, 0x66d59b02,
        0x5e9ad6bf, 0x5a5bdb08, 0x5718cdd1, 0x53d9c066,	0x4d9ee063, 0x495fedd4, 0x441cfb0d, 0x40ddf6ba,
        0xaca3d697, 0xa862db20, 0xa521cdf9, 0xa1e0c04e,	0xbfa7e04b, 0xbb66edfc, 0xb625fb25, 0xb2e4f692,
        0x8aabbb2f, 0x8e6ab698, 0x8329a041, 0x87e8adf6,	0x99af8df3, 0x9d6e8044, 0x902d969d, 0x94ec9b2a,
        0xe0b30de7, 0xe4720050, 0xe9311689, 0xedf01b3e,	0xf3b73b3b, 0xf776368c, 0xfa352055, 0xfef42de2,
        0xc6bb605f, 0xc27a6de8, 0xcf397b31, 0xcbf87686,	0xd5bf5683, 0xd17e5b34, 0xdc3d4ded, 0xd8fc405a,
        0x6904c0ee, 0x6dc5cd59, 0x6086db80, 0x6447d637,	0x7a00f632, 0x7ec1fb85, 0x7382ed5c, 0x7743e0eb,
        0x4f0cad56, 0x4bcda0e1, 0x468eb638, 0x424fbb8f,	0x5c089b8a, 0x58c9963d, 0x558a80e4, 0x514b8d53,
        0x25141b9e, 0x21d51629, 0x2c9600f0, 0x28570d47,	0x36102d42, 0x32d120f5, 0x3f92362c, 0x3b533b9b,
        0x031c7626, 0x07dd7b91, 0x0a9e6d48, 0x0e5f60ff,	0x101840fa, 0x14d94d4d, 0x199a5b94, 0x1d5b5623,
        0xf125760e, 0xf5e47bb9, 0xf8a76d60, 0xfc6660d7,	0xe22140d2, 0xe6e04d65, 0xeba35bbc, 0xef62560b,
        0xd72d1bb6, 0xd3ec1601, 0xdeaf00d8, 0xda6e0d6f,	0xc4292d6a, 0xc0e820dd, 0xcdab3604, 0xc96a3bb3,
        0xbd35ad7e, 0xb9f4a0c9, 0xb4b7b610, 0xb076bba7,	0xae319ba2, 0xaaf09615, 0xa7b380cc, 0xa3728d7b,
        0x9b3dc0c6, 0x9ffccd71, 0x92bfdba8, 0x967ed61f,	0x8839f61a, 0x8cf8fbad, 0x81bbed74, 0x857ae0c3,
        0x5d86a099, 0x5947ad2e, 0x5404bbf7, 0x50c5b640,	0x4e829645, 0x4a439bf2, 0x47008d2b, 0x43c1809c,
        0x7b8ecd21, 0x7f4fc096, 0x720cd64f, 0x76cddbf8,	0x688afbfd, 0x6c4bf64a, 0x6108e093, 0x65c9ed24,
        0x11967be9, 0x1557765e, 0x18146087, 0x1cd56d30,	0x02924d35, 0x06534082, 0x0b10565b, 0x0fd15bec,
        0x379e1651, 0x335f1be6, 0x3e1c0d3f, 0x3add0088,	0x249a208d, 0x205b2d3a, 0x2d183be3, 0x29d93654,
        0xc5a71679, 0xc1661bce, 0xcc250d17, 0xc8e400a0,	0xd6a320a5, 0xd2622d12, 0xdf213bcb, 0xdbe0367c,
        0xe3af7bc1, 0xe76e7676, 0xea2d60af, 0xeeec6d18,	0xf0ab4d1d, 0xf46a40aa, 0xf9295673, 0xfde85bc4,
        0x89b7cd09, 0x8d76c0be, 0x8035d667, 0x84f4dbd0,	0x9ab3fbd5, 0x9e72f662, 0x9331e0bb, 0x97f0ed0c,
        0xafbfa0b1, 0xab7ead06, 0xa63dbbdf, 0xa2fcb668,	0xbcbb966d, 0xb87a9bda, 0xb5398d03, 0xb1f880b4,
    ]
    # fmt: on

    def rkcrc_crc32_py(data: bytes, crc: int = 0) -> int:
        crc = crc & 0xFFFFFFFF
        for x in data:
            crc = _crc32_table[x ^ (crc >> 24)] ^ ((crc << 8) & 0xFFFFFFFF)

        return crc & 0xFFFFFFFF

    rkcrc_crc32 = rkcrc_crc32_py

    print("Use pure python rk_crc32!")


# ______________________________________________________________________________
@dataclass
class RkPkgFile:
    fname: str
    fpath: str
    fsize: int


@dataclass
class MtdInfo:
    partion_size: int
    flash_address: int


def read_file_chunk(file_path, chunk_size=8192):
    with open(file_path, 'rb') as file:
        while True:
            data = file.read(chunk_size)
            if not data:
                break
            yield data


def write_file_chunk(file_path, data, chunk_size=8192) -> None:
    with open(file_path, "wb") as f:
        for i in range(0, len(data), chunk_size):
            f.write(data[i : i + chunk_size])


#
# struct ParmImg{
#     char magic[4]         //"PARM"
#     uint32_t raw_size
#     uint8_t raw_bytes[]
#     uint32_t raw_crc32
# };
#
def encrypt_parm(file_path) -> bytearray:
    """
    Raises:
        AssertionError: If the size of parameter file > 0x3FF4
    """
    size = os.path.getsize(file_path)
    assert size <= 0x3FF4

    buf = bytearray(4 + 4)
    struct.pack_into("<4sI", buf, 0, b"PARM", size)
    crc32_value = 0
    for data in read_file_chunk(file_path):
        crc32_value = rkcrc_crc32(data, crc32_value)
        # crc32_value = parallel_crc32(data, crc32_value)
        buf.extend(data)
    buf.extend(b"0000")
    struct.pack_into("<I", buf, 4 + 4 + size, crc32_value)
    return buf


def set_str_field(buf: bytearray, val: str, max_len, offset):
    fmt = f"<{min(len(val), max_len)}s"
    struct.pack_into(fmt, buf, offset, val[:max_len].encode())


def parse_mtdparts(mtdparts: str) -> Dict[str, Type[MtdInfo]]:
    info = {}
    pat = "(-|0x[0-9A-Fa-f]{1,8})@(0x[0-9A-Fa-f]{1,8})\((\w+)(:\w+)?\)"
    sub = re.findall(pat, mtdparts)
    if not sub:
        raise ValueError(f"Invalid mtdparts: {mtdparts}")

    for mtd in sub:
        assert mtd[2]
        if mtd[0] == "-":
            info[mtd[2]] = MtdInfo(0xFFFFFFFF, int(mtd[1], 16))
            continue
        info[mtd[2]] = MtdInfo(int(mtd[0], 16), int(mtd[1], 16))

    # # to-do:
    # if not all(k in info for k in ("uboot", "boot", "rootfs")):
    #     raise ValueError(
    #         f"Invalid mtdparts: {mtdparts}, (uboot, boot, rootfs) must be set."
    #     )

    info["parameter"] = MtdInfo(0x00004000, 0x00000000)

    return info


#
# tagRKIMAGE_ITEM
#
def pack_items(
    package_items: Dict[str, Type[RkPkgFile]], mtdparts: str
) -> Tuple[bytearray, int]:
    mtd_info = parse_mtdparts(mtdparts)

    tag_items = bytearray()
    total_offset: int = 0x800
    for k, v in package_items.items():
        if k == "parameter":
            tmp = encrypt_parm(v.fpath)
            v.fpath += ".tmp"
            write_file_chunk(v.fpath, tmp)
            tmp_size = os.path.getsize(v.fpath)
            assert v.fsize == tmp_size - 0x0C
            v.fsize = tmp_size

        buf = bytearray(0x70)
        set_str_field(buf, k, 31, 0x00)
        set_str_field(buf, v.fname, 49, 0x20)

        offset = total_offset
        if offset > 0xFFFFFFFF:
            hoffset = offset >> 32
            struct.pack_into("<c", buf, 0x52, b'H')
            struct.pack_into("<I", buf, 0x53, hoffset)
            offset = offset & 0xFFFFFFFF
        struct.pack_into("<I", buf, 0x60, offset)

        if k in mtd_info:
            struct.pack_into("<I", buf, 0x5C, mtd_info[k].partion_size)
            struct.pack_into("<I", buf, 0x64, mtd_info[k].flash_address)
        else:
            struct.pack_into("<I", buf, 0x64, 0xFFFFFFFF)

        size = v.fsize
        if size > 0xFFFFFFFF:
            hsize = size >> 32
            struct.pack_into("<c", buf, 0x57, b'H')
            struct.pack_into("<I", buf, 0x58, hsize)
            size = v.fsize & 0xFFFFFFFF
        struct.pack_into("<I", buf, 0x6C, size)

        userspace = v.fsize // 0x800
        remainder = v.fsize % 0x800
        if remainder != 0:
            userspace += 1

        struct.pack_into("<I", buf, 0x68, userspace)

        total_offset += userspace * 0x800

        tag_items.extend(buf)

    return tag_items, total_offset


def pack_rkaf_hdr(
    package_items: Dict[str, Type[RkPkgFile]], parameter_items, file_size
) -> bytearray:
    hdr_len = 0x8C
    hdr = bytearray(hdr_len)

    struct.pack_into("<4s", hdr, 0, b"RKAF")

    if file_size > 0xFFFFFFFF:
        hsize = file_size >> 32
        struct.pack_into("<c", hdr, 0x25, b'H')
        struct.pack_into("<I", hdr, 0x26, hsize)
        file_size = file_size & 0xFFFFFFFF
    struct.pack_into("<I", hdr, 0x04, file_size)

    set_str_field(hdr, parameter_items["MACHINE_MODEL"], 28, 0x08)

    set_str_field(hdr, parameter_items["MACHINE_ID"], 29, 0x2A)

    set_str_field(hdr, parameter_items["MANUFACTURER"], 29, 0x48)

    ver = parameter_items["FIRMWARE_VER"].split('.')
    assert len(ver) >= 2
    ver_x = int(ver[0])
    ver_y = int(ver[1])
    ver_z = 0
    if len(ver) >= 3:
        ver_z = int(ver[2])
    assert ver_x < 0xFF and ver_y < 0xFF and ver_z < 0xFFFF
    struct.pack_into("<HBB", hdr, 0x84, ver_z, ver_y, ver_x)

    struct.pack_into("<I", hdr, 0x88, len(package_items))

    return hdr


def parse_package_file(package_file, indir) -> Dict[str, Type[RkPkgFile]]:
    items = {}
    with open(package_file, "r") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            if line.startswith('#'):
                continue
            if "SELF" in line or "RESERVED" in line:
                continue
            kname, name = line.split(maxsplit=1)
            assert kname and name
            if len(kname) >= 0x20:
                raise ValueError(f"Key name {kname} in the package-file is too long")
            name = name.strip()
            fname = os.path.basename(name)
            if len(fname) >= 0x32:
                raise ValueError(f"File name {fname} in the package-file is too long")
            fpath = os.path.join(indir, *name.split(sep='/'))
            if not os.path.isfile(fpath):
                raise ValueError(f"File {fpath} does not exist")
            fsize = os.path.getsize(fpath)
            items[kname] = RkPkgFile(fname, fpath, fsize)
    return items


def parse_parameter_file(parameter_file) -> Dict[str, str]:
    items = {}
    size = os.path.getsize(parameter_file)
    if size > 0x3FF4:
        raise BufferError("Parameter file size > 0x3FF4")
    with open(parameter_file, "r") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            if line.startswith('#'):
                continue
            k, v = line.split(sep=':', maxsplit=1)
            assert k and v
            items[k.strip()] = v.strip()
    must_have = [
        "FIRMWARE_VER",
        "MACHINE_MODEL",
        "MACHINE_ID",
        "MANUFACTURER",
        "CMDLINE",
    ]
    if not all(mh in items for mh in must_have):
        raise KeyError(f"Missing key in parameter file.")

    mtdparts = items.get("CMDLINE")
    if not (mtdparts and mtdparts.startswith("mtdparts=")):
        raise ValueError("CMDLINE must start with 'mtdparts='.")

    items["mtdparts"] = mtdparts[len("mtdparts=") :]

    return items


def pack_rkaf_img(indir, out="firmware.img") -> None:
    package_file = os.path.join(indir, "package-file")
    if not os.path.isfile(package_file):
        raise FileNotFoundError("package-file not found.")
    package_items = parse_package_file(package_file, indir)
    if len(package_items) > 16:
        # to-do:
        raise Exception("Too many files(N>16) in package file is not support now.")

    parameter_file = package_items.get("parameter")
    if not parameter_file:
        raise ValueError("parameter file not found in package-file.")
    parameter_items = parse_parameter_file(parameter_file.fpath)

    items, file_size = pack_items(package_items, parameter_items["mtdparts"])
    hdr = pack_rkaf_hdr(package_items, parameter_items, file_size)

    crcvalue: int = 0
    with open(out, "wb") as f:
        print(f"Start creating {out}. Please be patient as it may take some time.")
        print("Writing hdr ...")
        crcvalue = rkcrc_crc32(hdr, crcvalue)
        f.write(hdr)

        delta = 0x800 - len(hdr)
        items = items.ljust(delta, b"\x00")
        crcvalue = rkcrc_crc32(items, crcvalue)
        f.write(items)

        for _, v in package_items.items():
            print(f"Writing {v.fname} ...")
            for data in read_file_chunk(v.fpath):
                crcvalue = rkcrc_crc32(data, crcvalue)
                f.write(data)

            remainder = v.fsize % 0x800
            delta = 0x800 - remainder if remainder else 0
            if delta:
                rdata = bytearray(delta)
                crcvalue = rkcrc_crc32(rdata, crcvalue)
                f.write(rdata)
        print("Writing crc32 ...")
        f.write(struct.pack("<I", crcvalue))
    os.remove(parameter_file.fpath)
    print("Finished.")


# ______________________________________________________________________________
#
#
def pack_rkfw_hdr(chipval: int, bootloader_path, firmware_path) -> bytearray:
    hdr_len = 0x66
    hdr = bytearray(hdr_len)

    struct.pack_into("<4sH", hdr, 0, b"RKFW", hdr_len)

    for data in read_file_chunk(firmware_path, 256):
        fw_ver = data[0x84:0x88]
        struct.pack_into("<4s", hdr, 0x06, fw_ver)
        break

    struct.pack_into("<I", hdr, 0x0A, 0x02000000)  # 32M

    tm = datetime.now()
    struct.pack_into(
        "<H5B", hdr, 0x0E, tm.year, tm.month, tm.day, tm.hour, tm.minute, tm.second
    )

    # 0x33353838 -> b"38 38 35 33"
    struct.pack_into("<I", hdr, 0x15, chipval)

    bl_offset = hdr_len
    bl_bytes = os.path.getsize(bootloader_path)
    struct.pack_into("<2I", hdr, 0x19, bl_offset, bl_bytes)

    fw_offset = bl_offset + bl_bytes
    fw_bytes = os.path.getsize(firmware_path)
    if fw_bytes > 0xFFFFFFFF:
        fw_hsize = fw_bytes >> 32
        fw_bytes &= 0xFFFFFFFF
        struct.pack_into("<2s", hdr, 0x37, b"HI")
        struct.pack_into("<I", hdr, 0x39, fw_hsize)
    struct.pack_into("<2I", hdr, 0x21, fw_offset, fw_bytes)

    # -os_type:androidos
    struct.pack_into("<I", hdr, 0x2D, 0x01)

    return hdr


def pack_rkfw_img(chiptype, bootloader_path, firmware_path, out="update.img"):
    hdr = pack_rkfw_hdr(chiptype, bootloader_path, firmware_path)
    with open(out, "wb") as f:
        md5_hash = hashlib.md5()
        print(f"Start creating {out}. Please be patient as it may take some time.")
        print("Writing hdr ...")
        md5_hash.update(hdr)
        f.write(hdr)

        print("Writing bootloader ...")
        for data in read_file_chunk(bootloader_path):
            md5_hash.update(data)
            f.write(data)

        print("Writing firmware ...")
        for data in read_file_chunk(firmware_path):
            md5_hash.update(data)
            f.write(data)

        print("Writing md5 ...")
        f.write(md5_hash.hexdigest().encode())
    print("Finished.")


def get_chipval(chiptype) -> int:
    """
    Raises:
        ValueError: If chiptype is not supported.
    """
    if not (chiptype.startswith("RK") or chiptype.startswith("RV")):
        raise ValueError(f"Unknown chip type: {chiptype}")

    rkchips = {
        "RKNANO": 0x30,
        "RKSMART": 0x31,
        "RK28": 0x20,
        "RK281X": 0x21,
        "RKPANDA": 0x22,
        "RKCROWN": 0x40,
        "RKCAYMAN": 0x11,
        "RK29": 0x50,
        "RK292X": 0x51,
        "RK30": 0x60,
        "RK30B": 0x61,
        "RK31": 0x70,
        "RK32": 0x80,
    }
    val = rkchips.get(chiptype, -1)
    if val != -1:
        return val

    if len(chiptype) > 6:
        raise ValueError(f"Unknown chip type: {chiptype}")

    # "3588" -> "3588" -> b"33 35 38 38" -> 0x33353838
    # "358"  -> "0358" -> b"30 33 35 38" -> 0x30353838
    tmp = chiptype[2:].zfill(4).encode()
    val = int.from_bytes(tmp, "big")

    return val


# ______________________________________________________________________________
#
#
if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    subparser = parser.add_subparsers(title="L1cmd", dest="L1cmd", required=True)

    #
    afptool = subparser.add_parser("afptool", help="pack/unpack firmware.img")
    imgmker = subparser.add_parser("imgmker", help="pack/unpack update.img")

    #
    afptool_subcmd = afptool.add_subparsers(title="L2cmd", dest="L2cmd", required=True)
    afptool_pack = afptool_subcmd.add_parser("pack", help="make firmware.img")
    afptool_pack.add_argument("dir", help="dir that contains package-file")
    afptool_pack.add_argument("firmware", help="firmware.img packed by afptool")

    afptool_unpack = afptool_subcmd.add_parser("unpack", help="unpack firmware.img")
    afptool_unpack.add_argument("firmware", help="firmware.img packed by afptool")
    afptool_unpack.add_argument("outdir", help="output dir")

    #
    imgmker_subcmd = imgmker.add_subparsers(title="L2cmd", dest="L2cmd", required=True)
    imgmker_pack = imgmker_subcmd.add_parser("pack", help="make update.img")
    imgmker_pack.add_argument("chiptype", help="set chip type, eg: RK3588")
    imgmker_pack.add_argument("bootloader", help="bootloader.bin")
    imgmker_pack.add_argument("firmware", help="firmware.img packed by afptool")
    imgmker_pack.add_argument(
        "-os_type",
        required=True,
        choices=["androidos", "rkos"],
        nargs=1,
        help="set os type",
    )
    imgmker_pack.add_argument(
        "-storage",
        required=False,
        choices=["FLASH", "EMMC", "SD", "SPINAND", "SPINOR", "SATA", "PCIE"],
        nargs=1,
        help="set storage type",
    )

    imgmker_unpack = imgmker_subcmd.add_parser("unpack", help="unpack update.img")
    imgmker_unpack.add_argument("update", help="update.img packed by imgmker")
    imgmker_unpack.add_argument("outdir", help="output dir")

    args = parser.parse_args()

    if args.L1cmd == "afptool":
        if args.L2cmd == "pack":
            assert os.path.isdir(args.dir)
            pack_rkaf_img(args.dir, args.firmware)
        else:
            assert args.L2cmd == "unpack"
            # to-do:
            print("not support now")
    else:
        assert args.L1cmd == "imgmker"
        assert os.path.isfile(args.bootloader) and os.path.isfile(args.firmware)
        if args.L2cmd == "pack":
            if args.os_type[0] != "androidos":
                print(f"os type {args.os_type[0]} not support now")
                exit(0)
            try:
                chipval = get_chipval(args.chiptype)
                pack_rkfw_img(chipval, args.bootloader, args.firmware)
            except Exception as e:
                print(e)
        else:
            assert args.L2cmd == "unpack"
            # to-do:
            print("not support now")
