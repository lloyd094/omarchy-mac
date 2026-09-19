# Source attribution

Extracted from Omarchy (MIT; see LICENSE), preserving the original helper and service names. Extraction baseline: `omacom/omarchy-mac` commit `350c46550b99688cdb5224408edd5870de2ca07b`.

- Wi-Fi recovery and behavioral tests: Scott Jones, `092ab7cf881742e790f58303b31cf7787802a8a9` (Reload brcmfmac after s2idle when Apple Silicon Wi-Fi wedges). Hardware restrictions and the journal cursor recovery algorithm are retained.

The network backend default follows Marcelo Alcantara's Apple Silicon integration in #9835. Package layout, setup, and migration tests are new work.
