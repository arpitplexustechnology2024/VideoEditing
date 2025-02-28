//
//  VideoCaptureShowVC.swift
//  VideoEditing
//
//  Created by Plexus Technology on 28/02/25.
//

import UIKit
import Photos

// MARK: - VideoCaptureShowVC
class VideoCaptureShowVC: UIViewController {
    private var playerLayer: AVPlayerLayer?
    private var player: AVPlayer?
    private let playPauseButton = UIButton(type: .system)
    private let saveButton = UIButton(type: .system)
    private let cancelButton = UIButton(type: .system)
    var videoURL: URL?
    private var isPlaying = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupVideoPlayer()
        setupUI()
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(playerDidFinishPlaying),
                                               name: .AVPlayerItemDidPlayToEndTime,
                                               object: player?.currentItem)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        player?.play()
        isPlaying = true
        updatePlayPauseButton()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        playerLayer?.frame = view.bounds
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Setup Methods
    
    private func setupVideoPlayer() {
        guard let videoURL = videoURL else { return }

        player = AVPlayer(url: videoURL)

        playerLayer = AVPlayerLayer(player: player)
        playerLayer?.videoGravity = .resizeAspectFill
        playerLayer?.frame = view.bounds
        
        if let playerLayer = playerLayer {
            view.layer.addSublayer(playerLayer)
        }
    }
    
    private func setupUI() {
        playPauseButton.setImage(UIImage(systemName: "pause.fill"), for: .normal)
        playPauseButton.tintColor = .white
        playPauseButton.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        playPauseButton.layer.cornerRadius = 25
        playPauseButton.translatesAutoresizingMaskIntoConstraints = false
        playPauseButton.addTarget(self, action: #selector(playPauseButtonTapped), for: .touchUpInside)

        saveButton.setTitle("Save", for: .normal)
        saveButton.setTitleColor(.white, for: .normal)
        saveButton.backgroundColor = UIColor(red: 0, green: 0.5, blue: 0, alpha: 0.7)
        saveButton.layer.cornerRadius = 10
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        saveButton.addTarget(self, action: #selector(saveButtonTapped), for: .touchUpInside)
        
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.setTitleColor(.white, for: .normal)
        cancelButton.backgroundColor = UIColor(red: 0.8, green: 0, blue: 0, alpha: 0.7)
        cancelButton.layer.cornerRadius = 10
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.addTarget(self, action: #selector(cancelButtonTapped), for: .touchUpInside)
        
        view.addSubview(playPauseButton)
        view.addSubview(saveButton)
        view.addSubview(cancelButton)
        
        NSLayoutConstraint.activate([
            playPauseButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            playPauseButton.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            playPauseButton.widthAnchor.constraint(equalToConstant: 50),
            playPauseButton.heightAnchor.constraint(equalToConstant: 50),
            
            saveButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            saveButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -30),
            saveButton.widthAnchor.constraint(equalToConstant: 120),
            saveButton.heightAnchor.constraint(equalToConstant: 44),
            
            cancelButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            cancelButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -30),
            cancelButton.widthAnchor.constraint(equalToConstant: 120),
            cancelButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    // MARK: - Button Actions
    
    @objc private func playPauseButtonTapped() {
        if isPlaying {
            player?.pause()
        } else {
            player?.play()
        }
        
        isPlaying = !isPlaying
        updatePlayPauseButton()
    }
    
    @objc private func saveButtonTapped() {
        guard let videoURL = videoURL else { return }
        if #available(iOS 10.0, *) {
            PHPhotoLibrary.requestAuthorization { status in
                guard status == .authorized else {
                    DispatchQueue.main.async {
                        self.showAlert(title: "Permission Denied", message: "Please allow access to save video in your photo library.")
                    }
                    return
                }
                
                PHPhotoLibrary.shared().performChanges({
                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoURL)
                }) { success, error in
                    if success {
                        DispatchQueue.main.async {
                            self.showAlert(title: "Video Saved", message: "Your video has been saved to your photo library.")
                        }
                    } else {
                        DispatchQueue.main.async {
                            self.showAlert(title: "Error", message: "Could not save the video: \(error?.localizedDescription ?? "Unknown error")")
                        }
                    }
                }
            }
        }
    }
    
    @objc private func cancelButtonTapped() {
        player?.pause()
        self.dismiss(animated: true)
    }
    
    // MARK: - Helper Methods
    
    private func updatePlayPauseButton() {
        let imageName = isPlaying ? "pause.fill" : "play.fill"
        playPauseButton.setImage(UIImage(systemName: imageName), for: .normal)
    }
    
    @objc private func playerDidFinishPlaying() {
        player?.seek(to: .zero)
        player?.play()
        isPlaying = true
        updatePlayPauseButton()
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
