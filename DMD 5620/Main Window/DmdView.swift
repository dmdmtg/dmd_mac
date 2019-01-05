//
//  DmdView.swift
//  DMD 5620
//
//  Created by Seth Morabito on 12/22/18.
//  Copyright © 2018 Loom Communications LLC. All rights reserved.
//

import Cocoa
import CoreImage

struct Color {
    var r: UInt8
    var g: UInt8
    var b: UInt8
}

extension NSColor {
    func toColorStruct() -> Color {
        if self.colorSpaceName == NSColorSpaceName.calibratedRGB {
            return Color(r: UInt8(self.redComponent * 255.0),
                         g: UInt8(self.greenComponent * 255.0),
                         b: UInt8(self.blueComponent * 255.0))
        } else {
            // We need to convert the colorspace first
            let rgbColor = self.usingColorSpace(NSColorSpace.sRGB)!
            return Color(r: UInt8(rgbColor.redComponent * 255.0),
                         g: UInt8(rgbColor.greenComponent * 255.0),
                         b: UInt8(rgbColor.blueComponent * 255.0))
        }
    }
}

extension Notification.Name {
    static let preferencesUpdate = Notification.Name("preferencesUpdate")
}

class DmdView: NSView {
    @IBOutlet weak var imageView: NSImageView!
    
    var videoRam: Array<UInt8> = Array(repeating: 0, count: 100 * 1024)
    var previousVideoRam: Array<UInt8> = Array(repeating: 0, count: 100 * 1024)
    var raw: Array<UInt8> = Array(repeating: 0, count: 800 * 1024 * 4)
    
    var darkColor = Preferences.defaultDarkColor.toColorStruct()
    var lightColor = Preferences.defaultLightColor.toColorStruct()

    override init(frame: CGRect) {
        super.init(frame: frame)
        addObserver()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        addObserver()
    }
    
    private func addObserver() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(onDidReceivePreferencesUpdate(_:)),
                                               name: .preferencesUpdate,
                                               object: nil)
    }
    
    // We've received notice that the preferences have changed.
    @objc func onDidReceivePreferencesUpdate(_ notification: Notification) {
        let darkColorDefault = Preferences.global.useDefaultDarkColor
        let lightColorDefault = Preferences.global.useDefaultLightColor
        
        if (darkColorDefault) {
            self.darkColor = Preferences.defaultDarkColor.toColorStruct()
        } else {
            self.darkColor = Preferences.global.darkColor!.toColorStruct()
        }

        if (lightColorDefault) {
            self.lightColor = Preferences.defaultLightColor.toColorStruct()
        } else {
            self.lightColor = Preferences.global.lightColor!.toColorStruct()
        }
        
        // Finally, invalidate the image buffer.
        previousVideoRam.removeAll()
    }
    
    func setVideoRam(data: UnsafeMutablePointer<UInt8>) {
        self.videoRam = [UInt8](UnsafeBufferPointer(start: data, count: 100 * 1024))
    }
    
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // We don't capture any Command keys, those belong
        // to the OS.
        if (event.modifierFlags.contains(.command) || event.modifierFlags.contains(.option)) {
            return false
        }
        return true
    }
    
    func updateImage() {
        // Shortcut to avoid over-drawing
        if (previousVideoRam == videoRam) {
            return
        }
        
        previousVideoRam = videoRam
        
        var fromOffset = 0
        var toOffset = 0
        
        var oport: UInt8 = 0
        dmd_get_duart_output_port(&oport)
        
        let fgColor: Color
        let bgColor: Color
        
        if ((oport & 0x2) != 0) {
            fgColor = darkColor
            bgColor = lightColor
        } else {
            fgColor = lightColor
            bgColor = darkColor
        }
        
        for _ in 0 ..< 1024 {
            for _ in 0 ..< 100 {
                let byte = videoRam[fromOffset];
                for i: uint8 in 0..<8 {
                    let bit = (byte >> (7 as uint8 - i)) & 1
                    if (bit == 0) {
                        raw[toOffset] = bgColor.r
                        raw[toOffset + 1] = bgColor.g
                        raw[toOffset + 2] = bgColor.b
                        raw[toOffset + 3] = 255
                    } else {
                        raw[toOffset] = fgColor.r
                        raw[toOffset + 1] = fgColor.g
                        raw[toOffset + 2] = fgColor.b
                        raw[toOffset + 3] = 255
                    }
                    toOffset += 4
                }
                fromOffset += 1
            }
        }
        
        // This weird optional temp is required to satisfy the API of
        // NSBitmapImageRep
        var imgData: UnsafeMutablePointer<UInt8>?
        imgData = UnsafeMutablePointer<UInt8>(&raw)
        let imageRep = NSBitmapImageRep(bitmapDataPlanes: &imgData,
                                        pixelsWide: 800,
                                        pixelsHigh: 1024,
                                        bitsPerSample: 8,
                                        samplesPerPixel: 4,
                                        hasAlpha: true,
                                        isPlanar: false,
                                        colorSpaceName: NSColorSpaceName.deviceRGB,
                                        bitmapFormat: .thirtyTwoBitBigEndian,
                                        bytesPerRow: 4 * 800,
                                        bitsPerPixel: 32)
        let image = NSImage(size: imageRep!.size)
        image.addRepresentation(imageRep!)
        self.imageView.image = image
    }
}
