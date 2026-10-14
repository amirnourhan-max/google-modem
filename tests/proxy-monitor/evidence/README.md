# Browser evidence

Captured by real Chromium in successful GitHub Actions run [38631563055](https://github.com/amirnourhan-max/google-modem/actions/runs/38631563055), branch code at `2f621d09d95d22c2a81f6cb4c43b986644109321` (Actions PR validation merge ref `31d9965c276ca2be1ada19b91dd3fe6ac56686d3`; main was not merged or modified).

These are synthetic fixtures executing the **unmodified actual LuCI Overview host and real v15 baseclass include with the pinned official Bootstrap stylesheet**, not screenshots of the user's router or a complete OpenWrt installation. The real host sorts Proxy Monitor above System. RPC/System data and generic DOM/network helpers are fixture boundaries. Persian sample names/headings exercise bidi rendering. Test controls and PASS report are absent from production.

- Light/Dark at 360, 768 and 1366px, RTL.
- Seven PNGs, including a fallback theme without tokens.
- `browser-report.json`: six layout results and measured badge contrast (10.368 light, 8.652 dark), final opacity1 after native fade-in, actual host sorting, 30-second request gate, stable DOM and hidden/collapsed suspension.
- Node flags, inferred/configured-country distinction, full names/groups, unknown globe, separate exit country, manual refresh to IPv6 and zero automatic exit requests also passed browser assertions. Screenshots show the cached IPv4 fixture before the manual-button assertion. The sample IPs/countries/timestamps are synthetic, not router observations.
- The job-log ZIP was SHA256 checked: `2ba1a8c251a842e2ba999c5044d82353a136e9e9ab8d8231a49e14dcb06cb2fd`.
- All49 tests passed without skips in CI, including actual rpcd/ubusd registration/reload/deferred manual process and anonymous denial, and actual curl/TLS/SOCKS5h integration. Earlier evidence remains available through Git history.

Main, v14.3, APIv6 and Android sources are untouched. Router deployment and Android device refresh remain NOT VERIFIED.
