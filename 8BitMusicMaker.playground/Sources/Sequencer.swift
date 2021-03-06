import AVFoundation
import Foundation

extension NoteAtBlock: Hashable {
	public static func ==(lhs: NoteAtBlock, rhs: NoteAtBlock) -> Bool {
		return lhs.block == rhs.block
			&& lhs.note == rhs.note
	}

	public var hashValue: Int {
		return "\(note.rawValue).\(block)".hashValue
	}
}

protocol SequencerDelegate: class {
	func blockChanged(_ block: Int)
	func sequencerModeChanged(_ mode: Sequencer.Mode)
	func recordingStateChanged(isRecording: Bool)
	func stateChanged(_ state: [Instrument: Set<NoteAtBlock>])
}

class Sequencer {

	public enum Mode {
		case playing
		case stopped
	}

	// Constants
	let blocks: Int

	let blocksPerSecond: Double

	// AVFoundation dependancies
	public let engine = AVAudioEngine()

	// Organized state of the sequencer
	private let players: [Instrument: [Note: PitchedPlayer]]
	private(set) var notesAtBlocks: [Instrument: Set<NoteAtBlock>]
	private(set) var currentMode: Mode = .stopped
	let saveURL: URL?
	var isRecording = false

	weak var delegate: SequencerDelegate?

	init(with instruments: Set<Instrument>, initialState state: [Instrument: Set<NoteAtBlock>] = [:], numberOfBlocks blocks: Int, blocksPerSecond: Double, saveURL: URL?) {
		self.blocksPerSecond = blocksPerSecond
		let buffers = Sequencer.audioBuffers(for: Array(instruments))
		players = Sequencer.createPlayers(forBuffers: buffers, engine: engine)
		notesAtBlocks = state
		for instrument in instruments {
			if notesAtBlocks[instrument] == nil {
				notesAtBlocks[instrument] = []
			}
		}
		self.blocks = blocks
		self.saveURL = saveURL
	}

	// MARK: Static dispatched setup functions

	private static func audioBuffers(for instruments: [Instrument]) -> [Instrument: AVAudioPCMBuffer] {
		var audioBuffers = [Instrument: AVAudioPCMBuffer]()
		for instrument in instruments {
			let sample = instrument.sample
			let audioBuffer = AVAudioPCMBuffer(pcmFormat: sample.processingFormat, frameCapacity: UInt32(sample.length))!
			try! sample.read(into: audioBuffer)
			audioBuffers[instrument] = audioBuffer
		}
		return audioBuffers
	}

	private static func createPlayers(forBuffers buffers: [Instrument: AVAudioPCMBuffer], engine: AVAudioEngine) -> [Instrument: [Note: PitchedPlayer]] {
		var allPlayers = [Instrument: [Note: PitchedPlayer]]()
		let instruments = buffers.map { instrument, _ in return instrument }
		for instrument in instruments {
			var notePlayers = [Note: PitchedPlayer]()
			for note in Note.allValues {
				notePlayers[note] = PitchedPlayer(engine: engine, audioBuffer: buffers[instrument]!, note: note)
			}
			allPlayers[instrument] = notePlayers
		}
		return allPlayers
	}

	// MARK: Sequencer behavior

	func prepareForPlaying() {
		engine.prepare()
		try! engine.start()
		delegate?.stateChanged(notesAtBlocks)
	}

	func hardStop() {
		currentMode = .stopped
		for (instrument, notesAtBlocks) in notesAtBlocks {
			let notesInBlock = notesAtBlocks
				.map { noteAtBlock in noteAtBlock.note }
			notesInBlock.forEach { note in stopNote(note, onInstrument: instrument) }
		}
		delegate?.sequencerModeChanged(currentMode)
		delegate?.blockChanged(0)
	}

	func start() {
		currentMode = .playing
		delegate?.sequencerModeChanged(currentMode)
		sequenceNotes(forNewBlock: 0, oldBlock: nil)
	}

	private func sequenceNotes(forNewBlock newBlock: Int, oldBlock: Int?) {
		if let oldBlock = oldBlock {
			stopNotesForBlock(oldBlock)
		}
		guard currentMode == .playing else { return }
		delegate?.blockChanged(newBlock)
		playNotesForBlock(newBlock)
		DispatchQueue.main.asyncAfter(deadline: .now() + blocksPerSecond) { [weak self] in
			guard let blocks = self?.blocks else { return }
			let allButLastBlock = 0..<(blocks - 1)
			if allButLastBlock.contains(newBlock) {
				self?.sequenceNotes(forNewBlock: newBlock + 1, oldBlock: newBlock)
			} else {
				self?.sequenceNotes(forNewBlock: 0, oldBlock: newBlock)
			}
		}
	}

	private func playNotesForBlock(_ block: Int) {
		for (instrument, notesAtBlocks) in notesAtBlocks {
			let notesInBlock = notesAtBlocks
				.filter { noteAtBlock in noteAtBlock.block == block }
				.map { noteAtBlock in noteAtBlock.note }
			notesInBlock.forEach { note in playNote(note, onInstrument: instrument) }

		}
	}

	private func stopNotesForBlock(_ block: Int) {
		for (instrument, notesAtBlocks) in notesAtBlocks {
			let notesInBlock = notesAtBlocks
				.filter { noteAtBlock in noteAtBlock.block == block }
				.map { noteAtBlock in noteAtBlock.note }
			notesInBlock.forEach { note in stopNote(note, onInstrument: instrument) }
		}
	}

	func registerNote(_ note: Note, onInstrument instrument: Instrument, forBlock block: Int) {
		notesAtBlocks[instrument]?.insert(NoteAtBlock(note: note, block: block))
		delegate?.stateChanged(notesAtBlocks)
	}

	func deregisterNote(_ note: Note, onInstrument instrument: Instrument, forBlock block: Int) {
		if let _ = notesAtBlocks[instrument]?.remove(NoteAtBlock(note: note, block: block)) {
			delegate?.stateChanged(notesAtBlocks)
		}
	}

	func toggleNote(_ note: Note, onInstrument instrument: Instrument, forBlock block: Int) {
		if let instrumentBlocks = notesAtBlocks[instrument], instrumentBlocks.contains(NoteAtBlock(note: note, block: block)) {
			deregisterNote(note, onInstrument: instrument, forBlock: block)
		} else {
			registerNote(note, onInstrument: instrument, forBlock: block)
		}
	}

	func playNote(_ note: Note, onInstrument instrument: Instrument) {
		// simple play a note
		players[instrument]?[note]?.play()
	}

	private func stopNote(_ note: Note, onInstrument instrument: Instrument) {
		// simple play a note
		players[instrument]?[note]?.stop()
	}

	func toggleRecord() {
		if let saveURL = saveURL, isRecording == false, let audioFile = try? AVAudioFile(forWriting: saveURL, settings: [:]) {
			isRecording = true
			engine.mainMixerNode.installTap(onBus: 0, bufferSize: 4096, format: engine.mainMixerNode.outputFormat(forBus: 0)) { (buffer, _) in
				try? audioFile.write(from: buffer)
			}
		} else {
			hardStop()
			engine.mainMixerNode.removeTap(onBus: 0)
			isRecording = false
		}
		delegate?.recordingStateChanged(isRecording: isRecording)
	}
}
