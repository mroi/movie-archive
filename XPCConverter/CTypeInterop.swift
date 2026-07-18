import LibDVDRead


/* Extensions for more convenient and safe interaction with C types. */

extension UnsafeBufferPointer {
	/// Creates a new buffer pointer, while tolerating `nil` and 0 arguments.
	///
	/// - ToDo: Replace with a `Span` once `@lifetime` annotations become available.
	///   The use of `Span` will reduce the usage of memory-unsafe primitives.
	///   The annotation is necessary because the caller needs to prove that
	///   the `start` argument outlives the resulting `Span`.
	init<C: UnsignedInteger>(start: UnsafePointer<Element>?, count: C?) {
		if unsafe start != nil && count != nil && count! > 0 {
			unsafe self = Self(start: start, count: Int(count!))
		} else {
			unsafe self = Self(start: nil, count: 0)
		}
	}
}

extension Span {
	/// Compare the elements of the span to another `Sequence`.
	func elementsEqual<Other>(_ other: Other) -> Bool where Other: Sequence, Element: Equatable, Element == Other.Element {
		precondition(count == other.underestimatedCount)
		return unsafe withUnsafeBufferPointer { unsafe $0.elementsEqual(other) }
	}
}

extension MutableSpan {
	/// Invokes a closure with a temporary mutable span of the requested capacity.
	static func withTemporaryAllocation<R>(capacity: Int, body: (inout MutableSpan<Element>) -> R) -> R {
		unsafe withUnsafeTemporaryAllocation(of: Element.self, capacity: capacity) { buffer in
			var span = unsafe buffer.mutableSpan
			return body(&span)
		}
	}
}

/// Reads one DVD block at the given block offset.
func DVDReadBlock(_ handle: OpaquePointer, offset: Int, into buffer: inout MutableSpan<UInt8>) -> Bool {
	precondition(buffer.count >= Int(DVD_VIDEO_LB_LEN))
	let result = unsafe buffer.withUnsafeMutableBufferPointer {
		unsafe DVDReadBlocks(handle, Int32(offset), 1, $0.baseAddress)
	}
	return result == 1
}

extension pci_t {
	/// Parses a NAV PCI structure from a span of bytes.
	init(from data: Span<UInt8>) {
		self.init()
		precondition(data.count >= MemoryLayout<pci_t>.size)
		unsafe data.withUnsafeBufferPointer {
			unsafe navRead_PCI(&self, .init(mutating: $0.baseAddress))
		}
	}
}

extension dsi_t {
	/// Parses a NAV DSI structure from a span of bytes.
	init(from data: Span<UInt8>) {
		self.init()
		precondition(data.count >= MemoryLayout<dsi_t>.size)
		unsafe data.withUnsafeBufferPointer {
			unsafe navRead_DSI(&self, .init(mutating: $0.baseAddress))
		}
	}
}

extension BinaryInteger {
	/// Isolates a single bit.
	func bit(_ index: Int) -> Bool {
		assert(index >= 0)
		assert(index < self.bitWidth)
		let mask: Self = 1 << index
		return (self & mask) != 0
	}
	/// Isolates a range of bits.
	func bits(_ range: ClosedRange<Int>) -> Self {
		assert(range.lowerBound >= 0)
		assert(range.upperBound < self.bitWidth)
		let mask: Self = (1 << range.count) - 1
		return (self >> range.lowerBound) & mask
	}
}

extension Array {
	/// Create an `Array` from a fixed-size C-style array.
	///
	/// Swift represents fixed-size arrays as tuples.
	///
	/// - ToDo: If generic type sequences are added to Swift, this could be
	///   improved by replacing the `Mirror` with iterating over a type sequence.
	init<T>(tuple: T) {
		self = Mirror(reflecting: tuple).children.compactMap { $0.value as? Element }
	}
}

extension String {
	/// Create a `String` from a fixed-size C-style array of `CChar`.
	init<T>(tuple: T) {
		self.init(Array<CChar>(tuple: tuple).compactMap {
			let unicodePoint = Unicode.Scalar(UInt8($0))
			return unicodePoint != "\0" ? Character(unicodePoint) : nil
		})
	}
}
