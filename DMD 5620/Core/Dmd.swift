//
//  Dmd.swift
//  DMD 5620
//
//  Created by Seth Morabito on 12/22/18.
//  Copyright © 2018 Loom Communications LLC. All rights reserved.
//

import Foundation
import AppKit

class Dmd: TelnetReceiver {
    var viewUpdateTimer: Timer? = nil
    var dmdRunTimer: Timer? = nil
    var delegate: DmdProtocol?
    var telnetClient: TelnetClient = TelnetClient()
    var kbQueue: ByteQueue = ByteQueue()
    
    var dmdRunQueue = DispatchQueue(label: "dmd-runner")
    var uiUpdateQueue = DispatchQueue.main
    
    var dmdRunner: DispatchSourceTimer?
    var uiRunner: DispatchSourceTimer?
    
    init() {
        telnetClient.delegate = self
        dmd_reset();
    }
    
    func connect(host: String, port: UInt16) {
        telnetClient.connect(host: host, port: port)
        delegate?.telnetConnected(host: host, port: port)
    }
    
    func disconnect() {
        telnetClient.disconnect()
        delegate?.telnetDisconnected()
    }

    func start() {
        dmdRunner = DispatchSource.makeTimerSource(flags: DispatchSource.TimerFlags(rawValue: 0), queue: dmdRunQueue)
        dmdRunner?.schedule(deadline: .now() + .microseconds(500),
                            repeating: .microseconds(500),
                            leeway: .microseconds(50))
        dmdRunner?.setEventHandler(handler: { () in
            self.runAndPoll()
        })

        uiRunner = DispatchSource.makeTimerSource(flags: DispatchSource.TimerFlags(rawValue: 0), queue: uiUpdateQueue)
        uiRunner?.schedule(deadline: .now() + .microseconds(34_000),
                           repeating: .microseconds(34_000),
                           leeway: .microseconds(5_000))
        uiRunner?.setEventHandler(handler: { () in
            self.updateDisplay()
        })
        
        dmdRunner?.resume()
        uiRunner?.resume()
    }
    
    func stop() {
        dmdRunner?.cancel()
        uiRunner?.cancel()
    }

    // Used only for debugging.
    private func debugAtPoint(stepCount: UInt64) {
        var pc: UInt32 = 0
        
        dmd_get_pc(&pc)
        
        if (pc == 0x164e9) {
            print("[\(stepCount)] NAK: PS_BUSY");
        }
        
        if (pc == 0x1654e) {
            print("[\(stepCount)] ACK: OK");
        }
        
        if (pc == 0x16565) {
            print("[\(stepCount)] ACK: OK After Retry");
        }
        
        if (pc == 0x16571) {
            print("[\(stepCount)] NAK: PC_OOUTSEQ");
        }

        if (pc == 0x16890) {
            var r6: UInt32 = 0
            var header: UInt32 = 0
            dmd_get_register(6, &r6);
            dmd_read_word(r6, &header);
            let hex = String(format: "%02x", (header >> 4) & 0xff)
            print("[\(stepCount)] [psend >>>] Header is 0x\(hex)")
        }

        if (pc == 0x163dc) {
            var ap: UInt32 = 0
            var header: UInt32 = 0
            dmd_get_register(10, &ap);
            dmd_read_word(ap, &header);
            let hex = String(format: "%02x", header)
            print("[\(stepCount)] [precv <<<] Header is 0x\(hex)")
        }

        if (pc == 0x166e2) {
            print("[\(stepCount)] reply()");
        }
    }
    
    func runAndPoll() {
        dmd_step_loop(550)
        
        // Handle keyboard input from the UI to the terminal
        while (!self.kbQueue.isEmpty) {
            dmd_rx_keyboard(self.kbQueue.popBack()!)
        }

        // Handle keyboard output from the terminal to the UI
        // (used only for keyboard bell)
        var kbChar: UInt8 = 0
        if (dmd_kb_tx_poll(&kbChar) == 0) {
            // Successful poll. We check here for a status bit set by
            // the ASCII bell character (^G), and ring the bell if set
            
            if ((kbChar & 0x8) != 0) {
                NSSound.beep()
            }
        }

        // Handle polling for RS232 data from the terminal to the host
        var txData: Data = Data()
        var rs232Char: UInt8 = 0

        while (dmd_rs232_tx_poll(&rs232Char) == 0) {
            txData.append(rs232Char)
        }
        if (!txData.isEmpty) {
            self.telnetClient.transmit(data: txData)
        }
    }
    
    func updateDisplay() {
        self.delegate?.updateView(self, data: dmd_video_ram()!)
    }
    
    func kbChar(c: UInt8) {
        kbQueue.pushFront(b: c)
    }
    
    // Receive data from the Telnet Client
    func rxData(data: Data) {
        data.forEach { (b) in
            dmd_rx_char(b)
        }
    }
    
    func socketClosed() {
        delegate?.telnetDisconnected()
    }
}

protocol DmdProtocol {
    func updateView(_ dmd: Dmd, data: UnsafeMutablePointer<UInt8>)
    func telnetConnected(host: String, port: UInt16)
    func telnetDisconnected()
}
