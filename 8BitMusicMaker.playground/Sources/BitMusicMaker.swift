import UIKit

/// BitMusicMaker is the 8-BitMusicMaker. It's a facade that manages the sequencing of notes and user interation through the UI.
public class BitMusicMaker: UIView {
	let sequencer: Sequencer
	let blocks: Int
	let instriments: Set<Instrument>
	let sequencerViews: [Instrument: SequencerView]
	let sequencerContainers: [UIView]
	let logo = UIImage(.bitMusicMakerWP)
	let playStopButton: UIButton
	let recordingButton: UIButton
	let sequencerContainersHeight: CGFloat

	/// BitMusicMaker is the 8-BitMusicMaker.
	/// It's a facade that manages the sequencing of notes and user interation through the UI.
	///
	/// - Parameters:
	///   - instruments: the set of instruments to add to the sequencer.
	///   - state: the instruments and their notes to play on startup.
	///   - blocks: the length of the sequencer in blocks.
	///   - blocksPerSecond: the speed of the sequencer measured in blocks per second.
	///   - saveURL: the url to save any recording to.
	///   - numberOfOctaves: the number of octaves to for the given instruments to add to the sequncer.
	public init(with instruments: Set<Instrument>, initialState state: [Instrument: Set<NoteAtBlock>], numberOfBlocks blocks: Int, blocksPerSecond: Double, saveURL: URL?, numberOfOctaves: Note.NumberOfOctaves? = nil) {
		// setup global number of octaves
		if let numberOfOctaves = numberOfOctaves {
			Note.numberOfOctaves = numberOfOctaves
		}

		// setup state
		self.instriments = instruments
		self.blocks = blocks
		sequencer = Sequencer(with: instruments, initialState: state, numberOfBlocks: blocks, blocksPerSecond: 1/blocksPerSecond, saveURL: saveURL)

		// determine sequencerViews width/height
		let sequencerViewsWidth = CGFloat(blocks + 1) * Metrics.blockSize
		let sequencerViewsHeight = CGFloat(Note.allValues.count + 1) * Metrics.blockSize

		// create sequencerViews
		var sequencerViews = [Instrument: SequencerView]()
		sequencerContainers = instruments.map { instrument in
			let sequencerView = SequencerView(instrument: instrument, blocks: blocks)
			sequencerViews[instrument] = sequencerView
			return BitMusicMaker.sequencerViewContainer(sequencerView: sequencerView)
		}
		self.sequencerViews = sequencerViews

		// create play/stop button
		playStopButton = UIButton(frame: CGRect(
			x: logo.size.width + Metrics.blockSize * 2,
			y: Metrics.blockSize,
			width: Metrics.blockSize * 4,
			height: Metrics.blockSize * 4
		))

		// create record button
		recordingButton = UIButton(frame: CGRect(
			x: logo.size.width + Metrics.blockSize * 3 + playStopButton.bounds.width,
			y: Metrics.blockSize,
			width: Metrics.blockSize * 4,
			height: Metrics.blockSize * 4
		))

		// determine width and height of self
		let sequencerContainersHeight = sequencerContainers.reduce(0) { (result, view) -> CGFloat in
			return result + view.bounds.size.height
		}
		self.sequencerContainersHeight = sequencerContainersHeight
		let width = max(sequencerViewsWidth + Metrics.blockSize * 2, Metrics.blockSize * 4 + logo.size.width + playStopButton.frame.size.width + recordingButton.frame.size.width)
		let height = sequencerContainersHeight + CGFloat(sequencerContainers.count + 1) * Metrics.blockSize + logo.size.height

		super.init(frame: CGRect(x: 0, y: 0, width: width, height: height))
		setupViews(sequencerViewsWidth: sequencerViewsWidth, sequencerViewsHeight: sequencerViewsHeight)
		sequencer.delegate = self
		for (_, sequencerView) in sequencerViews {
			sequencerView.delegate = self
		}
	}

	public required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	public override func didMoveToSuperview() {
		super.didMoveToSuperview()
		sequencer.prepareForPlaying()
		sequencer.start()
	}

