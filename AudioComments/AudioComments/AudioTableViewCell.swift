//
//  AudioTableViewCell.swift
//  AudioComments
//
//  Created by Bradley Diroff on 6/2/20.
//  Copyright © 2020 Bradley Diroff. All rights reserved.
//

import UIKit
import AVFoundation

class AudioTableViewCell: UITableViewCell {

    @IBOutlet weak var audioVisualizer: AudioVisualizer!
    @IBOutlet weak var timeElapsedLabel: UILabel!
    @IBOutlet weak var timeRemainingLabel: UILabel!
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var timeSlider: UISlider!
    @IBOutlet weak var messageText: UILabel!
    
    @IBAction func didPressPlay(_ sender: Any) {
        if isPlaying { // isPlaying == true
             pause()
         } else {
             play()
         }
    }
    
    @IBAction func updateTime(_ sender: UISlider) {
        if isPlaying {
            pause()
        }
        
        audioPlayer?.currentTime = TimeInterval(timeSlider.value)
        updateViews()
    }
    
    var audioItem: AudioItem? {
        didSet {
            startTheCell()
        }
    }

    private lazy var timeIntervalFormatter: DateComponentsFormatter = {
        // NOTE: DateComponentFormatter is good for minutes/hours/seconds
        // DateComponentsFormatter is not good for milliseconds, use DateFormatter instead)
        
        let formatting = DateComponentsFormatter()
        formatting.unitsStyle = .positional // 00:00  mm:ss
        formatting.zeroFormattingBehavior = .pad
        formatting.allowedUnits = [.minute, .second]
        return formatting
    }()
    
    func startTheCell() {
        timeElapsedLabel.font = UIFont.monospacedDigitSystemFont(ofSize: timeElapsedLabel.font.pointSize,
                                                                 weight: .regular)
        timeRemainingLabel.font = UIFont.monospacedDigitSystemFont(ofSize: timeRemainingLabel.font.pointSize,
                                                                   weight: .regular)
        
        loadAudio()
        updateViews()
        try? prepareAudioSession()
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
        
    }
    
    // MARK: - Timer

    var timer: Timer?

    func startTimer() {
        timer?.invalidate() // Cancel a timer before you start a new one!
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.030, repeats: true) { [weak self] (_) in
            guard let self = self else { return }
            
            self.updateViews()
            
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
        guard let audio = audioItem else {return}
        audioPlayer = try? AVAudioPlayer(contentsOf: audio.audio)
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
    
}

extension AudioTableViewCell: AVAudioPlayerDelegate {
    
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
