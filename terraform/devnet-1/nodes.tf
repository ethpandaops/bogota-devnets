########################################################################################
#                                    NODE DEFINITIONS
#
# Define your fleet as a list of node entries. Each entry supports:
#
#   Required:
#     - name            : Node type (e.g., "lighthouse-geth-super", "bootnode")
#     - count           : Number of instances
#     - cloud           : "digitalocean" or "hetzner"
#
#   Optional:
#     - validator_start : First validator index (default: 0)
#     - validator_end   : Last validator index (default: 0)
#     - size            : Instance size override (provider-specific)
#     - region          : Region override (digitalocean) or location (hetzner)
#     - supernode       : Force supernode=true/false (auto-detected from name)
#     - builder_start   : First builder index (buildoor nodes only). Exposes a
#                         builder_index=N server tag and inventory var per instance.
#
# Examples:
#   { name = "bootnode", count = 1, cloud = "digitalocean" }
#   { name = "lighthouse-geth-super", count = 2, cloud = "hetzner", validator_start = 0, validator_end = 200 }
#   { name = "mev-relay", count = 1, cloud = "hetzner", size = "ccx53" }
#
########################################################################################

variable "nodes" {
  description = "List of node definitions for the devnet"
  default = [
    { name = "bootnode", count = 1, cloud = "digitalocean" },
    # Validators split 4 x 250 over the ELs that stayed in consensus through the kurtosis fuzz
    # runs (2026-10-15): any one of them forking off leaves 75%, above the 2/3 finality needs.
    # besu runs without validators until it charges the EIP-8250 keyed nonce access cost.
    { name = "lighthouse-geth", count = 2, cloud = "digitalocean", supernode = true, validator_start = 0, validator_end = 250 },
    { name = "lighthouse-nethermind", count = 2, cloud = "digitalocean", supernode = true, validator_start = 250, validator_end = 500 },
    { name = "lighthouse-reth", count = 2, cloud = "digitalocean", supernode = true, validator_start = 500, validator_end = 750 },
    { name = "lighthouse-ethrex", count = 2, cloud = "digitalocean", supernode = true, validator_start = 750, validator_end = 1000 },
    { name = "lighthouse-besu", count = 2, cloud = "digitalocean", supernode = true },
    # Nimbus EL joins as an observer while sync and frame transaction behavior are verified.
    { name = "lighthouse-nimbusel", count = 1, cloud = "digitalocean", supernode = true },
  ]

  validation {
    condition = alltrue([
      for n in var.nodes :
      try(n.validator_start, 0) >= 0 && try(n.validator_start, 0) <= try(n.validator_end, 0)
    ])
    error_message = "Each node must satisfy 0 <= validator_start <= validator_end. Omit both fields (or set both to 0) for nodes without validators."
  }

  validation {
    condition = alltrue(flatten([
      for i, a in var.nodes : [
        for j, b in var.nodes :
        i >= j ||
        try(a.validator_end, 0) == 0 ||
        try(b.validator_end, 0) == 0 ||
        try(a.validator_end, 0) <= try(b.validator_start, 0) ||
        try(b.validator_end, 0) <= try(a.validator_start, 0)
      ]
    ]))
    error_message = "Validator ranges overlap between nodes. Each [validator_start, validator_end) interval must be disjoint from every other node's interval."
  }
}

