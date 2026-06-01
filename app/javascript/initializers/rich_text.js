import { installUnfurler } from "../lib/rich_text/unfurl/unfurler"

// Support a `cite` block for attribution links
Trix.config.blockAttributes.cite = {
  tagName: "cite",
  inheritable: false,
}

installUnfurler()
