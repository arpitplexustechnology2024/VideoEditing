//
//  VideoCaptureShowVC.swift
//  VideoEditing
//
//  Created by Plexus Technology on 28/02/25.
//

import UIKit
import Photos
import AVFoundation

// MARK: - VideoCaptureShowVC
class VideoCaptureShowVC: UIViewController {
    
    var videoURL: URL?
    var playbackSpeed: Float = 1.0
    
    private var playerLayer: AVPlayerLayer?
    private var player: AVPlayer?
    private let playPauseButton = UIButton(type: .system)
    private let saveButton = UIButton(type: .system)
    private let cancelButton = UIButton(type: .system)
    
    private var isPlaying = false
    private var originalVideoOrientation: CGAffineTransform?
    private var currentTrimmedAsset: AVAsset? {
        if let videoURL = videoURL {
            return AVAsset(url: videoURL)
        }
        return nil
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupVideoPlayer()
        setupUI()
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(playerDidFinishPlaying),
                                               name: .AVPlayerItemDidPlayToEndTime,
                                               object: player?.currentItem)
        
        if let url = videoURL {
            let asset = AVAsset(url: url)
            if let videoTrack = asset.tracks(withMediaType: .video).first {
                originalVideoOrientation = videoTrack.preferredTransform
            }
        }
        
        print(playbackSpeed)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        player?.play()
        player?.rate = playbackSpeed
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
        player?.rate = playbackSpeed
        
        playerLayer = AVPlayerLayer(player: player)
        playerLayer?.videoGravity = .resizeAspectFill
        playerLayer?.frame = view.bounds
        
