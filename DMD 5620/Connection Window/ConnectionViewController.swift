//
//  ConnectionViewController.swift
//  DMD 5620
//
//  Created by Seth Morabito on 12/23/18.
//  Copyright © 2018 Loom Communications LLC. All rights reserved.
//

import Cocoa

class ConnectionViewController: NSViewController {
    @IBOutlet weak var hostName: NSTextField!
    @IBOutlet weak var port: NSTextField!
    @IBOutlet weak var connectButton: NSButton!
    @IBOutlet weak var cancelButton: NSButton!

    @IBAction func connect(sender: NSButton) {
        let h = hostName.stringValue.trimmingCharacters(in: NSCharacterSet.whitespacesAndNewlines)
        let p = UInt16(port.intValue)

        if (h.isEmpty || p == 0) {
            let alert = NSAlert()
            alert.messageText = "Cannot Connect"
            alert.informativeText = "Host and Port are both required"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }

        let appDelegate = NSApplication.shared.delegate as! AppDelegate
        appDelegate.dmd.connect(host: h, port: p)
        appDelegate.connectMenuItem.isEnabled = false
        appDelegate.disconnectMenuItem.isEnabled = true
        self.view.window?.close()
    }

    @IBAction func cancel(sender: NSButton) {
        self.view.window?.close()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let appDelegate = NSApplication.shared.delegate as! AppDelegate
        appDelegate.connectMenuItem.isEnabled = false
    }

    override func viewDidDisappear() {
        super.viewDidDisappear()
        let appDelegate = NSApplication.shared.delegate as! AppDelegate
        if (!appDelegate.disconnectMenuItem.isEnabled) {
            appDelegate.connectMenuItem.isEnabled = true
        }
    }
}

