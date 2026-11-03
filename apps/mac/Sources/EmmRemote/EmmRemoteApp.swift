import SwiftUI

@main
struct EmmRemoteApp: App {
    @StateObject private var almacen = Almacen()

    var body: some Scene {
        WindowGroup("Emm Remote") {
            Principal()
                .environmentObject(almacen)
                .frame(minWidth: 460, minHeight: 360)
        }
        .windowResizability(.contentSize)

        MenuBarExtra("Emm Remote", systemImage: "display") {
            ForEach(almacen.equipos) { e in
                Menu(e.nombre) {
                    Button("Conectar") { almacen.conectar(e) }
                    Button("Archivos") { almacen.archivos(e) }
                    Button("Despertar") { almacen.despertar(e) }.disabled(e.mac.isEmpty)
                }
            }
            Divider()
            Button("Salir") { NSApp.terminate(nil) }
        }
    }
}

let colorEmm = Color(red: 0.86, green: 0.16, blue: 0.20)

struct Principal: View {
    @EnvironmentObject var almacen: Almacen
    @State private var editando: Equipo? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            encabezado
            Divider()
            if almacen.equipos.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "display.2").font(.system(size: 40)).foregroundStyle(.secondary)
                    Text("Agrega tu primer equipo").font(.headline)
                    Text("Necesitas su IP de Tailscale (100.x.y.z).").foregroundStyle(.secondary)
                    Button("Agregar equipo") { editando = Equipo(nombre: "", direccion: "") }
                        .buttonStyle(.borderedProminent).tint(colorEmm)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(almacen.equipos) { e in
                            Tarjeta(equipo: e, estado: almacen.estados[e.id] ?? .revisando) { editando = e }
                        }
                    }
                    .padding(16)
                }
            }
            if let aviso = almacen.aviso {
                HStack(alignment: .top) {
                    Image(systemName: "info.circle")
                    Text(aviso).fixedSize(horizontal: false, vertical: true)
                    Spacer()
                    Button { almacen.aviso = nil } label: { Image(systemName: "xmark") }.buttonStyle(.plain)
                }
                .font(.callout)
                .padding(10)
                .background(.yellow.opacity(0.15))
            }
        }
        .sheet(item: $editando) { e in
            Editor(original: e).environmentObject(almacen)
        }
    }

    private var encabezado: some View {
        HStack(spacing: 10) {
            Image(systemName: "display").font(.title2).foregroundStyle(colorEmm)
            VStack(alignment: .leading, spacing: 2) {
                Text("Emm Remote").font(.title2.bold())
                if let ip = almacen.tailscaleIP {
                    Label("Tailscale conectado · \(ip)", systemImage: "checkmark.shield.fill")
                        .font(.caption).foregroundStyle(.green)
                } else {
                    HStack(spacing: 6) {
                        Label("Tailscale apagado: fuera de casa no vas a poder conectarte",
                              systemImage: "exclamationmark.triangle.fill")
                            .font(.caption).foregroundStyle(.orange)
                        Button("Abrir Tailscale") { almacen.abrirTailscale() }
                            .controlSize(.small)
                    }
                }
            }
            Spacer()
            Button { almacen.actualizar() } label: { Image(systemName: "arrow.clockwise") }
                .help("Revisar de nuevo")
            Button { editando = Equipo(nombre: "", direccion: "") } label: { Image(systemName: "plus") }
                .help("Agregar equipo")
        }
        .padding(16)
    }
}