	func setupViews(sequencerViewsWidth: CGFloat, sequencerViewsHeight: CGFloat) {
		backgroundColor = .backgroundColor

		let imageView = UIImageView(frame: CGRect(origin: CGPoint(x: Metrics.blockSize, y: 0), size: logo.size))
		imageView.contentMode = .scaleAspectFill
		imageView.image = logo
		addSubview(imageView)

		playStopButton.setImage(UIImage(.playButtonUp), for: .normal)
		playStopButton.setImage(UIImage(.playButtonDown), for: .highlighted)
		addSubview(playStopButton)
		playStopButton.addTarget(self, action: #selector(handlePlayStopTouch), for: .touchUpInside)

		recordingButton.setImage(UIImage(.recordButtonUp2), for: .normal)
		recordingButton.setImage(UIImage(.recordButtonDown), for: .highlighted)
		addSubview(recordingButton)
		recordingButton.addTarget(self, action: #selector(handleRecordButtonTouch), for: .touchUpInside)

		let stackView = UIStackView(arrangedSubviews: sequencerContainers)
		stackView.frame = CGRect(
			x: Metrics.blockSize,
			y: Metrics.blockSize + logo.size.height,
			width: sequencerViewsWidth,
			height: sequencerContainersHeight + CGFloat(sequencerViews.count - 1) * Metrics.blockSize
		)
		stackView.axis = .vertical
		stackView.distribution = .fillEqually
		stackView.spacing = Metrics.blockSize

		addSubview(stackView)
	}

	@objc func handlePlayStopTouch() {
		switch sequencer.currentMode {
		case .playing:
			sequencer.hardStop()
		case .stopped:
			sequencer.start()
		}
	}

	@objc func handleRecordButtonTouch() {
		sequencer.toggleRecord()
	}

	static func sequencerViewContainer(sequencerView: SequencerView) -> UIView {
		let sequenceViewContainer = UIView(frame: CGRect(
			x: 0,
			y: 0,
			width: sequencerView.bounds.size.width,
			height: sequencerView.bounds.size.height + Metrics.blockSize * 2
		))
		let instrumentWaveImage = UIImage(instrumentForWave: sequencerView.instrument)
		let waveImageView = UIImageView(frame: CGRect(
			x: 0,
			y: 0,
			width: instrumentWaveImage.size.width/2,
			height: instrumentWaveImage.size.height/2
		))
		waveImageView.image = instrumentWaveImage

		let instrumentTitleImage = UIImage(instrumentForTitle: sequencerView.instrument)
		let titleImageView = UIImageView(frame: CGRect(
			x: waveImageView.bounds.width + 10,
			y: 0,
			width: instrumentTitleImage.size.width/2,
			height: instrumentTitleImage.size.height/2
		))
		titleImageView.image = instrumentTitleImage

		sequenceViewContainer.addSubview(titleImageView)
		sequenceViewContainer.addSubview(waveImageView)
		sequenceViewContainer.addSubview(sequencerView)
		sequencerView.frame.origin.y = instrumentWaveImage.size.height/2

		return sequenceViewContainer
	}
}

extension BitMusicMaker: SequencerDelegate {
	func blockChanged(_ block: Int) {
		// render sequencerViews currentBlock
		for (_, sequencerView) in sequencerViews {
			sequencerView.pointToBlock(block)
		}
	}

	func sequencerModeChanged(_ mode: Sequencer.Mode) {
		// change play/stop button
		switch mode {
		case .playing:
			playStopButton.setImage(UIImage(.stopButtonUp), for: .normal)
			playStopButton.setImage(UIImage(.stopButtonDown), for: .highlighted)
		case .stopped:
			playStopButton.setImage(UIImage(.playButtonUp), for: .normal)
			playStopButton.setImage(UIImage(.playButtonDown), for: .highlighted)
		}
		sequencerViews.forEach { (_, sequencerView) in
			sequencerView.sequencerMode = mode
		}
	}

	func stateChanged(_ state: [Instrument : Set<NoteAtBlock>]) {
		// render sequenceViews (do diff)
		for (instrument, state) in state {
			sequencerViews[instrument]?.highlightNotes(newState: state)
		}
	}

	func recordingStateChanged(isRecording: Bool) {
		if isRecording {
			recordingButton.setImage(UIImage.recordingButton, for: .normal)
		} else {
			recordingButton.setImage(UIImage(.recordButtonUp2), for: .normal)
		}
	}
}

extension BitMusicMaker: SequencerViewDelegate {
	func noteDrawn(note: Note, block: Int, instrument: Instrument) {
		sequencer.toggleNote(note, onInstrument: instrument, forBlock: block)
	}
}
