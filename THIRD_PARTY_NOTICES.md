# Third-party notices

## Clippy artwork and animation data

- Upstream commit: [`748f199f0187f6f94ce395cdd55081f513476156`](https://github.com/pithings/clippy/tree/748f199f0187f6f94ce395cdd55081f513476156)
- Sprite atlas source: <https://github.com/pithings/clippy/blob/748f199f0187f6f94ce395cdd55081f513476156/src/agents/clippy/map.png>
- Animation metadata source: <https://github.com/pithings/clippy/blob/748f199f0187f6f94ce395cdd55081f513476156/src/agents/clippy/agent.ts>
- Expected atlas SHA-256: `880b63ac4d3fa84c78eceb02674c9eaedae032b2d85887539a7f6d107e5801e9`
- Source animation metadata SHA-256: `88a9f81fb1ea97fa9218f243113a3d40415b76b02fb065435c67c6d333c0e7f7`

The atlas is deliberately excluded from Git and can be downloaded locally with `scripts/fetch-assets.sh`. A non-executing, data-only conversion extracted animation coordinates, durations, exit routes, and weighted branches into native Swift. All 43 upstream routines were compared with the pinned metadata; three additional composite routines reuse those frames. No sound files are bundled.

The upstream repository's software license does not grant rights to Microsoft-owned character artwork. Clippy, Microsoft Office, and related character artwork and trademarks belong to their respective owners. Obtain the necessary permission before public or commercial redistribution. See Microsoft's [copyright permissions](https://www.microsoft.com/en-us/legal/intellectualproperty/copyright/permissions) and [trademark guidelines](https://www.microsoft.com/en-us/legal/intellectualproperty/trademarks).
