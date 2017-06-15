//
//  AVAVCamFocusView.swift
//  AVCamPicker
//
//  Created by igor on 6/13/17.
//  Copyright © 2017 igor. All rights reserved.
//

import UIKit

final class AVCamFocusView: UIView, CAAnimationDelegate {
    
    // MARK: - Constants
    
    private static let squareSize = CGSize(width: 80.0, height: 80.0)
    private static let animationKeyPath = "transform.scale"
    private static let selectionAnimation = "selectionAnimation"

    // MARK: - Properties
    
    fileprivate var scaleAnimation: CABasicAnimation?
    
    // MARK: - Lifecycle
    
    convenience init(touchPoint: CGPoint) {
        self.init()
        updatePoint(touchPoint)
        backgroundColor = UIColor.clear
        layer.borderWidth = 1.0
        layer.borderColor = UIColor.higlightsYellow.cgColor
        initAnimation()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    private func initAnimation() {
        let animation = CABasicAnimation(keyPath: AVCamFocusView.animationKeyPath)
        animation.toValue = NSNumber(value: 1.0)
        animation.fromValue = NSNumber(value: 1.5)
        animation.duration = 0.2
        animation.isRemovedOnCompletion = false
        animation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
        scaleAnimation = animation
        animation.delegate = self
    }

    // MARK: - Public methods
    
    /// Updates the location of the view based on the incoming touchPoint.
    ///
    /// - Parameter touchPoint: Center of new focus square.
    internal func updatePoint(_ touchPoint: CGPoint) {
        let size = AVCamFocusView.squareSize
        let origin = CGPoint(x: touchPoint.x - size.width / 2.0, y: touchPoint.y - size.height / 2.0)
        frame = CGRect(origin: origin, size: size)
    }
    
    /// Unhides the view and initiates the animation by adding it to the layer.
    internal func animateFocusingAction() {
        guard let animation = scaleAnimation else { return }
            // make the view visible
            alpha = 1.0
            isHidden = false
            // initiate the animation
            layer.add(animation, forKey: AVCamFocusView.selectionAnimation)
    }

    // MARK: - CAAnimationDelegate
    
    internal func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
        guard flag else { return }
            alpha = 0.0
            isHidden = true
    }
}
