# Browser evidence

Captured by real Chromium in successful GitHub Actions run [38623703561](https://github.com/amirnourhan-max/google-modem/actions/runs/38623703561), branch code at `afebcd29390cd1d0ae2c2d16603297e287a87e9d`.

These are synthetic fixtures executing the **unmodified actual LuCI Overview host and real v15 baseclass include with the pinned official Bootstrap stylesheet**, not screenshots of the user's router or a complete OpenWrt installation. The real host sorts Proxy Monitor above System. RPC/System data and generic DOM/network helpers are fixture boundaries. Persian sample names/headings exercise bidi rendering. Test controls and PASS report are absent from production.

- Light/Dark at 360, 768 and 1366px, RTL.
- Seven PNGs, including a fallback theme without tokens.
- `browser-report.json`: six layout results and measured badge contrast (10.368 light, 8.652 dark), final opacity1 after native fade-in, actual host sorting, 30-second request gate, stable DOM and hidden/collapsed suspension.
- The job-log ZIP was SHA256 checked: `1e3796259cf788fb3c41e7800b561815db921d2b27acd8af306e783b5d9e3c2f`.
- Native daemon integration: actual rpcd/ubusd registration/reload, read-only status and anonymous denial passed in the same run. Earlier evidence remains available through Git history.

Main, v14.3, APIv6 and Android sources are untouched. Router deployment and Android device refresh remain NOT VERIFIED.
