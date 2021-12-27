import Foundation
import MovieArchiveModel
import MovieArchiveImporters
import MovieArchiveExporters


let source = Bundle.main.url(forResource: "MinimalDVD", withExtension: "iso")!

let importer = try! Importer(source: source)
let exporter = Exporter(format: .movieArchiveLibrary)
let transform = Transform(importer: importer, exporter: exporter)

let updates = PlaygroundTransformUpdates()
transform.publisher.subscribe(updates)

transform.execute()

var status: Transform.Status!
status = updates.next()
status.handle()

// remove this line to inspect and handle status updates interactively
while updates.next()?.handle() != nil {}
