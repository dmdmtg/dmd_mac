//
//  DmdView.swift
//  DMD 5620
//
//  Created by Seth Morabito on 12/22/18.
//  Copyright © 2018 Loom Communications LLC. All rights reserved.
//

import Cocoa
import CoreImage

struct DmdColor {
    let r: UInt8
    let g: UInt8
    let b: UInt8

    func rFadedToward(percent: CGFloat, to: DmdColor) -> UInt8 {
        if (percent < 0.1) {
            return to.r
        }

        let fromRed = CGFloat(self.r)
        let toRed = CGFloat(to.r)

        return UInt8(((1.0 - percent) * (toRed - fromRed)) + fromRed)
    }

    func gFadedToward(percent: CGFloat, to: DmdColor) -> UInt8 {
        if (percent < 0.1) {
            return to.g
        }

        let fromGreen = CGFloat(self.g)
        let toGreen = CGFloat(to.g)

        return UInt8(((1.0 - percent) * (toGreen - fromGreen)) + fromGreen)
    }

    func bFadedToward(percent: CGFloat, to: DmdColor) -> UInt8 {
        if (percent < 0.1) {
            return to.b
        }

        let fromBlue = CGFloat(self.b)
        let toBlue = CGFloat(to.b)

        return UInt8(((1.0 - percent) * (toBlue - fromBlue)) + fromBlue)
    }
}

extension DmdColor: Equatable {
    static func == (lhs: DmdColor, rhs: DmdColor) -> Bool {
        return lhs.r == rhs.r && lhs.g == rhs.g && lhs.b == rhs.b
    }
}

extension NSColor {
    func asDmdColor() -> DmdColor {
        if (self.colorSpaceName == .calibratedRGB) {
            return DmdColor(r: UInt8(self.redComponent * 255.0),
                            g: UInt8(self.greenComponent * 255.0),
                            b: UInt8(self.blueComponent * 255.0))
        } else {
            let rgbColor = self.usingColorSpace(.sRGB)!
            return DmdColor(r: UInt8(rgbColor.redComponent * 255.0),
                            g: UInt8(rgbColor.greenComponent * 255.0),
                            b: UInt8(rgbColor.blueComponent * 255.0))
        }
    }
}

extension Notification.Name {
    static let preferencesUpdate = Notification.Name("preferencesUpdate")
}

class DmdView: NSView {
    var videoRam: Array<UInt8> = Array(repeating: 0, count: 100 * 1024)
    var raw: Array<UInt8> = Array(repeating: 0, count: 800 * 1024 * 4)

    // A map of pixels to fade amount. A value of 0.0 means background color.
    // A value of 1.0 means foreground color. Any value between means a fade
    // from foreground to background of that percent.
    var fadeMap: Array<CGFloat> = Array(repeating: 0, count: 800 * 1024)

    var darkColor = Preferences.defaultDarkColor.asDmdColor()
    var lightColor = Preferences.defaultLightColor.asDmdColor()
    var simulatePhosphor = false

    var imageChanged = false
    var preferencesUpdated = false

