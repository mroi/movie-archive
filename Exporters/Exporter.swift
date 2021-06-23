import MovieArchiveModel


/// Serialize a `MediaTree` to an external data format.
///
/// `Exporter` is the public interface of all export functionality. The exporter
/// consumes a `MediaTree` and generates a specified external data format from
/// it. It internally combines a number of passes to achieve its result.
///
/// - Remark: Exporters form a use case layer on top of the model types.
public struct Exporter: ExportPass {

	public init() {}
}
