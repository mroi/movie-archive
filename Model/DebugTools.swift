#if DEBUG

/// Exporter for testing, which black-holes its input.
struct NullExporter: ExportPass {
	func consume(_ mediaTree: MediaTree) {}
}

#endif
