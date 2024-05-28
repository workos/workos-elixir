defmodule WorkOS.DirectorySync.Directory.User do
  @moduledoc """
  WorkOS Directory User struct.
  """

  @behaviour WorkOS.Castable

  @type t() :: %__MODULE__{
          id: String.t(),
          object: String.t(),
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
          groups: [%WorkOS.DirectorySync.Directory.Group{}],
          updated_at: String.t(),
          created_at: String.t()
        }

  @enforce_keys [
    :id,
    :object,
    :directory_id,
    :raw_attributes,
    :custom_attributes,
    :idp_id,
    :emails,
    :username,
    :first_name,
    :last_name,
    :groups,
    :state,
    :updated_at,
    :created_at
  ]
  defstruct [
    :id,
    :object,
    :directory_id,
    :organization_id,
    :raw_attributes,
    :custom_attributes,
    :idp_id,
    :emails,
    :username,
    :first_name,
    :last_name,
    :job_title,
    :groups,
    :state,
    :updated_at,
    :created_at
  ]

  @impl true
  def cast(map) do
    %__MODULE__{
      id: map["id"],
      object: map["object"],
      organization_id: map["organization_id"],
      raw_attributes: map["raw_attributes"],
      custom_attributes: map["custom_attributes"],
      directory_id: map["directory_id"],
      idp_id: map["idp_id"],
      emails: map["emails"],
      username: map["username"],
      first_name: map["first_name"],
      last_name: map["last_name"],
      job_title: map["job_title"],
      groups: WorkOS.Castable.cast_list(WorkOS.DirectorySync.Directory.Group, map["groups"]),
      state: map["state"],
      updated_at: map["updated_at"],
      created_at: map["created_at"]
    }
  end
end
