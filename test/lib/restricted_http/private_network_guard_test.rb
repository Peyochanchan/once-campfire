require "test_helper"
require "restricted_http/private_network_guard"

class RestrictedHTTP::PrivateNetworkGuardTest < ActiveSupport::TestCase
  test "private_ip? returns true for 'This' network (RFC1700)" do
    assert_private_ip "0.0.0.0"
    assert_private_ip "0.255.255.255"
  end

  test "private_ip? returns true for loopback addresses" do
    assert_private_ip "127.0.0.0"
    assert_private_ip "127.0.0.1"
    assert_private_ip "127.255.255.255"
  end

  test "private_ip? returns true for RFC1918 private addresses" do
    assert_private_ip "10.0.0.0"
    assert_private_ip "10.255.255.255"
    assert_private_ip "172.16.0.0"
    assert_private_ip "172.31.255.255"
    assert_private_ip "192.168.0.0"
    assert_private_ip "192.168.255.255"
  end

  test "private_ip? returns true for link-local addresses" do
    assert_private_ip "169.254.0.1"
    assert_private_ip "169.254.169.254"  # AWS IMDS
    assert_private_ip "169.254.255.255"
  end

  test "private_ip? returns true for CGNAT addresses (RFC6598)" do
    assert_private_ip "100.64.0.0"
    assert_private_ip "100.125.35.222"  # NetBird overlay
    assert_private_ip "100.127.255.255"
  end

  test "private_ip? returns true for documentation / test-net ranges (RFC5737)" do
    assert_private_ip "192.0.2.1"        # TEST-NET-1
    assert_private_ip "198.51.100.42"    # TEST-NET-2
    assert_private_ip "203.0.113.7"      # TEST-NET-3
  end

  test "private_ip? returns true for benchmark range (RFC2544)" do
    assert_private_ip "198.18.0.1"
    assert_private_ip "198.19.255.255"
  end

  test "private_ip? returns true for multicast addresses" do
    assert_private_ip "224.0.0.1"
    assert_private_ip "239.255.255.255"
  end

  test "private_ip? returns true for IPv6 multicast and documentation" do
    assert_private_ip "ff02::1"          # link-scope all nodes
    assert_private_ip "2001:db8::1"      # IPv6 documentation
  end

  test "private_ip? returns false for public addresses" do
    assert_not RestrictedHTTP::PrivateNetworkGuard.private_ip?("93.184.216.34")
    assert_not RestrictedHTTP::PrivateNetworkGuard.private_ip?("8.8.8.8")
  end

  # IPv6 address format tests (SSRF bypass prevention)

  test "private_ip? returns true for IPv4-mapped IPv6 addresses with private IPs" do
    assert_private_ip "::ffff:192.168.1.1"
    assert_private_ip "::ffff:10.0.0.1"
    assert_private_ip "::ffff:172.16.0.1"
  end

  test "private_ip? returns true for IPv4-mapped IPv6 addresses with link-local IPs" do
    assert_private_ip "::ffff:169.254.169.254"  # AWS metadata via mapped format
  end

  test "private_ip? returns true for IPv4-mapped IPv6 addresses even with public IPs" do
    # Block all ipv4_mapped? since DNS never returns this format legitimately
    assert_private_ip "::ffff:93.184.216.34"
  end

  test "private_ip? returns true for IPv4-compatible IPv6 addresses with private IPs" do
    assert_private_ip "::192.168.1.1"
    assert_private_ip "::10.0.0.1"
  end

  test "private_ip? returns true for IPv4-compatible IPv6 addresses with link-local IPs" do
    assert_private_ip "::169.254.169.254"  # AWS metadata via compat format - the reported bypass
  end

  test "private_ip? returns true for IPv4-compatible IPv6 addresses even with public IPs" do
    # Block all ipv4_compat? since DNS never returns this format legitimately
    assert_private_ip "::93.184.216.34"
  end

  test "private_ip? returns true for invalid addresses" do
    assert RestrictedHTTP::PrivateNetworkGuard.private_ip?("not-an-ip")
    assert RestrictedHTTP::PrivateNetworkGuard.private_ip?("")
  end

  test "resolve raises Violation for private hostname" do
    Resolv.stubs(:getaddresses).returns([ "192.168.1.1" ])
    assert_raises RestrictedHTTP::Violation do
      RestrictedHTTP::PrivateNetworkGuard.resolve("private.example.com")
    end
  end

  test "resolve returns IP for public hostname" do
    Resolv.stubs(:getaddresses).returns([ "93.184.216.34" ])
    assert_equal "93.184.216.34", RestrictedHTTP::PrivateNetworkGuard.resolve("example.com")
  end

  test "resolve raises Violation if ANY resolved address is private (DNS rebinding defence)" do
    Resolv.stubs(:getaddresses).returns([ "93.184.216.34", "10.0.0.1" ])
    assert_raises RestrictedHTTP::Violation do
      RestrictedHTTP::PrivateNetworkGuard.resolve("multi.example.com")
    end
  end

  test "resolve raises Violation for empty DNS answer" do
    Resolv.stubs(:getaddresses).returns([])
    assert_raises RestrictedHTTP::Violation do
      RestrictedHTTP::PrivateNetworkGuard.resolve("nx.example.com")
    end
  end

  test "resolve raises Violation for blocked hostnames before any DNS lookup" do
    %w[localhost LOCALHOST app.internal node.consul x.local something.netbird.selfhosted].each do |host|
      assert_raises RestrictedHTTP::Violation, "expected #{host} to be blocked" do
        RestrictedHTTP::PrivateNetworkGuard.resolve(host)
      end
    end
  end

  private
    def assert_private_ip(address)
      assert RestrictedHTTP::PrivateNetworkGuard.private_ip?(address),
        "Expected #{address} to be classified as private"
    end
end
