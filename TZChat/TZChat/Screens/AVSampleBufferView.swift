//
//  AVSampleBufferView.swift
//  TZChat
//
//  Created by Viktor Goltvyanytsya on 31.01.2021.
//

import Foundation
import UIKit
import AVFoundation

class AVSampleBufferView: UIView {
    
    let canvas: AVSampleBufferDisplayLayer = {
        let layer = AVSampleBufferDisplayLayer()
        layer.backgroundColor = UIColor.black.cgColor
        layer.videoGravity = .resizeAspectFill
        return layer
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        layer.addSublayer(canvas)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        canvas.frame = self.bounds
    }
    
    public func play(sampleBuffer: CMSampleBuffer) {
        canvas.enqueue(sampleBuffer)
    }
}
