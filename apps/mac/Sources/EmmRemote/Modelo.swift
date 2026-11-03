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

    init() {
        if let data = try? Data(contentsOf: archivo),
           let lista = try? JSONDecoder().decode([Equipo].self, from: data) {
            equipos = lista
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

    func conectar(_ e: Equipo) { abrirRustDesk(["--connect", e.direccion]) }
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
        let enviados = Red.enviarWOL(mac: mac, ipEquipo: e.direccion)
        if enviados == 0 {
            aviso = "No pude enviar la señal de encendido."
            return
        }
        aviso = Red.estoyEnLaRedDe(e.direccion)
            ? nil
            : "Señal enviada. Ojo: si esta Mac no está en la misma red que «\(e.nombre)», la señal no le llega estando apagado (ver README)."
        esperarEncendido(e, restantes: 120)
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
}
