//
//  AVCamPhotoOutputDevice.swift
//  AVCamPicker
//
//  Created by igor on 6/13/17.
//  Copyright © 2017 igor. All rights reserved.
//

import Foundation
import AVFoundation
import UIKit

typealias PhotoCaptureCompletion = (_ photo: UIImage?, _ error: Error?) -> Void

final class OutputDeviceFactory: NSObject {
    static func newOutputDevice() -> AVCamPhotoOutputDevice {
        if #available(iOS 10, *) {
            return PhotoOutput()
        } else {
            return StillImageOutput()
        }
    }
}

protocol AVCamPhotoOutputDevice: class {
    var captureOutput: AVCaptureOutput { get }
    func capturePhoto(from connection: AVCaptureConnection, flashMode: AVCaptureFlashMode, completion: PhotoCaptureCompletion?)
    
//    init()
}



@available(iOS 10, *)
final class PhotoOutput: NSObject, AVCamPhotoOutputDevice, AVCapturePhotoCaptureDelegate {
    
    // MARK: - Properties
    
    internal let captureOutput: AVCaptureOutput = {
        let output = AVCapturePhotoOutput()
        output.isHighResolutionCaptureEnabled = true
        return output
    }()
    
    private var captureCompletion: PhotoCaptureCompletion?
    private var isVideoMirrored: Bool = false
    
    // MARK: - Lifecycle
    
    internal required override init() {
        super.init()
    }
    
    // MARK: - Public methods
    
    internal func capturePhoto(from connection: AVCaptureConnection, flashMode: AVCaptureFlashMode, completion: PhotoCaptureCompletion?) {
        captureCompletion = nil
        captureCompletion = completion

//        isVideoMirrored = connection.isVideoMirrored
        // Capture a JPEG photo with flash set to auto and high resolution photo enabled.
        let photoSettings = AVCapturePhotoSettings()
        photoSettings.isHighResolutionPhotoEnabled = true
        if (captureOutput as! AVCapturePhotoOutput).supportedFlashModes.contains(NSNumber(value: flashMode.rawValue)) {
            photoSettings.flashMode = flashMode
        }
        if photoSettings.availablePreviewPhotoPixelFormatTypes.count > 0 {
            photoSettings.previewPhotoFormat = [kCVPixelBufferPixelFormatTypeKey as String : photoSettings.availablePreviewPhotoPixelFormatTypes.first!]
        }
        (captureOutput as! AVCapturePhotoOutput).capturePhoto(with: photoSettings, delegate: self)
    }
    
    // MARK: - AVCapturePhotoCaptureDelegate
    
    internal func capture(_ captureOutput: AVCapturePhotoOutput, didFinishProcessingPhotoSampleBuffer photoSampleBuffer: CMSampleBuffer?, previewPhotoSampleBuffer: CMSampleBuffer?, resolvedSettings: AVCaptureResolvedPhotoSettings, bracketSettings: AVCaptureBracketedStillImageSettings?, error: Error?) {
        guard error == nil else {
            captureCompletion?(nil, error)
            captureCompletion = nil
            return
        }
        
        guard let sampleBuffer = photoSampleBuffer,
            let previewBuffer = previewPhotoSampleBuffer,
            let imageData = AVCapturePhotoOutput.jpegPhotoDataRepresentation(forJPEGSampleBuffer: sampleBuffer, previewPhotoSampleBuffer: previewBuffer),
            let image = UIImage(data: imageData) else {
                captureCompletion?(nil, nil)
                captureCompletion = nil
                return
        }
        
        captureCompletion?(image, nil)
        captureCompletion = nil
    }
}

@available(iOS, obsoleted: 10.0, message: "Use PhotoOutput")
final class StillImageOutput: NSObject, AVCamPhotoOutputDevice {
    
    // MARK: - Properties
    
    
    internal let captureOutput: AVCaptureOutput = {
        let output = AVCaptureStillImageOutput()
        output.isHighResolutionStillImageOutputEnabled = true
        return output
    }()
    
    
    // MARK: - Lifecycle
    
    internal required override init() {
        super.init()
    }
    
    // MARK: - Public methods
    
    internal func capturePhoto(from connection: AVCaptureConnection, flashMode: AVCaptureFlashMode, completion: PhotoCaptureCompletion?) {
        (captureOutput as! AVCaptureStillImageOutput).captureStillImageAsynchronously(from: connection) { (imageDataSampleBuffer, error) in
            guard error == nil else {
                completion?(nil, error)
                return
            }
            guard let imageData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(imageDataSampleBuffer),
                let image = UIImage(data: imageData) else {
                    completion?(nil, nil)
                    return
            }
            completion?(image, nil)
            
        }
    }
}
