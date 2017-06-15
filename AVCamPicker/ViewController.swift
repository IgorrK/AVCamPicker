//
//  ViewController.swift
//  AVCamPicker
//
//  Created by igor on 6/13/17.
//  Copyright © 2017 igor. All rights reserved.
//

import UIKit

final class ViewController: UIViewController {

    // MARK: - Outlets
    
    @IBOutlet fileprivate weak var capturedImageView: UIImageView!
    
    // MARK: - UIViewController
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    // MARK: - Actions
    
    @IBAction func didTapTakeShot(_ sender: UIButton) {
        let cameraController = AVCamController()
        cameraController.delegate = self
        present(cameraController, animated: true, completion: nil)
    }

}

extension ViewController: AVCamControllerDelegate {
    internal func cameraControllerDidTakePhoto(_ controller: AVCamController, _ image: UIImage) {
        dismiss(animated: true, completion: nil)
        capturedImageView.image = image
    }
    
    internal func cameraControllerDidCancel(_ controller: AVCamController) {
        dismiss(animated: true, completion: nil)
    }
    
}

