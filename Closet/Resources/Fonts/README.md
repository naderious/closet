# Fonts

Drop your **GT America** font files (`.otf` or `.ttf`) into this folder.

That's all you need to do. The folder is synced with the Xcode target, so new files get
bundled automatically, and `FontRegistry` registers them at launch and picks the faces:

- **Bold** (titles and important info): the heaviest face of the widest cut available,
  e.g. *GT America Expanded Black* or *Expanded Bold*.
- **Normal** (everything else): the matching *Regular* face.

Both static fonts and a variable GT America font work. Until files are added, the app
falls back to the system's expanded San Francisco, which has similar wide proportions.

This README is excluded from the app bundle.
