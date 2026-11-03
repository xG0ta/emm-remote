import AppKit
import Foundation

/// Un equipo que se puede controlar. Se guarda en
/// ~/Library/Application Support/Emm Remote/equipos.json (fuera del repo).
struct Equipo: Identifiable, Codable, Hashable {
    var id = UUID()
    var nombre: String
    /// IP de Tailscale (100.x.y.z) o IP de la red de casa.
    var direccion: String
    /// MAC de la tarjeta de red, para encenderlo con Wake-on-LAN (opcional).
    var mac: String = ""
    /// IP pública (o nombre DDNS) de la casa del equipo, para encenderlo desde fuera.
    /// La app la aprende sola de Tailscale mientras el equipo está en línea.
    var publica: String = ""
    /// Puerto UDP abierto en el router de la casa hacia el equipo (Wake-on-WAN).
    var puertoWOL: Int = 9

    init(nombre: String, direccion: String, mac: String = "") {
        self.nombre = nombre; self.direccion = direccion; self.mac = mac
    }

    // Los equipos guardados por versiones anteriores no traen los campos nuevos
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        nombre = try c.decode(String.self, forKey: .nombre)
        direccion = try c.decode(String.self, forKey: .direccion)
        mac = try c.decodeIfPresent(String.self, forKey: .mac) ?? ""
        publica = try c.decodeIfPresent(String.self, forKey: .publica) ?? ""
        puertoWOL = try c.decodeIfPresent(Int.self, forKey: .puertoWOL) ?? 9
    }
}

enum Estado: Equatable {
    case revisando
    case enLinea
    case sinRespuesta
    case despertando(segundos: Int)
}

@MainActor
final class Almacen: ObservableObject {
    @Published var equipos: [Equipo] = [] { didSet { guardar() } }
    @Published var estados: [UUID: Estado] = [:]
    @Published var tailscaleIP: String? = nil
    @Published var aviso: String? = nil

