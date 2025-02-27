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
import MobileCoreServices

@available(iOS 16.0, *)
class VideoEditingVC: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    @IBOutlet weak var videoView: UIView!
    @IBOutlet weak var addVideoButton: UIBarButtonItem!
    @IBOutlet weak var saveButton: UIButton!
    @IBOutlet weak var buttonStackView: UIStackView!
    @IBOutlet weak var musicButton: UIButton!
    @IBOutlet weak var muteButton: UIBarButtonItem!
    
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
    private var playerTimeObserver: Any?
    private var currentVideoRate: Float = 1.0
    private var originalVideoOrientation: CGAffineTransform?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupPlayPauseButton()
        setupUI()
        setupSwipeGesture()
        
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
    
    private func setupSwipeGesture() {
        let swipeGesture = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
        swipeGesture.edges = .left
        self.view.addGestureRecognizer(swipeGesture)
    }
    
    @objc private func handleSwipe(_ gesture: UIScreenEdgePanGestureRecognizer) {
        if gesture.state == .recognized {
            self.navigationController?.popViewController(animated: true)
        }
    }
    
    func setupUI() {
        saveButton.layer.cornerRadius = 10
        musicButton.layer.cornerRadius = 10
        
        saveButton.isEnabled = false
        musicButton.isEnabled = false
        
        muteButton.isHidden = true
        
        saveButton.alpha = 0.5
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
    
    private func requestCameraAccess() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.showVideoPicker(for: .camera)
                    } else {
                        self?.showSettingsAlert(title: "Camera Access Denied", message: "Enable camera access in Settings.")
                    }
                }
            }
        case .authorized:
            showVideoPicker(for: .camera)
        case .denied, .restricted:
            showSettingsAlert(title: "Camera Access Denied", message: "Enable camera access in Settings.")
        @unknown default:
            break
        }
    }
    
    private func requestGalleryAccess() {
        let status = PHPhotoLibrary.authorizationStatus()
        switch status {
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization { [weak self] status in
                DispatchQueue.main.async {
                    if status == .authorized {
                        self?.showVideoPicker(for: .photoLibrary)
                    } else {
                        self?.showSettingsAlert(title: "Gallery Access Denied", message: "Enable photo library access in Settings.")
                    }
                }
            }
        case .authorized, .limited:
            showVideoPicker(for: .photoLibrary)
        case .denied, .restricted:
            showSettingsAlert(title: "Gallery Access Denied", message: "Enable photo library access in Settings.")
        @unknown default:
            break
        }
    }
    
    private func showVideoPicker(for sourceType: UIImagePickerController.SourceType) {
        guard UIImagePickerController.isSourceTypeAvailable(sourceType) else {
            print("Source type \(sourceType) is not available")
            return
        }
        
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = sourceType
        picker.mediaTypes = [kUTTypeMovie as String]
        
        picker.videoQuality = .typeHigh
        
        if sourceType == .camera {
            if let cameraDevice = AVCaptureDevice.default(for: .video) {
                do {
                    try cameraDevice.lockForConfiguration()
                    if cameraDevice.isExposureModeSupported(.continuousAutoExposure) {
                        cameraDevice.exposureMode = .continuousAutoExposure
                    }
                    if cameraDevice.isFocusModeSupported(.continuousAutoFocus) {
                        cameraDevice.focusMode = .continuousAutoFocus
                    }
                    if cameraDevice.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                        cameraDevice.whiteBalanceMode = .continuousAutoWhiteBalance
                    }
                    cameraDevice.unlockForConfiguration()
                } catch {
                    print("Camera configuration error: \(error)")
                }
            }
        }
        
        picker.allowsEditing = true
        picker.videoMaximumDuration = 15.0
        
        if #available(iOS 14.0, *) {
            picker.videoExportPreset = AVAssetExportPresetPassthrough
        }
        
        present(picker, animated: true)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        if let videoURL = info[.mediaURL] as? URL {
            picker.dismiss(animated: true) { [weak self] in
                self?.setupVideoPlayer(with: videoURL)
                self?.saveButton.isEnabled = true
                self?.musicButton.isEnabled = true
                
                self?.muteButton.isHidden = false
                
                self?.saveButton.alpha = 1.0
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
