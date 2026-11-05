// MODULE ID: DATALINK
// Tuning constants for the Tactical Datalink Mesh (design doc "TDL v0.2").
// Everything gameplay-tunable lives here so playtests only touch one file.

/// Power classes (design doc §2)
#define DATALINK_CLASS_SUIT "suit"
#define DATALINK_CLASS_VEHICLE "vehicle"

/// Node states (design doc §4)
#define DATALINK_STATE_ACTIVE "active"
#define DATALINK_STATE_SILENT "silent"
#define DATALINK_STATE_DESTROYED "destroyed"

/// Packet kinds
#define DATALINK_PACKET_BEACON "beacon"
#define DATALINK_PACKET_COMMAND "command"

/// Command types (design doc §5.3)
#define DATALINK_CMD_MOVE_TO "move_to"
#define DATALINK_CMD_FOCUS "focus"
#define DATALINK_CMD_HOLD "hold"
#define DATALINK_CMD_REGROUP "regroup"
#define DATALINK_CMD_PING "ping"
#define DATALINK_CMD_CUSTOM "custom"

/// Command priorities
#define DATALINK_PRIORITY_NORMAL 0
#define DATALINK_PRIORITY_HIGH 1

/// Ranges in tiles — tuning knobs, not constants (design doc §2)
#define DATALINK_RANGE_SUIT 30
#define DATALINK_RANGE_VEHICLE 60

/// Relay depth: how many hops from origin this node will rebroadcast (design doc §6)
#define DATALINK_RELAY_DEPTH_NONE 0
#define DATALINK_RELAY_DEPTH_VEHICLE 2

/// Packet TTL for originated commands (design doc §5.3)
#define DATALINK_COMMAND_TTL_SUIT 3
#define DATALINK_COMMAND_TTL_VEHICLE 4

/// Hard caps (design doc §4, §9)
/// Active nodes; modules beyond this fail to register.
#define DATALINK_MAX_NODES 128
/// Neighbor table entries per node.
#define DATALINK_MAX_NEIGHBORS 32
/// Flattened contacts exposed to HUD/console per node.
#define DATALINK_MAX_CONTACTS 24
/// Dedupe ring entries per node, ~10 s window.
#define DATALINK_MAX_DEDUPE 64
/// Flood rate limiter: packets per second per node.
#define DATALINK_FLOOD_RATE 4
/// Flood packets drained from the relay queue per network tick.
#define DATALINK_FLOOD_DRAIN_PER_TICK 32
/// Uncached LOS checks allowed per network tick.
#define DATALINK_LOS_BUDGET_GLOBAL 64
/// LOS result cache cap; flushed bluntly when exceeded (refills within a second).
#define DATALINK_LOS_CACHE_SIZE 512

/// HUD marker pools per client (design doc §7, option B)
#define DATALINK_MAX_CONTACT_MARKERS 4
#define DATALINK_MAX_COMMAND_MARKERS 3

/// Timing in deciseconds unless stated otherwise (design doc §9)
#define DATALINK_BEACON_INTERVAL (1 SECONDS)
/// Random +/- jitter applied to each beacon interval, in deciseconds.
#define DATALINK_BEACON_JITTER 3
/// Floor for the jittered beacon interval, in deciseconds.
#define DATALINK_BEACON_MIN_INTERVAL 7
/// A neighbor not heard for this many beacon intervals is aged out.
#define DATALINK_AGING_INTERVALS 3
/// Relayed (2-hop) contacts age out at this multiple of the normal window.
#define DATALINK_RELAYED_AGING_MULTIPLIER 2
#define DATALINK_DEDUPE_WINDOW (10 SECONDS)
#define DATALINK_COMMAND_EXPIRY (30 SECONDS)
/// High-priority commands get a redundant second transmission this much later.
#define DATALINK_COMMAND_RETRANSMIT (0.5 SECONDS)
/// LOS results stay valid this long.
#define DATALINK_LOS_CACHE_TIME (1 SECONDS)
/// Foreign signal presence decays after this long without a foreign packet.
#define DATALINK_FOREIGN_DECAY (3 SECONDS)
/// Minimum gap between "foreign datalink in range" warnings.
#define DATALINK_FOREIGN_WARNING_COOLDOWN (30 SECONDS)

/// Sentinel returned by the LOS helper when the per-tick budget is exhausted.
#define DATALINK_LOS_DEFERRED -1

/// Default net ids (design doc §8) — a crypto fill key can rewrite these.
#define DATALINK_NET_NANOTRASEN "NT-CMD"
#define DATALINK_NET_SOL "SOL-NET"
#define DATALINK_NET_FREELANCE "FREELANCE"
#define DATALINK_NET_UNAFFILIATED "UNAFFILIATED"

/// Every node currently registered on any net. Hard-capped at DATALINK_MAX_NODES.
GLOBAL_LIST_EMPTY(datalink_nodes)

/// Net ids a crypto fill key can be programmed with.
GLOBAL_LIST_INIT(datalink_net_ids, list(
	DATALINK_NET_NANOTRASEN,
	DATALINK_NET_SOL,
	DATALINK_NET_FREELANCE,
	DATALINK_NET_UNAFFILIATED,
))
