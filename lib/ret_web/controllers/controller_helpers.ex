defmodule RetWeb.ControllerHelpers do
  import Plug.Conn
  import Phoenix.Controller
  import RetWeb.ErrorHelpers

  def render_error_json(conn, status, params) do
    conn |> put_status(status) |> put_layout(false) |> render(RetWeb.ErrorView, "error.json", %{ error: params })
  end

  def render_error_json(conn, %Ecto.Changeset{} = changeset) do
    errors = Ecto.Changeset.traverse_errors(changeset, &translate_error/1)
    render_error_json(conn, 422, errors)
  end

  def render_error_json(conn, status) do
    status = convert_status(status)
    code = Plug.Conn.Status.code(status)
    reason = Plug.Conn.Status.reason_phrase(code)
    render_error_json(conn, status, reason)
  end

  defp convert_status(status) do
    case status do
      :not_allowed -> :unauthorized # Used in Storage
      _ -> status
    end
  end
end