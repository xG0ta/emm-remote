// Dibuja el ícono de Emm Remote (1024×1024) con la gota de agua.
// Uso: swift icono.swift salida.png [1|2|3]
//   1 = «e» blanca centrada con una gota azul que escurre de su punta, fondo rojo
//   2 = gota azul con la «e» dentro, fondo oscuro
//   3 = monitor de vidrio con la «e» y una gota en la esquina
import AppKit
import CoreText

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

/// La «e» de Emm como trazo vectorial (SF Rounded, muy gruesa), centrada en c con la altura dada.
func letraE(centro c: NSPoint, alto: CGFloat) -> NSBezierPath {
    let base = NSFont.systemFont(ofSize: 1000, weight: .black)
    let fuente = NSFont(descriptor: base.fontDescriptor.withDesign(.rounded) ?? base.fontDescriptor, size: 1000) ?? base
    var unichar: UniChar = 0x65  // «e»
    var glifo: CGGlyph = 0
    CTFontGetGlyphsForCharacters(fuente as CTFont, &unichar, &glifo, 1)
    let p = NSBezierPath()
    p.move(to: .zero)
    p.append(withCGGlyph: glifo, in: fuente)
    let b = p.bounds
    let k = alto / b.height
    var t = AffineTransform(translationByX: c.x, byY: c.y)
    t.scale(k)
    t.translate(x: -b.midX, y: -b.midY)
    p.transform(using: t)
    return p
}

switch opcion {
case 2:
    // Gota azul brillante como ícono completo, con la «e» blanca dentro; fondo oscuro con brillo rojo
    NSGradient(starting: rgb(30, 32, 46), ending: rgb(10, 11, 17))!.draw(in: fondo, angle: -90)
    recortado(fondo) {
        NSGradient(starting: rgb(235, 45, 70, 0.6), ending: rgb(235, 45, 70, 0))!
            .draw(fromCenter: NSPoint(x: 512, y: 130), radius: 0, toCenter: NSPoint(x: 512, y: 130), radius: 520, options: [])
    }
    gotaBrillante(centro: NSPoint(x: 512, y: 375), radio: 245, destello: false)
    let e = letraE(centro: NSPoint(x: 522, y: 350), alto: 215)
    conSombra(rgb(0, 30, 100, 0.45), desplazamiento: 8, difuminado: 18) {
        NSColor.white.setFill(); e.fill()
    }
    brilloSuperior(0.06)
case 3:
    // Pantalla de vidrio con la «e» y una gota que cae de la esquina: monitor + marca Gota
    NSGradient(colors: [rgb(255, 92, 102), rgb(214, 30, 60), rgb(110, 12, 48)],
               atLocations: [0, 0.5, 1], colorSpace: .deviceRGB)!.draw(in: fondo, angle: -60)
    let r = NSRect(x: 190, y: 380, width: 600, height: 420)
    let (pantalla, pie) = caminoMonitor(r, radio: 64)
    conSombra(rgb(60, 0, 20, 0.45), desplazamiento: 22, difuminado: 50) {
        rgb(255, 255, 255, 0.16).setFill(); pantalla.fill()
    }
    recortado(pantalla) {
        NSGradient(starting: rgb(255, 255, 255, 0.28), ending: rgb(255, 255, 255, 0.04))!.draw(in: r, angle: -70)
    }
    rgb(255, 255, 255, 0.95).setStroke(); pantalla.lineWidth = 26; pantalla.stroke()
    conSombra(rgb(60, 0, 20, 0.35), desplazamiento: 10, difuminado: 24) {
        rgb(255, 255, 255, 0.95).setFill(); pie.fill()
        letraE(centro: NSPoint(x: r.midX, y: r.midY), alto: 250).fill()
    }
    gotaBrillante(centro: NSPoint(x: 762, y: 712), radio: 66)
    brilloSuperior(0.10)
default:
    // «e» blanca gigante y una gota azul que escurre de su terminación
    NSGradient(colors: [rgb(255, 92, 102), rgb(214, 30, 60), rgb(110, 12, 48)],
               atLocations: [0, 0.5, 1], colorSpace: .deviceRGB)!.draw(in: fondo, angle: -60)
    recortado(fondo) {
        NSGradient(starting: rgb(255, 180, 160, 0.45), ending: rgb(255, 180, 160, 0))!
            .draw(fromCenter: NSPoint(x: 260, y: 860), radius: 0, toCenter: NSPoint(x: 260, y: 860), radius: 560, options: [])
    }
    // «e» centrada en el ícono y la gota escurriendo de su punta
    let e = letraE(centro: NSPoint(x: 512, y: 520), alto: 500)
    conSombra(rgb(60, 0, 20, 0.45), desplazamiento: 22, difuminado: 45) {
        NSColor.white.setFill(); e.fill()
    }
    recortado(e) {
        NSGradient(starting: rgb(255, 255, 255, 0), ending: rgb(255, 210, 215, 0.6))!.draw(in: e.bounds, angle: -90)
    }
    let b = e.bounds
    let r = CGFloat(62)
    gotaBrillante(centro: NSPoint(x: b.maxX - 0.14 * b.width, y: b.minY + 0.2 * b.height - 2.05 * r), radio: r)
    brilloSuperior(0.10)
}

img.unlockFocus()
let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: salida))
