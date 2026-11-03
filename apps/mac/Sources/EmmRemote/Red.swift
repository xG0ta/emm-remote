import AppKit
import Darwin
import Foundation

enum NSWorkspaceAbrir {
    static func app(_ ruta: String) {
        NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: ruta),
                                           configuration: NSWorkspace.OpenConfiguration())
    }
}

extension Red {
    /// Ventanas normales de un proceso, aunque estén minimizadas o en otro escritorio
    /// (no requiere permisos especiales).
    static func ventanas(pid: Int32) -> Int {
        guard let lista = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID)
                as? [[String: Any]] else { return 0 }
        return lista.filter { w in
            guard (w[kCGWindowOwnerPID as String] as? Int32) == pid,
                  (w[kCGWindowLayer as String] as? Int) == 0,
                  let b = w[kCGWindowBounds as String] as? [String: CGFloat] else { return false }
            return (b["Height"] ?? 0) > 100 && (b["Width"] ?? 0) > 100
        }.count
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
        let paquete = paqueteMagico(mac)
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

    static func paqueteMagico(_ mac: [UInt8]) -> [UInt8] {
        [UInt8](repeating: 0xFF, count: 6) + Array([[UInt8]](repeating: mac, count: 16).joined())
    }

    /// Wake-on-WAN: manda el paquete mágico a la IP pública (o nombre DDNS) de la casa,
    /// al puerto UDP que el router reenvía hacia el equipo. Lo manda 3 veces por si se pierde.
    @discardableResult
    static func enviarWOLPorInternet(mac: [UInt8], host: String, puerto: UInt16) -> Int {
        guard let ip = resolverIPv4(host) else { return 0 }
        let paquete = paqueteMagico(mac)
        let s = socket(AF_INET, SOCK_DGRAM, 0)
        guard s >= 0 else { return 0 }
        defer { close(s) }
        var dir = sockaddr_in()
        dir.sin_family = sa_family_t(AF_INET)
        dir.sin_port = puerto.bigEndian
        dir.sin_addr.s_addr = ip
        var enviados = 0
        for _ in 0..<3 {
            let r = paquete.withUnsafeBytes { buf in
                withUnsafePointer(to: &dir) {
                    $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                        sendto(s, buf.baseAddress, buf.count, 0, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                    }
                }
            }
            if r == paquete.count { enviados += 1 }
            usleep(150_000)
        }
        return enviados
    }

    /// IPv4 de un texto «a.b.c.d» o de un nombre (DDNS) vía DNS.
    static func resolverIPv4(_ host: String) -> in_addr_t? {
        if let n = numero(host) { return n }
        var pistas = addrinfo()
        pistas.ai_family = AF_INET
        pistas.ai_socktype = SOCK_DGRAM
        var res: UnsafeMutablePointer<addrinfo>?
        guard getaddrinfo(host, nil, &pistas, &res) == 0, let r = res else { return nil }
        defer { freeaddrinfo(res) }
        return r.pointee.ai_addr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee.sin_addr.s_addr }
    }

    /// ¿Es un nombre (DDNS) y no una IP? Entonces lo escribió el usuario y no se reemplaza.
    static func esNombre(_ s: String) -> Bool { !s.isEmpty && numero(s) == nil }

    /// ¿IPv4 pública? (fuera de redes privadas, CGNAT/Tailscale, locales y de enlace)
    static func esPublica(_ ip: String) -> Bool {
        guard let n = numero(ip) else { return false }
        let h = UInt32(bigEndian: n)
        let privadas: [(UInt32, UInt32)] = [
            (0x0A00_0000, 0xFF00_0000), (0xAC10_0000, 0xFFF0_0000), (0xC0A8_0000, 0xFFFF_0000),
            (0x6440_0000, 0xFFC0_0000), (0x7F00_0000, 0xFF00_0000), (0xA9FE_0000, 0xFFFF_0000),
        ]
        return !privadas.contains { h & $0.1 == $0.0 }
    }

    /// Para cada IP de Tailscale dada, la IPv4 pública desde la que conecta ahora ese equipo
    /// (según «tailscale status»: «direct a.b.c.d:puerto»). Solo equipos en línea y con conexión directa.
    static func ipsPublicasTailscale(de direcciones: [String]) -> [String: String] {
        let cli = "/Applications/Tailscale.app/Contents/MacOS/Tailscale"
        guard FileManager.default.isExecutableFile(atPath: cli) else { return [:] }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: cli)
        p.arguments = ["status"]
        let tubo = Pipe()
        p.standardOutput = tubo
        p.standardError = FileHandle.nullDevice
        do { try p.run() } catch { return [:] }
        let datos = tubo.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        let texto = String(decoding: datos, as: UTF8.self)
        var vistas: [String: String] = [:]
        for linea in texto.split(separator: "\n") {
            let partes = linea.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
            guard let ip = partes.first, direcciones.contains(ip),
                  let i = partes.firstIndex(where: { $0.hasPrefix("direct") }), i + 1 < partes.count else { continue }
            let extremo = partes[i + 1].trimmingCharacters(in: CharacterSet(charactersIn: ","))
            guard !extremo.hasPrefix("["), let host = extremo.split(separator: ":").first.map(String.init),
                  esPublica(host) else { continue }
            vistas[ip] = host
        }
        return vistas
    }
}
