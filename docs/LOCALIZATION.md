# Localization

Fishtank supports English (`en`), Simplified Chinese (`zh-Hans`), Traditional Chinese (`zh-Hant`) and Japanese (`ja`). By default the app follows the system's preferred-language order, including the OS's per-app language preference. Settings → General on Mac, or Settings on iPad, provides Follow System and four explicit language choices. The app-owned `appearance.language` preference never changes the OS's `AppleLanguages`. Unsupported system languages and invalid saved choices fall back through system negotiation to English. Choices save and take effect immediately. `AppLocalization` activates the catalog and registers its font before publishing a UI refresh; view identities remain stable so navigation and drafts survive. Language choices are autonyms (简体中文 / 繁體中文 / English / 日本語), each drawn with its own pixel font. Only Follow System is translated.

All application UI, status bubbles, menu titles, accessibility descriptions, notification content, errors, species, decorations, achievements and icon names use the shared catalog in `Sources/Core/Resources/Localizations/`. Provider names, saved IDs, event names, filenames and user-entered names remain unchanged. No player-save migration is involved.

Catalog keys are the English source text, so a missing or new entry falls back to readable English rather than another language. `en.json` repeats each key as its value, which keeps the four catalogs structurally identical and lets English wording be inspected in one place; `check-localizations.py` enforces that identity. `L10n.text("…\(value)…")` captures interpolation separately and inserts each argument once. This supports reordered placeholders while preserving user text containing braces. Immutable metadata marks its keys with `L10n.source` and renders them through `L10n.key`; display enums keep ASCII raw values and expose a localized `title`. A missing translation uses the English catalog, then the key itself. The four catalogs currently share 606 templates.

## Pixel fonts

Chinese and Japanese use Fusion Pixel 12px, pinned to `2026.10.16`. English uses [Departure Mono](https://github.com/rektdeckard/departure-mono/releases/tag/v1.500), pinned to `v1.500`, with larger body text for readability. Its OFL notice is bundled as `DepartureMono-OFL.txt`. All active faces are registered within the process to render autonyms correctly. English also specifies a Fusion Pixel cascade for CJK user content. The font is embedded in the app, never installed into the user's system. The original SIL OFL notices remain bundled.

The glyph checker verifies every translated catalog character against its language's embedded font, without relying on system-font fallback. The Traditional Chinese minnow name uses `灰白條魚` because this font release does not contain `鰷`. This changes only the displayed name, never the saved species ID.

Longer English and Japanese controls use wider filter buttons and a two-column fallback for narrow navigation. The base pixel typography is preserved rather than shrinking translated text into tiny type.

## Checks

```sh
python3 tools/check-localizations.py
swift tools/verify-localized-fonts.swift
swift test
```

The source audit rejects any Chinese string literal in `Sources/` and any bare literal passed to `Text`, `Button`, `.help` or the accessibility modifiers, apart from `Fishtank ` and `Lv.{0}`. The checks cover Swift source coverage, catalog completeness, interpolation/format placeholders, language negotiation, English fallback, user-text insertion, stable IDs, glyph coverage, README links and version-free README text. `LocalizationUITests` exercises all four languages plus an unsupported locale at a 320-point iPad layout. Existing gameplay UI tests explicitly use Simplified Chinese, keeping their labels deterministic. Live-switch tests verify manual overrides and returning to the system language without relaunching. Immutable catalog entries store source keys so previously loaded species, decorations, icons, and achievements update as well.

README editions share language navigation and version-independent screenshots. The documentation screenshot harness hides only the version node in its isolated demo scene; production tanks continue to show the version normally. Demo screenshots contain no personal saves or desktop content.
