//
//  MusicBottomSheetVC.swift
//  VideoEditing
//
//  Created by Plexus Technology on 28/02/25.
//

import UIKit
import AVFoundation

// MARK: - Music Selection Delegate
protocol MusicSelectionDelegate: AnyObject {
    func didSelectMusic(url: URL)
}

// MARK: - Music Selection Bottom Sheet ViewController
class MusicSelectionBottomSheetVC: UIViewController {
    
    private let titleLabel = UILabel()
    private let tableView = UITableView()
    private var musicFiles: [URL] = []
    
    var selectedMusicURL: URL?
    var currentlyPlayingURL: URL?
    var audioPlayer: AVAudioPlayer?
    
    weak var delegate: MusicSelectionDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadMusicFiles()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        audioPlayer?.stop()
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        titleLabel.text = "Select Music"
        titleLabel.font = UIFont.boldSystemFont(ofSize: 18)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(MusicTableViewCell.self, forCellReuseIdentifier: "MusicCell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.separatorStyle = .singleLine
        
        view.addSubview(titleLabel)
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            tableView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }
    
    private func loadMusicFiles() {
        guard let resourcePath = Bundle.main.resourcePath else { return }
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: URL(fileURLWithPath: resourcePath), includingPropertiesForKeys: nil)
            musicFiles = fileURLs.filter { $0.pathExtension == "mp3" }
            tableView.reloadData()
        } catch {
            print("Error loading music files: \(error)")
        }
    }
    
    private func togglePlayPause(for url: URL, cell: MusicTableViewCell) {
        if currentlyPlayingURL == url {
            if audioPlayer?.isPlaying == true {
                audioPlayer?.pause()
                cell.updatePlayPauseButton(isPlaying: false)
            } else {
                audioPlayer?.play()
                cell.updatePlayPauseButton(isPlaying: true)
            }
        } else {
            audioPlayer?.stop()
            
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: url)
                audioPlayer?.delegate = self
                audioPlayer?.numberOfLoops = -1
                audioPlayer?.prepareToPlay()
                audioPlayer?.play()
                
                if let previousURL = currentlyPlayingURL,
                   let index = musicFiles.firstIndex(of: previousURL),
                   let previousCell = tableView.cellForRow(at: IndexPath(row: index, section: 0)) as? MusicTableViewCell {
                    previousCell.updatePlayPauseButton(isPlaying: false)
                }
                
                currentlyPlayingURL = url
                cell.updatePlayPauseButton(isPlaying: true)
            } catch {
                print("Error playing audio: \(error.localizedDescription)")
            }
        }
    }
    
    private func selectMusic(url: URL, cell: MusicTableViewCell) {
        if let previousURL = selectedMusicURL,
           let index = musicFiles.firstIndex(of: previousURL),
           let previousCell = tableView.cellForRow(at: IndexPath(row: index, section: 0)) as? MusicTableViewCell {
            previousCell.updateSelectedState(isSelected: false)
        }
        
        selectedMusicURL = url
        cell.updateSelectedState(isSelected: true)
        
        delegate?.didSelectMusic(url: url)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.dismiss(animated: true)
        }
    }
}

// MARK: - AVAudioPlayerDelegate
extension MusicSelectionBottomSheetVC: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if flag {
            player.currentTime = 0
            player.play()
            if let url = currentlyPlayingURL,
               let index = musicFiles.firstIndex(of: url),
               let cell = tableView.cellForRow(at: IndexPath(row: index, section: 0)) as? MusicTableViewCell {
                cell.updatePlayPauseButton(isPlaying: true)
            }
        }
    }
}

// MARK: - TableView Extension
extension MusicSelectionBottomSheetVC: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return musicFiles.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "MusicCell", for: indexPath) as! MusicTableViewCell
        
        let musicURL = musicFiles[indexPath.row]
        let filename = musicURL.lastPathComponent
        
        cell.configure(title: filename,
                       isPlaying: currentlyPlayingURL == musicURL,
                       isSelected: selectedMusicURL == musicURL)
        
        cell.playPauseHandler = { [weak self] in
            guard let self = self else { return }
            self.togglePlayPause(for: musicURL, cell: cell)
        }
        
        cell.selectHandler = { [weak self] in
            guard let self = self else { return }
            self.selectMusic(url: musicURL, cell: cell)
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 70
    }
}

// MARK: - Music Table View Cell
class MusicTableViewCell: UITableViewCell {
    
    private let titleLabel = UILabel()
    private let playPauseButton = UIButton()
    private let selectButton = UIButton()
    
    var playPauseHandler: (() -> Void)?
    var selectHandler: (() -> Void)?
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = UIFont.systemFont(ofSize: 16)
        titleLabel.numberOfLines = 1
        
        playPauseButton.translatesAutoresizingMaskIntoConstraints = false
        playPauseButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
        playPauseButton.tintColor = .systemBlue
        playPauseButton.addTarget(self, action: #selector(playPauseButtonTapped), for: .touchUpInside)
        
        selectButton.translatesAutoresizingMaskIntoConstraints = false
        selectButton.setTitle("Select", for: .normal)
        selectButton.setTitleColor(.white, for: .normal)
        selectButton.backgroundColor = .systemBlue
        selectButton.layer.cornerRadius = 15
        selectButton.addTarget(self, action: #selector(selectButtonTapped), for: .touchUpInside)
        
        contentView.addSubview(titleLabel)
        contentView.addSubview(playPauseButton)
        contentView.addSubview(selectButton)
        
        NSLayoutConstraint.activate([
            playPauseButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            playPauseButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            playPauseButton.widthAnchor.constraint(equalToConstant: 44),
            playPauseButton.heightAnchor.constraint(equalToConstant: 44),
            
            titleLabel.leadingAnchor.constraint(equalTo: playPauseButton.trailingAnchor, constant: 12),
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: selectButton.leadingAnchor, constant: -12),
            
            selectButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            selectButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            selectButton.widthAnchor.constraint(equalToConstant: 80),
            selectButton.heightAnchor.constraint(equalToConstant: 30)
        ])
    }
    
    func configure(title: String, isPlaying: Bool, isSelected: Bool) {
        titleLabel.text = title
        updatePlayPauseButton(isPlaying: isPlaying)
        updateSelectedState(isSelected: isSelected)
    }
    
    func updatePlayPauseButton(isPlaying: Bool) {
        let imageName = isPlaying ? "pause.fill" : "play.fill"
        playPauseButton.setImage(UIImage(systemName: imageName), for: .normal)
    }
    
    func updateSelectedState(isSelected: Bool) {
        if isSelected {
            selectButton.setTitle("Selected", for: .normal)
            selectButton.backgroundColor = .systemGreen
        } else {
            selectButton.setTitle("Select", for: .normal)
            selectButton.backgroundColor = .systemBlue
        }
    }
    
    @objc private func playPauseButtonTapped() {
        playPauseHandler?()
    }
    
    @objc private func selectButtonTapped() {
        selectHandler?()
    }
}
