defmodule RetWeb.ProjectsControllerTest do
  use RetWeb.ConnCase
  import Ret.TestHelpers

  alias Ret.{Project, Repo, Account}

  setup [:create_account, :create_owned_file, :create_project_owned_file, :create_thumbnail_owned_file, :create_project]

  setup do
    on_exit(fn ->
      clear_all_stored_files()
    end)
  end

  test "projects index 401's when not logged in", %{conn: conn} do
    conn |> get(api_v1_project_path(conn, :index)) |> response(401)
  end

  @tag :authenticated
  test "projects index works when logged in", %{conn: conn} do
    response = conn |> get(api_v1_project_path(conn, :index)) |> json_response(200)

    %{
      "projects" => [
        %{
          "thumbnail_url" => thumbnail_url,
          "project_url" => project_url,
          "project_id" => project_id,
          "name" => name
        }
      ]
    } = response

    assert name == "Test Scene"
    assert thumbnail_url != nil
    assert project_url != nil
    assert project_id != nil
  end

  test "projects show 401's when not logged in", %{conn: conn, project: project} do
    conn |> get(api_v1_project_path(conn, :show, project.project_sid)) |> response(401)
  end

  @tag :authenticated
  test "projects show works when logged in", %{conn: conn, project: project} do
    response = conn |> get(api_v1_project_path(conn, :show, project.project_sid)) |> json_response(200)

    %{
      "thumbnail_url" => thumbnail_url,
      "project_url" => project_url,
      "project_id" => project_id,
      "name" => name
    } = response

    assert name == "Test Scene"
    assert thumbnail_url != nil
    assert project_url != nil
    assert project_id != nil
  end

  test "projects create 401's when not logged in", %{conn: conn} do
    conn |> post(api_v1_project_path(conn, :create)) |> response(401)
  end

  @tag :authenticated
  test "projects create works when logged in", %{conn: conn} do
    params = %{ project: %{ name: "Test Project" } }
    response = conn |> post(api_v1_project_path(conn, :create, params)) |> json_response(200)

    %{
      "thumbnail_url" => thumbnail_url,
      "project_url" => project_url,
      "project_id" => project_id,
      "name" => name
    } = response

    assert name == "Test Project"
    assert thumbnail_url == nil
    assert project_url == nil
    assert project_id != nil
  end

  test "projects update 401's when not logged in", %{conn: conn, project: project, project_owned_file: project_owned_file, thumbnail_owned_file: thumbnail_owned_file} do
    params = %{
      project: %{
        name: "Test Project 2",
        thumbnail_file_id: thumbnail_owned_file.owned_file_uuid,
        thumbnail_file_token: thumbnail_owned_file.key,
        project_file_id: project_owned_file.owned_file_uuid,
        project_file_token: project_owned_file.key
      }
    }

    conn |> patch(api_v1_project_path(conn, :update, project.project_sid, params)) |> response(401)
  end

  @tag :authenticated
  test "projects update works when logged in", %{conn: conn, project: project, project_owned_file: project_owned_file, thumbnail_owned_file: thumbnail_owned_file} do
    params = %{
      project: %{
        name: "Test Project 2",
        thumbnail_file_id: thumbnail_owned_file.owned_file_uuid,
        thumbnail_file_token: thumbnail_owned_file.key,
        project_file_id: project_owned_file.owned_file_uuid,
        project_file_token: project_owned_file.key
      }
    }
    
    response = conn |> patch(api_v1_project_path(conn, :update, project.project_sid, params)) |> json_response(200)

    %{
      "thumbnail_url" => thumbnail_url,
      "project_url" => project_url,
      "project_id" => project_id,
      "name" => name
    } = response

    assert name == "Test Project 2"
    assert thumbnail_url != nil
    assert project_url != nil
    assert project_id != nil
  end

  test "projects delete 401's when not logged in", %{conn: conn, project: project} do
    conn |> delete(api_v1_project_path(conn, :delete, project.project_sid)) |> response(401)
  end

  @tag :authenticated
  test "projects delete works when logged in", %{conn: conn, project: project} do
    conn |> delete(api_v1_project_path(conn, :delete, project.project_sid)) |> response(200)

    deleted_project = Project |> Repo.get_by(project_sid: project.project_sid)

    assert deleted_project == nil
  end

  @tag :authenticated
  test "projects delete shows a 404 when the user does not own the project", %{conn: conn, project_owned_file: project_owned_file, thumbnail_owned_file: thumbnail_owned_file} do
    other_account = Account.account_for_email("test2@mozilla.com")

    {:ok, project} = %Project{}
      |> Project.changeset(other_account, project_owned_file, thumbnail_owned_file, %{
        name: "Test Scene"
      })
      |> Repo.insert_or_update()

    conn |> delete(api_v1_project_path(conn, :delete, project.project_sid)) |> response(404)

    deleted_project = Project |> Repo.get_by(project_sid: project.project_sid)

    assert deleted_project != nil
  end

  test "projects publish 401's when not logged in", %{conn: conn, project: project} do
    conn |> post(api_v1_project_publish_path(conn, :publish, project.project_sid)) |> response(401)
  end

  @tag :authenticated
  test "projects publish / republish works when logged in", %{conn: conn, project: project, owned_file: owned_file} do
    params1 =  %{
      "scene" => %{
        "name" => "Test Scene",
        "description" => "Test description",
        "model_file_id" => owned_file.owned_file_uuid,
        "model_file_token" => owned_file.key,
        "screenshot_file_id" => owned_file.owned_file_uuid,
        "screenshot_file_token" => owned_file.key,
        "allow_promotion" => true,
        "allow_remixing" => true
      }
    }

    # Test first publish
    response1 = conn |> post(api_v1_project_publish_path(conn, :publish, project.project_sid, params1)) |> json_response(200)

    %{
      "scenes" => [
        %{
          "allow_promotion" => allow_promotion1,
          "allow_remixing" => allow_remixing1,
          "attribution" => attribution1,
          "attributions" => attributions1,
          "description" => description1,
          "model_url" => model_url1,
          "name" => name1,
          "scene_id" => scene_id1,
          "screenshot_url" => screenshot_url1,
          "url" => url1
        }
      ]
    } = response1

    assert allow_promotion1 == true
    assert allow_remixing1 == true
    assert attribution1 == nil
    assert attributions1 == nil
    assert description1 == "Test description"
    assert model_url1 != nil
    assert name1 == "Test Scene"
    assert scene_id1 != nil
    assert screenshot_url1 != nil
    assert url1 != nil

    params2 =  %{
      "scene" => %{
        "name" => "Test Scene 2",
        "description" => "Test description 2",
        "model_file_id" => owned_file.owned_file_uuid,
        "model_file_token" => owned_file.key,
        "screenshot_file_id" => owned_file.owned_file_uuid,
        "screenshot_file_token" => owned_file.key,
        "allow_promotion" => false,
        "allow_remixing" => false
      }
    }

    # Test republish
    response2 = conn |> post(api_v1_project_publish_path(conn, :publish, project.project_sid, params2)) |> json_response(200)

    %{
      "scenes" => [
        %{
          "allow_promotion" => allow_promotion2,
          "allow_remixing" => allow_remixing2,
          "attribution" => attribution2,
          "attributions" => attributions2,
          "description" => description2,
          "model_url" => model_url2,
          "name" => name2,
          "scene_id" => scene_id2,
          "screenshot_url" => screenshot_url2,
          "url" => url2
        }
      ]
    } = response2

    assert allow_promotion2 == false
    assert allow_remixing2 == false
    assert attribution2 == nil
    assert attributions2 == nil
    assert description2 == "Test description 2"
    assert model_url2 != nil
    assert name2 == "Test Scene 2"
    assert scene_id2 == scene_id1
    assert screenshot_url2 != nil
    assert url2 == url1
  end
end
