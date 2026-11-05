# Tactical Datalink Mesh (TDL)

https://github.com/NovaSector/NovaSector/pull/<!--PR Number-->

## \<Tactical Datalink Mesh>

Module ID: DATALINK

### Description:

Wireless, ad-hoc datalink networking for entities carrying a datalink module.
Any MODsuit with the tactical datalink module, or any exosuit with the datalink
transceiver array, becomes a node on its net (design doc "TDL v0.2").

- Nodes broadcast a jittered ~1 Hz identity+position beacon; receivers keep a
  bounded neighbor table and age silent contacts out (no links, no relays as
  physical objects, no mappers-placed infrastructure).
- Vehicles/exosuits relay beacons and commands (`RelayDepth` 2); suit modules
  are endpoints only (`RelayDepth` 0). Two-hop contacts are marked distinctly.
- Commands (`MOVE_TO`, `FOCUS`, `HOLD`, `REGROUP`, `PING`, `CUSTOM`) flood with
  dedupe by `(Origin, Seq)` and a TTL; redundancy, not ACKs, is the reliability
  mechanism.
- `NetID` is the security boundary: mismatched packets are dropped, but their
  *presence* can be detected ("foreign datalink in range"). A crypto-fill key
  item can rewrite a module's net id — possession of the module is the key.
- **HUD presentation: screen-object markers (design doc §7 option B).** A small
  pool of `/atom/movable/screen/datalink_marker` objects is kept on the
  holder's client, refreshed at the network tick (4 Hz): nearest contacts,
  two-hop contacts, command markers, and out-of-view contacts pinned to the
  screen edge via `offset_to_screen_loc()` clamping. No lines, no TGUI window
  required for awareness; the `Datalink` TGUI window is the command console.

Scheduling/perf (design doc §9): `SSdatalink` runs a 0.25 s network tick
(aging, relay/flood drain capped at 32 packets, HUD refresh); beacons are
individually scheduled with +/-0.3 s jitter; LOS is `get_line()` + opacity
scan behind a 1 s cache and a global budget of 64 uncached checks per tick
(over-budget commands are deferred one tick, beacons are dropped and recur).

### TG Proc/File Changes:

- N/A (fully modular; `tgstation.dme` only gains `#include` lines for this
  module's files, plus the `Datalink.tsx` TGUI interface which by handbook rule
  lives in `tgui/packages/tgui/interfaces/`).

### Modular Overrides:

- N/A

### Defines:

- `modular_nova/modules/datalink/code/datalink_defines.dm` — all tuning
  constants: ranges (`DATALINK_RANGE_SUIT 30` / `DATALINK_RANGE_VEHICLE 60`),
  caps (`DATALINK_MAX_NODES 128`, neighbor/contact/dedupe/flood caps), timing
  (beacon interval, aging windows, command expiry), command type defines and
  the default `NetID`s.

### Included files that are not contained in this module:

- `tgui/packages/tgui/interfaces/Datalink.tsx` — marked with the mandatory
  `// THIS IS A NOVA SECTOR UI FILE` header.

### Art TODO:

- Item icons reuse existing states (`module`, `mecha_radio`) and HUD markers
  render maptext glyphs (`●` ally, `◆` two-hop, `▲` command) — dedicated
  sprites are an outstanding art task.

### Credits:

- TDL design document by the Nova Sector team.
