[Docs](../README.md) › **Rivue Guide logo**

# Rivue Guide logo

The mark for Rivue's documentation. It's a sibling of the [Rivue icon](../../assets/icon.svg):
the same tilted Studio-blue tile, with the V drawn as the pages of an open book and the mint V as
the spread inside.

<img src="./guide-lockup.svg" height="64" alt="Rivue Guide">

## Files

| File | Use it for |
|---|---|
| [guide-icon.svg](guide-icon.svg) · [guide-icon.png](guide-icon.png) (512 px) | the symbol on its own, 33 px and up |
| [guide-icon-small.svg](guide-icon-small.svg) | 32 px and below: wider spine gap, heavier inner V |
| [guide-lockup.svg](guide-lockup.svg) | symbol and name, on light backgrounds |
| [guide-lockup-dark.svg](guide-lockup-dark.svg) | symbol and name, on dark backgrounds |
| [guide-lockup-stacked.svg](guide-lockup-stacked.svg) | symbol over the name, for square spaces |
| [guide-icon-black.svg](guide-icon-black.svg) · [guide-icon-white.svg](guide-icon-white.svg) | one-colour printing, embroidery, stamps |
| [web/](web) | `favicon.ico`, 16 and 32 px favicons, 180 px Apple touch icon, 192 and 512 px app icons |

For a docs site, add this to the page `<head>`:

```html
<link rel="icon" href="/favicon.ico" sizes="32x32">
<link rel="icon" type="image/png" sizes="16x16" href="/favicon-16.png">
<link rel="apple-touch-icon" href="/apple-touch-icon.png">
```

## Colours

| | Hex | RGB |
|---|---|---|
| Studio blue (tile, "Guide" on light) | `#1F6FEB` | 31, 111, 235 |
| Mint (inner V, "Guide" on dark) | `#7EE8C0` | 126, 232, 192 |
| White (pages, "Rivue" on dark) | `#FFFFFF` | 255, 255, 255 |
| Ink ("Rivue" on light) | `#1F2328` | 31, 35, 40 |

The same palette as the Rivue icon. The type is Inter Display (Bold for "Rivue", Medium for
"Guide"), converted to outlines, so no font is needed to display it. Inter is licensed under the
SIL Open Font License.

## Using it

- **Clear space:** keep at least the width of one page (a quarter of the symbol) empty around the
  logo.
- **Minimum size:** 16 px for the symbol (use the small cut below 33 px), 96 px wide for the
  horizontal lockup.
- **Backgrounds:** the colour symbol works on white, light grey and near-black. On a busy image or
  a blue close to Studio blue, use the one-colour version.
- **Don't** recolour the parts, untilt the tile, add shadows or gradients, stretch it, or set
  "Rivue Guide" in another font.

## Badges

`badges/wally.svg` and `badges/docs.svg` are the README's link badges. The Wally badge uses Wally's
own logo, from [wally.run](https://wally.run).
