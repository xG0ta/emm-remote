// Dibuja el ícono de Emm Remote (1024×1024).
// Uso: swift icono.swift salida.png [1|2|3]
//   1 = monitor con señal remota (rojo)   2 = puntero sobre pantalla (rojo)   3 = encendido remoto (oscuro)
import AppKit

let salida = CommandLine.arguments[1]
let opcion = CommandLine.arguments.count > 2 ? Int(CommandLine.arguments[2]) ?? 1 : 1

let tam: CGFloat = 1024
let rojoClaro = NSColor(red: 0.95, green: 0.26, blue: 0.27, alpha: 1)
let rojoOscuro = NSColor(red: 0.62, green: 0.07, blue: 0.13, alpha: 1)

let img = NSImage(size: NSSize(width: tam, height: tam))
img.lockFocus()

// Fondo: cuadro redondeado estilo macOS (824 px con margen, radio ~185)
let marco = NSRect(x: 100, y: 100, width: 824, height: 824)
let fondo = NSBezierPath(roundedRect: marco, xRadius: 185, yRadius: 185)
if opcion == 3 {
    NSGradient(starting: NSColor(red: 0.16, green: 0.17, blue: 0.22, alpha: 1),
               ending: NSColor(red: 0.06, green: 0.06, blue: 0.09, alpha: 1))!.draw(in: fondo, angle: -90)
} else {
    NSGradient(starting: rojoClaro, ending: rojoOscuro)!.draw(in: fondo, angle: -90)
}

func monitor(_ r: NSRect, grosor: CGFloat, color: NSColor) {
    color.setStroke(); color.setFill()
    let p = NSBezierPath(roundedRect: r, xRadius: 46, yRadius: 46)
    p.lineWidth = grosor
    p.stroke()
    let base = NSBezierPath()
    base.lineWidth = grosor
    base.lineCapStyle = .round
    base.move(to: NSPoint(x: r.midX, y: r.minY - grosor / 2))
    base.line(to: NSPoint(x: r.midX, y: r.minY - 70))
    base.move(to: NSPoint(x: r.midX - 110, y: r.minY - 80))
    base.line(to: NSPoint(x: r.midX + 110, y: r.minY - 80))
    base.stroke()
}

func arco(centro: NSPoint, radio: CGFloat, grosor: CGFloat, color: NSColor, desde: CGFloat, hasta: CGFloat) {
    color.setStroke()
    let a = NSBezierPath()
    a.appendArc(withCenter: centro, radius: radio, startAngle: desde, endAngle: hasta)
    a.lineWidth = grosor
    a.lineCapStyle = .round
    a.stroke()
}

switch opcion {
case 2:
    // Pantalla blanca rellena y puntero rojo encima: «tomo el control»
    let r = NSRect(x: 222, y: 380, width: 580, height: 400)
    monitor(r, grosor: 48, color: .white)
    NSColor.white.setFill()
    NSBezierPath(roundedRect: r.insetBy(dx: 40, dy: 40), xRadius: 20, yRadius: 20).fill()
    let puntero = NSBezierPath()
    let o = NSPoint(x: 445, y: 712)  // punta
    let k: CGFloat = 0.78
    puntero.move(to: o)
    for (dx, dy) in [(0, -300), (72, -232), (128, -346), (180, -322), (124, -210), (220, -210)] as [(CGFloat, CGFloat)] {
        puntero.line(to: NSPoint(x: o.x + dx * k, y: o.y + dy * k))
    }
    puntero.close()
    puntero.lineJoinStyle = .round
    rojoOscuro.setFill(); puntero.fill()
    NSColor.white.setStroke(); puntero.lineWidth = 18; puntero.stroke()
case 3:
    // Monitor blanco con botón de encendido rojo: «despiértala desde lejos»
    let r = NSRect(x: 222, y: 380, width: 580, height: 400)
    monitor(r, grosor: 48, color: .white)
    let c = NSPoint(x: r.midX, y: r.midY)
    arco(centro: c, radio: 112, grosor: 44, color: rojoClaro, desde: 125, hasta: 415)
    rojoClaro.setStroke()
    let barra = NSBezierPath()
    barra.lineWidth = 44; barra.lineCapStyle = .round
    barra.move(to: NSPoint(x: c.x, y: c.y + 30)); barra.line(to: NSPoint(x: c.x, y: c.y + 150))
    barra.stroke()
default:
    // Monitor blanco con ondas de señal arriba a la derecha: «conexión a distancia»
    let r = NSRect(x: 200, y: 340, width: 540, height: 380)
    monitor(r, grosor: 48, color: .white)
    let estilo = NSMutableParagraphStyle(); estilo.alignment = .center
    NSAttributedString(string: "e", attributes: [
        .font: NSFont.systemFont(ofSize: 300, weight: .heavy),
        .foregroundColor: NSColor.white,
        .paragraphStyle: estilo,
    ]).draw(in: NSRect(x: r.minX, y: r.minY + 2, width: r.width, height: 360))
    let c = NSPoint(x: 690, y: 650)
    for (i, radio) in [CGFloat(55), 115, 175].enumerated() {
        arco(centro: c, radio: radio, grosor: 40, color: NSColor.white.withAlphaComponent(i == 0 ? 1 : 0.85),
             desde: 10, hasta: 80)
    }
    NSColor.white.setFill()
    NSBezierPath(ovalIn: NSRect(x: c.x - 26, y: c.y - 26, width: 52, height: 52)).fill()
}

img.unlockFocus()
let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: salida))