    private let archivo: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Emm Remote", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("equipos.json")
    }()
    private var temporizador: Timer?
    /// true si Emm Remote encendió Tailscale: entonces lo apaga al salir.
    private var encendiTailscale = false
    nonisolated static let tailscaleCLI = "/Applications/Tailscale.app/Contents/MacOS/Tailscale"

    init() {
        if let data = try? Data(contentsOf: archivo),
           let lista = try? JSONDecoder().decode([Equipo].self, from: data) {
            equipos = lista
        }
        if Red.ipTailscale() == nil { conectarTailscale() }
        NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: nil) { [weak self] _ in
            MainActor.assumeIsolated { self?.alSalir() }
        }
        actualizar()
        temporizador = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.actualizar() }
        }
    }

    private func guardar() {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? enc.encode(equipos) { try? data.write(to: archivo, options: .atomic) }
    }

    func actualizar() {
        tailscaleIP = Red.ipTailscale()
        aprenderIPsPublicas()
        for equipo in equipos {
            if case .despertando = estados[equipo.id] { continue }
            if estados[equipo.id] == nil { estados[equipo.id] = .revisando }
            let dir = equipo.direccion
            Task.detached {
                let ok = Red.puertoAbierto(host: dir, puerto: 21118, espera: 2)
                await MainActor.run { self.estados[equipo.id] = ok ? .enLinea : .sinRespuesta }
            }
        }
    }

    // MARK: Acciones

    func conectar(_ e: Equipo) {
        pantallaAjustable(e.direccion)
        abrirRustDesk(["--connect", e.direccion])
    }

    /// RustDesk recuerda por equipo la escala «original» (la PC se ve chica en ventana grande):
    /// la cambiamos a «adaptable» para que la pantalla remota se ajuste al tamaño de la ventana.
    private func pantallaAjustable(_ direccion: String) {
        let archivo = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Preferences/com.carriez.RustDesk/peers/\(direccion).toml")
        guard let texto = try? String(contentsOf: archivo, encoding: .utf8),
              texto.contains("view_style = 'original'") else { return }
        try? texto.replacingOccurrences(of: "view_style = 'original'", with: "view_style = 'adaptive'")
            .write(to: archivo, atomically: true, encoding: .utf8)
    }
    func archivos(_ e: Equipo) { abrirRustDesk(["--file-transfer", e.direccion]) }

    private func abrirRustDesk(_ args: [String]) {
        let bin = URL(fileURLWithPath: "/Applications/RustDesk.app/Contents/MacOS/RustDesk")
        guard FileManager.default.isExecutableFile(atPath: bin.path) else {
            aviso = "No encuentro RustDesk en Aplicaciones. Instálalo con «Instalar Emm Remote - Mac.command»."
            return
        }
        let p = Process()
        p.executableURL = bin
        p.arguments = args
        do { try p.run() } catch { aviso = "No pude abrir RustDesk: \(error.localizedDescription)" }
    }

    func despertar(_ e: Equipo) {
        guard let mac = Red.parsearMAC(e.mac) else {
            aviso = "Falta la MAC de «\(e.nombre)». Edítalo y escríbela (ej. AA:BB:CC:DD:EE:FF)."
            return
        }
        let publica = e.publica.trimmingCharacters(in: .whitespaces)
        let puerto = UInt16(clamping: e.puertoWOL)
        Task.detached {
            let enviados = Red.enviarWOL(mac: mac, ipEquipo: e.direccion)
            let porInternet = publica.isEmpty ? 0 : Red.enviarWOLPorInternet(mac: mac, host: publica, puerto: puerto)
            await MainActor.run {
                if enviados + porInternet == 0 {
                    self.aviso = "No pude enviar la señal de encendido."
                    return
                }
                self.aviso = porInternet > 0
                    ? "Señal enviada a tu casa (\(publica), puerto \(puerto)) y a esta red. Si no prende en 2 minutos, revisa el puerto del router (ver docs/ENCENDIDO-REMOTO.md)."
                    : "Señal enviada solo a esta red: falta la IP pública de la casa de «\(e.nombre)» (se aprende sola cuando el equipo está en línea con Tailscale)."
                self.esperarEncendido(e, restantes: 120)
            }
        }
    }

    /// Mientras un equipo está en línea, Tailscale sabe desde qué IP pública conecta:
    /// la guardamos para poder mandarle la señal de encendido cuando esté apagado.
    private func aprenderIPsPublicas() {
        let direcciones = equipos.map(\.direccion)
        Task.detached {
            let vistas = Red.ipsPublicasTailscale(de: direcciones)
            guard !vistas.isEmpty else { return }
            await MainActor.run {
                for (i, e) in self.equipos.enumerated() {
                    if let ip = vistas[e.direccion], ip != e.publica, !Red.esNombre(e.publica) {
                        self.equipos[i].publica = ip
                    }
                }
            }
        }
    }

    private func esperarEncendido(_ e: Equipo, restantes: Int) {
        estados[e.id] = .despertando(segundos: restantes)
        if restantes <= 0 { estados[e.id] = .sinRespuesta; return }
        let dir = e.direccion
        Task.detached {
            let ok = Red.puertoAbierto(host: dir, puerto: 21118, espera: 2)
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await MainActor.run {
                if ok { self.estados[e.id] = .enLinea; self.aviso = "«\(e.nombre)» ya está en línea." }
                else { self.esperarEncendido(e, restantes: restantes - 5) }
            }
        }
    }

    func abrirTailscale() {
        NSWorkspaceAbrir.app("/Applications/Tailscale.app")
    }

    /// Enciende Tailscale sin abrir su app (la extensión de red sigue instalada en la Mac).
    func conectarTailscale() {
        guard FileManager.default.isExecutableFile(atPath: Self.tailscaleCLI) else {
            aviso = "No encuentro Tailscale en Aplicaciones."
            return
        }
        aviso = "Conectando Tailscale…"
        Task.detached {
            let ok = Self.correrTailscale(["up"], espera: 30)
            await MainActor.run {
                self.encendiTailscale = ok
                self.aviso = ok ? nil : "No pude conectar Tailscale solo. Ábrelo y revisa que tengas sesión iniciada."
                self.actualizar()
            }
        }
    }

    /// Al cerrar Emm Remote: si fue la app la que encendió Tailscale, lo apaga.
    private func alSalir() {
        if encendiTailscale { _ = Self.correrTailscale(["down"], espera: 5) }
    }

    nonisolated static func correrTailscale(_ args: [String], espera: TimeInterval) -> Bool {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: tailscaleCLI)
        p.arguments = args
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        do { try p.run() } catch { return false }
        let limite = Date().addingTimeInterval(espera)
        while p.isRunning && Date() < limite { usleep(100_000) }
        if p.isRunning { p.terminate(); return false }
        return p.terminationStatus == 0
    }
}
