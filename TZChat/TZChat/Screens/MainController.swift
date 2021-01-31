//
//  MainController.swift
//  TZChat
//
//  Created by Viktor Goltvyanytsya on 27.01.2021.
//

import UIKit
import AVFoundation
import WebRTC
import os.log



class MainController: UIViewController {
    
    private let config: Config
    
    private var containerView: UIView
    private var preview: AVSampleBufferView
    private var menuButton: UIButton

    
    var roomClient: RoomClient?
    var roomInfo: JoinResponseParam? {
        didSet {
            DispatchQueue.main.async {
                // isConnected
            }
        }
    }
    
    // Disconnect to websocket
    var isConnected: Bool {
        return roomInfo != nil
    }
    
    var isInitiator: Bool {
        return roomInfo?.is_initiator == "true"
    }
    
    // MARK: Properties for Signaling
    var webSocket: WebSocketClient?
    var messageQueue = [String]()
    
    // MARK: Properties for calling
    var wRTCClient: WRTCClient?
    let cameraManager = CameraManager()
    
    var videoCallVC: CallViewController?
    
    deinit {
        
    }
    
    
    init() {
        
        self.config = Config.default

        self.containerView = UIView()
        self.preview = AVSampleBufferView()
        self.menuButton = UIButton()
        
        super.init(nibName: nil, bundle: nil)
    }
    
    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        initToolbar()
        initNavigationBar()
        initViews()
        
        setupCamera()
    }
    
    override func viewDidLayoutSubviews() {
        
        super.viewDidLayoutSubviews()
        
        let ar: CGRect = CGRect(x: 0,
                                y: 0,
                                width: self.view.frame.size.width,
                                height: self.view.frame.size.height)
        
        preview.frame = ar
        containerView.frame = ar
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        cameraManager.startCapture()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        cameraManager.stopCapture()
    }
    
    private func initToolbar() {
        
    }

    private func initNavigationBar() {
        navigationItem.title = "TZChat"

        let menuIcon: String = "ellipsis.circle"
        
        let button = UIButton(frame:CGRect(x:0, y:0, width:70, height:70))
        button.setImage(UIImage(systemName: menuIcon), for: .normal)
        button.addTarget(self, action: #selector(menuButtonDidTap), for: .touchUpInside)
        let menuItem: UIBarButtonItem =  UIBarButtonItem(customView: button)

        self.menuButton = button

        navigationItem.rightBarButtonItem = menuItem

    }
    
    private func initViews() {
        view.backgroundColor = UIColor.systemBackground
        
        let ar: CGRect = CGRect(x: 0,
                                y: 0,
                                width: self.view.frame.size.width,
                                height: self.view.frame.size.height)
        preview.frame = ar
        view.addSubview(preview)
        
        containerView.frame = ar
        containerView.backgroundColor = UIColor.clear
        containerView.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(containerView)
    }
    
    // MARK: UI Actions
    @objc func menuButtonDidTap(sender : UIButton) {
        
        let actionSheetController: UIAlertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        let action0: UIAlertAction = UIAlertAction(title: "Enter to room", style: .default) { action -> Void in
            self.enterToRoom()
        }
        
        let action1: UIAlertAction = UIAlertAction(title: "Disconnect", style: .default) { action -> Void in
            self.disconnect()
        }
        
        let cancelAction: UIAlertAction = UIAlertAction(title: "Cancel", style: .cancel) { action -> Void in }
        
        if isConnected {
            actionSheetController.addAction(action1)
        } else {
            actionSheetController.addAction(action0)
        }

        actionSheetController.addAction(cancelAction)
        
        actionSheetController.popoverPresentationController?.sourceView = self.menuButton
        
        present(actionSheetController, animated: true) {
            
        }
        
    }
    
    func enterToRoom( ) {
        let alert = UIAlertController(title: "Room",
                                      message: "You should input room number.",
                                      preferredStyle: .alert)
        alert.addTextField { (textField) in
            textField.placeholder = "Number of the chat room"
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "Send", style: .default, handler: { [weak self, unowned alert] _ in
            guard let roomID = alert.textFields?.first?.text else { return }
            
            guard let ref = self else { return }
            
            DispatchQueue.main.async {
                ref.navigationItem.title = roomID
                if ref.isConnected {
                    ref.disconnect()
                } else {
                    ref.prepare()
                    ref.requestJoin(roomID)
                }
            }
        }))
        self.present(alert, animated: true, completion: nil)
    }

    func prepare() {
        
        roomClient = RoomClient()
        wRTCClient = WRTCClient()
        webSocket = WebSocketClient()
        
        let vc = CallViewController()
        vc.wRTCClient = wRTCClient
        vc.cameraManager = cameraManager
        addChild(vc)
        self.containerView.addSubview(vc.view)
        videoCallVC = vc
    }
    
    func clear() {
        roomClient = nil
        wRTCClient = nil
        webSocket = nil
        
        videoCallVC?.removeFromParent()
        videoCallVC?.view.removeFromSuperview()
        videoCallVC = nil
        
        navigationItem.title = "TZChat"
        
        cameraManager.delegate = self
    }
    
}

