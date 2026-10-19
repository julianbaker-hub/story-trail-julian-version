import AVFoundation
import Combine
import CryptoKit
import Foundation
import MediaPlayer
import OSLog
import UIKit

struct QueuedTourStop {
    let tour: Tour
    let stop: TourStop
}

struct TourStopPlaybackQueue {
    private(set) var items: [QueuedTourStop] = []

    mutating func enqueue(tour: Tour, stop: TourStop) {
        guard !items.contains(where: { $0.tour.id == tour.id && $0.stop.id == stop.id }) else { return }
        items.append(QueuedTourStop(tour: tour, stop: stop))
    }

    mutating func popFirst() -> QueuedTourStop? {
        guard !items.isEmpty else { return nil }
        return items.removeFirst()
    }

    mutating func removeAll() {
        items.removeAll()
    }
}

enum ProximityPlaybackResult {
    case playing
    case queued
    case arrived
}

@MainActor
final class AudioPlayerModel: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published private(set) var currentTour: Tour?
    @Published private(set) var currentStop: TourStop?
    @Published private(set) var isPlaying = false
    @Published private(set) var progress: Double = 0
    @Published private(set) var duration: Double = 0
    @Published private(set) var hasFinished = false
    @Published private(set) var isLoading = false
    @Published private(set) var lastError: String?

    private var player: AVAudioPlayer?
    private var timer: Timer?
    private var lastNowPlayingSecond = -1
    private var loadingTask: Task<Void, Never>?
    private var activeLoadID = UUID()
    private var wasPlayingBeforeInterruption = false
    private var remoteCommandTargets: [(MPRemoteCommand, Any)] = []
    private var proximityQueue = TourStopPlaybackQueue()
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "StoryTrail", category: "Audio")

    override init() {
        super.init()
        configureAudioSession()
        configureRemoteCommands()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioInterruption),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        for (command, target) in remoteCommandTargets {
            command.removeTarget(target)
        }
        loadingTask?.cancel()
        timer?.invalidate()
    }

    func load(tour: Tour, stop: TourStop, autoplay: Bool = false) {
        proximityQueue.removeAll()
        loadAudio(tour: tour, stop: stop, autoplay: autoplay)
    }

    func handleProximityArrival(tour: Tour, stop: TourStop, autoplay: Bool) -> ProximityPlaybackResult {
        if currentTour?.id == tour.id, currentStop?.id == stop.id {
            if autoplay, !isPlaying, progress == 0, !hasFinished {
                play()
                return .playing
            }
            return .arrived
        }

        if isLoading || (player != nil && !hasFinished && progress < duration) {
            proximityQueue.enqueue(tour: tour, stop: stop)
            return .queued
        }

        loadAudio(tour: tour, stop: stop, autoplay: autoplay)
        return autoplay ? .playing : .arrived
    }

    private func loadAudio(tour: Tour, stop: TourStop, autoplay: Bool) {
        loadingTask?.cancel()
        let loadID = UUID()
        activeLoadID = loadID
        timer?.invalidate()
        player?.stop()
        player = nil
        currentTour = tour
        currentStop = stop
        isPlaying = false
        hasFinished = false
        isLoading = false
        lastError = nil
        progress = 0
        duration = 0
        updateNowPlayingInfo()

        if let file = stop.audioFile {
            guard let url = bundledURL(for: file) else {
                failLoading("The audio file \(file) could not be found.")
                return
            }
            preparePlayer(url: url, stop: stop, autoplay: autoplay)
            return
        }

        if let remoteURL = stop.audioURL {
            if let cachedURL = cachedAudioURL(for: remoteURL), FileManager.default.fileExists(atPath: cachedURL.path) {
                logger.notice("Using cached audio for \(stop.id, privacy: .public)")
                preparePlayer(url: cachedURL, stop: stop, autoplay: autoplay)
                return
            }
            isLoading = true
            loadingTask = Task { [weak self] in
                do {
                    let (data, response) = try await URLSession.shared.data(from: remoteURL)
                    try Task.checkCancellation()
                    guard let self, self.activeLoadID == loadID else { return }
                    if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                        throw URLError(.badServerResponse)
                    }
                    if let cachedURL = self.cachedAudioURL(for: remoteURL) {
                        do {
                            try data.write(to: cachedURL, options: .atomic)
                            self.preparePlayer(url: cachedURL, stop: stop, autoplay: autoplay)
                        } catch {
                            self.logger.error("Could not cache audio: \(error.localizedDescription, privacy: .public)")
                            self.preparePlayer(data: data, stop: stop, autoplay: autoplay)
                        }
                    } else {
                        self.preparePlayer(data: data, stop: stop, autoplay: autoplay)
                    }
                } catch is CancellationError {
                    return
                } catch {
                    guard let self, self.activeLoadID == loadID else { return }
                    self.failLoading(
                        "This story could not be downloaded. Check your connection and try again.", error: error)
                }
            }
            return
        }

        guard let previewURL = Bundle.main.url(forResource: "inner-harbor", withExtension: "mp3") else {
            failLoading("The tour audio could not be found.")
            return
        }
        preparePlayer(url: previewURL, stop: stop, autoplay: autoplay)
    }

    func toggle() { isPlaying ? pause() : play() }

    func play() {
        guard let player else { return }
        do {
            try AVAudioSession.sharedInstance().setActive(true)
            guard player.play() else {
                lastError = "Audio playback could not start."
                return
            }
            hasFinished = false
            isPlaying = true
            startTimer()
            updateNowPlayingInfo()
            logger.notice("Playback started for \(self.currentStop?.id ?? "unknown", privacy: .public)")
        } catch {
            lastError = error.localizedDescription
            logger.error("Playback failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func pause() {
        player?.pause()
        isPlaying = false
        timer?.invalidate()
        updateNowPlayingInfo()
        logger.notice("Playback paused at \(self.progress, format: .fixed(precision: 1)) seconds")
    }

    func seek(to fraction: Double) {
        guard let player else { return }
        player.currentTime = max(0, min(1, fraction)) * player.duration
        progress = player.currentTime
        hasFinished = false
        updateNowPlayingInfo()
    }

    func skip(seconds: Double) {
        guard let player else { return }
        player.currentTime = max(0, min(player.duration, player.currentTime + seconds))
        progress = player.currentTime
        hasFinished = progress >= duration
        updateNowPlayingInfo()
    }

    func playNext() -> Bool {
        guard let tour = currentTour,
            let stop = currentStop,
            let index = tour.stops.firstIndex(of: stop),
            index < tour.stops.count - 1
        else { return false }
        load(tour: tour, stop: tour.stops[index + 1], autoplay: true)
        return true
    }

    func playPrevious() -> Bool {
        guard let tour = currentTour,
            let stop = currentStop,
            let index = tour.stops.firstIndex(of: stop)
        else { return false }
        if progress > 4 {
            seek(to: 0)
            play()
            return true
        }
        guard index > 0 else { return false }
        load(tour: tour, stop: tour.stops[index - 1], autoplay: true)
        return true
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
        hasFinished = true
        progress = duration
        timer?.invalidate()
        updateNowPlayingInfo()
        if let next = proximityQueue.popFirst() {
            loadAudio(tour: next.tour, stop: next.stop, autoplay: true)
        }
    }

    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [])
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func bundledURL(for file: String) -> URL? {
        let filename = file as NSString
        let fileExtension = filename.pathExtension
        let resource = filename.deletingPathExtension
        return Bundle.main.url(
            forResource: resource,
            withExtension: fileExtension.isEmpty ? nil : fileExtension,
        )
    }

    private func cachedAudioURL(for remoteURL: URL) -> URL? {
        guard let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }
        let directory = caches.appendingPathComponent("StoryAudio", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            logger.error("Could not create audio cache: \(error.localizedDescription, privacy: .public)")
            return nil
        }
        let digest = SHA256.hash(data: Data(remoteURL.absoluteString.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
        let fileExtension = remoteURL.pathExtension.isEmpty ? "audio" : remoteURL.pathExtension
        return directory.appendingPathComponent(digest).appendingPathExtension(fileExtension)
    }

    private func preparePlayer(url: URL, stop: TourStop, autoplay: Bool) {
        do {
            finishPreparing(try AVAudioPlayer(contentsOf: url), stop: stop, autoplay: autoplay)
        } catch {
            failLoading("This story could not be opened.", error: error)
        }
    }

    private func preparePlayer(data: Data, stop: TourStop, autoplay: Bool) {
        do {
            finishPreparing(try AVAudioPlayer(data: data), stop: stop, autoplay: autoplay)
        } catch {
            failLoading("The downloaded story is not a supported audio file.", error: error)
        }
    }

    private func finishPreparing(_ preparedPlayer: AVAudioPlayer, stop: TourStop, autoplay: Bool) {
        player = preparedPlayer
        preparedPlayer.delegate = self
        preparedPlayer.prepareToPlay()
        duration = preparedPlayer.duration
        progress = 0
        isLoading = false
        updateRemoteCommandAvailability()
        updateNowPlayingInfo()
        logger.notice(
            "Loaded audio for \(stop.id, privacy: .public), duration \(self.duration, format: .fixed(precision: 1)) seconds"
        )
        if autoplay { play() }
    }

    private func failLoading(_ message: String, error: Error? = nil) {
        isLoading = false
        isPlaying = false
        lastError = message
        updateNowPlayingInfo()
        logger.error("Audio loading failed: \((error?.localizedDescription ?? message), privacy: .public)")
    }

    private func configureRemoteCommands() {
        let commands = MPRemoteCommandCenter.shared()
        register(commands.playCommand) { [weak self] _ in
            Task { @MainActor in self?.play() }
            return .success
        }
        register(commands.pauseCommand) { [weak self] _ in
            Task { @MainActor in self?.pause() }
            return .success
        }
        register(commands.togglePlayPauseCommand) { [weak self] _ in
            Task { @MainActor in self?.toggle() }
            return .success
        }
        commands.skipForwardCommand.preferredIntervals = [15]
        register(commands.skipForwardCommand) { [weak self] _ in
            Task { @MainActor in self?.skip(seconds: 15) }
            return .success
        }
        commands.skipBackwardCommand.preferredIntervals = [15]
        register(commands.skipBackwardCommand) { [weak self] _ in
            Task { @MainActor in self?.skip(seconds: -15) }
            return .success
        }
        register(commands.nextTrackCommand) { [weak self] _ in
            guard let self else { return .commandFailed }
            Task { @MainActor in _ = self.playNext() }
            return .success
        }
        register(commands.previousTrackCommand) { [weak self] _ in
            guard let self else { return .commandFailed }
            Task { @MainActor in _ = self.playPrevious() }
            return .success
        }
        register(commands.changePlaybackPositionCommand) { [weak self] event in
            guard let positionEvent = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            Task { @MainActor in
                guard let self, self.duration > 0 else { return }
                self.seek(to: positionEvent.positionTime / self.duration)
            }
            return .success
        }
    }

    private func register(
        _ command: MPRemoteCommand,
        handler: @escaping (MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus,
    ) {
        remoteCommandTargets.append((command, command.addTarget(handler: handler)))
    }

    private func updateRemoteCommandAvailability() {
        guard let tour = currentTour,
            let stop = currentStop,
            let index = tour.stops.firstIndex(of: stop)
        else { return }
        let commands = MPRemoteCommandCenter.shared()
        commands.previousTrackCommand.isEnabled = index > 0 || progress > 4
        commands.nextTrackCommand.isEnabled = index < tour.stops.count - 1
    }

    private func updateNowPlayingInfo() {
        guard let tour = currentTour, let stop = currentStop else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }

        var info: [String: Any] = [
            MPMediaItemPropertyTitle: stop.title,
            MPMediaItemPropertyAlbumTitle: tour.title,
            MPMediaItemPropertyArtist: "StoryTrail",
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: progress,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue,
            MPNowPlayingInfoPropertyExternalContentIdentifier: stop.id,
        ]
        if let artwork = Self.makeArtwork() {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: artwork.size) { _ in artwork }
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        MPNowPlayingInfoCenter.default().playbackState = isPlaying ? .playing : .paused
        updateRemoteCommandAvailability()
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    private func tick() {
        guard let player else { return }
        progress = player.currentTime
        if !player.isPlaying { isPlaying = false }
        let currentSecond = Int(player.currentTime)
        if currentSecond != lastNowPlayingSecond {
            lastNowPlayingSecond = currentSecond
            updateNowPlayingInfo()
        }
    }

    @objc private func handleAudioInterruption(_ notification: Notification) {
        guard let typeValue = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
            let type = AVAudioSession.InterruptionType(rawValue: typeValue)
        else { return }
        if type == .began {
            wasPlayingBeforeInterruption = isPlaying
            isPlaying = false
            timer?.invalidate()
            updateNowPlayingInfo()
        } else if type == .ended {
            let optionsValue = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            if wasPlayingBeforeInterruption && options.contains(.shouldResume) { play() }
            wasPlayingBeforeInterruption = false
        }
    }

    @objc private func handleRouteChange(_ notification: Notification) {
        guard let reasonValue = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
            AVAudioSession.RouteChangeReason(rawValue: reasonValue) == .oldDeviceUnavailable
        else { return }
        // Avoid unexpectedly moving a walking tour from disconnected headphones
        // to the phone speaker.
        if isPlaying { pause() }
    }

    private static func makeArtwork() -> UIImage? {
        UIImage(named: "BrandIcon")
    }
}
