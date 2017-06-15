//
//  FlashModeCollectionViewCell.swift
//  AVCamPicker
//
//  Created by igor on 6/14/17.
//  Copyright © 2017 igor. All rights reserved.
//

import UIKit

final class FlashModeCollectionViewCell: UICollectionViewCell {

    // MARK: - Constants
    
    private static let defaultTitleColor = UIColor.white
    private static let selectedTitleColor = UIColor.higlightsYellow
    
    // MARK: - Outlets
    
    @IBOutlet private weak var titleLabel: UILabel!
    
    // MARK: - Lifecycle
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    // MARK: - UICollectionViewCell

    override var isSelected: Bool {
        didSet {
            titleLabel.textColor = isSelected ? FlashModeCollectionViewCell.selectedTitleColor : FlashModeCollectionViewCell.defaultTitleColor
        }
    }
    
    // MARK: - Public methods
    
    internal func setTitle(_ title: String) {
        titleLabel.text = title
    }
}
