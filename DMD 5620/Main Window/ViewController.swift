//
//  ViewController.swift
//  DMD 5620
//
//  Created by Seth Morabito on 12/22/18.
//  Copyright © 2018 Loom Communications LLC. All rights reserved.
//

import Cocoa

class ViewController: NSViewController {
    var dmd: Dmd?
    lazy var window: NSWindow = self.view.window!
    
    let windowTitleConnectedHead = "DMD 5620 (Connected to "
    let windowTitleConnectedTail = ")"
    let windowTitleDisconnected = "DMD 5620 (Disconnected)"
    
    @IBOutlet weak var dmdView: DmdView?
    
    @IBAction func disconnect(sender: NSMenuItem) {
        dmd?.disconnect()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.window?.title = windowTitleDisconnected

        NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: { (event) in
            if (event.windowNumber == self.window.windowNumber) {
                self.keyDown(with: event)
            }
            return event
        })

        NSEvent.addLocalMonitorForEvents(matching: .mouseMoved, handler: { (event) in
            if (event.windowNumber == self.window.windowNumber) {
                self.mouseMoved(with: event)
            }
            return event
        })
        
        NSEvent.addLocalMonitorForEvents(matching: [.rightMouseDragged, .leftMouseDragged, .otherMouseDragged], handler: { (event) in
            if (event.windowNumber == self.window.windowNumber) {
                self.mouseMoved(with: event)
            }
            return event
        })

        NSEvent.addLocalMonitorForEvents(matching: [.rightMouseDown, .otherMouseDown], handler: { (event) in
            if (event.windowNumber == self.window.windowNumber) {
                self.mouseDown(with: event)
            }
            return event
        })

        NSEvent.addLocalMonitorForEvents(matching: [.rightMouseUp, .otherMouseUp], handler: { (event) in
            if (event.windowNumber == self.window.windowNumber) {
                self.mouseUp(with: event)
            }
            return event
        })

        let appDelegate = NSApplication.shared.delegate as! AppDelegate
        
        dmd = appDelegate.dmd
        dmd?.delegate = self
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    
    override func keyDown(with event: NSEvent) {
        // Return early if this is an OS handled key
        if (event.modifierFlags.contains(.command) || event.modifierFlags.contains(.option)) {
            return
        }

        let chars = event.characters!.utf8.map{ UInt8($0) }
        
        // Match non-ASCII characters
        switch (event.keyCode) {
        case 122: // F1
            dmd?.kbChar(c: 0xe8)
        case 120: // F2
            dmd?.kbChar(c: 0xe9)
        case 99:  // F3
            dmd?.kbChar(c: 0xea)
        case 118: // F4
            dmd?.kbChar(c: 0xeb)
        case 96:  // F5
            dmd?.kbChar(c: 0xec)
        case 97:  // F6
            dmd?.kbChar(c: 0xed)
        case 98:  // F7
            dmd?.kbChar(c: 0xee)
        case 100: // F8
            dmd?.kbChar(c: 0xef)
        case 123: // Left Arrow
            dmd?.kbChar(c: 0x9a)
        case 124: // Right Arrow
            dmd?.kbChar(c: 0x9b)
        case 125: // Down Arrow
            dmd?.kbChar(c: 0x90)
        case 126: // Up Arrow
            dmd?.kbChar(c: 0x92)
        case 101: // F9 - SETUP key
            if (event.modifierFlags.contains(.shift)) {
                dmd?.kbChar(c: 0x8e)
            } else {
                dmd?.kbChar(c: 0xae)
            }
        case 117: // DELETE
            dmd?.kbChar(c: 0xfe)
        case 51:  // BACKSPACE (send control-H)
            dmd?.kbChar(c: 0x08)
        default:
            dmd?.kbChar(c: chars[0])
        }
    }

    override func mouseMoved(with event: NSEvent) {
        if (self.dmdView == nil) {
            return
        }

        let eventLocation = event.locationInWindow

        // If the event location is outside the view's coordinates, ignore it.
        let viewBounds = self.dmdView!.bounds
        let bottomLeft = viewBounds.origin
        let topRight = CGPoint(x: bottomLeft.x + viewBounds.width, y: bottomLeft.y + viewBounds.height)

        if (eventLocation.x < bottomLeft.x || eventLocation.y < bottomLeft.y ||
            eventLocation.x > topRight.x || eventLocation.y > topRight.y) {
            return
        }

        // The 'y' coordinate is always 1 based. macOS is weird.
        dmd_mouse_move(UInt16(eventLocation.x), UInt16(eventLocation.y - 1))
    }
    
    func getMouseButton(event: NSEvent) -> UInt8 {
        // Button events on macOS are weird. Left = 0, Right = 1, Middle = 2
        switch event.buttonNumber {
        case 0:
            return 0
        case 1:
            return 2
        case 2:
            return 1
        default:
            return 0
        }
    }
    
    override func mouseDown(with event: NSEvent) {
        let button = getMouseButton(event: event)
        dmd_mouse_down(button)
    }
    
    override func mouseUp(with event: NSEvent) {
        let button = getMouseButton(event: event)
        dmd_mouse_up(button)
    }
    
    func setDisconnecteTitle() {
        view.window?.title = windowTitleDisconnected
    }
    
    func setConnectedTitle(host: String, port: UInt16) {
        view.window?.title =
            String(format: "\(windowTitleConnectedHead) \(host):\(port)\(windowTitleConnectedTail)", host, port)
    }
}

extension ViewController: DmdProtocol {
    func updateView(_ dmd: Dmd, data: UnsafeMutablePointer<UInt8>) {
        dmdView?.setVideoRam(data: data);
        dmdView?.updateImage()
    }
    
    func telnetConnected(host: String, port: UInt16) {
        let appDelegate = NSApplication.shared.delegate as! AppDelegate
        appDelegate.connectMenuItem.isEnabled = false
        appDelegate.disconnectMenuItem.isEnabled = true
        setConnectedTitle(host: host, port: port)
    }

    func telnetDisconnected(withError err: Error?) {
        let appDelegate = NSApplication.shared.delegate as! AppDelegate
        appDelegate.connectMenuItem.isEnabled = true
        appDelegate.disconnectMenuItem.isEnabled = false
        setDisconnecteTitle()
        
        if (err != nil) {
            let alert: NSAlert = NSAlert(error: err!)
            alert.runModal()
        }
    }
}
