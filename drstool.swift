// drstool: remove LC_DYLIB_CODE_SIGN_DRS
import Foundation

guard CommandLine.arguments.count == 2 else {
    print("usage: drstool <dylib>")
    exit(1)
}
let path = CommandLine.arguments[1]
var data = try! Data(contentsOf: URL(fileURLWithPath: path))

// Mach‑O constants
let MH_MAGIC_64: UInt32 = 0xfeedfacf
let LC_SEGMENT_64: UInt32 = 0x19
let LC_DYLIB_CODE_SIGN_DRS: UInt32 = 0x2A

struct mach_header_64: Layout {
    var magic: UInt32
    var cputype: Int32
    var cpusubtype: Int32
    var filetype: UInt32
    var ncmds: UInt32
    var sizeofcmds: UInt32
    var flags: UInt32
    var reserved: UInt32
}
struct load_command: Layout {
    var cmd: UInt32
    var cmdsize: UInt32
}

protocol Layout {}
extension Data {
    func get<T:Layout>(_ o:Int) -> T {
        return subdata(in:o..<o+MemoryLayout<T>.size).withUnsafeBytes{$0.load(as:T.self)}
    }
    mutating func del(_ off:Int,_ sz:Int) {
        removeSubrange(off..<off+sz)
    }
}

var offset = MemoryLayout<mach_header_64>.size
var header = data.get(0) as mach_header_64
guard header.magic == MH_MAGIC_64 else {
    print("not 64‑bit mach‑o")
    exit(1)
}
var i = 0
while i < header.ncmds {
    let lc = data.get(offset) as load_command
    if lc.cmd == LC_DYLIB_CODE_SIGN_DRS {
        data.del(offset,Int(lc.cmdsize))
        header.ncmds -= 1
        header.sizeofcmds -= lc.cmdsize
        data.replaceSubrange(0..<MemoryLayout<mach_header_64>.size, with: Data(bytes:&header, count:MemoryLayout<mach_header_64>.size))
        continue
    }
    offset += Int(lc.cmdsize)
    i += 1
}
try! data.write(to:URL(fileURLWithPath:path))
print("stripped DRS OK")
