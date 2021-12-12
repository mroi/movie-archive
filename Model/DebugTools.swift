#if DEBUG

/// Test exporter which black-holes its input.
struct NullExporter: ExportPass {
	func consume(_ mediaTree: MediaTree) {}
}

#endif
