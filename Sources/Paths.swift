import Foundation

enum Paths {

    static let root: URL = {
        var u = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Documents", isDirectory: true)
        var buf = [CChar](repeating: 0, count: Int(PATH_MAX))
        if realpath(u.path, &buf) != nil { u = URL(fileURLWithPath: String(cString: buf)) }
        return u
    }()

    static var userBin: URL { root.appendingPathComponent("bin", isDirectory: true) }
    static var tmp: URL { root.appendingPathComponent("tmp", isDirectory: true) }

    static func bootstrap() {
        let fm = FileManager.default
        for d in [userBin, tmp] where !fm.fileExists(atPath: d.path) {
            try? fm.createDirectory(at: d, withIntermediateDirectories: true)
        }
        for f in (try? fm.contentsOfDirectory(at: userBin, includingPropertiesForKeys: nil)) ?? [] {
            try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: f.path)
        }
        _ = chdir(root.path)
    }

    static func shell() -> URL? {
        let fm = FileManager.default
        for p in ["/bin/sh", "/bin/bash", "/usr/bin/sh", "/usr/bin/bash"] {
            if fm.isExecutableFile(atPath: p) { return URL(fileURLWithPath: p) }
        }
        return nil
    }

    static func env() -> [String] {
        [
            "HOME=\(root.path)",
            "PWD=\(root.path)",
            "TMPDIR=\(tmp.path)",
            "PATH=\(userBin.path):/usr/bin:/bin:/usr/sbin:/sbin",
            "TERM=xterm-256color",
            "LANG=en_US.UTF-8",
            "PS1=$ ",
        ]
    }
}
