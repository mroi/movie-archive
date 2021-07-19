import Foundation
import MovieArchiveModel
import MovieArchiveImporters
import MovieArchiveExporters


let source = Bundle.main.url(forResource: "MinimalDVD", withExtension: "iso")!

let importer = try! Importer(source: source)
let exporter = Exporter(format: .movieArchiveLibrary)
let transform = Transform(importer: importer, exporter: exporter)
