# Browser evidence

Captured by real Chromium in successful GitHub Actions run [38531448259](https://github.com/amirnourhan-max/google-modem/actions/runs/38531448259), branch code at `8ae71552c91eb08b2553fb6c40de0a7a10b29df0`.

These are synthetic fixtures of the **actual v15 view source with the pinned official Bootstrap stylesheet**, not screenshots of the user's router or a complete running OpenWrt installation. Persian sample names/headings exercise bidi rendering. Fixture controls and PASS report at the top are test-only and absent from production.

- Light/Dark at 360, 768 and 1366px, RTL.
- Seven PNGs, including a fallback theme without tokens.
- `browser-report.json`: six layout results and measured badge contrast (10.368 light, 8.652 dark), visible-only callback guard and 30-second interval.
- The original job-log ZIP was SHA256 checked: `fbb12fea443dfb38ee233d5632fa775690b092a3b185d3c28200a0a10d90379b`.

Main, v14.3, APIv6 and Android sources are untouched. Router deployment and Android device refresh remain NOT VERIFIED.
