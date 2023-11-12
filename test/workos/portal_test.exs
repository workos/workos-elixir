defmodule WorkOS.PortalTest do
  use WorkOS.TestCase

  alias WorkOS.Portal.ClientMock

  setup :setup_env

  describe "generate_link" do
    test "with invalid intent, raises an error", context do
      opts = [
        intent: "invalid"
      ]

      context |> ClientMock.generate_link(assert_fields: opts)

      assert_raise ArgumentError, fn ->
        WorkOS.Portal.generate_link(opts |> Enum.into(%{}))
      end
    end

    test "with a valid intent and without an organization, raises an error", context do
      opts = [
        intent: "sso"
      ]

      context |> ClientMock.generate_link(assert_fields: opts)

      assert_raise ArgumentError, fn ->
        WorkOS.Portal.generate_link(opts |> Enum.into(%{}))
      end
    end

    test "with a audit_logs intent, returns portal link", context do
      opts = [
        intent: "audit_logs",
        organization: "org_01EHQMYV6MBK39QC5PZXHY59C3"
      ]

      context |> ClientMock.generate_link(assert_fields: opts)

      assert {:ok, %WorkOS.Portal.Link{link: link}} =
               WorkOS.Portal.generate_link(opts |> Enum.into(%{}))

      refute is_nil(link)
    end

    test "with a domain_verification intent, returns portal link", context do
      opts = [
        intent: "domain_verification",
        organization: "org_01EHQMYV6MBK39QC5PZXHY59C3"
      ]

      context |> ClientMock.generate_link(assert_fields: opts)

      assert {:ok, %WorkOS.Portal.Link{link: link}} =
               WorkOS.Portal.generate_link(opts |> Enum.into(%{}))

      refute is_nil(link)
    end

    test "with a dsync intent, returns portal link", context do
      opts = [
        intent: "dsync",
        organization: "org_01EHQMYV6MBK39QC5PZXHY59C3"
      ]

      context |> ClientMock.generate_link(assert_fields: opts)

      assert {:ok, %WorkOS.Portal.Link{link: link}} =
               WorkOS.Portal.generate_link(opts |> Enum.into(%{}))

      refute is_nil(link)
    end

    test "with a log_streams intent, returns portal link", context do
      opts = [
        intent: "log_streams",
        organization: "org_01EHQMYV6MBK39QC5PZXHY59C3"
      ]

      context |> ClientMock.generate_link(assert_fields: opts)

      assert {:ok, %WorkOS.Portal.Link{link: link}} =
               WorkOS.Portal.generate_link(opts |> Enum.into(%{}))

      refute is_nil(link)
    end

    test "with a sso intent, returns portal link", context do
      opts = [
        intent: "sso",
        organization: "org_01EHQMYV6MBK39QC5PZXHY59C3"
      ]

      context |> ClientMock.generate_link(assert_fields: opts)

      assert {:ok, %WorkOS.Portal.Link{link: link}} =
               WorkOS.Portal.generate_link(opts |> Enum.into(%{}))

      refute is_nil(link)
    end
  end
end
