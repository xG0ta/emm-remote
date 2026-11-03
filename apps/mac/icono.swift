// Dibuja el ícono de Emm Remote (1024×1024) con la gota de agua.
// Uso: swift icono.swift salida.png [1|2|3]
//   1 = vidrio: monitor translúcido con gota sobre degradado rojo-vino
//   2 = gota protagonista: gota grande con monitor dentro, fondo oscuro con brillo
//   3 = degradado rojo→azul: monitor blanco con gota blanca
import AppKit

let salida = CommandLine.arguments[1]
let opcion = CommandLine.arguments.count > 2 ? Int(CommandLine.arguments[2]) ?? 1 : 1

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
    NSColor(red: r / 255, green: g / 255, blue: b / 255, alpha: a)
}

let tam: CGFloat = 1024
let img = NSImage(size: NSSize(width: tam, height: tam))
img.lockFocus()
let ctx = NSGraphicsContext.current!

// Cuadro redondeado estilo macOS con sombra suave
let marco = NSRect(x: 100, y: 100, width: 824, height: 824)
let fondo = NSBezierPath(roundedRect: marco, xRadius: 185, yRadius: 185)

func conSombra(_ color: NSColor, desplazamiento: CGFloat, difuminado: CGFloat, _ dibujo: () -> Void) {
    ctx.saveGraphicsState()
    let s = NSShadow()
    s.shadowColor = color
    s.shadowOffset = NSSize(width: 0, height: -desplazamiento)
    s.shadowBlurRadius = difuminado
    s.set()
    dibujo()
    ctx.restoreGraphicsState()
}

func recortado(_ camino: NSBezierPath, _ dibujo: () -> Void) {
    ctx.saveGraphicsState()
    camino.addClip()
    dibujo()
    ctx.restoreGraphicsState()
}

/// Gota: círculo de radio r centrado en c, con la punta arriba.
func gota(centro c: NSPoint, radio r: CGFloat) -> NSBezierPath {
    let p = NSBezierPath()
    let punta = NSPoint(x: c.x, y: c.y + 2.05 * r)
    p.move(to: punta)
    p.curve(to: NSPoint(x: c.x + r, y: c.y),
            controlPoint1: NSPoint(x: c.x + 0.28 * r, y: c.y + 1.45 * r),
            controlPoint2: NSPoint(x: c.x + r, y: c.y + 0.78 * r))
    p.appendArc(withCenter: c, radius: r, startAngle: 0, endAngle: 180, clockwise: true)
    p.curve(to: punta,
            controlPoint1: NSPoint(x: c.x - r, y: c.y + 0.78 * r),
            controlPoint2: NSPoint(x: c.x - 0.28 * r, y: c.y + 1.45 * r))
    p.close()
    return p
}

/// Gota de agua brillante (azul con reflejos), estilo emoji.
func gotaBrillante(centro c: NSPoint, radio r: CGFloat, destello: Bool = true) {
    let g = gota(centro: c, radio: r)
    conSombra(rgb(0, 20, 60, 0.45), desplazamiento: r * 0.12, difuminado: r * 0.3) {
        rgb(40, 140, 255).setFill(); g.fill()
    }
    recortado(g) {
        NSGradient(colors: [rgb(140, 225, 255), rgb(40, 150, 255), rgb(10, 70, 210)],
                   atLocations: [0, 0.55, 1], colorSpace: .deviceRGB)!
            .draw(in: g, relativeCenterPosition: NSPoint(x: -0.35, y: 0.25))
        // Reflejo inferior (luz que rebota)
        rgb(160, 235, 255, 0.4).setFill()
        NSBezierPath(ovalIn: NSRect(x: c.x + 0.05 * r, y: c.y - 0.8 * r, width: 0.55 * r, height: 0.2 * r)).fill()
    }
    // Brillo principal arriba a la izquierda
    let brillo = NSBezierPath(ovalIn: NSRect(x: c.x - 0.62 * r, y: c.y + 0.05 * r, width: 0.34 * r, height: 0.62 * r))
    let t = AffineTransform(translationByX: c.x - 0.45 * r, byY: c.y + 0.36 * r)
    var giro = AffineTransform(translationByX: -(c.x - 0.45 * r), byY: -(c.y + 0.36 * r))
    giro.append(AffineTransform(rotationByDegrees: -25))
    giro.append(t)
    brillo.transform(using: giro)
    rgb(255, 255, 255, 0.85).setFill(); brillo.fill()
    guard destello else { return }
    rgb(255, 255, 255, 0.9).setFill()
    NSBezierPath(ovalIn: NSRect(x: c.x - 0.38 * r, y: c.y + 0.82 * r, width: 0.14 * r, height: 0.14 * r)).fill()
}

