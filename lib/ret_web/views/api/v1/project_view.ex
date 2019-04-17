defmodule RetWeb.Api.V1.ProjectView do
  use RetWeb, :view
  alias Ret.{OwnedFile, Scene}

  defp url_for_file(%OwnedFile{} = f), do: f |> OwnedFile.uri_for() |> URI.to_string()
  defp url_for_file(_), do: nil

  defp get_scene_sid(%Scene{} = scene), do: scene.scene_sid
  defp get_scene_sid(_), do: nil

  defp render_project(project) do
    %{
      project_id: project.project_sid,
      name: project.name,
      project_url: url_for_file(project.project_owned_file),
      thumbnail_url: url_for_file(project.thumbnail_owned_file),
      remixed_from_scene_id: get_scene_sid(project.remixed_from_scene),
      published_scene_id: get_scene_sid(project.published_scene)
    }
  end

  def render("index.json", %{projects: projects}) do
    %{
      projects: Enum.map(projects, fn p -> render_project(p) end)
    }
  end

  def render("show.json", %{project: project}) do
    Map.merge(
      %{ status: :ok },
      render_project(project)
    )
  end
end
