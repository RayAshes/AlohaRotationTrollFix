// FAT‑aware drstool, strip LC_DYLIB_CODE_SIGN_DRS from every slice
import Foundation

guard CommandLine.arguments.count == 2 else {
    print("usage: drstool <fat_or_thin.dylib>")
    exit(1)
}
let path = CommandLine.arguments[1]
var fileData = try! Data(contentsOf: URL(fileURLWithPath: path))

let MH_MAGIC_64: UInt32 = 0xfeedfacf
let FAT_MAGIC_64: UInt32 = 0xcafebabf
let LC_DYLIB_CODE_SIGN_DRS: UInt32 = 0x2A

struct fat_header {
    var magic: UInt32
    var nfat_arch: UInt32
}
struct fat_arch_64 {
    var cputype: Int32
    var cpusubtype: Int32
    var offset: UInt64
    var size: UInt64
    var align: UInt32
    var reserved: UInt32
}
struct mach_header_64 {
    var magic: UInt32
    var cputype: Int32
    var cpusubtype: Int32
    var filetype: UInt32
    var ncmds: UInt32
    var sizeofcmds: UInt32
    var flags: UInt32
    var reserved: UInt32
}
struct load_command {
    var cmd: UInt32
    var cmdsize: UInt32
}

func stripDRS(_ slice:Data) -> Data? {
    var d = slice
    var mh = d.get(0) as mach_header_64
    guard mh.magic == MH_MAGIC_64 else { return nil }
    var pos = MemoryLayout<mach_header_64>.size
    var i:UInt32 = 0
    while i < mh.ncmds {
        let lc = d.get(pos) as load_command
        if lc.cmd == LC_DYLIB_CODE_SIGN_DRS {
            d.removeSubrange(pos..<pos+Int(lc.cmdsize))
            mh.ncmds -= 1
            mh.sizeofcmds -= lc.cmdsize
            var mhData = Data(bytes:&mh, count:MemoryLayout<mach_header_64>.size)
            d.replaceSubrange(0..<mhData.count, with: mhData)
            continue
        }
        pos += Int(lc.cmdsize)
        i += 1
    }
    return d
}

extension Data {
    func get<T>(_ o:Int) -> T {
        subdata(in:o..<o+MemoryLayout<T>.size).withUnsafeBytes{$0.load(as:T.self)}
    }
}

let magic:UInt32 = fileData.get(0)
if magic == FAT_MAGIC_64 {
    var fh = fileData.get(0) as fat_header
    var archPtr = MemoryLayout<fat_header>.size
    var newSlices = [Data]()
    for _ in 0..<fh.nfat_arch {
        let fa:fat_arch_64 = fileData.get(archPtr)
        let slice = fileData.subdata(in:Int(fa.offset)..<Int(fa.offset+fa.size))
        if let fixed = stripDRS(slice) {
            newSlices.append(fixed)
        } else {
            newSlices.append(slice)
        }
        archPtr += MemoryLayout<fat_arch_64>.size
    }
    // 重打包FAT64
    var out = Data()
    var newArchs = [fat_arch_64]()
    var offset = MemoryLayout<fat_header>.size + newSlices.count * MemoryLayout<fat_arch_64>.size
    for s in newSlices {
        let align:UInt64 = 0x4000
        let pad = (align - (UInt64(offset) % align)) % align
        offset += pad
        var fa = fat_arch_64(cputype:0, cpusubtype:0, offset:UInt64(offset), size:UInt64(s.count), align:14, reserved:0)
        newArchs.append(fa)
        offset += UInt64(s.count)
    }
    fh.nfat_arch = UInt32(newSlices.count)
    out.append(Data(bytes:&fh,count:MemoryLayout<fat_header>.size))
    for var a in newArchs { out.append(Data(bytes:&a,count:MemoryLayout<fat_arch_64>.size)) }
    var ptr = out.count
    for (idx,var s) in newSlices.enumerated() {
        let align:UInt64 = 0x4000
        let pad = (align - (UInt64(ptr) % align)) % align
        out.append(Data(repeating:0,count:Int(pad)))
        newArchs[idx].offset = UInt64(out.count)
        out.append(s)
        ptr = out.count
    }
    // 回填修正后的fat_arch_64 offset
    out.replaceSubrange(MemoryLayout<fat_header>.size..<MemoryLayout<fat_header>.size+newArchs.count*MemoryLayout<fat_arch_64>.size,
                        with: newArchs.flatMap{var a=$0;return Data(bytes:&a,count:MemoryLayout<fat_arch_64>.size)})
    try! out.write(to:URL(fileURLWithPath:path))
    print("FAT64 DRS stripped OK")
} else {
    if let res = stripDRS(fileData) {
        try! res.write(to:URL(fileURLWithPath:path))
        print("Thin DRS stripped OK")
    } else {
        print("not 64‑bit mach‑o")
        exit(1)
    }
}