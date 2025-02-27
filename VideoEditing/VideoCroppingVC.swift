//
//  VideoCroppingVC.swift
//  VideoEditing
//
//  Created by Plexus Technology on 27/02/25.
//

import UIKit
import AVFoundation
import Photos
import AVKit

class VideoCroppingVC: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    @IBOutlet weak var videoView: UIView!
    @IBOutlet weak var addVideoButton: UIBarButtonItem!
    @IBOutlet weak var cropButton: UIButton!
    @IBOutlet weak var buttonStackView: UIStackView!
    @IBOutlet weak var saveButton: UIButton!
    
    private var player: AVPlayer?
    private var playerLayer: AVPlayerLayer?
    private var isPlaying = false
    private var playPauseButton: UIButton!
    private var videoLooper: Any?
    private var currentTrimmedAsset: AVAsset?
    private var currentVideoURL: URL?
    private var trimmerView: VideoTrimmer?
    private var trimmerContainer: UIView?
    private var timingStackView: UIStackView?
    private var leadingTrimLabel: UILabel?
    private var currentTimeLabel: UILabel?
    private var trailingTrimLabel: UILabel?
    private var doneButton: UIButton?
    private var cancelButton: UIButton?
    private var wasPlaying = false
    private var playerTimeObserver: Any?
    
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
        cropButton.layer.cornerRadius = 10
        saveButton.layer.cornerRadius = 10
        
        cropButton.isEnabled = false
        saveButton.isEnabled = false
        
        cropButton.alpha = 0.5
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
                self?.cropButton.isEnabled = true
                self?.saveButton.isEnabled = true
                self?.cropButton.alpha = 1.0
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
    
    // MARK: - Trimming Related Methods
    @IBAction func cropButtonTapped(_ sender: UIButton) {
        guard let asset = currentTrimmedAsset else { return }
        
        wasPlaying = isPlaying
        player?.pause()
        isPlaying = false
        
        buttonStackView.isHidden = true
        playPauseButton.isHidden = true
        
        trimmerContainer = UIView()
        guard let trimmerContainer = trimmerContainer else { return }
        trimmerContainer.backgroundColor = UIColor.systemBackground
        trimmerContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(trimmerContainer)
        
        NSLayoutConstraint.activate([
            trimmerContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            trimmerContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            trimmerContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            trimmerContainer.topAnchor.constraint(equalTo: videoView.bottomAnchor, constant: -50)
        ])
        
        doneButton = UIButton(type: .system)
        cancelButton = UIButton(type: .system)
        
        guard let doneButton = doneButton, let cancelButton = cancelButton else { return }
        
        doneButton.setTitle("Done", for: .normal)
        doneButton.setTitleColor(.systemBlue, for: .normal)
        doneButton.addTarget(self, action: #selector(doneTrimmingTapped), for: .touchUpInside)
        
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.setTitleColor(.systemRed, for: .normal)
        cancelButton.addTarget(self, action: #selector(cancelTrimmingTapped), for: .touchUpInside)
        
        let buttonStackView = UIStackView(arrangedSubviews: [cancelButton, doneButton])
        buttonStackView.axis = .horizontal
        buttonStackView.distribution = .equalSpacing
        buttonStackView.alignment = .center
        buttonStackView.translatesAutoresizingMaskIntoConstraints = false
        
        trimmerContainer.addSubview(buttonStackView)
        
        NSLayoutConstraint.activate([
            buttonStackView.leadingAnchor.constraint(equalTo: trimmerContainer.leadingAnchor, constant: 20),
            buttonStackView.trailingAnchor.constraint(equalTo: trimmerContainer.trailingAnchor, constant: -20),
            buttonStackView.topAnchor.constraint(equalTo: trimmerContainer.topAnchor, constant: 10),
            buttonStackView.heightAnchor.constraint(equalToConstant: 44)
        ])
        
        trimmerView = VideoTrimmer()
        guard let trimmer = trimmerView else { return }
        
        trimmer.minimumDuration = CMTime(seconds: 1, preferredTimescale: 600)
        trimmer.addTarget(self, action: #selector(didBeginTrimming(_:)), for: VideoTrimmer.didBeginTrimming)
        trimmer.addTarget(self, action: #selector(didEndTrimming(_:)), for: VideoTrimmer.didEndTrimming)
        trimmer.addTarget(self, action: #selector(selectedRangeDidChanged(_:)), for: VideoTrimmer.selectedRangeChanged)
        trimmer.addTarget(self, action: #selector(didBeginScrubbing(_:)), for: VideoTrimmer.didBeginScrubbing)
        trimmer.addTarget(self, action: #selector(didEndScrubbing(_:)), for: VideoTrimmer.didEndScrubbing)
        trimmer.addTarget(self, action: #selector(progressDidChanged(_:)), for: VideoTrimmer.progressChanged)
        
        trimmerContainer.addSubview(trimmer)
        trimmer.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            trimmer.leadingAnchor.constraint(equalTo: trimmerContainer.leadingAnchor, constant: 16),
            trimmer.trailingAnchor.constraint(equalTo: trimmerContainer.trailingAnchor, constant: -16),
            trimmer.topAnchor.constraint(equalTo: buttonStackView.bottomAnchor, constant: 0),
            trimmer.heightAnchor.constraint(equalToConstant: 50)
        ])
        
        leadingTrimLabel = UILabel()
        currentTimeLabel = UILabel()
        trailingTrimLabel = UILabel()
        
        guard let leadingTrimLabel = leadingTrimLabel,
              let currentTimeLabel = currentTimeLabel,
              let trailingTrimLabel = trailingTrimLabel else { return }
        
        leadingTrimLabel.font = UIFont.preferredFont(forTextStyle: .caption1)
        leadingTrimLabel.textAlignment = .left
        
        currentTimeLabel.font = UIFont.preferredFont(forTextStyle: .caption1)
        currentTimeLabel.textAlignment = .center
        
        trailingTrimLabel.font = UIFont.preferredFont(forTextStyle: .caption1)
        trailingTrimLabel.textAlignment = .right
        
        timingStackView = UIStackView(arrangedSubviews: [leadingTrimLabel, currentTimeLabel, trailingTrimLabel])
        guard let timingStackView = timingStackView else { return }
        
        timingStackView.axis = .horizontal
        timingStackView.alignment = .fill
        timingStackView.distribution = .fillEqually
        timingStackView.spacing = UIStackView.spacingUseSystem
        
        trimmerContainer.addSubview(timingStackView)
        timingStackView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            timingStackView.leadingAnchor.constraint(equalTo: trimmerContainer.leadingAnchor, constant: 16),
            timingStackView.trailingAnchor.constraint(equalTo: trimmerContainer.trailingAnchor, constant: -16),
            timingStackView.topAnchor.constraint(equalTo: trimmer.bottomAnchor, constant: 8)
        ])
        
        trimmer.asset = asset
        setupTimeObserver()
        updateLabels()
    }
    
    private func setupTimeObserver() {
        if let timeObserver = playerTimeObserver, let player = player {
            player.removeTimeObserver(timeObserver)
            playerTimeObserver = nil
        }
        
        playerTimeObserver = player?.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 30), queue: .main) { [weak self] time in
            guard let self = self, let trimmer = self.trimmerView else { return }
            
            let finalTime = trimmer.trimmingState == .none ? CMTimeAdd(time, trimmer.selectedRange.start) : time
            trimmer.progress = finalTime
            
            self.updateLabels()
        }
    }
    
    @objc private func didBeginTrimming(_ sender: VideoTrimmer) {
        updateLabels()
        player?.pause()
        updatePlayerAsset()
    }
    
    @objc private func didEndTrimming(_ sender: VideoTrimmer) {
        updateLabels()
        updatePlayerAsset()
    }
    
    @objc private func selectedRangeDidChanged(_ sender: VideoTrimmer) {
        updateLabels()
    }
    
    @objc private func didBeginScrubbing(_ sender: VideoTrimmer) {
        updateLabels()
        player?.pause()
    }
    
    @objc private func didEndScrubbing(_ sender: VideoTrimmer) {
        updateLabels()
    }
    
    @objc private func progressDidChanged(_ sender: VideoTrimmer) {
        updateLabels()
        
        guard let trimmer = trimmerView else { return }
        let time = CMTimeSubtract(trimmer.progress, trimmer.selectedRange.start)
        player?.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
    }
    
    private func updateLabels() {
        guard let trimmer = trimmerView,
              let leadingLabel = leadingTrimLabel,
              let currentLabel = currentTimeLabel,
              let trailingLabel = trailingTrimLabel else { return }
        
        leadingLabel.text = trimmer.selectedRange.start.displayString
        currentLabel.text = trimmer.progress.displayString
        trailingLabel.text = trimmer.selectedRange.end.displayString
    }
    
    private func updatePlayerAsset() {
        guard let trimmer = trimmerView, let asset = trimmer.asset else { return }
        
        let outputRange = trimmer.trimmingState == .none ? trimmer.selectedRange : asset.fullRange
        let trimmedAsset = asset.trimmedComposition(outputRange)
        
        if let player = player, trimmedAsset != player.currentItem?.asset {
            player.replaceCurrentItem(with: AVPlayerItem(asset: trimmedAsset))
        }
    }
    
    @objc private func doneTrimmingTapped() {
        guard let trimmer = trimmerView, let asset = trimmer.asset else { return }
        
        let outputRange = trimmer.selectedRange
        let trimmedAsset = asset.trimmedComposition(outputRange)
        
        currentTrimmedAsset = trimmedAsset
        
        if let videoLooper = videoLooper {
            NotificationCenter.default.removeObserver(videoLooper)
        }
        
        let playerItem = AVPlayerItem(asset: trimmedAsset)
        player?.replaceCurrentItem(with: playerItem)
        
        videoLooper = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player?.currentItem,
            queue: .main) { [weak self] _ in
                self?.replayVideo()
            }
        
        cleanupTrimmerInterface()
        
        if wasPlaying {
            player?.play()
            isPlaying = true
            playPauseButton.setImage(UIImage(systemName: "pause.fill"), for: .normal)
            playPauseButton.isHidden = true
        } else {
            playPauseButton.isHidden = false
            playPauseButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
        }
    }
    
    @objc private func cancelTrimmingTapped() {
        cleanupTrimmerInterface()
        
        if wasPlaying {
            player?.play()
            isPlaying = true
            playPauseButton.setImage(UIImage(systemName: "pause.fill"), for: .normal)
            playPauseButton.isHidden = true
        } else {
            playPauseButton.isHidden = false
            playPauseButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
        }
    }
    
    private func cleanupTrimmerInterface() {
        if let timeObserver = playerTimeObserver, let player = player {
            player.removeTimeObserver(timeObserver)
            playerTimeObserver = nil
        }
        
        trimmerView?.removeFromSuperview()
        trimmerView = nil
        
        timingStackView?.removeFromSuperview()
        timingStackView = nil
        
        trimmerContainer?.removeFromSuperview()
        trimmerContainer = nil
        
        buttonStackView.isHidden = false
    }
    
    @IBAction func saveButtonTapped(_ sender: UIButton) {
        guard let asset = currentTrimmedAsset else { return }
        
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
        
        // કંપોઝિશન બનાવવું
        let composition = AVMutableComposition()
        
        // વિડિયો ટ્રેક માટે
        guard let videoTrack = asset.tracks(withMediaType: .video).first,
              let compositionVideoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            showAlert(title: "Error", message: "Could not create video tracks")
            loadingAlert.dismiss(animated: true, completion: nil)
            return
        }
        
        let assetDuration = asset.duration
        let timeRange = CMTimeRangeMake(start: .zero, duration: assetDuration)
        
        do {
            // વિડિયો ટ્રેક ઇન્સર્ટ કરવું
            try compositionVideoTrack.insertTimeRange(timeRange, of: videoTrack, at: .zero)
            
            // ઓડિયો ટ્રેક માટે - આ ભાગ ઉમેરવાથી ઓડિયો જળવાઈ રહેશે
            let audioTracks = asset.tracks(withMediaType: .audio)
            for audioTrack in audioTracks {
                let compositionAudioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
                try compositionAudioTrack?.insertTimeRange(timeRange, of: audioTrack, at: .zero)
            }
            
        } catch {
            showAlert(title: "Error", message: "Could not create composition: \(error.localizedDescription)")
            loadingAlert.dismiss(animated: true, completion: nil)
            return
        }
        
        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = videoTrack.naturalSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
        
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRangeMake(start: .zero, duration: composition.duration)
        
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compositionVideoTrack)
        
        instruction.layerInstructions = [layerInstruction]
        videoComposition.instructions = [instruction]
        
        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            showAlert(title: "Error", message: "Could not create export session")
            loadingAlert.dismiss(animated: true, completion: nil)
            return
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.videoComposition = videoComposition
        
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
