//
//  AppDelegate.swift
//  DMD 5620
//
//  Created by Seth Morabito on 12/22/18.
//  Copyright © 2018 Loom Communications LLC. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    let NVRAM_SIZE = 8192
    let NVRAM_NAME = "nvram.bin"
    
    @IBOutlet var connectMenuItem: NSMenuItem!
    @IBOutlet var disconnectMenuItem: NSMenuItem!
    @IBOutlet var greenColorMenuItem: NSMenuItem!
    @IBOutlet var whiteColorMenuItem: NSMenuItem!
    
    var dmd = Dmd()
    
    func applicationDirectory() -> URL? {
        let fm = FileManager.default
        var appSupportDirs = fm.urls(for: .applicationDirectory, in: .userDomainMask)
        if (appSupportDirs.count > 0) {
            var dirPath = appSupportDirs[0]
            dirPath.appendPathComponent(Bundle.main.bundleIdentifier!)
            try? fm.createDirectory(at: dirPath, withIntermediateDirectories: true, attributes: nil)
            return dirPath
        }
        return nil
    }
    
    func applicationWillFinishLaunching(_ notification: Notification) {
        let appDir = applicationDirectory()
        
        if (appDir != nil) {
            var nvramFile = appDir!
            nvramFile.appendPathComponent(NVRAM_NAME)
            if (FileManager.default.fileExists(atPath: nvramFile.relativePath)) {
                let data = try! Data(contentsOf: nvramFile)
                var buffer = [UInt8](repeating: 0, count: data.count)
                data.copyBytes(to: &buffer, count: data.count)
                dmd_set_nvram(&buffer)
            }
        }
        
        // Tell the DMD View to load preferences
        NotificationCenter.default.post(name: .preferencesUpdate, object: nil)
        
        dmd.start()
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        let appDir = applicationDirectory()
        
        if (appDir != nil) {
            var nvramFile = appDir!
            nvramFile.appendPathComponent(NVRAM_NAME)
            var buffer = [UInt8](repeating: 0, count: NVRAM_SIZE)
            dmd_get_nvram(&buffer)
            let data = Data(bytes: &buffer, count: NVRAM_SIZE)
            try! data.write(to: nvramFile)
        }
        
        dmd.stop()
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

