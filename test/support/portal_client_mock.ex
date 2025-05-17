defmodule WorkOS.Portal.ClientMock do
  @moduledoc false

  import ExUnit.Assertions, only: [assert: 1]

  def generate_link(context, opts \\ []) do
    fn request ->
      %{api_key: api_key} = context

      assert request.method == :post
      assert request.url == "#{WorkOS.base_url()}/portal/generate_link"

      assert Enum.find(request.headers, &(elem(&1, 0) == "Authorization")) ==
               {"Authorization", "Bearer #{api_key}"}

      body = Jason.decode!(request.body)

      for {field, value} <-
            Keyword.get(opts, :assert_fields, []) do
        assert body[to_string(field)] == value
      end

      success_body = %{
        "link" => "https://id.workos.com/portal/launch?secret=secret"
      }

      {status, body} = Keyword.get(opts, :respond_with, {200, success_body})
      %Tesla.Env{status: status, body: body}
    end
  end
end
