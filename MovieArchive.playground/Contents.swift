import Foundation
import MovieArchiveModel
import MovieArchiveImporters
import MovieArchiveExporters


let source = Bundle.main.url(forResource: "MinimalDVD", withExtension: "iso")!
let transform = Transform(importer: try! Importer(source: source), exporter: Exporter())
