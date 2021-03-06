defmodule Data.Repo.Migrations.CreateSkills do
  use Ecto.Migration

  def change do
    create table(:skills) do
      add(:description, :text)
      add(:achievements, {:array, :text})
      add :index, :integer, null: false, default: 1

      add(
        :resume_id,
        references(:resumes, on_delete: :delete_all),
        null: false,
        comment: "The resume"
      )
    end

    :skills
    |> index([:resume_id])
    |> create()
  end
end
