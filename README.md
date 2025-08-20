# NIfTIViewQL

![screenshot image](image002.png)

A quick and *very* messy Quick Look Preview Extension for macOS 15 and beyond.

Early drafts were me trying to remember objective-c and decipher apple dev docs.
Later drafts leaned on Github co-pilot and Claude.ai for trying to get it to work.
At some point I'll attempt to clean up the code, but for now, it works. 

Pull requests welcome! 

To build:
```
git clone https://github.com/pmolfese/NIfTIViewQL
cd NIfTIViewQL
xcodebuild -project NIfTIViewQL.xcodeproj -scheme NIfTIViewQuickLook -configuration Release -derivedDataPath ./output build
```

Copy the resulting NIfTIViewQL.app into your /Applications folder.

Run the program once (it doesn't do much other than simple renders).

Enjoy Quick Look Previews of NIfTI files! 

If you find this helpful, please give us a Star!