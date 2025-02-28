////
////  File.swift
////  VideoEditing
////
////  Created by Plexus Technology on 28/02/25.
////
//
//import UIKit
//import AVFoundation
//
//// MARK: - VideoCaptureVC
//@available(iOS 15.0, *)
//class VideoCaptureVCc: UIViewController {
//    
//    private var captureSession: AVCaptureSession?
//    private var videoDeviceInput: AVCaptureDeviceInput?
//    private var audioDeviceInput: AVCaptureDeviceInput?
//    private var videoOutput: AVCaptureMovieFileOutput?
//    private var previewLayer: AVCaptureVideoPreviewLayer?
//    
//    private let recordButton = UIButton(type: .custom)
//    private let recordButtonInner = UIButton(type: .custom)
//    private let switchCameraButton = UIButton(type: .system)
//    private let timerLabel = UILabel()
//    private let torchButton = UIButton(type: .system)
//    
//    private let timerButton = UIButton(type: .system)
//    private let speedButton = UIButton(type: .system)
//    private let musicButton = UIButton(type: .system)
//    private let filterButton = UIButton(type: .system)
//    
//    private let countdownLabel = UILabel()
//    private var countdownTimer: Timer?
//    private var selectedTimerSeconds = 0
//    private var selectedSpeed: Float = 1.0
//    
//    private let countdownOverlay = UIView()
//    
//    private var isRecording = false
//    private var isFrontCameraActive = false
//    private var isTorchActive = false
//    private var outputFileURL: URL?
//    
//    // MARK: - Add Selected Music properties
//    private var selectedMusicURL: URL?
//    private var audioPlayer: AVAudioPlayer?
//    private var audioSession: AVAudioSession?
//    private var audioPlayerObserver: NSObjectProtocol?
//    
//    private var recordingTimer: Timer?
//    private var elapsedSeconds = 0
//    
//    override func viewDidLoad() {
//        super.viewDidLoad()
//        setupUI()
//        setupCaptureSession()
//        setupCountdownOverlay()
//    }
//    
//    override func viewWillAppear(_ animated: Bool) {
//        super.viewWillAppear(animated)
//        startCaptureSession()
//        if isTorchActive {
//            isTorchActive = false
//            updateTorchButtonIcon()
//        }
//        selectedSpeed = 1.0
//        speedButton.setImage(UIImage(systemName: "speedometer"), for: .normal)
//        speedButton.tintColor = .white
//    }
//    
//    override func viewDidAppear(_ animated: Bool) {
//        super.viewDidAppear(animated)
//        updateTorchStateFromDevice()
//    }
//    
//    override func viewWillDisappear(_ animated: Bool) {
//        super.viewWillDisappear(animated)
//        stopCaptureSession()
//        stopTimer()
//        if isTorchActive {
//            toggleTorch(on: false)
//        }
//        
//        // Remove audio player observer
//        if let observer = audioPlayerObserver {
//            NotificationCenter.default.removeObserver(observer)
//            audioPlayerObserver = nil
//        }
//    }
//    
//    // MARK: - UI Setup Method
//    private func setupUI() {
//        timerLabel.translatesAutoresizingMaskIntoConstraints = false
//        timerLabel.text = "00:00"
//        timerLabel.textColor = .white
//        timerLabel.textAlignment = .center
//        timerLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 18, weight: .medium)
//        timerLabel.backgroundColor = UIColor.black.withAlphaComponent(0.5)
//        timerLabel.layer.cornerRadius = 10
//        timerLabel.clipsToBounds = true
//        timerLabel.isHidden = true
//        
//        countdownLabel.translatesAutoresizingMaskIntoConstraints = false
//        countdownLabel.textColor = .white
//        countdownLabel.textAlignment = .center
//        countdownLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 80, weight: .bold)
//        countdownLabel.isHidden = true
//        
//        recordButton.translatesAutoresizingMaskIntoConstraints = false
//        recordButton.backgroundColor = .clear
//        recordButton.layer.cornerRadius = 35
//        recordButton.layer.borderColor = UIColor.white.cgColor
//        recordButton.layer.borderWidth = 3
//        recordButton.addTarget(self, action: #selector(recordButtonTapped), for: .touchUpInside)
//        
//        recordButtonInner.translatesAutoresizingMaskIntoConstraints = false
//        recordButtonInner.backgroundColor = .red
//        recordButtonInner.layer.cornerRadius = 30
//        recordButtonInner.addTarget(self, action: #selector(recordButtonTapped), for: .touchUpInside)
//        
//        musicButton.setImage(UIImage(systemName: "music.note"), for: .normal)
//        musicButton.tintColor = .white
//        musicButton.backgroundColor = UIColor.black.withAlphaComponent(0.5)
//        musicButton.layer.cornerRadius = 22
//        musicButton.translatesAutoresizingMaskIntoConstraints = false
//        musicButton.addTarget(self, action: #selector(musicButtonTapped), for: .touchUpInside)
//        
//        filterButton.setImage(UIImage(systemName: "camera.filters"), for: .normal)
//        filterButton.tintColor = .white
//        filterButton.backgroundColor = UIColor.black.withAlphaComponent(0.5)
//        filterButton.layer.cornerRadius = 22
//        filterButton.translatesAutoresizingMaskIntoConstraints = false
//        
//        view.addSubview(recordButton)
//        view.addSubview(switchCameraButton)
//        view.addSubview(timerLabel)
//        view.addSubview(torchButton)
//        view.addSubview(timerButton)
//        view.addSubview(speedButton)
//        view.addSubview(musicButton)
//        view.addSubview(filterButton)
//        view.addSubview(countdownLabel)
//        recordButton.addSubview(recordButtonInner)
//        
//        NSLayoutConstraint.activate([
//            recordButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
//            recordButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -30),
//            recordButton.widthAnchor.constraint(equalToConstant: 70),
//            recordButton.heightAnchor.constraint(equalToConstant: 70),
//            
//            recordButtonInner.centerXAnchor.constraint(equalTo: recordButton.centerXAnchor),
//            recordButtonInner.centerYAnchor.constraint(equalTo: recordButton.centerYAnchor),
//            recordButtonInner.widthAnchor.constraint(equalToConstant: 60),
//            recordButtonInner.heightAnchor.constraint(equalToConstant: 60),
//            
//            timerLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
//            timerLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
//            timerLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 80),
//            timerLabel.heightAnchor.constraint(equalToConstant: 36),
//            
//            filterButton.topAnchor.constraint(equalTo: musicButton.bottomAnchor, constant: 15),
//            filterButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30),
//            filterButton.widthAnchor.constraint(equalToConstant: 44),
//            filterButton.heightAnchor.constraint(equalToConstant: 44),
//            
//            countdownLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
//            countdownLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
//            countdownLabel.widthAnchor.constraint(equalToConstant: 150),
//            countdownLabel.heightAnchor.constraint(equalToConstant: 150)
//        ])
//        
//        timerLabel.layoutMargins = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10)
//    }
//    
//    private func setupCountdownOverlay() {
//        countdownOverlay.translatesAutoresizingMaskIntoConstraints = false
//        countdownOverlay.backgroundColor = UIColor.black.withAlphaComponent(0.5)
//        countdownOverlay.isHidden = true
//        
//        view.addSubview(countdownOverlay)
//        
//        NSLayoutConstraint.activate([
//            countdownOverlay.topAnchor.constraint(equalTo: view.topAnchor),
//            countdownOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
//            countdownOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
//            countdownOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor)
//        ])
//        
//        view.bringSubviewToFront(countdownLabel)
//    }
//    
//    // MARK: - Camera Setup Methods
//    private func setupCaptureSession() {
//        captureSession = AVCaptureSession()
//        
//        guard let captureSession = captureSession else { return }
//        
//        if captureSession.canSetSessionPreset(.high) {
//            captureSession.sessionPreset = .high
//        }
//        
//        setupAudioInput()
//        configureCameraInput(position: .back)
//        configureVideoOutput()
//        setupPreviewLayer()
//    }
//    
//    private func setupAudioInput() {
//        guard let captureSession = captureSession else { return }
//        
//        guard let audioDevice = AVCaptureDevice.default(for: .audio) else {
//            print("Audio device not found")
//            return
//        }
//        
//        do {
//            let audioInput = try AVCaptureDeviceInput(device: audioDevice)
//            
//            if captureSession.canAddInput(audioInput) {
//                captureSession.addInput(audioInput)
//                audioDeviceInput = audioInput
//                print("Audio input added successfully")
//            } else {
//                print("Could not add audio input")
//            }
//        } catch {
//            print("Audio input setup error: \(error.localizedDescription)")
//        }
//    }
//    
//    private func configureCameraInput(position: AVCaptureDevice.Position) {
//        guard let captureSession = captureSession else { return }
//        
//        let wasRecording = isRecording
//        var savedFileURL: URL? = nil
//        
//        if wasRecording, let videoOutput = videoOutput {
//            savedFileURL = outputFileURL
//            videoOutput.stopRecording()
//            isRecording = false
//        }
//        
//        if captureSession.isRunning {
//            captureSession.beginConfiguration()
//        }
//        
//        if let existingInput = videoDeviceInput {
//            captureSession.removeInput(existingInput)
//        }
//        
//        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) else {
//            if captureSession.isRunning {
//                captureSession.commitConfiguration()
//            }
//            return
//        }
//        
//        do {
//            let videoInput = try AVCaptureDeviceInput(device: videoDevice)
//            
//            if captureSession.canAddInput(videoInput) {
//                captureSession.addInput(videoInput)
//                videoDeviceInput = videoInput
//                
//                let previousCameraPosition = isFrontCameraActive ? AVCaptureDevice.Position.front : AVCaptureDevice.Position.back
//                isFrontCameraActive = position == .front
//                
//                configureVideoOutput()
//                
//                if isFrontCameraActive {
//                    torchButton.isHidden = true
//                    if isTorchActive {
//                        isTorchActive = false
//                        toggleTorch(on: false)
//                    }
//                } else {
//                    torchButton.isHidden = false
//                    
//                    if previousCameraPosition == .front {
//                        isTorchActive = false
//                        updateTorchButtonIcon()
//                    }
//                }
//            }
//        } catch {
//            print("Camera input setup error: \(error.localizedDescription)")
//        }
//        
//        if captureSession.isRunning {
//            captureSession.commitConfiguration()
//        }
//        
//        if wasRecording {
//            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
//                self?.startRecording(continueFromURL: savedFileURL)
//            }
//        }
//    }
//    
//    private func configureVideoOutput() {
//        guard let captureSession = captureSession else { return }
//        
//        if let existingOutput = videoOutput {
//            captureSession.removeOutput(existingOutput)
//        }
//        
//        let movieOutput = AVCaptureMovieFileOutput()
//        
//        if captureSession.canAddOutput(movieOutput) {
//            captureSession.addOutput(movieOutput)
//            
//            if let connection = movieOutput.connection(with: .video) {
//                if connection.isVideoStabilizationSupported {
//                    connection.preferredVideoStabilizationMode = .auto
//                }
//                
//                if connection.isVideoOrientationSupported {
//                    connection.videoOrientation = .portrait
//                }
//                
//                if connection.isVideoMirroringSupported {
//                    connection.isVideoMirrored = isFrontCameraActive
//                }
//            }
//            
//            if let audioConnection = movieOutput.connection(with: .audio) {
//                audioConnection.isEnabled = true
//            }
//            
//            videoOutput = movieOutput
//        }
//    }
//    
//    private func setupPreviewLayer() {
//        guard let captureSession = captureSession else { return }
//        
//        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
//        previewLayer.videoGravity = .resizeAspectFill
//        previewLayer.frame = view.layer.bounds
//        view.layer.insertSublayer(previewLayer, at: 0)
//        
//        self.previewLayer = previewLayer
//    }
//    
//    private func startCaptureSession() {
//        if let captureSession = captureSession, !captureSession.isRunning {
//            DispatchQueue.global(qos: .userInitiated).async {
//                self.captureSession?.startRunning()
//            }
//        }
//    }
//    
//    private func stopCaptureSession() {
//        if let captureSession = captureSession, captureSession.isRunning {
//            captureSession.stopRunning()
//        }
//    }
//    
//    // MARK: - Torch State Management
//    private func updateTorchStateFromDevice() {
//        guard let device = AVCaptureDevice.default(for: .video),
//              !isFrontCameraActive,
//              device.hasTorch else {
//            return
//        }
//        
//        let actualTorchState = device.torchMode == .on
//        if isTorchActive != actualTorchState {
//            isTorchActive = actualTorchState
//            updateTorchButtonIcon()
//        }
//    }
//    
//    // MARK: - Timer Methods
//    private func startTimer() {
//        elapsedSeconds = 0
//        updateTimerLabel()
//        timerLabel.isHidden = false
//        
//        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
//            guard let self = self else { return }
//            self.elapsedSeconds += 1
//            self.updateTimerLabel()
//        }
//    }
//    
//    private func stopTimer() {
//        recordingTimer?.invalidate()
//        recordingTimer = nil
//        timerLabel.isHidden = true
//    }
//    
//    private func updateTimerLabel() {
//        let minutes = elapsedSeconds / 60
//        let seconds = elapsedSeconds % 60
//        timerLabel.text = String(format: "%02d:%02d", minutes, seconds)
//    }
//    
//    // MARK: - Recording Methods
//    @objc private func recordButtonTapped() {
//        if isRecording {
//            stopRecording()
//        } else {
//            if let timer = countdownTimer, timer.isValid {
//                timer.invalidate()
//                countdownTimer = nil
//                countdownLabel.isHidden = true
//                countdownOverlay.isHidden = true
//                
//                recordButton.isEnabled = true
//                switchCameraButton.isEnabled = true
//                torchButton.isEnabled = true
//                timerButton.isEnabled = true
//                speedButton.isEnabled = true
//                musicButton.isEnabled = true
//            }
//            
//            if selectedTimerSeconds > 0 {
//                startCountdown()
//            } else {
//                startRecording()
//            }
//        }
//    }
//    
//    // MARK: - Modified startRecording method to play music
//    func startRecording(continueFromURL: URL? = nil) {
//        guard let videoOutput = videoOutput, !isRecording else { return }
//        
//        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
//        let fileName = "video_\(Date().timeIntervalSince1970).mov"
//        let fileURL = documentsPath.appendingPathComponent(fileName)
//        
//        do {
//            if FileManager.default.fileExists(atPath: fileURL.path) {
//                try FileManager.default.removeItem(at: fileURL)
//            }
//        } catch {
//            print("Could not remove file: \(error.localizedDescription)")
//        }
//        
//        if let connection = videoOutput.connection(with: .video) {
//            if connection.isVideoOrientationSupported {
//                connection.videoOrientation = .portrait
//            }
//            if connection.isVideoMirroringSupported {
//                connection.isVideoMirrored = isFrontCameraActive
//            }
//        }
//        
//        if let player = audioPlayer {
//            player.currentTime = 0
//            player.play()
//        }
//        
//        videoOutput.startRecording(to: fileURL, recordingDelegate: self)
//        
//        UIView.animate(withDuration: 0.3) {
//            self.recordButtonInner.layer.cornerRadius = 6
//            self.recordButtonInner.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
//        }
//        
//        isRecording = true
//        outputFileURL = fileURL
//        
//        if continueFromURL == nil {
//            startTimer()
//        }
//    }
//    
//    // MARK: - Modified stopRecording to stop music playback
//    func stopRecording() {
//        guard let videoOutput = videoOutput, isRecording else { return }
//        videoOutput.stopRecording()
//        
//        audioPlayer?.stop()
//        
//        UIView.animate(withDuration: 0.3) {
//            self.recordButtonInner.layer.cornerRadius = 30
//            self.recordButtonInner.transform = .identity
//        }
//        
//        isRecording = false
//        stopTimer()
//    }
//    
//    override func viewDidLayoutSubviews() {
//        super.viewDidLayoutSubviews()
//        previewLayer?.frame = view.layer.bounds
//    }
//}
//
//// MARK: - AVCaptureFileOutputRecordingDelegate Extension
//@available(iOS 15.0, *)
//extension VideoCaptureVCc: AVCaptureFileOutputRecordingDelegate, MusicSelectionDelegate {
//    func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
//        print("Recording started")
//    }
//    
//    func didSelectMusic(url: URL) {
//        selectedMusicURL = url
//        setupAudioForRecording()
//        
//        DispatchQueue.main.async {
//            self.musicButton.tintColor = .systemGreen
//        }
//    }
//    
//    // MARK: - Modified fileOutput completion to handle music merging
//    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
//        if isRecording {
//            return
//        }
//        
//        if let error = error {
//            print("Recording error: \(error.localizedDescription)")
//            return
//        }
//        
//        if isTorchActive {
//            toggleTorch(on: false)
//        }
//        
//        audioPlayer?.stop()
//        
//        if let selectedMusicURL = selectedMusicURL {
//            DispatchQueue.main.async {
//                let loadingAlert = UIAlertController(title: "", message: "", preferredStyle: .alert)
//                let loadingIndicator = UIActivityIndicatorView(style: .large)
//                loadingIndicator.hidesWhenStopped = true
//                loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
//                loadingIndicator.startAnimating()
//                
//                loadingAlert.view.addSubview(loadingIndicator)
//                
//                NSLayoutConstraint.activate([
//                    loadingIndicator.centerXAnchor.constraint(equalTo: loadingAlert.view.centerXAnchor),
//                    loadingIndicator.centerYAnchor.constraint(equalTo: loadingAlert.view.centerYAnchor),
//                    loadingIndicator.heightAnchor.constraint(equalToConstant: 50),
//                    loadingIndicator.widthAnchor.constraint(equalToConstant: 50)
//                ])
//                
//                loadingAlert.view.heightAnchor.constraint(equalToConstant: 100).isActive = true
//                loadingAlert.view.widthAnchor.constraint(equalToConstant: 100).isActive = true
//                
//                self.present(loadingAlert, animated: true, completion: nil)
//                
//                self.mergeAudioAndVideo(videoURL: outputFileURL, audioURL: selectedMusicURL) { mergedURL in
//                    DispatchQueue.main.async {
//                        loadingAlert.dismiss(animated: true) {
//                            if let mergedURL = mergedURL {
//                                if let storyboard = self.storyboard {
//                                    if let previewVC = storyboard.instantiateViewController(identifier: "VideoCaptureShowVC") as? VideoCaptureShowVC {
//                                        previewVC.videoURL = mergedURL
//                                        previewVC.playbackSpeed = self.selectedSpeed
//                                        previewVC.modalPresentationStyle = .fullScreen
//                                        self.present(previewVC, animated: true)
//                                    } else {
//                                        print("Could not instantiate VideoCaptureShowVC")
//                                    }
//                                }
//                            } else {
//                                let errorAlert = UIAlertController(title: "Error", message: "Error merging video and music", preferredStyle: .alert)
//                                errorAlert.addAction(UIAlertAction(title: "OK", style: .default))
//                                self.present(errorAlert, animated: true)
//                            }
//                        }
//                    }
//                }
//            }
//        } else {
//            DispatchQueue.main.async {
//                if let storyboard = self.storyboard {
//                    if let previewVC = storyboard.instantiateViewController(identifier: "VideoCaptureShowVC") as? VideoCaptureShowVC {
//                        previewVC.videoURL = outputFileURL
//                        previewVC.playbackSpeed = self.selectedSpeed
//                        previewVC.modalPresentationStyle = .fullScreen
//                        self.present(previewVC, animated: true)
//                    } else {
//                        print("Could not instantiate VideoCaptureShowVC")
//                    }
//                }
//            }
//        }
//    }
//}
