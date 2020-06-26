A Movie Archive to Experience your DVDs in a Modern Way
=======================================================

*Movie Archive is in an early development phase. Nothing end-user compatible is working yet.*

You want to free your DVDs from their physical existence and convert them to files you can 
consume on your devices? Then this project is for you. Movie Archive ingests DVDs into a 
modern experience with menus and bonus content. Not all DVD features are represented 
faithfully, but we preserve as much as we can. To be future-proof, the resulting menus and 
bonus clips can be watched in any recent web browser as well.

Code Structure
--------------

These modules form the architectural layers of the application:

**Model**  
The core data structures store a tree of movie assets and menus. The data model includes 
facilities to manipulate it, but it is not concerned with how and why these manipulations 
take place. Manipulations are conducted as a work queue of tree operators. The data model 
tree is value-typed, but may contain reference-typed payload.

**Importers**  
This module implements the use case of importing from external representations like DVDs to 
the internal data model. Initially, the entire DVD structures are imported into one opaque 
model node, then tree operators are executed to transform the imported data into a useful 
model representation.

**Exporters**  
Exporting will convert the internal data model to an on-disk representation. The canonical 
export is to encode M4V files and write out the JSON menu files.

**XPCConverter**  
All external libraries like `libdvdread` or `libhandbrake` run in isolation within this XPC 
service. It implements a controller layer to interface with these libraries.

**macOS**  
This layer contains all macOS-specific code and bridges the importer and exporter use case 
layers to the macOS frameworks.

**Players**  
Players are separate from the model, importer, and exporter layers and present UI to view 
the stored movies.

___
This work is licensed under the [GNU GPLv2](https://www.gnu.org/licenses/old-licenses/gpl-2.0.html) unless otherwise noted.
The [player components](https://github.com/mroi/movie-archive/tree/master/Players) are licensed under [MPLv2](https://www.mozilla.org/en-US/MPL/2.0/) for compatibility with the App Store.
Nothing in this work handles copy-protected DVDs, you have to [deal with the CSS copy-protection](http://www.videolan.org/developers/libdvdcss.html) yourself.
