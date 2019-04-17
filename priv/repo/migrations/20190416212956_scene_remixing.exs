defmodule Ret.Repo.Migrations.SceneRemixing do
  use Ecto.Migration

  def change do
    alter table("projects") do
      add(:remixed_from_scene_id, references(:scenes, column: :scene_id), null: true)
      add(:published_scene_id, references(:scenes, column: :scene_id), null: true)
    end

    alter table("scenes") do
      add(:remixed_from_scene_id, references(:scenes, column: :scene_id), null: true)
    end
  end
end
