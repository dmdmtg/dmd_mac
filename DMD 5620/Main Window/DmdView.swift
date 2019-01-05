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
    @IBOutlet weak var imageView: NSImageView!

    var lastVideoRam: Array<UInt8>?
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
        var toOffset = 0
        var fadeOffset = 0

        for _ in 0 ..< 1024 {
            for _ in 0 ..< 100 {
                let byte = videoRam[fromOffset];
                for i: uint8 in 0..<8 {
                    let bit = (byte >> (7 as uint8 - i)) & 1
                    if (bit == 0) {
                        if (bgColor == lightColor) {
                            fadeMap[fadeOffset] = 1.0
                            raw[toOffset] = bgColor.r
                            raw[toOffset + 1] = bgColor.g
                            raw[toOffset + 2] = bgColor.b
                        } else {
                            raw[toOffset] = fgColor.rFadedToward(percent: fadeMap[fadeOffset], to: bgColor)
                            raw[toOffset + 1] = fgColor.gFadedToward(percent: fadeMap[fadeOffset], to: bgColor)
                            raw[toOffset + 2] = fgColor.bFadedToward(percent: fadeMap[fadeOffset], to: bgColor)
                            if (fadeMap[fadeOffset] > 0.2) {
                                fadeMap[fadeOffset] *= 0.65
                            } else {
                                fadeMap[fadeOffset] = 0.0
                            }
                        }
                        raw[toOffset + 3] = 255
                    } else {
                        fadeMap[fadeOffset] = 1.0
                        raw[toOffset] = fgColor.r
                        raw[toOffset + 1] = fgColor.g
                        raw[toOffset + 2] = fgColor.b
                        raw[toOffset + 3] = 255
                    }
                    fadeOffset += 1
                    toOffset += 4
                }
                fromOffset += 1
            }
        }
    }

    private func redrawRawWithoutFade(fgColor: DmdColor, bgColor: DmdColor) {
        var fromOffset = 0
        var toOffset = 0

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
            if (self.videoRam == self.lastVideoRam) {
                return
            }
            redrawRawWithoutFade(fgColor: fgColor, bgColor: bgColor)
        }

        lastVideoRam = videoRam

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

