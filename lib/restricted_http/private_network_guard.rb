require "resolv"
require "ipaddr"

module RestrictedHTTP
  class Violation < StandardError; end

  module PrivateNetworkGuard
    extend self

    # IANA-reserved / never-routable / specifically-dangerous ranges that
    # complement IPAddr#private?/loopback?/link_local? (which only cover
    # RFC1918 + 127.0.0.0/8 + 169.254.0.0/16 + IPv6 equivalents).
    EXTRA_BLOCKED_RANGES = [
      IPAddr.new("0.0.0.0/8"),            # "This" network (RFC1122)
      IPAddr.new("100.64.0.0/10"),        # CGNAT (RFC6598) — used by NetBird etc.
      IPAddr.new("192.0.0.0/24"),         # IETF protocol assignments
      IPAddr.new("192.0.2.0/24"),         # TEST-NET-1 (RFC5737)
      IPAddr.new("192.88.99.0/24"),       # 6to4 relay anycast (deprecated)
      IPAddr.new("198.18.0.0/15"),        # Benchmark (RFC2544)
      IPAddr.new("198.51.100.0/24"),      # TEST-NET-2 (RFC5737)
      IPAddr.new("203.0.113.0/24"),       # TEST-NET-3 (RFC5737)
      IPAddr.new("224.0.0.0/4"),          # IPv4 multicast
      IPAddr.new("240.0.0.0/4"),          # IPv4 reserved for future use
      IPAddr.new("255.255.255.255/32"),   # Limited broadcast
      IPAddr.new("64:ff9b::/96"),         # NAT64 well-known prefix
      IPAddr.new("100::/64"),             # IPv6 discard
      IPAddr.new("2001:db8::/32"),        # IPv6 documentation
      IPAddr.new("ff00::/8")              # IPv6 multicast
    ].freeze

    # Hostnames that should never reach DNS resolution — either explicitly
    # blocked or RFC-reserved special-use TLDs likely to resolve to internal
    # services on misconfigured networks.
    BLOCKED_HOSTNAMES = %w[
      localhost
      ip6-localhost
      ip6-loopback
    ].to_set.freeze

    BLOCKED_HOSTNAME_SUFFIXES = %w[
      .localhost
      .internal
      .local
      .consul
      .docker
      .invalid
      .test
      .example
      .arpa
      .netbird.selfhosted
    ].freeze

    # Resolve a hostname to a single IP, raising Violation if the hostname
    # itself is blocked, or if ANY of the resolved A/AAAA records points to
    # a private/reserved range (prevents DNS rebinding via multi-answer round
    # robin where one of the IPs is private).
    def resolve(hostname)
      raise Violation.new("Blocked hostname: #{hostname.inspect}") if blocked_hostname?(hostname)
      addresses = Resolv.getaddresses(hostname.to_s)
      raise Violation.new("Cannot resolve hostname: #{hostname.inspect}") if addresses.empty?
      addresses.each do |ip|
        raise Violation.new("Attempt to access private IP #{ip} via #{hostname}") if private_ip?(ip)
      end
      addresses.first
    end

    def private_ip?(ip)
      ipaddr = IPAddr.new(ip.to_s)
      return true if ipaddr.private?
      return true if ipaddr.loopback?
      return true if ipaddr.link_local?
      return true if ipaddr.ipv4_mapped? || ipaddr.ipv4_compat?
      EXTRA_BLOCKED_RANGES.any? { |range| range.include?(ipaddr) }
    rescue IPAddr::InvalidAddressError
      true
    end

    private
      def blocked_hostname?(hostname)
        return true if hostname.blank?
        normalized = hostname.to_s.downcase.strip
        return true if BLOCKED_HOSTNAMES.include?(normalized)
        BLOCKED_HOSTNAME_SUFFIXES.any? { |suffix| normalized.end_with?(suffix) }
      end
  end
end