struct Tarjeta: View {
    @EnvironmentObject var almacen: Almacen
    let equipo: Equipo
    let estado: Estado
    let editar: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "desktopcomputer")
                .font(.system(size: 30))
                .foregroundStyle(estado == .enLinea ? colorEmm : .secondary)
                .frame(width: 44)
            VStack(alignment: .leading, spacing: 4) {
                Text(equipo.nombre).font(.headline)
                HStack(spacing: 6) {
                    Circle().fill(colorEstado).frame(width: 8, height: 8)
                    Text(textoEstado).font(.caption).foregroundStyle(.secondary)
                }
                Text(equipo.publica.isEmpty ? equipo.direccion : "\(equipo.direccion) · casa \(equipo.publica)")
                    .font(.caption.monospaced()).foregroundStyle(.tertiary)
            }
            Spacer()
            if estado == .enLinea {
                Button("Archivos") { almacen.archivos(equipo) }
                Button("Conectar") { almacen.conectar(equipo) }
                    .buttonStyle(.borderedProminent).tint(colorEmm)
                    .keyboardShortcut(.defaultAction)
            } else {
                Button {
                    almacen.despertar(equipo)
                } label: { Label("Despertar", systemImage: "power") }
                    .buttonStyle(.borderedProminent).tint(colorEmm)
                    .disabled(equipo.mac.isEmpty || { if case .despertando = estado { return true }; return false }())
                    .help(equipo.mac.isEmpty ? "Agrega la MAC del equipo para encenderlo" : "Enviar señal Wake-on-LAN")
            }
            Menu {
                Button("Editar…", action: editar)
                Button("Despertar (Wake-on-LAN)") { almacen.despertar(equipo) }.disabled(equipo.mac.isEmpty)
                Divider()
                Button("Quitar", role: .destructive) { almacen.equipos.removeAll { $0.id == equipo.id } }
            } label: { Image(systemName: "ellipsis.circle") }
                .menuStyle(.borderlessButton).frame(width: 28)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.2)))
    }

    private var colorEstado: Color {
        switch estado {
        case .enLinea: return .green
        case .revisando: return .gray
        case .sinRespuesta: return .red
        case .despertando: return .orange
        }
    }

    private var textoEstado: String {
        switch estado {
        case .enLinea: return "En línea"
        case .revisando: return "Revisando…"
        case .sinRespuesta: return "Apagado o sin conexión"
        case .despertando(let s): return "Despertando… (\(s) s)"
        }
    }
}

struct Editor: View {
    @EnvironmentObject var almacen: Almacen
    @Environment(\.dismiss) private var cerrar
    let original: Equipo
    @State private var e: Equipo

    init(original: Equipo) {
        self.original = original
        _e = State(initialValue: original)
    }

    private var esNuevo: Bool { !almacen.equipos.contains { $0.id == original.id } }
    private var valido: Bool {
        !e.nombre.trimmingCharacters(in: .whitespaces).isEmpty && Red.numero(e.direccion) != nil
            && (e.mac.isEmpty || Red.parsearMAC(e.mac) != nil)
            && (1...65535).contains(e.puertoWOL)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(esNuevo ? "Agregar equipo" : "Editar equipo").font(.title3.bold())
            Form {
                TextField("Nombre", text: $e.nombre, prompt: Text("PC Casa"))
                TextField("IP de Tailscale", text: $e.direccion, prompt: Text("100.x.y.z"))
                TextField("MAC (para encenderlo)", text: $e.mac, prompt: Text("AA:BB:CC:DD:EE:FF"))
                TextField("IP pública de su casa", text: $e.publica, prompt: Text("Se llena sola · o un nombre DDNS"))
                TextField("Puerto del router", value: $e.puertoWOL, format: .number.grouping(.never))
            }
            Text("La IP la ves en la app de Tailscale. La MAC, en Windows con «getmac /v» (la de la tarjeta por cable). La IP pública se aprende sola mientras el equipo está en línea; el puerto es el que abriste en el router para encenderlo desde fuera.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button("Cancelar") { cerrar() }.keyboardShortcut(.cancelAction)
                Button("Guardar") {
                    if let i = almacen.equipos.firstIndex(where: { $0.id == e.id }) { almacen.equipos[i] = e }
                    else { almacen.equipos.append(e) }
                    almacen.actualizar()
                    cerrar()
                }
                .keyboardShortcut(.defaultAction).disabled(!valido)
            }
        }
        .padding(20)
        .frame(width: 420)
    }
}
