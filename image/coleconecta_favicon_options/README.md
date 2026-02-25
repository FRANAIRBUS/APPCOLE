# ColeConecta — Favicon options (generated)

You asked to use the provided icon. Here are **3 export options**:

## Option A (recommended): people-only, transparent
Folder: `A_people_transparent_recommended/`
- Removes the chopped red piece and excess whitespace.
- Adds a thin outline so it doesn't disappear on light tabs.
- Best readability at 16×16.

## Option B: people-only with dark badge
Folder: `B_people_badge_dark/`
- Same symbol, but with a rounded dark background for maximum contrast.
- Most consistent across light/dark browser UI.

## Option C: full image "as provided"
Folder: `C_full_as_image/`
- Includes the chopped red top piece.
- At 16×16 it tends to look like a mistake (because it *is* visually incomplete).

## How to use
Pick ONE option folder and copy its contents into your `web/` folder (Flutter web).

Then in `web/index.html` add something like:

```html
<link rel="icon" type="image/x-icon" href="favicon.ico">
<link rel="icon" type="image/png" sizes="32x32" href="favicon-32x32.png">
<link rel="icon" type="image/png" sizes="16x16" href="favicon-16x16.png">
<link rel="apple-touch-icon" href="apple-touch-icon.png">
```

A quick preview is in `preview.png`.