        if let playerLayer = playerLayer {
            view.layer.addSublayer(playerLayer)
        }
    }
    
    @objc private func playerDidFinishPlaying() {
        player?.seek(to: .zero)
        player?.play()
        player?.rate = playbackSpeed
        isPlaying = true
        updatePlayPauseButton()
    }
    
    @objc private func playPauseButtonTapped() {
        if isPlaying {
            player?.pause()
        } else {
            player?.play()
            player?.rate = playbackSpeed
        }
        
        isPlaying = !isPlaying
        updatePlayPauseButton()
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
    
    @objc private func saveButtonTapped() {
        guard let asset = currentTrimmedAsset else { return }
        
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let dateString = dateFormatter.string(from: Date())
        let outputURL = documentsDirectory.appendingPathComponent("TrimmedVideo_\(dateString).mp4")
        
        if FileManager.default.fileExists(atPath: outputURL.path) {
            do {
                try FileManager.default.removeItem(at: outputURL)
            } catch {
                print("Could not remove existing file: \(error)")
            }
        }
        
        print("Current Video Rate before export: \(playbackSpeed)")
        
        let composition = AVMutableComposition()
        
        guard let videoTrack = asset.tracks(withMediaType: .video).first,
              let compositionVideoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            showAlert(title: "Error", message: "Could not create video composition track")
            return
        }
        
        var compositionAudioTrack: AVMutableCompositionTrack?
        if let audioTrack = asset.tracks(withMediaType: .audio).first {
            compositionAudioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        }
        
        let assetDuration = asset.duration
        let timeRange = CMTimeRangeMake(start: .zero, duration: assetDuration)
        
        do {
            try compositionVideoTrack.insertTimeRange(timeRange, of: videoTrack, at: .zero)
            
            if let audioTrack = asset.tracks(withMediaType: .audio).first,
               let compositionAudioTrack = compositionAudioTrack {
                try compositionAudioTrack.insertTimeRange(timeRange, of: audioTrack, at: .zero)
            }
            
            if let originalTransform = originalVideoOrientation {
                compositionVideoTrack.preferredTransform = originalTransform
            } else {
                compositionVideoTrack.preferredTransform = videoTrack.preferredTransform
            }
            
            let speedFactor = 1.0 / Double(playbackSpeed)
            let newDuration = CMTimeMultiplyByFloat64(assetDuration, multiplier: speedFactor)
            
            print("Original Duration: \(CMTimeGetSeconds(assetDuration)) seconds")
            print("Speed Factor: \(speedFactor)")
            print("Speed: \(playbackSpeed)x")
            print("New Duration Should Be: \(CMTimeGetSeconds(newDuration)) seconds")
            
            compositionVideoTrack.scaleTimeRange(
                CMTimeRangeMake(start: .zero, duration: assetDuration),
                toDuration: newDuration
            )
            
            if let compositionAudioTrack = compositionAudioTrack {
                compositionAudioTrack.scaleTimeRange(
                    CMTimeRangeMake(start: .zero, duration: assetDuration),
                    toDuration: newDuration
                )
            }
            
            print("Final Composition Duration: \(CMTimeGetSeconds(composition.duration)) seconds")
            
        } catch {
            showAlert(title: "Error", message: "Could not create composition: \(error.localizedDescription)")
            return
        }
        
        let videoComposition = AVMutableVideoComposition()
        
        let renderSize = getRenderSizeForVideoTrack(videoTrack)
        videoComposition.renderSize = renderSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
        
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRangeMake(start: .zero, duration: composition.duration)
        
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compositionVideoTrack)
        
        let transform = getVideoTransformForTrack(videoTrack, renderSize: renderSize)
        layerInstruction.setTransform(transform, at: .zero)
        
        instruction.layerInstructions = [layerInstruction]
        videoComposition.instructions = [instruction]
        
        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            showAlert(title: "Error", message: "Could not create export session")
            return
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.videoComposition = videoComposition
        exportSession.shouldOptimizeForNetworkUse = true
        
        print("Export Session Duration: \(CMTimeGetSeconds(exportSession.timeRange.duration)) seconds")
        
        let loadingAlert = UIAlertController(title: "", message: "", preferredStyle: .alert)
        let loadingIndicator = UIActivityIndicatorView(style: .large)
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.startAnimating()
        
        loadingAlert.view.addSubview(loadingIndicator)
        
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: loadingAlert.view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: loadingAlert.view.centerYAnchor),
            loadingIndicator.heightAnchor.constraint(equalToConstant: 50),
            loadingIndicator.widthAnchor.constraint(equalToConstant: 50)
        ])
        
        loadingAlert.view.heightAnchor.constraint(equalToConstant: 100).isActive = true
        loadingAlert.view.widthAnchor.constraint(equalToConstant: 100).isActive = true
        
        present(loadingAlert, animated: true, completion: nil)
        
        exportSession.exportAsynchronously {
            DispatchQueue.main.async {
                loadingAlert.dismiss(animated: true) {
                    switch exportSession.status {
                    case .completed:
                        self.saveToPhotoLibrary(videoURL: outputURL)
                    case .failed, .cancelled:
                        if let error = exportSession.error {
                            self.showAlert(title: "Export Failed", message: error.localizedDescription)
                        } else {
                            self.showAlert(title: "Export Failed", message: "Unknown error occurred")
                        }
                    default:
                        self.showAlert(title: "Export Failed", message: "Unknown error occurred")
                    }
                }
            }
        }
    }
    
    private func getRenderSizeForVideoTrack(_ videoTrack: AVAssetTrack) -> CGSize {
        let naturalSize = videoTrack.naturalSize
        let transform = videoTrack.preferredTransform
        
        let isPortrait = abs(transform.b) == 1.0 || abs(transform.c) == 1.0
        
        if isPortrait {
            return CGSize(width: naturalSize.height, height: naturalSize.width)
        } else {
            return naturalSize
        }
    }
    
    private func getVideoTransformForTrack(_ videoTrack: AVAssetTrack, renderSize: CGSize) -> CGAffineTransform {
        let naturalSize = videoTrack.naturalSize
        let transform = videoTrack.preferredTransform
        
        if let originalTransform = originalVideoOrientation {
            return originalTransform
        }
        
        let isPortrait = abs(transform.b) == 1.0 || abs(transform.c) == 1.0
        
        if isPortrait {
            var adjustedTransform = CGAffineTransform.identity
            
            if transform.a == 0 && transform.b == 1.0 && transform.c == -1.0 && transform.d == 0 {
                adjustedTransform = CGAffineTransform(a: 0, b: 1.0, c: -1.0, d: 0, tx: naturalSize.height, ty: 0)
            } else if transform.a == 0 && transform.b == -1.0 && transform.c == 1.0 && transform.d == 0 {
                adjustedTransform = CGAffineTransform(a: 0, b: -1.0, c: 1.0, d: 0, tx: 0, ty: naturalSize.width)
            }
            
            return adjustedTransform
        } else {
            return transform
        }
    }
    
    private func saveToPhotoLibrary(videoURL: URL) {
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
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
