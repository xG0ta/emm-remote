// Dibuja el ícono de Emm Remote (1024×1024): fondo rojo Emm, monitor blanco y una «e».
import AppKit

let tam: CGFloat = 1024
let img = NSImage(size: NSSize(width: tam, height: tam))
img.lockFocus()
let fondo = NSBezierPath(roundedRect: NSRect(x: 64, y: 64, width: 896, height: 896), xRadius: 200, yRadius: 200)
NSGradient(starting: NSColor(red: 0.92, green: 0.22, blue: 0.24, alpha: 1),
           ending: NSColor(red: 0.62, green: 0.08, blue: 0.14, alpha: 1))!.draw(in: fondo, angle: -90)

NSColor.white.setStroke()
let pantalla = NSBezierPath(roundedRect: NSRect(x: 232, y: 360, width: 560, height: 380), xRadius: 40, yRadius: 40)
pantalla.lineWidth = 44
pantalla.stroke()
NSColor.white.setFill()
NSBezierPath(roundedRect: NSRect(x: 452, y: 258, width: 120, height: 100), xRadius: 10, yRadius: 10).fill()
NSBezierPath(roundedRect: NSRect(x: 352, y: 220, width: 320, height: 48), xRadius: 24, yRadius: 24).fill()

let estilo = NSMutableParagraphStyle(); estilo.alignment = .center
let texto = NSAttributedString(string: "e", attributes: [
    .font: NSFont.systemFont(ofSize: 300, weight: .heavy),
    .foregroundColor: NSColor.white,
    .paragraphStyle: estilo,
])
texto.draw(in: NSRect(x: 232, y: 370, width: 560, height: 360))
img.unlockFocus()

let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
