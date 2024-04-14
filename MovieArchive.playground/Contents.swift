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

let importer = try! Importer(source: source)
let exporter = Exporter(format: .movieArchiveLibrary)
let transform = Transform(importer: importer, exporter: exporter)

let updates = PlaygroundTransformUpdates()
transform.publisher.subscribe(updates)

transform.execute()

var status: Transform.Status!
status = updates.next()  // progress
status.handle()
status = updates.next()  // media tree

/* TODO: remove temporary MP4 processing once import passes generate media tree
   Currently, the import passes generate inconvenient media trees. For DVDs
   consisting only of a main movie, I import them manually to an MP4 file. These
   files are then read to generate the target media tree.
   This allows the DVD importer to record input and output media trees and
   store them as test cases, so future passes can work towards generating the
   output tree. */

// import media tree from manually created MP4 file
let mp4 = Bundle.main.url(forResource: "movie", withExtension: "mp4")!
status.mediaTree = try! MediaTree(fromMovie: mp4)

status.handle()

// remove this line to inspect and handle status updates interactively
updates.handleAll()
