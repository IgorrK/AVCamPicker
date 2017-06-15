//
//  Utilities.swift
//  AVCamPicker
//
//  Created by igor on 6/14/17.
//  Copyright © 2017 igor. All rights reserved.
//

import Foundation
import UIKit
import AVFoundation

extension UIAlertController {
    
    /// Creates an instance of UIAlertController of .alert type
    /// and configures it with sepcified parameters.
    ///
    /// - Parameters:
    ///   - title: Optional alert title.
    ///   - message: Optional alert message.
    ///   - actions: Options alert actions (if nil - default 'Ok' action will be added).
    /// - Returns: Configured and ready to use alert controller.
    internal static func alert(title: String?, message: String?, actions: [UIAlertAction]? = nil) -> UIAlertController {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let actions = actions ?? [UIAlertAction(title: "Ok", style: .default, handler: nil)]
        actions.forEach({ alertController.addAction($0) })
        return alertController
    }
}

extension UIColor {
    static let higlightsYellow = UIColor(red: 0.964, green: 0.7886, blue: 0.0109, alpha: 1)
}

extension AVCaptureFlashMode {
    var title: String {
        switch self {
        case .auto:
            return "Auto"
        case .on:
            return "On"
        case .off:
            return "Off"
        }
    }
    
    var icon: UIImage {
        switch self {
        case .auto:
            return #imageLiteral(resourceName: "Flash Auto")
        case .on:
            return #imageLiteral(resourceName: "Flash On")
        case .off:
            return #imageLiteral(resourceName: "Flash Off")
        }
    }
}
