[Docs](../README.md) › **Assets**

# Assets

Every image the README and the docs use lives in this folder.

| Folder | What's in it |
|---|---|
| this folder | the Rivue icon and the Guide logo |
| [diagrams/](diagrams) | the pictures in the guide and API pages |
| [badges/](badges) | the link badges at the top of the README |
| [web/](web) | favicons and app icons for the docs site |

## Logos

The Rivue icon is the one at the top of the README. The Guide logo, used for the documentation,
is the same tilted blue tile with the V drawn as an open book.

<img src="./guide-lockup.svg" height="64" alt="Rivue Guide">

| File | Use it for |
|---|---|
| [icon.svg](icon.svg) · [icon.png](icon.png) | the Rivue icon |
| [guide-icon.svg](guide-icon.svg) · [guide-icon.png](guide-icon.png) (512 px) | the Guide symbol, 33 px and up |
| [guide-icon-small.svg](guide-icon-small.svg) | the Guide symbol at 32 px and below, with thicker lines so it stays readable |
| [guide-lockup.svg](guide-lockup.svg) | symbol and name, on light backgrounds |
| [guide-lockup-dark.svg](guide-lockup-dark.svg) | symbol and name, on dark backgrounds |
| [guide-lockup-stacked.svg](guide-lockup-stacked.svg) | symbol above the name, for square spaces |
| [guide-icon-black.svg](guide-icon-black.svg) · [guide-icon-white.svg](guide-icon-white.svg) | one colour, for printing |

The colours are Studio blue `#1F6FEB` for the tile, mint `#7EE8C0` for the inner V, white, and ink
`#1F2328` for text on light backgrounds. The names are set in Inter Display and converted to
outlines, so no font is needed to show them. Inter is under the SIL Open Font License.

Leave a gap of about a quarter of the symbol's width around the logo. Below 33 px use the small
cut, and don't put the colour version on a busy image or a blue close to the tile's; use the
one-colour files there. Please don't recolour it, straighten the tile, stretch it, or add shadows.

The docs site uses the files in `web/`. To use them on another site, put this in the page
`<head>`:

```html
<link rel="icon" href="/favicon.ico" sizes="32x32">
<link rel="icon" type="image/png" sizes="16x16" href="/favicon-16.png">
<link rel="apple-touch-icon" href="/apple-touch-icon.png">
```

## Diagrams

Hand-written SVGs, 780 px wide, white with a grey border, so they read the same on GitHub and on
the docs site in light or dark mode. Link them with a relative path, like
`![a store module](../assets/diagrams/store-flow.svg)` from a guide page.

## Badges

Each badge is the project's icon and name on its own colour, 32 px tall, so all six fit on one
row. The Wally, pesde and Luau icons are those projects' own logos. Rokit has no logo, so its
badge uses a terminal prompt. The three dark badges have a grey outline, which keeps them visible
on GitHub's dark theme.
