//
//  AVCamController.swift
//  AVCamPicker
//
//  Created by igor on 6/13/17.
//  Copyright © 2017 igor. All rights reserved.
//

import UIKit
import AVFoundation
import Photos

fileprivate extension Notification.Name {
    @nonobjc static let AVCaptureDeviceSubjectAreaDidChange = NSNotification.Name("AVCaptureDeviceSubjectAreaDidChange")
}

protocol AVCamControllerDelegate: class {
    func cameraControllerDidCancel(_ controller: AVCamController)
    func cameraControllerDidTakePhoto(_ controller: AVCamController, _ image: UIImage)
}

final class AVCamController: UIViewController {
    
    private enum SessionSetupResult {
        case success
        case notAuthorized
        case configurationFailed
    }
    
    // MARK: - Constants
    
    private static let permissionMsg = "AVCamPicker doesn't have permission to use the camera, please change privacy settings";
    private static let errorMsg = "Unable to capture photos";
    
    
    // MARK: - Outlets
    
    @IBOutlet private weak var previewView: AVCamPreviewView!
    @IBOutlet weak var previewOverlayViewsSpacing: NSLayoutConstraint!

    @IBOutlet private weak var capturedPhotoView: UIView!
    @IBOutlet private weak var photoImageView: UIImageView!
    @IBOutlet private weak var captureButton: UIButton!
    @IBOutlet private weak var switchCameraButton: UIButton!
    @IBOutlet private weak var cameraUnavailableLabel: UILabel!
    @IBOutlet fileprivate weak var flashModeButton: UIButton!
    @IBOutlet fileprivate weak var flashModesCollectionView: UICollectionView!
    @IBOutlet private weak var flashModesCollectionViewWidth: NSLayoutConstraint!
    
    // MARK: - Properties
    
    
    internal weak var delegate: AVCamControllerDelegate?
    internal var cameraDevice: UIImagePickerControllerCameraDevice = .rear
    
    private let session = AVCaptureSession()
    
    private var isSessionRunning = false
    
    private let sessionQueue = DispatchQueue(label: "session queue", attributes: [], target: nil) // Communicate with the session and other session objects on this queue.
    private var setupResult: SessionSetupResult = .success
    
    private var videoDeviceInput: AVCaptureDeviceInput!
    
    
    private let photoOutputDevice = OutputDeviceFactory.newOutputDevice()
    
    private var focusView: AVCamFocusView?
    private var flashModesCollectionCoordinator: FlashModesCollectionViewCoordinator?
    fileprivate var preferredFlashMode: AVCaptureFlashMode = .auto {
        didSet {
            flashModeButton.setImage(preferredFlashMode.icon, for: .normal)
        }
    }
    
    // MARK: - Lifecycle
    
    internal convenience init() {
        self.init(nibName: String(describing: AVCamController.self), bundle: Bundle.main)
    }
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    // MARK: - UIViewController
    
