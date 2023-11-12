defmodule WorkOS.DirectorySync.Directory.User do
  @moduledoc """
  WorkOS Directory User struct.
  """

  @behaviour WorkOS.Castable

  @type t() :: %__MODULE__{
          id: String.t(),
          directory_id: String.t(),
          organization_id: String.t() | nil,
          raw_attributes: %{String.t() => any()},
          custom_attributes: %{String.t() => any()},
          idp_id: String.t(),
          first_name: String.t(),
          emails: [%{type: String.t(), value: String.t(), primary: boolean()}],
          username: String.t(),
          last_name: String.t(),
          job_title: String.t() | nil,
          state: String.t(),
          updated_at: DateTime.t(),
          created_at: DateTime.t()
        }

  @enforce_keys [
    :id,
    :directory_id,
    :raw_attributes,
    :custom_attributes,
    :idp_id,
    :first_name,
    :emails,
    :username,
    :last_name,
    :state,
    :updated_at,
    :created_at
  ]
  defstruct [
    :id,
    :directory_id,
    :organization_id,
    :raw_attributes,
    :custom_attributes,
    :idp_id,
    :first_name,
    :emails,
    :username,
    :last_name,
    :job_title,
    :state,
    :updated_at,
    :created_at
  ]

  @impl true
  def cast(map) do
    %__MODULE__{
      id: map["id"],
      organization_id: map["organization_id"],
      raw_attributes: map["raw_attributes"],
      custom_attributes: map["custom_attributes"],
      directory_id: map["directory_id"],
      idp_id: map["idp_id"],
      first_name: map["first_name"],
      emails: map["emails"],
      username: map["username"],
      last_name: map["last_name"],
      job_title: map["job_title"],
      state: map["state"],
      updated_at: map["created_at"],
      created_at: map["created_at"]
    }
  end
end
