defmodule RetWeb.Api.V1.SceneController do
  use RetWeb, :controller

  alias Ret.{Repo, Scene, SceneListing, Project, Storage}

  plug(RetWeb.Plugs.RateLimit when action in [:create, :update])

  def show(conn, %{"id" => scene_sid}) do
    case scene_sid |> get_scene_or_scene_listing() do
      %t{} = s when t in [Scene, SceneListing] -> conn |> render("show.json", scene: s)
      _ -> conn |> send_resp(404, "not found")
    end
  end

  defp get_scene_or_scene_listing(scene_sid) do
    scene_sid
    |> Scene.scene_or_scene_listing_by_sid()
    |> Repo.preload([:account, :model_owned_file, :screenshot_owned_file, :scene_owned_file])
  end

  def update(conn, %{"id" => scene_sid, "scene" => params}) do
    account = conn |> Guardian.Plug.current_resource()

    case Scene.scene_by_sid_for_account(scene_sid, account) do
      %Scene{} = scene -> create_or_update(conn, account, params, scene)
      _ -> conn |> send_resp(404, "not found")
    end
  end

  def create(conn, %{"scene" => params}) do
    account = conn |> Guardian.Plug.current_resource()

    create_or_update(conn, account, params)
  end

  defp create_or_update(conn, account, params, scene \\ %Scene{}) do
    # Legacy
    params = params |> Map.put_new("attributions", %{"extras" => params["attribution"]})

    promotion_params = %{
      model: {params["model_file_id"], params["model_file_token"]},
      screenshot: {params["screenshot_file_id"], params["screenshot_file_token"]},
      scene: {params["scene_file_id"], params["scene_file_token"]}
    }

    with %{model: {:ok, model_file}, screenshot: {:ok, screenshot_file}, scene: {:ok, scene_file}} <- Storage.promote(promotion_params, account),
         {:ok, scene} <- Scene.create_or_update(account, scene, model_file, scene_file, screenshot_file, params) do
      render(conn, "create.json", scene: scene)
    else
      {:error, error} -> render_error_json(conn, error)
    end
  end

  def remix(conn, %{"scene_id" => scene_sid}) do
    account = Guardian.Plug.current_resource(conn)

    with %Scene{} = scene <- get_scene(scene_sid),
         true <- scene.allow_remixing,
         {:ok, project} <- Project.remix_scene(account, scene) do
      conn
      |> put_view(RetWeb.Api.V1.ProjectView)
      |> render("show.json", project: project)
    else
      nil -> render_error_json(conn, :not_found)
      false -> render_error_json(conn, :unauthorized)
      {:error, error} -> render_error_json(conn, error)
    end
  end

  defp get_scene(scene_sid) do
    Repo.get_by(Scene, scene_sid: scene_sid) |> Repo.preload([:account, :model_owned_file, :screenshot_owned_file, :scene_owned_file])
  end
end
