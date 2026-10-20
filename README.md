# closet.

Digitize your wardrobe and let color theory put outfits together for you.

closet. is a native SwiftUI iPhone app. You scan each piece with the camera (the background is
removed automatically), describe it once, and the home screen lays out generated outfits as a flat
lay with animated callouts. Tap **regenerate** for a new one.

## Requirements

- Xcode 16 or newer (the project uses Xcode 16's synchronized folders)
- iOS 17 or newer, iPhone
- A real device for scanning: the camera and Vision's background removal don't run in the
  Simulator. In the Simulator you can import photos with the photo icon on the scan screen, and a
  simpler built-in background remover is used instead.

Nothing else is needed. There are no packages or downloads; every icon is drawn in code and the
app icon is in the asset catalog.

## Run it

1. Open `Closet.xcodeproj`.
2. Select the **Closet** target → **Signing & Capabilities** and choose your **Team**. If Xcode
   reports that the bundle identifier is taken, change `com.naderious.closet` to anything unique.
3. Pick your iPhone and press **Run**.

### Preview without scanning (debug builds only)

Under **Product → Scheme → Edit Scheme → Run → Arguments**, add:

- `-seedDemo` fills an empty wardrobe with simple drawn sample pieces
- `-route wardrobe` (or `scan`, `editor`) opens a screen directly
- `-expandAll` unfolds every wardrobe section

None of this is compiled into release builds or the IPA.

## Build an IPA

1. Choose **Any iOS Device (arm64)** as the run destination.
2. **Product → Archive**.
3. In the Organizer, click **Distribute App** and pick a method: **Release Testing** (ad hoc,
   for registered devices), **TestFlight & App Store**, or **Debugging** (development).
4. Click **Export** to get `Closet.ipa`.

Exporting an `.ipa` needs a paid Apple Developer account. With a free account you can still
install straight from Xcode with **Run**.

## Font: GT America

The design uses GT America: Bold for titles and important info, Regular for everything else.
GT America is a commercial typeface, so it isn't checked in. Drop the `.otf`/`.ttf` files into
`Closet/Resources/Fonts/`. That's the only step: the folder is synced with the target and
`FontRegistry` registers the files at launch, picking the widest cut that has both weights
(Expanded, then Extended, then Standard). Variable fonts work too.

Until the files are there, the app uses the system's expanded San Francisco, which has the same
wide proportions.

## How it works

### Screens and motion

| Screen | What it does |
| --- | --- |
| **closet.** (home) | The generated outfit as a flat lay: pants, shirt over the pants, belt and shoes over the pants. Callout lines draw out from each garment's edge, then the name fades in. **regenerate** folds into a spinning arrow while the next outfit is picked. Tap a single garment to swap only that piece. |
| **wardrobe** | One card per category, each in its own color so neighboring cards always contrast, plus a **favorites** section. Unfold a card to see its pieces: color, the two category attributes (e.g. stitching and cut for jeans), the cutout, ✎ to edit, ☆ to favorite. |
| **scan** | Live back-camera preview. **capture** freezes the frame, turns into a spinning arrow, and lifts the garment off the background. The photo icon imports from your library. |
| **review** | Shows the cutout with a glint sweep. You can keep the original background instead. |
| **details / edit** | Name, category, color (drag the eyedropper across the photo, or use the color wheel), and the category's two attributes with quick-pick chips. Edit mode also has retake photo and delete. |

Navigation follows one rule: a page enters from the side of the control you pressed. Left
controls slide the page in from the left, right controls from the right, top controls up from the
bottom, and bottom controls down from the top. Elements on each page then assemble with staggered
springs. ProMotion is enabled (`CADisableMinimumFrameDurationOnPhone`), so animations run at up to
120 fps.

### Outfit generation

`OutfitGenerator` samples combinations (top, bottom, shoes, and sometimes a belt and jacket),
scores each with `OutfitScorer`, and picks among the best with a little randomness so regenerating
stays varied:

- **Color harmony** (`ColorHarmony`). Colors are analyzed in OKLCH. Black, white, grey, navy,
  denim blue and earth tones (beige, camel, brown, olive) count as neutrals. One accent color
  against neutrals scores highest. Pairs of accents are judged on the painter's (RYB) wheel:
  monochrome, analogous and complementary pairs score well, while clashing hue gaps and
  three-plus loud colors are penalized.
- **Light/dark balance** between layers, with deliberate tonal looks (all black) allowed.
- **Belt matches shoes**: a black belt with brown shoes is penalized.
- **Silhouette**: a loose cut balanced with a fitted top is preferred over loose on loose.
- **Shoes vs. cut**: bootcut and flares pair best with boots, wide legs with sneakers, and so on.
  Double denim needs clearly different washes.
- **Favorites** get a boost, and recently shown pieces are rotated out.

### Project layout

```
Closet/
  App/        entry point, router (directional page transitions), scan flow state
  Models/     ClothingItem, ClothingCategory (attributes per category), Outfit, EdgeProfile
  Logic/      color science, harmony, scorer, generator, flat-lay layout, SVG icon parser,
              fallback background removal (all pure Swift)
  Design/     typography (GT America loader), theme colors, icons, vignette, buttons
  Services/   wardrobe/outfit persistence, image store, camera, Vision background removal
  Features/   Home, Wardrobe, Scan, Editor screens
  Resources/  Assets.xcassets (app icon, colors), Fonts/
```

Data stays on the device: the wardrobe is a JSON file and the cutouts are PNGs in
Application Support.

To add a category, add a case to `ClothingCategory` (with its slot and attributes) and a color
in `Theme.swift`.

## CI

`.github/workflows/ios-build.yml` compiles the app with `xcodebuild` on a macOS runner for every
push.
