//
//  AVCamPreviewView.swift
//  AVCamPicker
//
//  Created by igor on 6/13/17.
//  Copyright © 2017 igor. All rights reserved.
//

import UIKit
import AVFoundation

final class AVCamPreviewView: UIView {
	var videoPreviewLayer: AVCaptureVideoPreviewLayer {
		return layer as! AVCaptureVideoPreviewLayer
	}
	
	internal var session: AVCaptureSession? {
		get {
			return videoPreviewLayer.session
		}
		set {
			videoPreviewLayer.session = newValue
		}
	}
	
	// MARK: UIView
	
    override class var layerClass: AnyClass {
		return AVCaptureVideoPreviewLayer.self
	}
}


