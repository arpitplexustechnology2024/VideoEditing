//
//  MusicCell.swift
//  VideoEditing
//
//  Created by Plexus Technology on 27/02/25.
//

import Foundation
import UIKit

class MusicCell: UITableViewCell {
    let musicNameLabel = UILabel()
    let playButton = UIButton()
    let selectButton = UIButton()
    var indexPath: IndexPath!
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        selectionStyle = .none
        
        musicNameLabel.translatesAutoresizingMaskIntoConstraints = false
        musicNameLabel.font = UIFont.systemFont(ofSize: 16)
        contentView.addSubview(musicNameLabel)
        
        playButton.translatesAutoresizingMaskIntoConstraints = false
        playButton.setImage(UIImage(systemName: "play.circle"), for: .normal)
        playButton.tintColor = .systemBlue
        contentView.addSubview(playButton)
        
        selectButton.translatesAutoresizingMaskIntoConstraints = false
        selectButton.setImage(UIImage(systemName: "plus.circle"), for: .normal)
        selectButton.tintColor = .systemGray
        contentView.addSubview(selectButton)
        
        NSLayoutConstraint.activate([
            musicNameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            musicNameLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            musicNameLabel.trailingAnchor.constraint(lessThanOrEqualTo: playButton.leadingAnchor, constant: -8),
            
            playButton.trailingAnchor.constraint(equalTo: selectButton.leadingAnchor, constant: -16),
            playButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            playButton.widthAnchor.constraint(equalToConstant: 40),
            playButton.heightAnchor.constraint(equalToConstant: 40),
            
            selectButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            selectButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            selectButton.widthAnchor.constraint(equalToConstant: 40),
            selectButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    func configure(with musicName: String, indexPath: IndexPath) {
        musicNameLabel.text = musicName
        self.indexPath = indexPath
    }
}