    override func viewDidLoad() {
        super.viewDidLoad()
        switchCameraButton.isEnabled = false
        captureButton.isEnabled = false
        previewView.session = session
        requestAuthorizationIfNeeded()
        flashModesCollectionCoordinator = FlashModesCollectionViewCoordinator(collectionView: flashModesCollectionView, flashModes: [.auto, .on, .off])
        flashModesCollectionCoordinator?.delegate = self
        sessionQueue.async { [weak self] in
            self?.configureSession()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setNeedsStatusBarAppearanceUpdate()
        //        flashModesCollectionViewWidth.constant = flashModesCollectionView.contentSize.width
        view.setNeedsUpdateConstraints()
        sessionQueue.async { [weak self] in
            guard let sSelf = self else { return }
            sSelf.handleSessionSetup(sSelf.setupResult)
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        sessionQueue.async { [weak self] in
            guard let sSelf = self else { return }
            
            if sSelf.setupResult == .success {
                sSelf.session.stopRunning()
                sSelf.isSessionRunning = sSelf.session.isRunning
                sSelf.removeObservers()
            }
        }
        super.viewWillDisappear(animated)
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        let constant = view.bounds.width * 4/3
        previewOverlayViewsSpacing.constant = constant
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
        return .slide
    }
    
    override var shouldAutorotate: Bool {
        return false
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        if let videoPreviewLayerConnection = previewView.videoPreviewLayer.connection {
            videoPreviewLayerConnection.videoOrientation = .portrait
        }
    }
    
    // MARK: - Authorization and Session Management
    
    
    // Checks video authorization status. Video access is required.
    private func requestAuthorizationIfNeeded() {
        switch AVCaptureDevice.authorizationStatus(forMediaType: AVMediaTypeVideo) {
        case .authorized:
            // The user has previously granted access to the camera.
            break
        case .notDetermined:
            // The user hasn't determined access -> request for it.
            sessionQueue.suspend()
            AVCaptureDevice.requestAccess(forMediaType: AVMediaTypeVideo, completionHandler: { [weak self] granted in
                guard let sSelf = self else { return }
                
                if !granted {
                    sSelf.setupResult = .notAuthorized
                }
                sSelf.sessionQueue.resume()
            })
        default:
            // The user has previously denied access.
            setupResult = .notAuthorized
        }
    }
    
    private func handleSessionSetup(_ result: SessionSetupResult) {
        switch result {
        case .success:
            // Only setup observers and start the session running if setup succeeded.
            self.addObservers()
            self.session.startRunning()
            self.isSessionRunning = self.session.isRunning
        case .notAuthorized:
            DispatchQueue.main.async { [weak self] in
                guard let sSelf = self else { return }
                let message = AVCamController.permissionMsg
                let okAction = UIAlertAction(title: "Ok", style: .default, handler: nil)
                let settingsAction = UIAlertAction(title: "Settings", style: .default, handler: { (action) in
                    UIApplication.shared.openURL(URL(string: UIApplicationOpenSettingsURLString)!)
                })
                let alertController = UIAlertController.alert(title: "Warning", message: message, actions: [okAction, settingsAction])
                alertController.preferredAction = settingsAction
                
                sSelf.present(alertController, animated: true, completion: nil)
            }
        case .configurationFailed:
            DispatchQueue.main.async { [weak self] in
                guard let sSelf = self else { return }
                let message = AVCamController.errorMsg
                let alertController = UIAlertController.alert(title: "Warning", message: message)
                sSelf.present(alertController, animated: true, completion: nil)
            }
        }
    }
    
    // Configures AVCaptureSession.
    private func configureSession() {
        guard setupResult == .success else { return }
        session.beginConfiguration()
        session.sessionPreset = AVCaptureSessionPresetPhoto
        
        // Add video input.
        do {
            var defaultVideoDevice: AVCaptureDevice?
            
            // Choose the back dual camera if available, otherwise default to a wide angle camera.
            let availableCameraDevices = AVCaptureDevice.allVideoDevices
            if availableCameraDevices.count > 0 {
                defaultVideoDevice = availableCameraDevices.first!
                for device in availableCameraDevices {
                    if device.position == .front && cameraDevice == .front {
                        defaultVideoDevice = device
                    } else if device .position == .back && cameraDevice == .rear {
                        defaultVideoDevice = device
                    }
                    guard device.hasFlash else { continue }
                    do {
                        try device.lockForConfiguration()
                        device.flashMode = preferredFlashMode
                        device.unlockForConfiguration()
                    }
                }
            }
            
            let videoDeviceInput = try AVCaptureDeviceInput(device: defaultVideoDevice)
            
            if session.canAddInput(videoDeviceInput) {
                session.addInput(videoDeviceInput)
                self.videoDeviceInput = videoDeviceInput
                
                DispatchQueue.main.async {
                    // Default orientation to portrait mode
                    self.previewView.videoPreviewLayer.connection.videoOrientation = .portrait
                }
            } else {
                print("Could not add video device input to the session")
                setupResult = .configurationFailed
                session.commitConfiguration()
                return
            }
        } catch {
            print("Could not create video device input: \(error)")
            setupResult = .configurationFailed
            session.commitConfiguration()
            return
        }
        
        if self.session.canAddOutput(self.photoOutputDevice.captureOutput) {
            self.session.addOutput(self.photoOutputDevice.captureOutput)
        } else {
            print("Could not add photo output to the session")
            setupResult = .configurationFailed
            session.commitConfiguration()
            return
        }
        session.commitConfiguration()
    }
    
    // MARK: - Capturing Photos
    
    private func focus(with focusMode: AVCaptureFocusMode, exposureMode: AVCaptureExposureMode, at devicePoint: CGPoint, monitorSubjectAreaChange: Bool) {
        sessionQueue.async { [weak self] in
            guard let sSelf = self else { return }
            
            guard let device = sSelf.videoDeviceInput.device,
                let _ = try? device.lockForConfiguration() else {
                    return
            }
            
            // Setting (focus/exposure)PointOfInterest alone does not initiate a (focus/exposure) operation.
            // Call set(Focus/Exposure)Mode() to apply the new point of interest.
            
            if device.isFocusPointOfInterestSupported && device.isFocusModeSupported(focusMode) {
                device.focusPointOfInterest = devicePoint
                device.focusMode = focusMode
            }
            
            if device.isExposurePointOfInterestSupported && device.isExposureModeSupported(exposureMode) {
                device.exposurePointOfInterest = devicePoint
                device.exposureMode = exposureMode
            }
            
            device.isSubjectAreaChangeMonitoringEnabled = monitorSubjectAreaChange
            device.unlockForConfiguration()
        }
    }
    
    @IBAction private func capturePhoto(_ captureButton: UIButton) {
        sessionQueue.async { [weak self] in
            guard let sSelf = self else { return }
            
            // Update the photo output's connection to match the video orientation of the video preview layer.
            guard let videoPreviewLayerConnection = sSelf.previewView.videoPreviewLayer.connection,
                let photoOutputConnection = sSelf.photoOutputDevice.captureOutput.connection(withMediaType: AVMediaTypeVideo) else { return }
            
            let isMirrored = videoPreviewLayerConnection.isVideoMirrored
            photoOutputConnection.videoOrientation = videoPreviewLayerConnection.videoOrientation
            photoOutputConnection.isVideoMirrored = isMirrored
            
            sSelf.photoOutputDevice.capturePhoto(from: photoOutputConnection, flashMode: sSelf.preferredFlashMode, completion: { (image, error) in
                if let image = image {
                    sSelf.showCapturedPhoto(image)
                }
            })
        }
    }
    
    private func showCapturedPhoto(_ image: UIImage) {
        photoImageView.image = image
        setCapturedPhotoView(hidden: false)
    }
    
    private func setCapturedPhotoView(hidden: Bool) {
        UIView.transition(with: view,
                          duration: 0.2,
                          options: .transitionCrossDissolve,
                          animations: { [weak self] in
                            self?.capturedPhotoView.isHidden = hidden
            }, completion: { finished in
                
        })
    }
    
    // MARK: - Actions
    
    @IBAction private func focusAndExposeTap(_ gestureRecognizer: UITapGestureRecognizer) {
        guard setupResult == .success else { return }
        let touchPoint = gestureRecognizer.location(in: self.previewView)
        let devicePoint = self.previewView.videoPreviewLayer.captureDevicePointOfInterest(for: gestureRecognizer.location(in: gestureRecognizer.view))
        guard CGRect(x: 0, y: 0, width: 1.0, height: 1.0).contains(devicePoint) else { return }
        if let focusView = focusView {
            focusView.updatePoint(touchPoint)
        } else {
            focusView = AVCamFocusView(touchPoint: touchPoint)
            previewView.insertSubview(focusView!, at: 1)
            focusView?.setNeedsDisplay()
        }
        focusView?.animateFocusingAction()
        focus(with: .autoFocus, exposureMode: .autoExpose, at: devicePoint, monitorSubjectAreaChange: true)
    }
    
    
    @IBAction private func changeCamera(_ switchCameraButton: UIButton) {
        switchCameraButton.isEnabled = false
        captureButton.isEnabled = false
        
        sessionQueue.async { [weak self] in
            guard let sSelf = self else { return }
            let currentVideoDevice = sSelf.videoDeviceInput.device
            let currentPosition = currentVideoDevice!.position
            
            let preferredPosition: AVCaptureDevicePosition
            
            switch currentPosition {
            case .unspecified, .front:
                preferredPosition = .back
            case .back:
                preferredPosition = .front
            }
            
            let devices = AVCaptureDevice.allVideoDevices
            var newVideoDevice: AVCaptureDevice? = nil
            
            // First, look for a device with both the preferred position and device type. Otherwise, look for a device with only the preferred position.
            if let device = devices.filter({ $0.position == preferredPosition }).first {
                newVideoDevice = device
            } else if let device = devices.filter({ $0.position == preferredPosition }).first {
                newVideoDevice = device
            }
            
            if let videoDevice = newVideoDevice,
                let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice) {
                sSelf.updateFlashModes(for: videoDevice)
                sSelf.session.beginConfiguration()
                
                // Remove the existing device input first, since using the front and back camera simultaneously is not supported.
                sSelf.session.removeInput(sSelf.videoDeviceInput)
                
                if sSelf.session.canAddInput(videoDeviceInput) {
                    NotificationCenter.default.removeObserver(sSelf, name: .AVCaptureDeviceSubjectAreaDidChange, object: currentVideoDevice!)
                    NotificationCenter.default.addObserver(sSelf,
                                                           selector: #selector(sSelf.subjectAreaDidChange),
                                                           name: .AVCaptureDeviceSubjectAreaDidChange,
                                                           object: videoDeviceInput.device)
                    
                    sSelf.session.addInput(videoDeviceInput)
                    sSelf.videoDeviceInput = videoDeviceInput
                } else {
                    sSelf.session.addInput(sSelf.videoDeviceInput);
                }
                sSelf.session.commitConfiguration()
            }
            
            DispatchQueue.main.async { [weak self] in
                self?.switchCameraButton.isEnabled = true
                self?.captureButton.isEnabled = true
            }
        }
    }
    
    private func updateFlashModes(for device: AVCaptureDevice) {
        var availableModes = [AVCaptureFlashMode]()
        var selectedMode: AVCaptureFlashMode? = nil
        defer {
            DispatchQueue.main.async { [weak self] in
                self?.flashModesCollectionCoordinator?.setModes(availableModes, selected: selectedMode)
            }
        }
        
        guard device.hasFlash else { return }
        let allModes: [AVCaptureFlashMode] = [.auto, .on, .off]
        availableModes = allModes.filter({ device.isFlashModeSupported($0)})
        selectedMode = preferredFlashMode
        if availableModes.contains(preferredFlashMode) {
            do {
                try? device.lockForConfiguration()
                device.flashMode = preferredFlashMode
                device.unlockForConfiguration()
            }
        }
    }
    
    @IBAction private func didTapFlashMode(_ sender: UIButton) {
        UIView.transition(with: view, duration: 0.15, options: .transitionCrossDissolve, animations: { [weak self] in
            let isHidden = self?.flashModesCollectionView.isHidden ?? true
            self?.flashModesCollectionView.isHidden = !isHidden
        }, completion: nil)        
    }

    
    @IBAction private func didTapBack(_ sender: UIButton) {
        delegate?.cameraControllerDidCancel(self)
    }
    
    @IBAction private func didTapUsePhoto(_ sender: UIButton) {
        if let image = photoImageView.image {
            delegate?.cameraControllerDidTakePhoto(self, image)
        }
    }
    
    @IBAction private func didTapRetake(_ sender: UIButton) {
        setCapturedPhotoView(hidden: true)
        photoImageView.image = nil
    }
    
    // MARK: KVO and Notifications
    
    private var sessionRunningObserveContext = 0
    
    private func addObservers() {
        session.addObserver(self, forKeyPath: "running", options: .new, context: &sessionRunningObserveContext)
        
        NotificationCenter.default.addObserver(self, selector: #selector(subjectAreaDidChange), name: .AVCaptureDeviceSubjectAreaDidChange, object: videoDeviceInput.device)
    }
    
    private func removeObservers() {
        NotificationCenter.default.removeObserver(self)
        
        session.removeObserver(self, forKeyPath: "running", context: &sessionRunningObserveContext)
    }
    
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        //        guard #available(iOS 10, *) else { return }
        if context == &sessionRunningObserveContext {
            let newValue = change?[.newKey] as AnyObject?
            guard let isSessionRunning = newValue?.boolValue else { return }
            
            DispatchQueue.main.async { [weak self] in
                guard let sSelf = self else { return }
                // Only enable the ability to change camera if the device has more than one camera.
                sSelf.switchCameraButton.isEnabled = isSessionRunning && AVCaptureDevice.uniqueDevicePositionsCount() > 1
                sSelf.captureButton.isEnabled = isSessionRunning
            }
        } else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }
    
    func subjectAreaDidChange(notification: NSNotification) {
        let devicePoint = CGPoint(x: 0.5, y: 0.5)
        focus(with: .autoFocus, exposureMode: .continuousAutoExposure, at: devicePoint, monitorSubjectAreaChange: false)
    }
}

extension AVCamController: FlashModesCoordinatorDelegate {
    internal func flashModesCoordinator(_ coordinator: FlashModesCollectionViewCoordinator, didSelect mode: AVCaptureFlashMode) {
        preferredFlashMode = mode
        flashModesCollectionView.isHidden = true
    }
}

extension UIDeviceOrientation {
    var videoOrientation: AVCaptureVideoOrientation? {
        switch self {
        case .portrait:
            return .portrait
        case .portraitUpsideDown:
            return .portraitUpsideDown
        case .landscapeLeft:
            return .landscapeRight
        case .landscapeRight:
            return .landscapeLeft
        default:
            return nil
        }
    }
}

extension UIInterfaceOrientation {
    var videoOrientation: AVCaptureVideoOrientation? {
        switch self {
        case .portrait:
            return .portrait
        case .portraitUpsideDown:
            return .portraitUpsideDown
        case .landscapeLeft:
            return .landscapeLeft
        case .landscapeRight:
            return .landscapeRight
        default:
            return nil
        }
    }
}


fileprivate extension AVCaptureDevice {
    static var allVideoDevices: [AVCaptureDevice] {
        return AVCaptureDevice.devices(withMediaType: AVMediaTypeVideo) as? [AVCaptureDevice] ?? [AVCaptureDevice]()
    }
    
    static func uniqueDevicePositionsCount() -> Int {
        var uniqueDevicePositions = [AVCaptureDevicePosition]()
        let devices = allVideoDevices
        
        for device in devices {
            if !uniqueDevicePositions.contains(device.position) {
                uniqueDevicePositions.append(device.position)
            }
        }
        return uniqueDevicePositions.count
    }
}
