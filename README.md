# NIfTIViewQL

![screenshot image](image002.png)

A quick and *very* messy Quick Look Preview Extension for macOS 15 and beyond.

Rough Development process:
1. Link nifti_clib to xcode and run as command line
2. Code GUI using Objective-C to open/read NIfTI files
3. Create Quick Look Preview target in Xcode
4. Fail at #3 multiple times due to macOS 15 API changes
5. Turn to AI to try and Quick Look Preview to work
6. Start sharing things on Github


Pull requests welcome! 

To build:
```
git clone https://github.com/pmolfese/NIfTIViewQL
cd NIfTIViewQL
xcodebuild -project NIfTIViewQL.xcodeproj -scheme NIfTIViewQuickLook -configuration Release -derivedDataPath ./output build
ditto output/Build/Products/Release/NIfTIViewQL.app /Applications/NIfTIViewQL.app
open /Applications/NIfTIViewQL.app
#after inital open you may close the program (forever?)
```

Enjoy Quick Look Previews of NIfTI files! 

If you find this helpful, please give us a Star!