//
//  VideoEditingVC.swift
//  VideoEditing
//
//  Created by Arpit iOS Dev. on 26/02/25.
//

import UIKit
import AVFoundation
import Photos
import AVKit

@available(iOS 16.0, *)
class VideoEditingVC: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    @IBOutlet weak var videoView: UIView!
    @IBOutlet weak var addVideoButton: UIBarButtonItem!
    @IBOutlet weak var cropButton: UIButton!
    @IBOutlet weak var textButton: UIButton!
    @IBOutlet weak var saveButton: UIButton!
    @IBOutlet weak var buttonStackView: UIStackView!
    @IBOutlet weak var stickerButton: UIButton!
    @IBOutlet weak var timerButton: UIButton!
    @IBOutlet weak var musicButton: UIButton!
    @IBOutlet weak var muteButton: UIBarButtonItem!
    @IBOutlet weak var filterButton: UIButton!
    
    private var player: AVPlayer?
    private var playerLayer: AVPlayerLayer?
    private var isPlaying = false
    private var playPauseButton: UIButton!
    private var videoLooper: Any?
    private var currentVideoURL: URL?
    private var isMuted = false
    private var currentTrimmedAsset: AVAsset?
    private var textViews: [DraggableTextView] = []
    private var musicBottomSheet: UIView?
    private var musicPlayer: AVAudioPlayer?
    private var selectedMusicURL: URL?
    private var currentPlayingButton: UIButton?
    private var musicTableView: UITableView?
    private var musicFiles: [URL] = []
    private var originalAudioEnabled = true
    
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
    private var currentVideoRate: Float = 1.0
    private var originalVideoOrientation: CGAffineTransform?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupPlayPauseButton()
        setupUI()
        
        muteButton.image = UIImage(systemName: "speaker.wave.2.fill")
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(videoViewTapped))
        videoView.addGestureRecognizer(tapGesture)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        musicPlayer?.stop()
        musicPlayer = nil
    }
    
    private func loadMusicFiles() {
        guard let resourcePath = Bundle.main.resourcePath else { return }
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: URL(fileURLWithPath: resourcePath), includingPropertiesForKeys: nil)
            musicFiles = fileURLs.filter { $0.pathExtension == "mp3" }
        } catch {
            print("Error loading music files: \(error)")
        }
    }
    
    func setupUI() {
        cropButton.layer.cornerRadius = 10
        filterButton.layer.cornerRadius = 10
        textButton.layer.cornerRadius = 10
        stickerButton.layer.cornerRadius = 10
        saveButton.layer.cornerRadius = 10
        timerButton.layer.cornerRadius = 10
        musicButton.layer.cornerRadius = 10
        
        cropButton.isEnabled = false
        filterButton.isEnabled = false
        textButton.isEnabled = false
        stickerButton.isEnabled = false
        saveButton.isEnabled = false
        timerButton.isEnabled = false
        musicButton.isEnabled = false
        
        muteButton.isHidden = true
        
        cropButton.alpha = 0.5
        filterButton.alpha = 0.5
        stickerButton.alpha = 0.5
        textButton.alpha = 0.5
        saveButton.alpha = 0.5
        timerButton.alpha = 0.5
        musicButton.alpha = 0.5
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        playerLayer?.frame = videoView.bounds
    }
    
    deinit {
        if let videoLooper = videoLooper {
            NotificationCenter.default.removeObserver(videoLooper)
        }
        
        if let playerTimeObserver = playerTimeObserver, let player = player {
            player.removeTimeObserver(playerTimeObserver)
        }
    }
    
    @IBAction func muteButtonTapped(_ sender: UIBarButtonItem) {
        guard let player = player else { return }
        isMuted = !isMuted
        player.volume = isMuted ? 0.0 : 1.0
        if isMuted {
            muteButton.image = UIImage(systemName: "speaker.slash.fill")
            showMuteStatusFeedback(isMuted: true)
        } else {
            muteButton.image = UIImage(systemName: "speaker.wave.2.fill")
            showMuteStatusFeedback(isMuted: false)
        }
    }
    
    private func showMuteStatusFeedback(isMuted: Bool) {
        let feedbackLabel = UILabel()
        feedbackLabel.text = isMuted ? "Video Mute" : "Video Unmute"
        feedbackLabel.textAlignment = .center
        feedbackLabel.textColor = .white
        feedbackLabel.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        feedbackLabel.layer.cornerRadius = 8
        feedbackLabel.layer.masksToBounds = true
        feedbackLabel.translatesAutoresizingMaskIntoConstraints = false
        feedbackLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        feedbackLabel.alpha = 1.0
        
        videoView.addSubview(feedbackLabel)
        
        NSLayoutConstraint.activate([
            feedbackLabel.centerXAnchor.constraint(equalTo: videoView.centerXAnchor),
            feedbackLabel.topAnchor.constraint(equalTo: videoView.topAnchor, constant: 50),
            feedbackLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 180),
            feedbackLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 30)
        ])
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            UIView.animate(withDuration: 0.5, animations: {
                feedbackLabel.alpha = 0
            }, completion: { _ in
                feedbackLabel.removeFromSuperview()
            })
        }
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
            
            if !originalAudioEnabled && selectedMusicURL != nil {
                musicPlayer?.pause()
            }
        } else {
            player.play()
            player.rate = currentVideoRate
            playPauseButton.setImage(UIImage(systemName: "pause.fill"), for: .normal)
            
            if !originalAudioEnabled && selectedMusicURL != nil {
                musicPlayer?.play()
            }
            
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
        
        if !originalAudioEnabled && selectedMusicURL != nil {
            musicPlayer?.currentTime = 0
            musicPlayer?.play()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self = self else { return }
            if self.isPlaying {
                self.playPauseButton.isHidden = true
            }
        }
    }
    
    // MARK: - Video Player Methods
    private func setupVideoPlayer(with url: URL) {
        currentVideoURL = url
        playerLayer?.removeFromSuperlayer()
        
        if let videoLooper = videoLooper {
            NotificationCenter.default.removeObserver(videoLooper)
        }
        
        let asset = AVURLAsset(url: url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
        currentTrimmedAsset = asset
        
        if let videoTrack = asset.tracks(withMediaType: .video).first {
            originalVideoOrientation = videoTrack.preferredTransform
        }
        
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
        player?.volume = isMuted ? 0.0 : 1.0
        if isMuted {
            muteButton.image = UIImage(systemName: "speaker.slash.fill")
        } else {
            muteButton.image = UIImage(systemName: "speaker.wave.2.fill")
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
                self?.filterButton.isEnabled = true
                self?.textButton.isEnabled = true
                self?.stickerButton.isEnabled = true
                self?.saveButton.isEnabled = true
                self?.timerButton.isEnabled = true
                self?.musicButton.isEnabled = true
                self?.muteButton.isHidden = false
                self?.cropButton.alpha = 1.0
                self?.filterButton.alpha = 1.0
                self?.stickerButton.alpha = 1.0
                self?.textButton.alpha = 1.0
                self?.saveButton.alpha = 1.0
                self?.timerButton.alpha = 1.0
                self?.musicButton.alpha = 1.0
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
            player?.rate = currentVideoRate
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
            player?.rate = currentVideoRate
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
        
        let composition = AVMutableComposition()
        
        guard let videoTrack = asset.tracks(withMediaType: .video).first,
              let compositionVideoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            showAlert(title: "Error", message: "Could not create composition tracks")
            return
        }
        
        let assetDuration = asset.duration
        
        let speedAdjustedDuration = CMTimeMultiplyByRatio(assetDuration, multiplier: 1, divisor: Int32(currentVideoRate))
        
        let timeRange = CMTimeRangeMake(start: .zero, duration: assetDuration)
        
        do {
            try compositionVideoTrack.insertTimeRange(timeRange, of: videoTrack, at: .zero)
            
            if let originalTransform = originalVideoOrientation {
                compositionVideoTrack.preferredTransform = originalTransform
            } else {
                compositionVideoTrack.preferredTransform = videoTrack.preferredTransform
            }
            
            compositionVideoTrack.scaleTimeRange(
                CMTimeRangeMake(start: .zero, duration: assetDuration),
                toDuration: speedAdjustedDuration
            )
            
            if originalAudioEnabled && !isMuted, let audioTrack = asset.tracks(withMediaType: .audio).first {
                let compositionAudioTrack = composition.addMutableTrack(
                    withMediaType: .audio,
                    preferredTrackID: kCMPersistentTrackID_Invalid
                )
                
                try compositionAudioTrack?.insertTimeRange(timeRange, of: audioTrack, at: .zero)
                
                compositionAudioTrack?.scaleTimeRange(
                    CMTimeRangeMake(start: .zero, duration: assetDuration),
                    toDuration: speedAdjustedDuration
                )
            }
            
            if let musicURL = selectedMusicURL {
                let musicAsset = AVURLAsset(url: musicURL)
                if let audioTrack = musicAsset.tracks(withMediaType: .audio).first {
                    let compositionAudioTrack = composition.addMutableTrack(
                        withMediaType: .audio,
                        preferredTrackID: kCMPersistentTrackID_Invalid
                    )
                    
                    let audioTimeRange = CMTimeRangeMake(start: .zero, duration: musicAsset.duration)
                    var currentTime = CMTime.zero
                    
                    while currentTime < speedAdjustedDuration {
                        let remainingTime = CMTimeSubtract(speedAdjustedDuration, currentTime)
                        let insertDuration = CMTimeCompare(remainingTime, audioTimeRange.duration) < 0 ? remainingTime : audioTimeRange.duration
                        
                        if CMTimeCompare(insertDuration, CMTime.zero) <= 0 {
                            break
                        }
                        
                        let insertRange = CMTimeRangeMake(start: .zero, duration: insertDuration)
                        try compositionAudioTrack?.insertTimeRange(insertRange, of: audioTrack, at: currentTime)
                        
                        currentTime = CMTimeAdd(currentTime, insertDuration)
                    }
                }
            }
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
        
        let alert = UIAlertController(title: "Saving Video", message: "Please wait...", preferredStyle: .alert)
        present(alert, animated: true)
        
        exportSession.exportAsynchronously {
            DispatchQueue.main.async {
                alert.dismiss(animated: true) {
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
    
    @IBAction func timerButtonTapped(_ sender: UIButton) {
        player?.pause()
        isPlaying = false
        playPauseButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
        playPauseButton.isHidden = false
        
        let alert = UIAlertController(title: "Video Speed Select", message: nil, preferredStyle: .actionSheet)
        
        let speeds: [Float] = [0.5, 1.0, 1.5, 2.0]
        
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
    
    @IBAction func musicButtonTapped(_ sender: UIButton) {
        if musicBottomSheet != nil {
            closeBottomSheet()
            return
        }
        
        if musicFiles.isEmpty {
            loadMusicFiles()
        }
        setupMusicBottomSheet()
    }
    
    private func setupMusicBottomSheet() {
        let bottomSheet = UIView()
        bottomSheet.backgroundColor = .systemBackground
        bottomSheet.layer.cornerRadius = 12
        bottomSheet.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        bottomSheet.clipsToBounds = true
        bottomSheet.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bottomSheet)
        
        let sheetHeight = view.bounds.height * 0.4
        
        NSLayoutConstraint.activate([
            bottomSheet.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomSheet.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomSheet.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            bottomSheet.heightAnchor.constraint(equalToConstant: sheetHeight)
        ])
        
        let handleView = UIView()
        handleView.backgroundColor = .systemGray3
        handleView.layer.cornerRadius = 2.5
        handleView.translatesAutoresizingMaskIntoConstraints = false
        bottomSheet.addSubview(handleView)
        
        NSLayoutConstraint.activate([
            handleView.widthAnchor.constraint(equalToConstant: 40),
            handleView.heightAnchor.constraint(equalToConstant: 5),
            handleView.centerXAnchor.constraint(equalTo: bottomSheet.centerXAnchor),
            handleView.topAnchor.constraint(equalTo: bottomSheet.topAnchor, constant: 8)
        ])
        
        let titleLabel = UILabel()
        titleLabel.text = "Music Add"
        titleLabel.font = UIFont.boldSystemFont(ofSize: 18)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        bottomSheet.addSubview(titleLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: bottomSheet.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: bottomSheet.trailingAnchor, constant: -16),
            titleLabel.topAnchor.constraint(equalTo: handleView.bottomAnchor, constant: 16)
        ])
        
        let closeButton = UIButton(type: .system)
        closeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        closeButton.tintColor = .systemGray
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addTarget(self, action: #selector(closeBottomSheet), for: .touchUpInside)
        bottomSheet.addSubview(closeButton)
        
        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: bottomSheet.topAnchor, constant: 16),
            closeButton.trailingAnchor.constraint(equalTo: bottomSheet.trailingAnchor, constant: -16),
            closeButton.heightAnchor.constraint(equalToConstant: 30),
            closeButton.widthAnchor.constraint(equalToConstant: 30)
        ])
        
        let noMusicButton = UIButton(type: .system)
        noMusicButton.setTitle("Original Music", for: .normal)
        noMusicButton.contentHorizontalAlignment = .left
        noMusicButton.translatesAutoresizingMaskIntoConstraints = false
        noMusicButton.addTarget(self, action: #selector(noMusicSelected), for: .touchUpInside)
        bottomSheet.addSubview(noMusicButton)
        
        NSLayoutConstraint.activate([
            noMusicButton.leadingAnchor.constraint(equalTo: bottomSheet.leadingAnchor, constant: 16),
            noMusicButton.trailingAnchor.constraint(equalTo: bottomSheet.trailingAnchor, constant: -16),
            noMusicButton.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            noMusicButton.heightAnchor.constraint(equalToConstant: 44)
        ])
        
        if originalAudioEnabled {
            noMusicButton.setImage(UIImage(systemName: "checkmark"), for: .normal)
            noMusicButton.tintColor = .systemBlue
        }
        
        let tableView = UITableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(MusicCell.self, forCellReuseIdentifier: "MusicCell")
        tableView.separatorStyle = .singleLine
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        tableView.rowHeight = 60
        bottomSheet.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            tableView.leadingAnchor.constraint(equalTo: bottomSheet.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: bottomSheet.trailingAnchor),
            tableView.topAnchor.constraint(equalTo: noMusicButton.bottomAnchor, constant: 8),
            tableView.bottomAnchor.constraint(equalTo: bottomSheet.bottomAnchor)
        ])
        
        musicTableView = tableView
        musicBottomSheet = bottomSheet
        
        bottomSheet.transform = CGAffineTransform(translationX: 0, y: sheetHeight)
        
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut, animations: {
            bottomSheet.transform = .identity
        }, completion: nil)
    }
    
    @objc private func closeBottomSheet() {
        guard let bottomSheet = musicBottomSheet else { return }
        
        musicPlayer?.stop()
        musicPlayer = nil
        currentPlayingButton?.setImage(UIImage(systemName: "play.circle"), for: .normal)
        currentPlayingButton = nil
        
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseIn, animations: {
            bottomSheet.transform = CGAffineTransform(translationX: 0, y: bottomSheet.frame.height)
        }, completion: { _ in
            bottomSheet.removeFromSuperview()
            self.musicBottomSheet = nil
        })
    }
    
    @objc private func noMusicSelected() {
        originalAudioEnabled = true
        player?.volume = isMuted ? 0 : 1.0
        
        showMusicSelectionFeedback(message: "Original Music Add")
        
        selectedMusicURL = nil
        
        closeBottomSheet()
        
        if let tableView = musicTableView {
            tableView.reloadData()
        }
    }
    
    @objc private func toggleMusicPreview(_ sender: UIButton) {
        guard let musicCell = sender.superview?.superview as? MusicCell else { return }
        let indexPath = musicCell.indexPath
        
        if currentPlayingButton != sender {
            musicPlayer?.stop()
            currentPlayingButton?.setImage(UIImage(systemName: "play.circle"), for: .normal)
            
            let musicURL = musicFiles[indexPath!.row]
            do {
                musicPlayer = try AVAudioPlayer(contentsOf: musicURL)
                musicPlayer?.prepareToPlay()
                musicPlayer?.play()
                sender.setImage(UIImage(systemName: "pause.circle"), for: .normal)
                currentPlayingButton = sender
            } catch {
                print("Failed to play music: \(error)")
            }
        } else {
            if let player = musicPlayer, player.isPlaying {
                player.pause()
                sender.setImage(UIImage(systemName: "play.circle"), for: .normal)
            } else {
                musicPlayer?.play()
                sender.setImage(UIImage(systemName: "pause.circle"), for: .normal)
            }
        }
    }
    
    @objc private func selectMusic(_ sender: UIButton) {
        guard let musicCell = sender.superview?.superview as? MusicCell else { return }
        let indexPath = musicCell.indexPath
        
        musicPlayer?.stop()
        currentPlayingButton?.setImage(UIImage(systemName: "play.circle"), for: .normal)
        currentPlayingButton = nil
        selectedMusicURL = musicFiles[indexPath!.row]
        originalAudioEnabled = false
        player?.volume = 0
        let musicName = musicFiles[indexPath!.row].lastPathComponent.replacingOccurrences(of: ".mp3", with: "")
        showMusicSelectionFeedback(message: "\"\(musicName)\" Music Add")
        closeBottomSheet()
        startBackgroundMusic()
    }
    
    private func startBackgroundMusic() {
        guard let musicURL = selectedMusicURL else { return }
        
        do {
            musicPlayer = try AVAudioPlayer(contentsOf: musicURL)
            musicPlayer?.numberOfLoops = -1
            musicPlayer?.prepareToPlay()
            musicPlayer?.play()
        } catch {
            print("Failed to play background music: \(error)")
        }
    }
    
    private func showMusicSelectionFeedback(message: String) {
        let feedbackLabel = UILabel()
        feedbackLabel.text = message
        feedbackLabel.textAlignment = .center
        feedbackLabel.textColor = .white
        feedbackLabel.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        feedbackLabel.layer.cornerRadius = 8
        feedbackLabel.layer.masksToBounds = true
        feedbackLabel.translatesAutoresizingMaskIntoConstraints = false
        feedbackLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        feedbackLabel.alpha = 1.0
        
        videoView.addSubview(feedbackLabel)
        
        NSLayoutConstraint.activate([
            feedbackLabel.centerXAnchor.constraint(equalTo: videoView.centerXAnchor),
            feedbackLabel.centerYAnchor.constraint(equalTo: videoView.centerYAnchor),
            feedbackLabel.widthAnchor.constraint(lessThanOrEqualTo: videoView.widthAnchor, constant: -40),
            feedbackLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 40)
        ])
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            UIView.animate(withDuration: 0.5, animations: {
                feedbackLabel.alpha = 0
            }, completion: { _ in
                feedbackLabel.removeFromSuperview()
            })
        }
    }
    
    @IBAction func filterButtonTapped(_ sender: UIButton) {
        
    }
    
    @IBAction func textButtonTapped(_ sender: UIButton) {

    }
}

@available(iOS 16.0, *)
extension VideoEditingVC: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return musicFiles.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "MusicCell", for: indexPath) as! MusicCell
        
        let musicURL = musicFiles[indexPath.row]
        let musicName = musicURL.lastPathComponent.replacingOccurrences(of: ".mp3", with: "")
        
        cell.configure(with: musicName, indexPath: indexPath)
        cell.playButton.addTarget(self, action: #selector(toggleMusicPreview(_:)), for: .touchUpInside)
        cell.selectButton.addTarget(self, action: #selector(selectMusic(_:)), for: .touchUpInside)
        
        if let selectedURL = selectedMusicURL, selectedURL == musicURL {
            cell.selectButton.setImage(UIImage(systemName: "checkmark.circle.fill"), for: .normal)
            cell.selectButton.tintColor = .systemBlue
        } else {
            cell.selectButton.setImage(UIImage(systemName: "plus.circle"), for: .normal)
            cell.selectButton.tintColor = .systemGray
        }
        
        return cell
    }
}

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
