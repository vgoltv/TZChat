//
//  RoomClient.swift
//  WebRTCTutorial
//
//  Created by Eric on 2020/03/03.
//  Copyright © 2020 Eric. All rights reserved.
//

import Foundation
import os.log

enum RoomResponseError: Error {
    case full
}

struct RoomClient {
    
    func join(roomID: String, completion: @escaping ((_ response: JoinResponseParam?, _ error: Error?) -> Void)) {
        let roomRef: URL = roomURL(roomID: roomID)
        Logger.appLogger.debug("\(roomRef)")
        
        var request = URLRequest(url: roomURL(roomID: roomID))
        
        request.httpMethod = "POST"
        
        let task = URLSession.shared.dataTask(with: request) {(data, response, error) in
            guard let data = data else {
                if let error = error {
                    completion(nil, error)
                }
                return
            }
            do {
                let decoder = JSONDecoder()
                let result = try decoder.decode(JoinResponse.self, from: data)
                
                Logger.appLogger.debug("result: \(data)")
                
                if result.result == .SUCCESS {
                    completion(result.params, nil)
                } else if result.result == .FULL {
                    completion(nil, RoomResponseError.full)
                }
            } catch let error {
                completion(nil, error)
            }
        }
        
        task.resume()
    }
    
    func disconnect(roomID: String, userID: String, completion: @escaping (() -> Void)) {
        var request = URLRequest(url: leaveURL(roomID: roomID, userID: userID))
        request.httpMethod = "POST"
        
        let task = URLSession.shared.dataTask(with: request) { _,_,_  in
            completion()
        }
        
        task.resume()
    }
    
    func sendMessage(_ message: Data, roomID: String, userID: String, completion: @escaping (() -> Void)) {
        var request = URLRequest(url: messageURL(roomID: roomID, userID: userID))
        request.httpMethod = "POST"
        request.httpBody = message
        
        if let msg = message.prettyPrintedJSONString {
            Logger.appLogger.debug("roomClient sendMessage: \(msg)")
        }
        
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error  in
            if let data = data {
                if let msg = data.prettyPrintedJSONString {
                    Logger.appLogger.debug("\(msg)")
                }
            } else if let error = error {
                Logger.appLogger.error("roomClient send message error: \(error.localizedDescription)")
            }
            
            completion()
        }
        
        task.resume()
    }
}

// MARK: URL Path
extension RoomClient {
    func roomURL(roomID: String) -> URL {
        let base = Config.default.serverURLPath + "/join/"
        return URL(string: base + "\(roomID)")!
    }
    func leaveURL(roomID: String, userID: String) -> URL {
        let base =  Config.default.serverURLPath + "/leave/"
        return URL(string: base + "\(roomID)/\(userID)")!
    }
    func messageURL(roomID: String, userID: String) -> URL {
        let base =  Config.default.serverURLPath + "/message/"
        return URL(string: base + "\(roomID)/\(userID)")!
    }
}
