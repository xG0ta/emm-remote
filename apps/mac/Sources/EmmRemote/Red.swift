import AppKit
import Darwin
import Foundation

enum NSWorkspaceAbrir {
    static func app(_ ruta: String) {
        NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: ruta),
                                           configuration: NSWorkspace.OpenConfiguration())
    }
}

/// Utilidades de red sin dependencias: interfaces, prueba de puerto y Wake-on-LAN.
enum Red {
    struct Interfaz { let ip: in_addr_t; let mascara: in_addr_t; let difusion: in_addr_t? }

    static func interfacesIPv4() -> [Interfaz] {
        var lista: [Interfaz] = []
        var ifap: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifap) == 0, let primero = ifap else { return [] }
        defer { freeifaddrs(ifap) }
        var p: UnsafeMutablePointer<ifaddrs>? = primero
        while let i = p {
            defer { p = i.pointee.ifa_next }
            let flags = Int32(i.pointee.ifa_flags)
            guard let a = i.pointee.ifa_addr, a.pointee.sa_family == UInt8(AF_INET),
                  flags & IFF_UP != 0, flags & IFF_LOOPBACK == 0,
                  let m = i.pointee.ifa_netmask else { continue }
            let ip = a.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee.sin_addr.s_addr }
            let mask = m.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee.sin_addr.s_addr }
            var bc: in_addr_t? = nil
            if flags & IFF_BROADCAST != 0, let d = i.pointee.ifa_dstaddr {
                bc = d.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee.sin_addr.s_addr }
            }
            lista.append(Interfaz(ip: ip, mascara: mask, difusion: bc))
        }
        return lista
    }

    static func texto(_ a: in_addr_t) -> String {
        var addr = in_addr(s_addr: a)
        var buf = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
        inet_ntop(AF_INET, &addr, &buf, socklen_t(INET_ADDRSTRLEN))
        return String(cString: buf)
    }

    static func numero(_ s: String) -> in_addr_t? {
        var a = in_addr()
        return inet_pton(AF_INET, s, &a) == 1 ? a.s_addr : nil
    }

    /// IP de Tailscale de esta Mac (rango 100.64.0.0/10), si está conectada.
    static func ipTailscale() -> String? {
        let red = numero("100.64.0.0")!, mascara = numero("255.192.0.0")!
        return interfacesIPv4().first { $0.ip & mascara == red }.map { texto($0.ip) }
    }

    /// ¿La IP pertenece a una red local de esta Mac (sin contar Tailscale)?
    static func estoyEnLaRedDe(_ ip: String) -> Bool {
        guard let n = numero(ip) else { return false }
        return interfacesIPv4().contains { $0.difusion != nil && ($0.ip & $0.mascara) == (n & $0.mascara) }
    }

    /// Conexión TCP con tiempo límite: sirve para saber si RustDesk responde en el equipo.
    static func puertoAbierto(host: String, puerto: UInt16, espera: Int) -> Bool {
        guard let n = numero(host) else { return false }
        let s = socket(AF_INET, SOCK_STREAM, 0)
        guard s >= 0 else { return false }
        defer { close(s) }
        _ = fcntl(s, F_SETFL, fcntl(s, F_GETFL) | O_NONBLOCK)
        var dir = sockaddr_in()
        dir.sin_family = sa_family_t(AF_INET)
        dir.sin_port = puerto.bigEndian
        dir.sin_addr.s_addr = n
        let r = withUnsafePointer(to: &dir) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(s, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        if r == 0 { return true }
        guard errno == EINPROGRESS else { return false }
        var pfd = pollfd(fd: s, events: Int16(POLLOUT), revents: 0)
        guard poll(&pfd, 1, Int32(espera * 1000)) == 1 else { return false }
        var err: Int32 = 0
        var len = socklen_t(MemoryLayout<Int32>.size)
        getsockopt(s, SOL_SOCKET, SO_ERROR, &err, &len)
        return err == 0
    }

    /// Acepta AA:BB:CC:DD:EE:FF, AA-BB-..., o 12 dígitos seguidos.
    static func parsearMAC(_ s: String) -> [UInt8]? {
        let hex = s.filter { $0.isHexDigit }
        guard hex.count == 12 else { return nil }
        var bytes: [UInt8] = []
        var i = hex.startIndex
        while i < hex.endIndex {
            let j = hex.index(i, offsetBy: 2)
            guard let b = UInt8(hex[i..<j], radix: 16) else { return nil }
            bytes.append(b)
            i = j
        }
        return bytes
    }

    /// Envía el «paquete mágico» (6×FF + 16×MAC) a todas las redes locales, puertos 9 y 7.
    /// Devuelve cuántos envíos salieron.
    @discardableResult
    static func enviarWOL(mac: [UInt8], ipEquipo: String) -> Int {
        let paquete = [UInt8](repeating: 0xFF, count: 6) + Array([[UInt8]](repeating: mac, count: 16).joined())
        var destinos = Set<in_addr_t>([INADDR_BROADCAST])
        for i in interfacesIPv4() { if let b = i.difusion { destinos.insert(b) } }
        if let n = numero(ipEquipo) { destinos.insert(n) }

        let s = socket(AF_INET, SOCK_DGRAM, 0)
        guard s >= 0 else { return 0 }
        defer { close(s) }
        var si: Int32 = 1
        setsockopt(s, SOL_SOCKET, SO_BROADCAST, &si, socklen_t(MemoryLayout<Int32>.size))
        var enviados = 0
        for d in destinos {
            for puerto: UInt16 in [9, 7] {
                var dir = sockaddr_in()
                dir.sin_family = sa_family_t(AF_INET)
                dir.sin_port = puerto.bigEndian
                dir.sin_addr.s_addr = d
                let r = paquete.withUnsafeBytes { buf in
                    withUnsafePointer(to: &dir) {
                        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                            sendto(s, buf.baseAddress, buf.count, 0, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                        }
                    }
                }
                if r == paquete.count { enviados += 1 }
            }
        }
        return enviados
    }
}
