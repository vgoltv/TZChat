//
//  WebSocketClient.swift
//  WebRTCTutorial
//
//  Created by Eric on 2020/03/03.
//  Copyright © 2020 Eric. All rights reserved.
//

import Foundation
import SocketRocket
import os.log

protocol WebSocketClientDelegate: class {
    func webSocketDidConnect(_ webSocket: WebSocketClient)
    func webSocketDidDisconnect(_ webSocket: WebSocketClient)
    func webSocket(_ webSocket: WebSocketClient, didReceive data: String)
}

class WebSocketClient: NSObject {
    weak var delegate: WebSocketClientDelegate?
    var socket: SRWebSocket?
    
    var isConnected: Bool {
        return socket != nil
    }
    
    func connect(url: URL) {
        socket = SRWebSocket(url: url)
        Logger.appLogger.debug("Connect to websocket: \(url)")
        socket?.delegate = self
        socket?.open()
    }
    
    func disconnect() {
        socket?.close()
        socket = nil
        self.delegate?.webSocketDidDisconnect(self)
    }
    
    func send(data: Data) {
        guard let socket = socket else {
            Logger.appLogger.debug("Check Socket connection")
            return
        }
        
        if let str = data.prettyPrintedJSONString {
            Logger.appLogger.debug("Sent message: \(str)")
        }
        
        socket.send(data)
    }
}

extension WebSocketClient: SRWebSocketDelegate {
    
    func webSocket(_ webSocket: SRWebSocket!, didReceiveMessage message: Any!) {
        if let message = message as? String {
            Logger.appLogger.debug("Received message: \(message)")
            delegate?.webSocket(self, didReceive: message)
        }else{
            Logger.appLogger.debug("Error in didReceiveMessage")
        }
    }
    
    func webSocketDidOpen(_ webSocket: SRWebSocket!) {
        Logger.appLogger.debug("did open")
        delegate?.webSocketDidConnect(self)
    }
    
    func webSocket(_ webSocket: SRWebSocket!, didFailWithError error: Error!) {
        Logger.appLogger.error("did Fail to connect websocket")
        self.disconnect()
    }
    
    func webSocket(_ webSocket: SRWebSocket!, didCloseWithCode code: Int, reason: String!, wasClean: Bool) {
        Logger.appLogger.debug("did close websocket")
        self.disconnect()
    }
    
}