    var ioSurface: IOSurface!

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonSetup()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonSetup()
    }

    private func commonSetup() {

        var pixelFormat: UInt32 = 0
        for c in "RGBA".utf8 {
            pixelFormat *= 256
            pixelFormat += UInt32(c)
        }

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(onDidReceivePreferencesUpdate(_:)),
                                               name: .preferencesUpdate,
                                               object: nil)

        if #available(OSX 10.14, *) {
            ioSurface = IOSurface(properties: [.width: 800,
                                               .height: 1024,
                                               .bytesPerElement: 4,
                                               .bytesPerRow: 800 * 4,
                                               .allocSize: 800 * 1024 * 4,
                                               .pixelFormat: pixelFormat])
        } else {
            ioSurface = IOSurface(properties: [.width: 800,
                                               .height: 1024,
                                               .bytesPerElement: 4,
                                               .bytesPerRow: 800 * 4,
                                               .pixelFormat: pixelFormat])
        }

        self.wantsLayer = true
        self.layer!.shouldRasterize = true
        self.layer!.contents = ioSurface
    }

    // We've received notice that the preferences have changed.
    @objc func onDidReceivePreferencesUpdate(_ notification: Notification) {
        let darkColorDefault = Preferences.global.useDefaultDarkColor
        let lightColorDefault = Preferences.global.useDefaultLightColor

        if (darkColorDefault) {
            self.darkColor = Preferences.defaultDarkColor.asDmdColor()
        } else {
            self.darkColor = Preferences.global.darkColor!.asDmdColor()
        }

        if (lightColorDefault) {
            self.lightColor = Preferences.defaultLightColor.asDmdColor()
        } else {
            self.lightColor = Preferences.global.lightColor!.asDmdColor()
        }

        self.simulatePhosphor = Preferences.global.simulatePhosphor

        if (self.simulatePhosphor) {
            // Reset the state of the fade map
            for i in 0 ..< fadeMap.count {
                fadeMap[i] = 0.0
            }
        }

        self.preferencesUpdated = true
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

    private func needsRedraw() -> Bool {
        if (preferencesUpdated) {
            preferencesUpdated = false
            return true
        }

        if (imageChanged) {
            imageChanged = false
            return true
        }

        return false
    }

    private func redrawRawWithFade(fgColor: DmdColor, bgColor: DmdColor) {
        var fromOffset = 0
        var fadeOffset = 0

        var seed: UInt32 = 0

        ioSurface.lock(options: [], seed: &seed)

        var buf = ioSurface.baseAddress

        for _ in 0 ..< 1024 {
            for _ in 0 ..< 100 {
                let byte = videoRam[fromOffset];
                for i: uint8 in 0..<8 {
                    let bit = (byte >> (7 as uint8 - i)) & 1
                    if (bit == 0) {
                        if (bgColor == lightColor) {
                            fadeMap[fadeOffset] = 1.0
                            buf.storeBytes(of: bgColor.r, as: UInt8.self)
                            buf += 1
                            buf.storeBytes(of: bgColor.g, as: UInt8.self)
                            buf += 1
                            buf.storeBytes(of: bgColor.b, as: UInt8.self)
                            buf += 1
                        } else {
                            buf.storeBytes(of: fgColor.rFadedToward(percent: fadeMap[fadeOffset], to: bgColor), as: UInt8.self)
                            buf += 1
                            buf.storeBytes(of: fgColor.gFadedToward(percent: fadeMap[fadeOffset], to: bgColor), as: UInt8.self)
                            buf += 1
                            buf.storeBytes(of: fgColor.bFadedToward(percent: fadeMap[fadeOffset], to: bgColor), as: UInt8.self)
                            buf += 1
                            if (fadeMap[fadeOffset] > 0.05) {
                                fadeMap[fadeOffset] *= 0.90
                            } else {
                                fadeMap[fadeOffset] = 0.0
                            }
                        }
                        buf.storeBytes(of: 255, as: UInt8.self)
                        buf += 1
                    } else {
                        fadeMap[fadeOffset] = 1.0
                        buf.storeBytes(of: fgColor.r, as: UInt8.self)
                        buf += 1
                        buf.storeBytes(of: fgColor.g, as: UInt8.self)
                        buf += 1
                        buf.storeBytes(of: fgColor.b, as: UInt8.self)
                        buf += 1
                        buf.storeBytes(of: 255, as: UInt8.self)
                        buf += 1
                    }
                    fadeOffset += 1
                }
                fromOffset += 1
            }
        }

        ioSurface.unlock(options: [], seed: &seed)
    }

    private func redrawRawWithoutFade(fgColor: DmdColor, bgColor: DmdColor) {
        var seed: UInt32 = 0

        ioSurface.lock(options: [], seed: &seed)

        var buf = ioSurface.baseAddress

        var fromOffset = 0

        for _ in 0 ..< 1024 {
            for _ in 0 ..< 100 {
                let byte = videoRam[fromOffset];
                for i: uint8 in 0..<8 {
                    let bit = (byte >> (7 as uint8 - i)) & 1
                    if (bit == 0) {
                        buf.storeBytes(of: bgColor.r, as: UInt8.self)
                        buf += 1
                        buf.storeBytes(of: bgColor.g, as: UInt8.self)
                        buf += 1
                        buf.storeBytes(of: bgColor.b, as: UInt8.self)
                        buf += 1
                        buf.storeBytes(of: 255, as: UInt8.self)
                        buf += 1
                    } else {
                        buf.storeBytes(of: fgColor.r, as: UInt8.self)
                        buf += 1
                        buf.storeBytes(of: fgColor.g, as: UInt8.self)
                        buf += 1
                        buf.storeBytes(of: fgColor.b, as: UInt8.self)
                        buf += 1
                        buf.storeBytes(of: 255, as: UInt8.self)
                        buf += 1
                    }
                }
                fromOffset += 1
            }
        }

        ioSurface.unlock(options: [], seed: &seed)
    }

    func updateImage() {
        var oport: UInt8 = 0
        dmd_get_duart_output_port(&oport)

        let fgColor: DmdColor
        let bgColor: DmdColor

        if ((oport & 0x2) != 0) {
            fgColor = darkColor
            bgColor = lightColor
        } else {
            fgColor = lightColor
            bgColor = darkColor
        }

        if (self.simulatePhosphor) {
            redrawRawWithFade(fgColor: fgColor, bgColor: bgColor)
        } else {
            redrawRawWithoutFade(fgColor: fgColor, bgColor: bgColor)
        }

        // To force the update of the layer, we have to clear out
        // the contents and reset them. Crazy! Apple is CRAZY!
        self.layer?.contents = nil
        self.layer?.contents = ioSurface
    }
}
