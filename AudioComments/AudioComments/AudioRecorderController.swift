//
//  AudioRecorderController.swift
//  AudioComments
//
//  Created by Bradley Diroff on 6/2/20.
//  Copyright © 2020 Bradley Diroff. All rights reserved.
//

import UIKit
import AVFoundation

protocol AddItemDelegate {
func itemWasAdded(_ item: AudioItem)
}

class AudioRecorderController: UIViewController {
    
    @IBOutlet var playButton: UIButton!
    @IBOutlet var recordButton: UIButton!
    @IBOutlet var timeElapsedLabel: UILabel!
    @IBOutlet var timeRemainingLabel: UILabel!
    @IBOutlet var timeSlider: UISlider!
    @IBOutlet var audioVisualizer: AudioVisualizer!
    
    @IBOutlet weak var messageText: UITextField!
    
    
    private lazy var timeIntervalFormatter: DateComponentsFormatter = {
        // NOTE: DateComponentFormatter is good for minutes/hours/seconds
        // DateComponentsFormatter is not good for milliseconds, use DateFormatter instead)
        
        let formatting = DateComponentsFormatter()
        formatting.unitsStyle = .positional // 00:00  mm:ss
        formatting.zeroFormattingBehavior = .pad
        formatting.allowedUnits = [.minute, .second]
        return formatting
    }()
    
    // MARK: - View Controller Lifecycle
    
    var delegate: AddItemDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Use a font that won't jump around as values change
        timeElapsedLabel.font = UIFont.monospacedDigitSystemFont(ofSize: timeElapsedLabel.font.pointSize,
                                                                 weight: .regular)
        timeRemainingLabel.font = UIFont.monospacedDigitSystemFont(ofSize: timeRemainingLabel.font.pointSize,
                                                                   weight: .regular)
        
