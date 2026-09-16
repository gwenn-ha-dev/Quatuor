import AVFoundation

/// Synchronized multi-track audio player built on `AVAudioEngine`.
///
/// All stems play in parallel through individual `AVAudioPlayerNode` instances
/// connected to a shared mixer, enabling per-stem mute and volume control.
/// Ideal for karaoke-style use: mute vocals and sing along.
@Observable
@MainActor
final class StemPlayer {
    static let shared = StemPlayer()

    struct TrackState {
        var isMuted: Bool = false
        var isSoloed: Bool = false
        var volume: Float = 1.0
    }

    private(set) var isPlaying = false
    private(set) var progress: Double = 0
    private(set) var duration: TimeInterval = 0
    var tracks: [UUID: TrackState] = [:]
    /// True when at least one track is soloed — non-soloed tracks are silenced.
    var hasSolo: Bool { tracks.values.contains { $0.isSoloed } }

    private var engine = AVAudioEngine()
    private var playerNodes: [UUID: AVAudioPlayerNode] = [:]
    private var audioFiles: [UUID: AVAudioFile] = [:]
    private var referenceNodeID: UUID?
    private var totalFrames: AVAudioFramePosition = 0
    private var sampleRate: Double = 44100
    private var seekFrame: AVAudioFramePosition = 0
    private var pollingTask: Task<Void, Never>?

    /// Prepares the engine with one player node per stem.
    func load(stems: [SeparationResult.Stem]) {
        unload()

        for stem in stems {
            guard let file = try? AVAudioFile(forReading: stem.pcmFileURL) else { continue }
            let node = AVAudioPlayerNode()
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: file.processingFormat)
            playerNodes[stem.id] = node
            audioFiles[stem.id] = file
            tracks[stem.id] = TrackState()
            if referenceNodeID == nil { referenceNodeID = stem.id }
        }

        if let file = audioFiles.values.first {
            totalFrames = file.length
            sampleRate = file.processingFormat.sampleRate
            duration = Double(totalFrames) / sampleRate
        }
    }

    func togglePlayPause() {
        isPlaying ? pause() : play()
    }

    func setVolume(_ volume: Float, for stemID: UUID) {
        tracks[stemID]?.volume = volume
        applyTrackVolume(for: stemID)
    }

    func toggleMute(for stemID: UUID) {
        guard tracks[stemID] != nil else { return }
        tracks[stemID]!.isMuted.toggle()
        applyTrackVolume(for: stemID)
    }

    func toggleSolo(for stemID: UUID) {
        guard tracks[stemID] != nil else { return }
        tracks[stemID]!.isSoloed.toggle()
        // Reapply volumes to all tracks since solo affects everyone.
        for id in tracks.keys { applyTrackVolume(for: id) }
    }

    /// Computes the effective volume for a track considering mute, solo, and volume.
    private func applyTrackVolume(for stemID: UUID) {
        guard let track = tracks[stemID] else { return }
        let effectiveVolume: Float
        if track.isMuted {
            effectiveVolume = 0
        } else if hasSolo && !track.isSoloed {
            effectiveVolume = 0
        } else {
            effectiveVolume = track.volume
        }
        playerNodes[stemID]?.volume = effectiveVolume
    }

    func seek(fraction: Double) {
        let wasPlaying = isPlaying
        stopAllNodes()
        seekFrame = AVAudioFramePosition(fraction * Double(totalFrames))
        seekFrame = max(0, min(seekFrame, totalFrames))
        progress = fraction
        if wasPlaying {
            scheduleAndPlay()
        }
    }

    func stop() {
        stopPolling()
        stopAllNodes()
        seekFrame = 0
        progress = 0
        isPlaying = false
    }

    func unload() {
        stop()
        for node in playerNodes.values {
            engine.detach(node)
        }
        engine.stop()
        engine = AVAudioEngine()
        playerNodes = [:]
        audioFiles = [:]
        tracks = [:]
        referenceNodeID = nil
        totalFrames = 0
        duration = 0
    }

    // MARK: - Private

    private func play() {
        guard !isPlaying else { return }
        do {
            try engine.start()
        } catch {
            NSLog("AVAudioEngine start failed: \(error)")
            return
        }
        scheduleAndPlay()
    }

    private func pause() {
        seekFrame = currentFrame()
        for node in playerNodes.values {
            node.stop()
        }
        isPlaying = false
        stopPolling()
    }

    private func scheduleAndPlay() {
        let remaining = totalFrames - seekFrame
        guard remaining > 0 else {
            stop()
            return
        }

        for (id, node) in playerNodes {
            guard let file = audioFiles[id] else { continue }
            node.stop()
            node.scheduleSegment(
                file,
                startingFrame: seekFrame,
                frameCount: AVAudioFrameCount(remaining),
                at: nil
            )
            applyTrackVolume(for: id)
        }

        // Start all nodes at the same host time for sample-accurate sync.
        if let hostTime = playerNodes.values.first?.lastRenderTime?.hostTime {
            let startTime = AVAudioTime(hostTime: hostTime + UInt64(0.01 * Double(NSEC_PER_SEC)))
            for node in playerNodes.values {
                node.play(at: startTime)
            }
        } else {
            for node in playerNodes.values {
                node.play()
            }
        }

        isPlaying = true
        startPolling()
    }

    private func currentFrame() -> AVAudioFramePosition {
        guard let refID = referenceNodeID,
              let node = playerNodes[refID],
              let nodeTime = node.lastRenderTime,
              nodeTime.isSampleTimeValid,
              let playerTime = node.playerTime(forNodeTime: nodeTime) else {
            return seekFrame
        }
        return min(seekFrame + playerTime.sampleTime, totalFrames)
    }

    private func stopAllNodes() {
        for node in playerNodes.values {
            node.stop()
        }
        engine.stop()
        isPlaying = false
        stopPolling()
    }

    private func startPolling() {
        pollingTask?.cancel()
        pollingTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self, self.isPlaying else { return }
                let frame = self.currentFrame()
                if frame >= self.totalFrames {
                    self.stop()
                    return
                }
                self.progress = Double(frame) / Double(self.totalFrames)
                try? await Task.sleep(for: .milliseconds(50))
            }
        }
    }

    private func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }
}
