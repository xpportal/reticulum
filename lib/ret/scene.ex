defmodule Ret.Scene.SceneSlug do
  use EctoAutoslugField.Slug, from: :name, to: :slug

  def get_sources(_changeset, _opts) do
    [:scene_sid, :name]
  end
end

defmodule Ret.Scene do
  use Ecto.Schema
  import Ecto.Query
  import Ecto.Changeset

  alias Ret.{Repo, Scene, SceneListing, Storage}
  alias Ret.Scene.{SceneSlug}

  @schema_prefix "ret0"
  @primary_key {:scene_id, :id, autogenerate: true}

  schema "scenes" do
    field(:scene_sid, :string)
    field(:slug, SceneSlug.Type)
    field(:name, :string)
    field(:description, :string)
    field(:attribution, :string)
    field(:attributions, :map)
    field(:allow_remixing, :boolean)
    field(:allow_promotion, :boolean)
    belongs_to(:account, Ret.Account, references: :account_id)
    belongs_to(:model_owned_file, Ret.OwnedFile, references: :owned_file_id)
    belongs_to(:screenshot_owned_file, Ret.OwnedFile, references: :owned_file_id)
    belongs_to(:scene_owned_file, Ret.OwnedFile, references: :owned_file_id)
    belongs_to(:remixed_from_scene, Ret.Scene, references: :scene_id)
    field(:state, Scene.State)

    timestamps()
  end

  def scene_or_scene_listing_by_sid(sid) do
    Scene |> Repo.get_by(scene_sid: sid) || SceneListing |> Repo.get_by(scene_listing_sid: sid) |> Repo.preload(:scene)
  end

  def scene_by_sid_for_account(scene_sid, account) do
    from(s in Scene,
      where: s.scene_sid == ^scene_sid and s.account_id == ^account.account_id,
      preload: [:account, :model_owned_file, :screenshot_owned_file, :scene_owned_file])
    |> Repo.one
  end

  def to_sid(%Scene{} = scene), do: scene.scene_sid
  def to_sid(%SceneListing{} = scene_listing), do: scene_listing.scene_listing_sid
  def to_url(%t{} = s) when t in [Scene, SceneListing], do: "#{RetWeb.Endpoint.url()}/scenes/#{s |> to_sid}/#{s.slug}"

  def publish(account, project, model_owned_file, screenshot_owned_file, params) do
    Repo.transaction(fn() ->
      with {:ok, project_owned_file} <- Storage.duplicate(account, project.project_owned_file),
           {:ok, scene} <- create_or_update(account, project.published_scene, model_owned_file, project_owned_file, screenshot_owned_file, params),
           {:ok, _} <- maybe_update_published_scene(project, scene) do
        scene
      else
        {:error, reason} -> Repo.rollback(reason)
        _ -> Repo.rollback(:internal_server_error)
      end
    end)
  end

  def maybe_update_published_scene(project, scene) do
    case project.published_scene do
      %Scene{} = _ -> {:ok, project}
      nil -> change(project) |> put_assoc(:published_scene, scene) |> Repo.update()
    end
  end

  def create_or_update(account, nil, model_owned_file, project_owned_file, screenshot_owned_file, params) do
    create_or_update(account, %Scene{}, model_owned_file, project_owned_file, screenshot_owned_file, params)
  end

  def create_or_update(account, scene, model_owned_file, project_owned_file, screenshot_owned_file, params) do
    with {:ok, updated_scene} <- scene |> Repo.preload([:account]) |> Scene.changeset(account, model_owned_file, screenshot_owned_file, project_owned_file, params) |> Repo.insert_or_update() do
      updated_scene = Repo.preload(updated_scene, [:model_owned_file, :screenshot_owned_file, :scene_owned_file])

      if scene.allow_promotion do
        Task.async(fn -> updated_scene |> Ret.Support.send_notification_of_new_scene() end)
      end

      {:ok, updated_scene}
    end
  end

  def changeset(
        %Scene{} = scene,
        account,
        model_owned_file,
        screenshot_owned_file,
        scene_owned_file,
        params \\ %{}
      ) do
    scene
    |> cast(params, [
      :name,
      :description,
      :attribution,
      :attributions,
      :allow_remixing,
      :allow_promotion,
      :state
    ])
    |> validate_required([
      :name
    ])
    |> validate_length(:name, min: 4, max: 64)
    # TODO BP: this is repeated from hub.ex. Maybe refactor the regex out.
    |> validate_format(:name, ~r/^[A-Za-z0-9-':"!@#$%^&*(),.?~ ]+$/)
    |> maybe_add_scene_sid_to_changeset
    |> unique_constraint(:scene_sid)
    |> put_assoc(:account, account)
    |> put_change(:model_owned_file_id, model_owned_file.owned_file_id)
    |> put_change(:screenshot_owned_file_id, screenshot_owned_file.owned_file_id)
    |> put_change(:scene_owned_file_id, scene_owned_file.owned_file_id)
    |> SceneSlug.maybe_generate_slug()
    |> SceneSlug.unique_constraint()
  end

  def changeset_to_mark_as_reviewed(%Scene{} = scene) do
    scene
    |> Ecto.Changeset.change()
    |> put_change(:reviewed_at, Timex.now())
  end

  defp maybe_add_scene_sid_to_changeset(changeset) do
    scene_sid = changeset |> get_field(:scene_sid) || Ret.Sids.generate_sid()
    put_change(changeset, :scene_sid, scene_sid)
  end
end