        loadAudio()
        updateViews()
        try? prepareAudioSession() // TODO: handle case where on phone call and it fails
    }
    
    deinit {
        // Protects us from a crash if the timer is still going when the user navigates away from the
        // timer UI
        cancelTimer()
    }
    
    private func updateViews() {
        playButton.isSelected = isPlaying
        
        let currentTime = audioPlayer?.currentTime ?? 0.0
        let duration = audioPlayer?.duration ?? 0.0
        
        // Rounding the duration prevents a glitch with labels updating at different times
        // 3.1 = currentTime -> 3
        // 7 = duration
        // 3.7 = timeRemaining -> 4
        let timeRemaining = round(duration) - currentTime

        timeElapsedLabel.text = timeIntervalFormatter.string(from: currentTime) ?? "00:00"
        timeRemainingLabel.text = "-" + (timeIntervalFormatter.string(from: timeRemaining) ?? "00:00")

        timeSlider.minimumValue = 0
        timeSlider.maximumValue = Float(duration)
        timeSlider.value = Float(currentTime)
        
        // Recording
        recordButton.isSelected = isRecording
    }
    
    // MARK: - Timer

    var timer: Timer?

    func startTimer() {
        timer?.invalidate() // Cancel a timer before you start a new one!
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.030, repeats: true) { [weak self] (_) in
            guard let self = self else { return }
            
            self.updateViews()
            
                if let audioRecorder = self.audioRecorder,
                    self.isRecording == true {
    
                    audioRecorder.updateMeters()
                    self.audioVisualizer.addValue(decibelValue: audioRecorder.averagePower(forChannel: 0))
    
                }
            
                if let audioPlayer = self.audioPlayer,
                    self.isPlaying == true {
    
                    audioPlayer.updateMeters()
                    self.audioVisualizer.addValue(decibelValue: audioPlayer.averagePower(forChannel: 0))
                }
        }
    }

    func cancelTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    // MARK: - Playback
    
    var audioPlayer: AVAudioPlayer? {
        didSet {
            // Using a didSet allows us to make sure we don't forget to set the delegate
            audioPlayer?.delegate = self
            audioPlayer?.isMeteringEnabled = true
        }
    }
    
    var isPlaying: Bool {
        audioPlayer?.isPlaying ?? false
    }
    
    func loadAudio() {
        // App Bundle is read-only (Download from the App Store - or install from Xcode)
        // Documents directory is read-write
 //       let songURL = Bundle.main.url(forResource: "piano", withExtension: "mp3")!
        
  //      audioPlayer = try? AVAudioPlayer(contentsOf: songURL)
    }
    
    func prepareAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, options: [.defaultToSpeaker])
        try session.setActive(true, options: []) // can fail if on a phone call, for instance
    }
    
    func play() {
        audioPlayer?.play()
        startTimer()
        updateViews()
    }

    func pause() {
        audioPlayer?.pause()
        cancelTimer()
        updateViews()
    }
    
    // MARK: - Recording
    
    var audioRecorder: AVAudioRecorder?
    var recordingURL: URL?
    
    var isRecording: Bool {
        audioRecorder?.isRecording ?? false
    }
    
    func createNewRecordingURL() -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        let name = ISO8601DateFormatter.string(from: Date(), timeZone: .current, formatOptions: .withInternetDateTime)
        let file = documents.appendingPathComponent(name, isDirectory: false).appendingPathExtension("caf")
        
        print("recording URL: \(file)")
        print("URL AS STRING: \(file.absoluteString)")
        
        return file
    }
    
    func requestPermissionOrStartRecording() {
        switch AVAudioSession.sharedInstance().recordPermission {
        case .undetermined:
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                guard granted == true else {
                    print("We need microphone access")
                    return
                }
                
                print("Recording permission has been granted!")
                // NOTE: Invite the user to tap record again, since we just interrupted them, and they may not have been ready to record
            }
        case .denied:
            print("Microphone access has been blocked.")
            
            let alertController = UIAlertController(title: "Microphone Access Denied", message: "Please allow this app to access your Microphone.", preferredStyle: .alert)
            
            alertController.addAction(UIAlertAction(title: "Open Settings", style: .default) { (_) in
                UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
            })
            
            alertController.addAction(UIAlertAction(title: "Cancel", style: .default, handler: nil))
            
            present(alertController, animated: true, completion: nil)
        case .granted:
            startRecording()
        @unknown default:
            break
        }
    }
    
    func startRecording() {
        let recordingURL = createNewRecordingURL()
        
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
        audioRecorder = try? AVAudioRecorder(url: recordingURL, format: format)  // TODO: Error handling do/catch
        audioRecorder?.delegate = self
        audioRecorder?.isMeteringEnabled = true
        audioRecorder?.record()
        self.recordingURL = recordingURL
        updateViews()
        
        startTimer()
    }

    func stopRecording() {
        audioRecorder?.stop()
        updateViews()
        cancelTimer()
    }
    
    // MARK: - Actions
    
    @IBAction func togglePlayback(_ sender: Any) {
        if isPlaying { // isPlaying == true
            pause()
        } else {
            play()
        }
    }
    
    @IBAction func updateCurrentTime(_ sender: UISlider) {
        if isPlaying {
            pause()
        }
        
        audioPlayer?.currentTime = TimeInterval(timeSlider.value)
        updateViews()
    }
    
    @IBAction func toggleRecording(_ sender: Any) {
        if isRecording {
            stopRecording()
        } else {
            requestPermissionOrStartRecording()
        }
    }
    
    @IBAction func saveUrlToArray(_ sender: Any) {
        guard let recordingURL = recordingURL, let messageText = messageText.text, messageText != "" else { return }
        
        let item = AudioItem(name: messageText, audio: recordingURL)
        
        delegate?.itemWasAdded(item)
        
    }
}

extension AudioRecorderController: AVAudioPlayerDelegate {
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        updateViews()
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        if let error = error {
            print("Audio Player Error: \(error)")
        }
        updateViews()
    }
}

extension AudioRecorderController: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if flag,
            let recordingURL = recordingURL {
            audioPlayer = try? AVAudioPlayer(contentsOf: recordingURL) // TODO: error handling
        }
        updateViews()
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        if let error = error {
            print("Audio Record Error: \(error)")
        }
        updateViews()
    }
}

