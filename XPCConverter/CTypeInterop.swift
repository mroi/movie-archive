/* Extensions for more convenient interaction with C types. */

extension UnsafeBufferPointer {
	/// Creates a new buffer pointer, while tolerating `nil` and 0 arguments.
	init<C: UnsignedInteger>(start: UnsafePointer<Element>?, count: C?) {
		if start != nil && count != nil && count! > 0 {
			self = Self(start: start, count: Int(count!))
		} else {
			self = Self(start: nil, count: 0)
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
