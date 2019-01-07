//
//  PreferencesViewController.swift
//  DMD 5620
//
//  Created by Seth Morabito on 12/28/18.
//  Copyright © 2018 Loom Communications LLC. All rights reserved.
//

import Cocoa

class PreferencesViewController: NSViewController {
    @IBOutlet var darkColorWell: NSColorWell!
    @IBOutlet var lightColorWell: NSColorWell!
    @IBOutlet var darkColorDefault: NSButton!
    @IBOutlet var lightColorDefault: NSButton!
    @IBOutlet var simulatePhosphor: NSButton!
    @IBOutlet var phosphorPersistence: NSSlider!

    @IBAction func useLightDefaultColor(source: NSButton) {
        lightColorWell.isEnabled = (source.state == .off)
        Preferences.global.useDefaultLightColor = (source.state == .on)
        applyPreferences()
    }

    @IBAction func useDarkDefaultColor(source: NSButton) {
        darkColorWell.isEnabled = (source.state == .off)
        Preferences.global.useDefaultDarkColor = (source.state == .on)
        applyPreferences()
    }

    @IBAction func lightColorChanged(source: NSColorWell) {
        Preferences.global.lightColor = source.color
        applyPreferences()
    }

    @IBAction func darkColorChanged(source: NSColorWell) {
        Preferences.global.darkColor = source.color
        applyPreferences()
    }

    @IBAction func simulatePhosphorChanged(source: NSButton) {
        if (source.state == .on) {
            Preferences.global.simulatePhosphor = true
            phosphorPersistence.isEnabled = true
        } else {
            Preferences.global.simulatePhosphor = false
            phosphorPersistence.isEnabled = false
        }
        applyPreferences()
    }

    @IBAction func phosphorPersistenceChanged(source: NSSlider) {
        Preferences.global.phosphorPersistence = source.integerValue
        applyPreferences()
    }

    @IBAction func closeWindow(source: NSMenuItem) {
        self.view.window?.performClose(source)
    }

    func applyPreferences() {
        NotificationCenter.default.post(name: .preferencesUpdate, object: nil)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        lightColorWell.color = Preferences.global.lightColor!
        darkColorWell.color = Preferences.global.darkColor!

        if (Preferences.global.useDefaultDarkColor) {
            darkColorDefault.state = .on
            darkColorWell.isEnabled = false
        } else {
            darkColorDefault.state = .off
            darkColorWell.isEnabled = true
        }

        if (Preferences.global.useDefaultLightColor) {
            lightColorDefault.state = .on
            lightColorWell.isEnabled = false
        } else {
            lightColorDefault.state = .off
            lightColorWell.isEnabled = true
        }

        phosphorPersistence.integerValue = Preferences.global.phosphorPersistence

        if (Preferences.global.simulatePhosphor) {
            simulatePhosphor.state = .on
            phosphorPersistence.isEnabled = true
        } else {
            simulatePhosphor.state = .off
            phosphorPersistence.isEnabled = false
        }
    }
}

