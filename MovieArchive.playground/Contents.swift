/*:
 Playground for interactive exploration of the Movie Archive backend APIs. The
 sample code constructs a `Transform` and iterates over the status updates.
 */
import Foundation
import MovieArchiveModel
import MovieArchiveImporters
import MovieArchiveExporters


//let source = URL(fileURLWithPath: "/Volumes/DVD_VIDEO")
let source = Bundle.main.url(forResource: "MinimalDVD", withExtension: "iso")!

let importer = try! await Importer(source: source)
let exporter = Exporter(format: .movieArchiveLibrary)
let transform = Transform(importer: importer, exporter: exporter)

let updates = PlaygroundTransformUpdates()
transform.publisher.subscribe(updates)

transform.execute()

var status: Transform.Status!
status = updates.next()
status.handle()

// remove this line to inspect and handle status updates interactively
updates.handleAll()
