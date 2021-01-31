//
//  CallViewController.swift
//  TZChat
//
//  Created by Viktor Goltvyanytsya on 27.01.2021.
//

import UIKit
import AVFoundation
import WebRTC

class CallViewController: UIViewController {
    
    var wRTCClient: WRTCClient?
    
    var localVideoView: UIView!
    var remoteVideoView: UIView!
    
    var cameraManager: CameraManager?
    
    deinit {
        
    }
    
    init() {
        self.localVideoView = UIView()
        self.remoteVideoView = UIView()
        
        super.init(nibName: nil, bundle: nil)
    }
    
    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = UIColor.systemBackground
        
        remoteVideoView.backgroundColor = UIColor.black
        localVideoView.backgroundColor = UIColor.black
        
        self.view.addSubview(remoteVideoView)
        
        let fr: CGRect = self.view.frame
        let cw: CGFloat = 80
        let ch: CGFloat = 80
        self.localVideoView.frame = CGRect(x: fr.size.width - (cw+10),
                                           y: fr.size.height-(ch+80),
                                           width: cw,
                                           height: ch)
        self.view.addSubview(localVideoView)
        
        setupView()
        cameraManager?.delegate = self
    }
    
    override func viewDidLayoutSubviews() {

        super.viewDidLayoutSubviews()
        
        let fr: CGRect = self.view.frame
        let cw: CGFloat = 80
        let ch: CGFloat = 80
        self.localVideoView.frame = CGRect(x: fr.size.width - (cw+10),
                                           y: fr.size.height-(ch+80),
                                           width: cw,
                                           height: ch)
        
        remoteVideoView.frame = CGRect(x: 0,
                                     y: 0,
                                     width: fr.size.width,
                                     height: fr.size.height)
    }
        
    private func setupView() {
        guard let wRTCClient = wRTCClient else { return }
        
        #if arch(arm64)
            // Using metal (arm64 only)
            let localRenderer = RTCMTLVideoView(frame: self.localVideoView.frame)
            let remoteRenderer = RTCMTLVideoView(frame: self.remoteVideoView.frame)
            localRenderer.videoContentMode = .scaleAspectFill
            remoteRenderer.videoContentMode = .scaleAspectFit
                
        #else
            // Using OpenGLES for the rest
            let localRenderer = RTCEAGLVideoView(frame: self.localVideoView.frame)
            let remoteRenderer = RTCEAGLVideoView(frame: self.remoteVideoView.frame)
        #endif
        
        wRTCClient.setupLocalRenderer(localRenderer)
        wRTCClient.setupRemoteRenderer(remoteRenderer)
        
        if let localVideoView = self.localVideoView {
            self.embedView(localRenderer, into: localVideoView)
            localVideoView.addSubview(localRenderer)
        }
        //remoteVideoView.addSubview(remoteRenderer)
        self.embedView(remoteRenderer, into: remoteVideoView)
    }
}

// MARK: Camera
extension CallViewController: CameraCaptureDelegate {
    func captureVideoOutput(sampleBuffer: CMSampleBuffer) {
        if let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            let rtcpixelBuffer = RTCCVPixelBuffer(pixelBuffer: pixelBuffer)
            let timeStampNs: Int64 = Int64(CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer)) * 1000000000)
            let videoFrame = RTCVideoFrame(buffer: rtcpixelBuffer, rotation: RTCVideoRotation._0, timeStampNs: timeStampNs)
            
            wRTCClient?.didCaptureLocalFrame(videoFrame)
        }
    }
}
