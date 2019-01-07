//
//  Preferences.swift
//  DMD 5620
//
//  Created by Seth Morabito on 12/28/18.
//  Copyright © 2018 Loom Communications LLC. All rights reserved.
//

import Foundation
import Cocoa

extension NSColor {
    func toData() -> Data? {
        do {
            if #available(OSX 10.13, *) {
                return try NSKeyedArchiver.archivedData(withRootObject: self, requiringSecureCoding: false)
            } else {
                return NSArchiver.archivedData(withRootObject: self)
            }
        } catch {
            return nil
        }
    }

    static func fromData(data: Data) -> NSColor? {
        do {
            if #available(OSX 10.13, *) {
                return try NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data)
            } else {
                return NSUnarchiver.unarchiveObject(with: data) as? NSColor
            }
        } catch {
            return nil
        }
    }
}

class Preferences {
    private var settings: UserDefaults = UserDefaults.standard

    public static let defaultLightColor = NSColor(calibratedRed: 0.0, green: 0.98, blue: 0.0, alpha: 1.0)
    public static let defaultDarkColor = NSColor(calibratedRed: 0.15, green: 0.15, blue: 0.15, alpha: 1.0)
    public static let defaultPhosphorPersistence = 85
    public static let lightColorDefaultKey = "dmd.lightcolor.default"
    public static let darkColorDefaultKey = "dmd.darkcolor.default"
    public static let lightColorKey = "dmd.lightcolor.color"
    public static let darkColorKey = "dmd.darkcolor.color"
    public static let simulatePhosphorKey = "dmd.phosphor.enabled"
    public static let phosphorPersistenceKey = "dmd.phosphor.amount"

    public static let global = Preferences()

    private init() {
        settings.register(defaults: [Preferences.lightColorDefaultKey : true])
        settings.register(defaults: [Preferences.darkColorDefaultKey : true])
        settings.register(defaults: [Preferences.lightColorKey : Preferences.defaultLightColor.toData()!])
        settings.register(defaults: [Preferences.darkColorKey : Preferences.defaultDarkColor.toData()!])
        settings.register(defaults: [Preferences.simulatePhosphorKey : false])
        settings.register(defaults: [Preferences.phosphorPersistenceKey : Preferences.defaultPhosphorPersistence])
    }

    var lightColor: NSColor? {
        get {
            let data = settings.data(forKey: Preferences.lightColorKey)

            if (data != nil) {
                return NSColor.fromData(data: data!)
            } else {
                return nil
            }
        }
        set(color) {
            let data = color?.toData()

            if (data != nil) {
                settings.set(data, forKey: Preferences.lightColorKey)
                settings.synchronize()
            }
        }
    }

    var darkColor: NSColor? {
        get {
            let data = settings.data(forKey: Preferences.darkColorKey)

            if (data != nil) {
                return NSColor.fromData(data: data!)
            } else {
                return nil
            }
        }
        set(color) {
            let data = color?.toData()

            if (data != nil) {
                settings.set(data, forKey: Preferences.darkColorKey)
                settings.synchronize()
            }
        }
    }

    var useDefaultLightColor: Bool {
        get {
            return settings.bool(forKey: Preferences.lightColorDefaultKey)
        }
        set(val) {
            settings.set(val, forKey: Preferences.lightColorDefaultKey)
            settings.synchronize()
        }
    }

    var useDefaultDarkColor: Bool {
        get {
            return settings.bool(forKey: Preferences.darkColorDefaultKey)
        }
        set(val) {
            settings.set(val, forKey: Preferences.darkColorDefaultKey)
            settings.synchronize()
        }
    }

    var simulatePhosphor: Bool {
        get {
            return settings.bool(forKey: Preferences.simulatePhosphorKey)
        }
        set(val) {
            settings.set(val, forKey: Preferences.simulatePhosphorKey)
            settings.synchronize()
        }
    }

    var phosphorPersistence: Int {
        get {
            return settings.integer(forKey: Preferences.phosphorPersistenceKey)
        }
        set(val) {
            settings.set(val, forKey: Preferences.phosphorPersistenceKey)
            settings.synchronize()
        }
    }
}