/// Monitor: pantalla redondeada + pie. Devuelve el rectángulo de la pantalla.
func caminoMonitor(_ r: NSRect, radio: CGFloat) -> (pantalla: NSBezierPath, pie: NSBezierPath) {
    let pantalla = NSBezierPath(roundedRect: r, xRadius: radio, yRadius: radio)
    let pie = NSBezierPath()
    pie.append(NSBezierPath(roundedRect: NSRect(x: r.midX - 34, y: r.minY - 78, width: 68, height: 90), xRadius: 10, yRadius: 10))
    pie.append(NSBezierPath(roundedRect: NSRect(x: r.midX - 130, y: r.minY - 108, width: 260, height: 40), xRadius: 20, yRadius: 20))
    return (pantalla, pie)
}

/// Brillo de cristal en la mitad superior del fondo.
func brilloSuperior(_ alfa: CGFloat) {
    recortado(fondo) {
        NSGradient(starting: rgb(255, 255, 255, alfa), ending: rgb(255, 255, 255, 0))!
            .draw(in: NSRect(x: 100, y: 512, width: 824, height: 412), angle: -90)
    }
}

switch opcion {
case 2:
    // Fondo casi negro con un resplandor rojo Emm abajo y azul arriba
    NSGradient(starting: rgb(28, 30, 42), ending: rgb(8, 9, 14))!.draw(in: fondo, angle: -90)
    recortado(fondo) {
        NSGradient(starting: rgb(235, 45, 70, 0.75), ending: rgb(235, 45, 70, 0))!
            .draw(fromCenter: NSPoint(x: 512, y: 150), radius: 0, toCenter: NSPoint(x: 512, y: 150), radius: 520, options: [])
        NSGradient(starting: rgb(40, 140, 255, 0.35), ending: rgb(40, 140, 255, 0))!
            .draw(fromCenter: NSPoint(x: 512, y: 760), radius: 0, toCenter: NSPoint(x: 512, y: 760), radius: 420, options: [])
    }
    // Órbita roja alrededor de la gota: «conexión remota»
    let orbita = NSBezierPath(ovalIn: NSRect(x: 190, y: 330, width: 644, height: 300))
    orbita.transform(using: {
        var t = AffineTransform(translationByX: -512, byY: -480)
        t.append(AffineTransform(rotationByDegrees: -18))
        t.append(AffineTransform(translationByX: 512, byY: 480))
        return t
    }())
    orbita.lineWidth = 22
    conSombra(rgb(255, 60, 80, 0.8), desplazamiento: 0, difuminado: 30) {
        rgb(255, 75, 95).setStroke(); orbita.stroke()
    }
    gotaBrillante(centro: NSPoint(x: 512, y: 400), radio: 200, destello: false)
    // La parte de la órbita que pasa por delante
    recortado(NSBezierPath(rect: NSRect(x: 100, y: 100, width: 824, height: 330))) {
        rgb(255, 75, 95).setStroke(); orbita.stroke()
    }
    // Monitor blanco dentro de la gota
    let (pantalla, pie) = caminoMonitor(NSRect(x: 412, y: 400, width: 200, height: 140), radio: 22)
    pie.transform(using: {
        var t = AffineTransform(translationByX: 512, byY: 400)
        t.scale(0.5)
        t.translate(x: -512, y: -400)
        return t
    }())
    conSombra(rgb(0, 30, 90, 0.5), desplazamiento: 6, difuminado: 14) {
        NSColor.white.setStroke(); pantalla.lineWidth = 22; pantalla.stroke()
        NSColor.white.setFill(); pie.fill()
    }
    brilloSuperior(0.07)
case 3:
    // Degradado diagonal rojo Emm → azul gota
    NSGradient(colors: [rgb(255, 70, 85), rgb(200, 40, 120), rgb(40, 110, 245)],
               atLocations: [0, 0.5, 1], colorSpace: .deviceRGB)!.draw(in: fondo, angle: -45)
    brilloSuperior(0.18)
    let r = NSRect(x: 222, y: 400, width: 580, height: 390)
    let (pantalla, pie) = caminoMonitor(r, radio: 60)
    conSombra(rgb(30, 0, 60, 0.35), desplazamiento: 18, difuminado: 40) {
        NSColor.white.setStroke(); pantalla.lineWidth = 46; pantalla.stroke()
        NSColor.white.setFill(); pie.fill()
        gota(centro: NSPoint(x: 512, y: 540), radio: 92).fill()
    }
    // Brillo en la gota blanca
    rgb(120, 90, 220, 0.35).setFill()
    NSBezierPath(ovalIn: NSRect(x: 455, y: 560, width: 34, height: 64)).fill()
default:
    // Degradado rojo-vino con brillo de cristal
    NSGradient(colors: [rgb(255, 92, 102), rgb(214, 30, 60), rgb(110, 12, 48)],
               atLocations: [0, 0.5, 1], colorSpace: .deviceRGB)!.draw(in: fondo, angle: -60)
    recortado(fondo) {
        NSGradient(starting: rgb(255, 180, 160, 0.45), ending: rgb(255, 180, 160, 0))!
            .draw(fromCenter: NSPoint(x: 260, y: 860), radius: 0, toCenter: NSPoint(x: 260, y: 860), radius: 560, options: [])
    }
    let r = NSRect(x: 200, y: 390, width: 624, height: 420)
    let (pantalla, pie) = caminoMonitor(r, radio: 64)
    // Pantalla de vidrio esmerilado
    conSombra(rgb(60, 0, 20, 0.45), desplazamiento: 22, difuminado: 50) {
        rgb(255, 255, 255, 0.16).setFill(); pantalla.fill()
    }
    recortado(pantalla) {
        NSGradient(starting: rgb(255, 255, 255, 0.28), ending: rgb(255, 255, 255, 0.04))!.draw(in: r, angle: -70)
    }
    rgb(255, 255, 255, 0.95).setStroke(); pantalla.lineWidth = 26; pantalla.stroke()
    conSombra(rgb(60, 0, 20, 0.35), desplazamiento: 10, difuminado: 24) {
        rgb(255, 255, 255, 0.95).setFill(); pie.fill()
    }
    gotaBrillante(centro: NSPoint(x: 512, y: 540), radio: 112)
    // Ondas de conexión arriba a la derecha de la pantalla
    for (i, radio) in [CGFloat(40), 82].enumerated() {
        let a = NSBezierPath()
        a.appendArc(withCenter: NSPoint(x: 740, y: 726), radius: radio, startAngle: 5, endAngle: 85)
        a.lineWidth = 20; a.lineCapStyle = .round
        rgb(255, 255, 255, i == 0 ? 0.95 : 0.7).setStroke(); a.stroke()
    }
    rgb(255, 255, 255, 0.95).setFill()
    NSBezierPath(ovalIn: NSRect(x: 726, y: 712, width: 28, height: 28)).fill()
    brilloSuperior(0.10)
}

img.unlockFocus()
let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: salida))