// MARK: Network
extension MainController {
    func requestJoin(_ roomID: String) {
        guard let roomClient = roomClient else {
            Logger.appLogger.debug("Check room client initialize part.")
            return
        }
        
        roomClient.join(roomID: roomID) { [weak self](response, error) in
            if let response = response {
                self?.append(log: "Successfully join to room.")
                
                self?.roomInfo = response
                if let messages = response.messages {
                    self?.handleMessages(messages)
                }
                self?.connectToWebSocket()
            } else if let error = error as? RoomResponseError,
                error == .full {
                self?.append(log: "Room is full. Use different room number.")
            } else if let error = error {
                self?.append(log: error.localizedDescription)
            }
        }
    }
        
    func disconnect() {
        guard let roomID = roomInfo?.room_id,
            let userID = roomInfo?.client_id,
            let roomClient = roomClient,
            let webSocket = webSocket,
            let wRTCClient = wRTCClient else { return }
        
        roomClient.disconnect(roomID: roomID, userID: userID) { [weak self] in
            self?.roomInfo = nil
            self?.append(log: "Disconnected.")
        }
        
        let message = ["type": "bye"]
        
        if let data = message.JSONData {
            webSocket.send(data: data)
        }
                
        webSocket.delegate = nil
        roomInfo = nil

        wRTCClient.disconnect()
        
        clear()
    }
    
    func handleMessages(_ messages: [String]) {
        messageQueue.append(contentsOf: messages)
        drainMessageQueue()
    }
    
    func drainMessageQueue() {
        guard let webSocket = webSocket,
            webSocket.isConnected,
            let wRTCClient = wRTCClient else {
                return
        }
        
        for message in messageQueue {
            handleMessage(message)
        }
        messageQueue.removeAll()
        wRTCClient.drainMessageQueue()
    }
    
    func handleMessage(_ message: String) {
        guard let wRTCClient = wRTCClient else { return }
        
        let signalMessage = SignalMessage.from(message: message)
        switch signalMessage {
        case .candidate(let candidate):
            wRTCClient.handleCandidateMessage(candidate)
            append(log: "Receive candidate")
        case .answer(let answer):
            wRTCClient.handleRemoteDescription(answer)
            append(log: "Recevie Answer")
        case .offer(let offer):
            wRTCClient.handleRemoteDescription(offer)
            append(log: "Recevie Offer")
        case .bye:
            disconnect()
        default:
            break
        }
    }
    
    func sendSignalingMessage(_ message: Data) {
        guard let roomID = roomInfo?.room_id,
            let userID = roomInfo?.client_id,
            let roomClient = roomClient else { return }
        
        roomClient.sendMessage(message, roomID: roomID, userID: userID) { [weak self] in
            self?.append(log: "Send signal message successfully")
        }
    }
}

// MARK: WebSocket
extension MainController: WebSocketClientDelegate {
    func connectToWebSocket() {
        guard let webSocketURLPath = roomInfo?.wss_url,
            let url = URL(string: webSocketURLPath),
            let webSocket = webSocket else {
                append(log: "Fail to connect websocket for signaling")
                return
        }

        webSocket.delegate = self
        webSocket.connect(url: url)
    }
    
    func registerRoom() {
        guard let roomID = roomInfo?.room_id,
            let userID = roomInfo?.client_id,
            let webSocket = webSocket else {
                append(log: "RoomID or UserID is empty. Should be check.")
                return
        }
        
        let message = ["cmd": "register",
                       "roomid": roomID,
                       "clientid": userID
        ]
        
        guard let data = message.JSONData else {
            Logger.appLogger.debug("Error in Register room.")
            return
        }
                
        webSocket.send(data: data)
        Logger.appLogger.debug("Register Room")
    }
    
    func webSocketDidConnect(_ webSocket: WebSocketClient) {
        guard let wRTCClient = wRTCClient else { return }
        
        append(log: "Successfully connect to websocket")
        registerRoom()
        
        wRTCClient.delegate = self
        
        if isInitiator {
            wRTCClient.offer()
        }
        
        drainMessageQueue()
    }
    
    func webSocketDidDisconnect(_ webSocket: WebSocketClient) {
        webSocket.delegate = nil
        append(log: "Disconnect to websocket")
    }
    
    func webSocket(_ webSocket: WebSocketClient, didReceive data: String) {
        append(log: "Receive data from websocket")
        Logger.appLogger.debug("Received data from websocket \(data)")

        handleMessage(data)
        
        wRTCClient?.drainMessageQueue()
    }
}

extension MainController: WRTCClientDelegate {
    func wRTCClient(_ client: WRTCClient, sendData data: Data) {
        sendSignalingMessage(data)
    }
}

// MARK: Handle camera and show preview
extension MainController: CameraCaptureDelegate {
    func setupCamera() {
        cameraManager.delegate = self
        cameraManager.setupCamera()
    }

    func captureVideoOutput(sampleBuffer: CMSampleBuffer) {
        self.preview.play(sampleBuffer: sampleBuffer)
    }
}

// MARK: Handle Log
extension MainController {
    func append(log: String) {
        DispatchQueue.main.async {
            Logger.appLogger.debug("Log: \(log)")
        }
    }
}
