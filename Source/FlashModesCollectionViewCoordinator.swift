//
//  FlashModesCollectionViewCoordinator.swift
//  AVCamPicker
//
//  Created by igor on 6/14/17.
//  Copyright © 2017 igor. All rights reserved.
//

import UIKit
import AVFoundation

protocol FlashModesCoordinatorDelegate: class {
    func flashModesCoordinator(_ coordinator: FlashModesCollectionViewCoordinator, didSelect mode: AVCaptureFlashMode)
}

final class FlashModesCollectionViewCoordinator: NSObject, UICollectionViewDelegate, UICollectionViewDataSource {

    // MARK: - Constants
    
    private static let cellIdentifier = "FlashModeCell"
    
    // MARK: - Propeties
    
    internal weak var delegate: FlashModesCoordinatorDelegate?
    private var collectionView: UICollectionView
    private var dataSource: [AVCaptureFlashMode] {
        didSet {
            self.dataSource = self.dataSource.sorted(by: { $0.rawValue > $1.rawValue })
        }
    }
    
    // MARK: - Lifecycle
    
    internal init(collectionView: UICollectionView, flashModes: [AVCaptureFlashMode], selectedMode: AVCaptureFlashMode? = .auto) {
        self.collectionView = collectionView
        self.dataSource = flashModes
        super.init()
        configureCollectionView()
    }
    
    // MARK: - Private methods
    
    private func configureCollectionView() {
        let cellNib = UINib(nibName: String(describing: FlashModeCollectionViewCell.self), bundle: nil)
        collectionView.register(cellNib, forCellWithReuseIdentifier: FlashModesCollectionViewCoordinator.cellIdentifier)
        collectionView.dataSource = self
        collectionView.delegate = self
    }
    
    // MARK: - Public methods
    
    internal func setModes(_ modes: [AVCaptureFlashMode], selected: AVCaptureFlashMode? = nil) {
        dataSource = modes
        collectionView.reloadData()
        if let selectedMode = selected,
            let index = modes.index(of: selectedMode) {
            let indexPath = IndexPath(row: index, section: 0)
            collectionView.selectItem(at: indexPath, animated: false, scrollPosition: .centeredHorizontally)
        }
    }
    
    // MARK: - UICollectionViewDelegate
    
    internal func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let mode = dataSource[indexPath.row]
        delegate?.flashModesCoordinator(self, didSelect: mode)
    }
    
    // MARK: - UICollectionViewDataSource
    
    internal func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return dataSource.count
    }
    
    internal func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    internal func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let genericCell = collectionView.dequeueReusableCell(withReuseIdentifier: FlashModesCollectionViewCoordinator.cellIdentifier, for: indexPath)
        guard let cell = genericCell as? FlashModeCollectionViewCell else { return genericCell }
        cell.setTitle(dataSource[indexPath.row].title)
        return cell
    }
}

