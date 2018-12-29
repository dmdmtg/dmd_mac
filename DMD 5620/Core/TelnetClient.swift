//
//  TelnetClient.swift
//  DMD 5620
//
//  Created by Seth Morabito on 12/22/18.
//  Copyright © 2018 Loom Communications LLC. All rights reserved.
//

import Foundation
import CocoaAsyncSocket

enum TelnetState: UInt8 {
    case data = 0
    case iac = 255
    case dont_opt = 254
    case do_opt = 253
    case wont_opt = 252
    case will_opt = 251
    case sb = 250
    case ga = 249
    case el = 248
    case ec = 247
    case ayt = 246
    case ao = 245
    case ip = 244
    case brk = 243
    case data_mark = 242
    case nop = 241
    case se = 240
}

// Telnet Negotiation Options we can handle
let OPT_BINARY: UInt8 = 0
let OPT_ECHO: UInt8 = 1
let OPT_SUPPRESS_GO_AHEAD: UInt8 = 2

protocol TelnetReceiver {
    func rxData(data: Data)
    func socketClosed()
}

class TelnetClient: NSObject, GCDAsyncSocketDelegate {
    var delegate: TelnetReceiver?
    var asyncSocket: GCDAsyncSocket?
    var rawBuffer: Data = Data()
    var rxBuffer: Data = Data()
    var txBuffer: Data = Data()
    var state: TelnetState = .data
    let validOptions = [OPT_BINARY, OPT_ECHO, OPT_SUPPRESS_GO_AHEAD]
    
    func connect(host: String, port: UInt16) {
        if (asyncSocket != nil) {
            asyncSocket?.disconnect();
            asyncSocket = nil;
        }
        
        self.asyncSocket = GCDAsyncSocket(delegate: self, delegateQueue: DispatchQueue.main)
        self.asyncSocket?.autoDisconnectOnClosedReadStream = true
        try? self.asyncSocket?.connect(toHost: host, onPort: port, withTimeout: 75)
    }
    
    func disconnect() {
        self.asyncSocket?.disconnect()
        self.asyncSocket = nil
    }
    
    func transmit(data: Data) {
        var transmitData = Data(capacity: data.count)

        // If the data contains any IAC characters, escape them.
        for b in data {
            transmitData.append(b)
            if (b == TelnetState.iac.rawValue) {
                transmitData.append(TelnetState.iac.rawValue)
            }
        }
        
        self.asyncSocket?.write(transmitData, withTimeout: -1, tag: 2)
    }
    
    @objc
    public func socketDidDisconnect(_ sock: GCDAsyncSocket, withError err: Error?) {
        delegate?.socketClosed()
    }
    
    @objc
    public func socket(_ sock: GCDAsyncSocket, didConnectToHost host: String, port: UInt16) {
        // After connection, trigger an immediate read to
        // start consuming the Telnet stream.
        self.asyncSocket?.readData(withTimeout: -1, tag: 0)
    }
    
    @objc
    public func socket(_ sock: GCDAsyncSocket, didRead data: Data, withTag tag: Int) {
        rxBuffer.removeAll(keepingCapacity: true)
        txBuffer.removeAll(keepingCapacity: true)

        data.forEach({ (b) in
            switch state {
            case .data:
                if (TelnetState.iac.rawValue == b) {
                    // The byte 255 means that a command (or an escaped 255)
                    // is going to be the next byte.
                    state = .iac
                } else {
                    // Otherwise, we're just receiving data and appending it to
                    // our decoded data receive buffer.
                    rxBuffer.append(b)
                }
            case .iac:
                switch b {
                case TelnetState.iac.rawValue:
                    // In telnet, the bytes "255 255" in sequence are
                    // an escaped 255, so we pass the escaped value
                    // along to the rxBuffer.
                    state = .data
                    rxBuffer.append(b)
                case TelnetState.dont_opt.rawValue:
                    state = .dont_opt
                case TelnetState.do_opt.rawValue:
                    state = .do_opt
                case TelnetState.wont_opt.rawValue:
                    state = .wont_opt
                case TelnetState.will_opt.rawValue:
                    state = .will_opt
                case TelnetState.sb.rawValue:
                    state = .sb
                case TelnetState.se.rawValue:
                    state = .data
                default:
                    state = .data
                }
            case .dont_opt:
                // Confirm that we won't
                txBuffer.append(TelnetState.iac.rawValue)
                txBuffer.append(TelnetState.wont_opt.rawValue)
                txBuffer.append(b)
                
                state = .data
            case .do_opt:
                if validOptions.contains(b) {
                    // OK!
                    txBuffer.append(TelnetState.iac.rawValue)
                    txBuffer.append(TelnetState.will_opt.rawValue)
                    txBuffer.append(b)
                } else {
                    // Sorry, we won't
                    txBuffer.append(TelnetState.iac.rawValue)
                    txBuffer.append(TelnetState.wont_opt.rawValue)
                    txBuffer.append(b)
                }
                state = .data
            case .wont_opt:
                // OK, we won't
                txBuffer.append(TelnetState.iac.rawValue)
                txBuffer.append(TelnetState.dont_opt.rawValue)
                txBuffer.append(b)

                state = .data
            case .will_opt:
                if (validOptions.contains(b)) {
                    // OK, that's cool
                    txBuffer.append(TelnetState.iac.rawValue)
                    txBuffer.append(TelnetState.do_opt.rawValue)
                    txBuffer.append(b)
                } else {
                    // Otherwise, we won't
                    txBuffer.append(TelnetState.iac.rawValue)
                    txBuffer.append(TelnetState.dont_opt.rawValue)
                    txBuffer.append(b)
                }
                state = .data
            case .sb:
                // This very simple telnet client ignores all subnegotiation
                // commands. This should really never be triggered anyway,
                // because we aggressively decline all WILL and DO negotiations,
                // but let's cover it just in case. We'll receive an IAC SE
                // at some point that will take us out of this.
                break
            default:
                // Oops, this shouldn't happen! Not sure what to do about
                // it other than reset the state machine.
                state = .data
                break
            }
        })
        
        // If we have built up a response due to IAC commands, send it.
        if (txBuffer.count > 0) {
            self.asyncSocket?.write(txBuffer, withTimeout: -1, tag: 1)
        }
        
        // If we have parsed any receive data, send it on to our delegate.
        if (rxBuffer.count > 0) {
            delegate?.rxData(data: rxBuffer)
        }
        
        // Keep consuming.
        self.asyncSocket?.readData(withTimeout: -1, tag: 0)
    }
}
