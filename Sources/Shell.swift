import Foundation

final class Shell {
    static let shared = Shell()

    var onOutput: ((String) -> Void)?

    private var pid: pid_t = 0
    private var toChild: Int32 = -1
    private var running = false
    private let lock = NSLock()
    private var buf = Data()

    private init() {}

    func start() {
        guard !running else { return }
        Paths.bootstrap()
        guard let sh = Paths.shell() else {
            emit("fatal: no /bin/sh found\n"); return
        }

        var inPipe: [Int32] = [0, 0]
        var outPipe: [Int32] = [0, 0]
        guard pipe(&inPipe) == 0, pipe(&outPipe) == 0 else {
            emit("fatal: pipe failed\n"); return
        }

        var fa: posix_spawn_file_actions_t?
        var at: posix_spawnattr_t?
        posix_spawn_file_actions_init(&fa)
        posix_spawnattr_init(&at)
        posix_spawnattr_setflags(&at, Int16(POSIX_SPAWN_SETPGROUP))
        posix_spawnattr_setpgroup(&at, 0)
        posix_spawn_file_actions_adddup2(&fa, inPipe[0], 0)
        posix_spawn_file_actions_adddup2(&fa, outPipe[1], 1)
        posix_spawn_file_actions_adddup2(&fa, outPipe[1], 2)
        posix_spawn_file_actions_addchdir_np(&fa, Paths.root.path)
        posix_spawn_file_actions_addclose(&fa, inPipe[1])
        posix_spawn_file_actions_addclose(&fa, outPipe[0])

        var argv: [UnsafeMutablePointer<CChar>?] = [strdup(sh.path), strdup("-i")]
        argv.append(nil)
        var envp: [UnsafeMutablePointer<CChar>?] = Paths.env().map { strdup($0) }
        envp.append(nil)

        let rc = posix_spawn(&pid, sh.path, &fa, &at, argv, envp)
        posix_spawn_file_actions_destroy(&fa)
        posix_spawnattr_destroy(&at)
        close(inPipe[0])
        close(outPipe[1])
        argv.forEach { free($0) }
        envp.forEach { free($0) }

        guard rc == 0 else {
            close(inPipe[1]); close(outPipe[0])
            emit("fatal: spawn \(String(cString: strerror(rc)))\n"); return
        }

        toChild = inPipe[1]
        running = true
        readLoop(outPipe[0])
    }

    private func readLoop(_ fd: Int32) {
        DispatchQueue.global(qos: .userInitiated).async {
            var chunk = [UInt8](repeating: 0, count: 4096)
            while true {
                let n = Darwin.read(fd, &chunk, chunk.count)
                if n <= 0 { break }
                self.lock.lock()
                self.buf.append(contentsOf: chunk[0..<n])
                self.lock.unlock()
                self.flush()
            }
            close(fd)
            self.running = false
            self.emit("\n[shell exited]\n")
        }
    }

    private func flush() {
        lock.lock()
        let d = buf; buf.removeAll()
        lock.unlock()
        guard !d.isEmpty else { return }
        let s = String(decoding: d, as: UTF8.self)
        DispatchQueue.main.async { self.onOutput?(s) }
    }

    private func emit(_ s: String) {
        lock.lock(); buf.append(contentsOf: s.utf8); lock.unlock()
        flush()
    }

    func write(_ s: String) {
        guard running, toChild >= 0 else { return }
        let bytes = Array(s.utf8)
        let fd = toChild
        DispatchQueue.global(qos: .userInitiated).async {
            var off = 0
            while off < bytes.count {
                let n = bytes[off...].withUnsafeBytes {
                    Darwin.write(fd, $0.baseAddress, $0.count)
                }
                if n <= 0 { break }
                off += n
            }
        }
    }

    func interrupt() {
        guard running, pid > 0 else { return }
        kill(-pid, SIGINT)
        emit("^C\n")
    }
}
