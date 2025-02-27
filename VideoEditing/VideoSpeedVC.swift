//
//  VideoSpeedVC.swift
//  VideoEditing
//
//  Created by Plexus Technology on 27/02/25.
//

import UIKit
import AVFoundation
import Photos

class VideoSpeedVC: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    @IBOutlet weak var addVideoButton: UIBarButtonItem!
    @IBOutlet weak var videoView: UIView!
    @IBOutlet weak var speedButton: UIButton!
    @IBOutlet weak var saveButton: UIButton!
    
    private var player: AVPlayer?
    private var playerLayer: AVPlayerLayer?
    private var isPlaying = false
    private var playPauseButton: UIButton!
    private var videoLooper: Any?
    private var currentTrimmedAsset: AVAsset?
    private var currentVideoURL: URL?
    private var originalVideoOrientation: CGAffineTransform?
    private var currentVideoRate: Float = 1.0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupPlayPauseButton()
        setupUI()
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(videoViewTapped))
        videoView.addGestureRecognizer(tapGesture)
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        playerLayer?.frame = videoView.bounds
    }
    
    deinit {
        if let videoLooper = videoLooper {
            NotificationCenter.default.removeObserver(videoLooper)
        }
    }
    
    func setupUI() {
        speedButton.layer.cornerRadius = 10
        saveButton.layer.cornerRadius = 10
        
        speedButton.isEnabled = false
        saveButton.isEnabled = false
        
        speedButton.alpha = 0.5
        saveButton.alpha = 0.5
    }
    
    private func setupPlayPauseButton() {
        playPauseButton = UIButton(type: .system)
        playPauseButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
        playPauseButton.tintColor = .white
        playPauseButton.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        playPauseButton.layer.cornerRadius = 30
        playPauseButton.translatesAutoresizingMaskIntoConstraints = false
        playPauseButton.addTarget(self, action: #selector(togglePlayPause), for: .touchUpInside)
        playPauseButton.isHidden = true
        
        videoView.addSubview(playPauseButton)
        NSLayoutConstraint.activate([
            playPauseButton.centerXAnchor.constraint(equalTo: videoView.centerXAnchor),
            playPauseButton.centerYAnchor.constraint(equalTo: videoView.centerYAnchor),
            playPauseButton.widthAnchor.constraint(equalToConstant: 60),
            playPauseButton.heightAnchor.constraint(equalToConstant: 60)
        ])
    }
    
    @IBAction func addVideoButtonTapped(_ sender: UIBarButtonItem) {
        showImageSourceOptions()
    }
    
    @objc func videoViewTapped() {
        togglePlayPause()
    }
    
    @objc func togglePlayPause() {
        guard let player = player else { return }
        
        if isPlaying {
            player.pause()
            playPauseButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
            playPauseButton.isHidden = false
            
        } else {
            player.play()
            player.rate = currentVideoRate
            playPauseButton.setImage(UIImage(systemName: "pause.fill"), for: .normal)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                guard let self = self else { return }
                if self.isPlaying {
                    self.playPauseButton.isHidden = true
                }
            }
        }
        
        isPlaying.toggle()
    }
    
    @objc private func replayVideo() {
        player?.seek(to: CMTime.zero)
        player?.play()
        player?.rate = currentVideoRate
        isPlaying = true
        playPauseButton.setImage(UIImage(systemName: "pause.fill"), for: .normal)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self = self else { return }
            if self.isPlaying {
                self.playPauseButton.isHidden = true
            }
        }
    }
    
    // MARK: - Video Player Methods
    private func setupVideoPlayer(with url: URL) {
        playerLayer?.removeFromSuperlayer()
        
        if let videoLooper = videoLooper {
            NotificationCenter.default.removeObserver(videoLooper)
        }
        
        currentVideoURL = url
        currentTrimmedAsset = AVAsset(url: url)
        
        player = AVPlayer(url: url)
        playerLayer = AVPlayerLayer(player: player)
        playerLayer?.videoGravity = .resizeAspectFill
        playerLayer?.frame = videoView.bounds
        
        if let playerLayer = playerLayer {
            videoView.layer.addSublayer(playerLayer)
        }
        videoLooper = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player?.currentItem,
            queue: .main) { [weak self] _ in
                self?.replayVideo()
            }
        
        videoView.bringSubviewToFront(playPauseButton)
        playPauseButton.isHidden = false
        player?.play()
        isPlaying = true
        playPauseButton.setImage(UIImage(systemName: "pause.fill"), for: .normal)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self = self else { return }
            if self.isPlaying {
                self.playPauseButton.isHidden = true
            }
        }
    }
    
    // MARK: - Image Picker Methods
    func showImageSourceOptions() {
        let alert = UIAlertController(title: "Select Video", message: "Choose an option", preferredStyle: .actionSheet)
        
        let cameraAction = UIAlertAction(title: "Camera", style: .default) { _ in
            self.requestCameraAccess()
        }
        
        let galleryAction = UIAlertAction(title: "Gallery", style: .default) { _ in
            self.requestGalleryAccess()
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        
        alert.addAction(cameraAction)
        alert.addAction(galleryAction)
        alert.addAction(cancelAction)
        
        present(alert, animated: true, completion: nil)
    }
    
    func requestCameraAccess() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            openImagePicker(sourceType: .camera)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    DispatchQueue.main.async {
                        self.openImagePicker(sourceType: .camera)
                    }
                }
            }
        case .denied, .restricted:
            showSettingsAlert(title: "Camera Access Denied", message: "Enable camera access in Settings.")
        @unknown default:
            break
        }
    }
    
    func requestGalleryAccess() {
        let status = PHPhotoLibrary.authorizationStatus()
        switch status {
        case .authorized, .limited:
            openImagePicker(sourceType: .photoLibrary)
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization { status in
                if status == .authorized || status == .limited {
                    DispatchQueue.main.async {
                        self.openImagePicker(sourceType: .photoLibrary)
                    }
                }
            }
        case .denied, .restricted:
            showSettingsAlert(title: "Gallery Access Denied", message: "Enable photo library access in Settings.")
        @unknown default:
            break
        }
    }
    
    func openImagePicker(sourceType: UIImagePickerController.SourceType) {
        guard UIImagePickerController.isSourceTypeAvailable(sourceType) else { return }
        
        let imagePicker = UIImagePickerController()
        imagePicker.delegate = self
        imagePicker.sourceType = sourceType
        imagePicker.allowsEditing = false
        imagePicker.mediaTypes = ["public.movie"]
        
        present(imagePicker, animated: true, completion: nil)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        if let videoURL = info[.mediaURL] as? URL {
            picker.dismiss(animated: true) { [weak self] in
                self?.setupVideoPlayer(with: videoURL)
                self?.speedButton.isEnabled = true
                self?.saveButton.isEnabled = true
                self?.speedButton.alpha = 1.0
                self?.saveButton.alpha = 1.0
            }
        } else {
            picker.dismiss(animated: true, completion: nil)
        }
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
    
    func showSettingsAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let settingsAction = UIAlertAction(title: "Settings", style: .default) { _ in
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsURL, options: [:], completionHandler: nil)
            }
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        alert.addAction(settingsAction)
        alert.addAction(cancelAction)
        present(alert, animated: true, completion: nil)
    }
    
    @IBAction func speedButtonTapped(_ sender: UIButton) {
        player?.pause()
        isPlaying = false
        playPauseButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
        playPauseButton.isHidden = false
        
        let alert = UIAlertController(title: "Video Speed Select", message: nil, preferredStyle: .actionSheet)
        
        let speeds: [Float] = [0.5, 1.0, 1.5, 2.0, 3.0, 4.0]
        
        for speed in speeds {
            let action = UIAlertAction(title: "\(speed)x", style: .default) { [weak self] _ in
                self?.changeVideoSpeed(to: speed)
            }
            alert.addAction(action)
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        alert.addAction(cancelAction)
        
        present(alert, animated: true, completion: nil)
    }
    
    private func changeVideoSpeed(to speed: Float) {
        guard let player = player else { return }
        
        currentVideoRate = speed
        player.seek(to: CMTime.zero)
        player.play()
        player.rate = speed
        isPlaying = true
        playPauseButton.setImage(UIImage(systemName: "pause.fill"), for: .normal)
        
        let feedbackMessage = " \(speed)x speed set. "
        
        let feedbackLabel = UILabel()
        feedbackLabel.text = feedbackMessage
        feedbackLabel.textAlignment = .center
        feedbackLabel.textColor = .white
        feedbackLabel.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        feedbackLabel.layer.cornerRadius = 8
        feedbackLabel.layer.masksToBounds = true
        feedbackLabel.translatesAutoresizingMaskIntoConstraints = false
        feedbackLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        
        videoView.addSubview(feedbackLabel)
        
        NSLayoutConstraint.activate([
            feedbackLabel.centerXAnchor.constraint(equalTo: videoView.centerXAnchor),
            feedbackLabel.bottomAnchor.constraint(equalTo: videoView.bottomAnchor, constant: -20),
            feedbackLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 80),
            feedbackLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 30)
        ])
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            UIView.animate(withDuration: 0.5, animations: {
                feedbackLabel.alpha = 0
            }, completion: { _ in
                feedbackLabel.removeFromSuperview()
            })
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self = self else { return }
            if self.isPlaying {
                self.playPauseButton.isHidden = true
            }
        }
    }
    
    @IBAction func saveButtonTapped(_ sender: UIButton) {
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
        
        print("Current Video Rate before export: \(currentVideoRate)")
        
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
            
            let speedFactor = 1.0 / Double(currentVideoRate)
            let newDuration = CMTimeMultiplyByFloat64(assetDuration, multiplier: speedFactor)
            
            print("Original Duration: \(CMTimeGetSeconds(assetDuration)) seconds")
            print("Speed Factor: \(speedFactor)")
            print("Speed: \(currentVideoRate)x")
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
        videoComposition.renderSize = videoTrack.naturalSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
        
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRangeMake(start: .zero, duration: composition.duration)
        
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compositionVideoTrack)
        
        if let originalTransform = originalVideoOrientation {
            layerInstruction.setTransform(originalTransform, at: .zero)
        } else {
            layerInstruction.setTransform(videoTrack.preferredTransform, at: .zero)
        }
        
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
                        self.saveVideoToLibrary(outputURL)
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
    
    private func saveVideoToLibrary(_ videoURL: URL) {
        PHPhotoLibrary.requestAuthorization { status in
            if status == .authorized {
                PHPhotoLibrary.shared().performChanges({
                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoURL)
                }) { success, error in
                    DispatchQueue.main.async {
                        if success {
                            self.showAlert(title: "Success", message: "Video saved to your photo library")
                        } else {
                            if let error = error {
                                self.showAlert(title: "Save Failed", message: error.localizedDescription)
                            } else {
                                self.showAlert(title: "Save Failed", message: "Unknown error occurred")
                            }
                        }
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.showSettingsAlert(title: "Permission Denied", message: "To save videos, allow photo library access in Settings.")
                }
            }
        }
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
        alert.addAction(okAction)
        present(alert, animated: true, completion: nil)
    }
}
