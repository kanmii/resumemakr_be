defmodule Data.Resumes do
  @moduledoc """
  The Resume context.
  """

  import Ecto.Query, warn: false
  alias Data.Repo
  alias Ecto.Changeset
  alias Ecto.Multi
  alias Data.Resumes.PersonalInfo
  alias Data.Resumes.Resume
  alias Data.Resumes.Experience
  alias Data.Resumes.Education

  @doc """
  Returns the list of resumes for a user.

  ## Examples

      iex> list_resumes(12345)
      [%Resume{}, ...]

  """

  def list_resumes(user_id) do
    Resume
    |> where([r], r.user_id == ^user_id)
    |> Repo.all()
  end

  @spec list_resumes(any(), %{
          after: nil | integer(),
          before: nil | integer(),
          first: nil | integer(),
          last: nil | integer()
        }) ::
          {:error, <<_::64, _::_*8>>}
          | {:ok,
             %{
               edges: [map()],
               page_info: %{
                 end_cursor: binary(),
                 has_next_page: boolean(),
                 has_previous_page: boolean(),
                 start_cursor: binary()
               }
             }}
  def list_resumes(user_id, pagination_args) do
    Resume
    |> where([r], r.user_id == ^user_id)
    |> Absinthe.Relay.Connection.from_query(&Repo.all/1, pagination_args)
  end

  @doc """
  Gets a single Resume.

  Raises `Ecto.NoResultsError` if the Resume does not exist.

  ## Examples

      iex> get_resume!(123)
      %Resume{}

      iex> get_resume!(456)
      ** (Ecto.NoResultsError)

  """
  def get_resume(id), do: Repo.get(Resume, id)

  def get_resume_by(attrs) do
    Repo.get_by(Resume, attrs)
  end

  @doc """
  Creates a Resume.

  ## Examples

      iex> create_resume_full(%{field: value})
      {:ok, %Resume{}}

      iex> create_resume_full(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_resume(attrs) do
    Ecto.Multi.new()
    |> Multi.run(
      :resume,
      __MODULE__,
      :insert_resume,
      [Map.take(attrs, Resume.my_fields())]
    )
    |> Multi.run(
      :personal_info,
      __MODULE__,
      :insert_personal_info,
      [Map.get(attrs, :personal_info)]
    )
    |> insert_experiences(Map.get(attrs, :experiences))
    |> insert_education(Map.get(attrs, :education))
    |> Repo.transaction()
    |> case do
      {:ok,
       %{
         resume: resume
       } = successes} ->
        {:ok, unwrap_trxn(successes) |> Map.merge(resume)}

      {:error, failed_operations, changeset, _successes} ->
        {:error, failed_operations, changeset}
    end
  end

  @doc false
  def insert_resume(_repo, _changes, %{} = attrs) do
    changes = Resume.changeset(%Resume{}, attrs)

    case changes.valid? do
      true ->
        %{changes: %{title: title, user_id: user_id}} = changes

        changes_with_uniqie_title =
          case get_resume_by(title: title, user_id: user_id) do
            nil ->
              changes

            _ ->
              # title already exists, so we append current time to make it unique

              Changeset.put_change(
                changes,
                :title,
                "#{title}_#{System.os_time(:seconds)}"
              )
          end

        Repo.insert(changes_with_uniqie_title)

      _ ->
        {:error, Changeset.apply_action(changes, :insert)}
    end
  end

  @doc false
  def insert_personal_info(_, _changes, nil), do: {:ok, nil}

  @doc false
  def insert_personal_info(_, %{resume: resume}, attrs) do
    resume
    |> Ecto.build_assoc(:personal_info)
    |> PersonalInfo.changeset(attrs)
    |> Repo.insert()
  end

  defp insert_experiences(multi, nil), do: multi

  defp insert_experiences(multi, attrs) when is_list(attrs) do
    Multi.merge(multi, fn %{resume: resume} ->
      attrs
      |> Enum.map(&Ecto.build_assoc(resume, :experiences, &1))
      |> Enum.with_index(1)
      |> Enum.reduce(Multi.new(), fn {changeset, index}, multi_ ->
        Multi.run(multi_, {:experience, index}, fn _repo, _changes ->
          Repo.insert(changeset)
        end)
      end)
    end)
  end

  defp insert_education(multi, nil), do: multi

  defp insert_education(multi, attrs) when is_list(attrs) do
    Multi.merge(multi, fn %{resume: resume} ->
      attrs
      |> Enum.map(&Ecto.build_assoc(resume, :education, &1))
      |> Enum.with_index(1)
      |> Enum.reduce(Multi.new(), fn {changeset, index}, multi_ ->
        Multi.run(multi_, {:education, index}, fn _repo, _changes ->
          Repo.insert(changeset)
        end)
      end)
    end)
  end

  defp unwrap_trxn(trxn) do
    {experiences, education} =
      Enum.reduce(
        trxn,
        {[], []},
        &unwrap_trxn/2
      )

    %Resume{}
    |> unwrap_trxn(:experiences, experiences)
    |> unwrap_trxn(:education, education)
    |> unwrap_trxn(:personal_info, trxn.personal_info)
  end

  defp unwrap_trxn({{:experience, _}, val}, {a, b}) do
    {[val | a], b}
  end

  defp unwrap_trxn({{:education, _}, val}, {a, b}) do
    {a, [val | b]}
  end

  defp unwrap_trxn(_, acc) do
    acc
  end

  defp unwrap_trxn(acc, _key, []), do: acc
  defp unwrap_trxn(acc, _key, nil), do: acc
  defp unwrap_trxn(acc, key, values), do: Map.put(acc, key, values)

  ########################## RESUME ONLY #####################################

  @doc """
  Updates a Resume.

  ## Examples

      iex> update_resume(Resume, %{field: new_value})
      {:ok, %Resume{}}

      iex> update_resume(Resume, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_resume(%Resume{} = resume, attrs) do
    resume
    |> Resume.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a Resume.

  ## Examples

      iex> delete_resume(Resume)
      {:ok, %Resume{}}

      iex> delete_resume(Resume)
      {:error, %Ecto.Changeset{}}

  """
  def delete_resume(%Resume{} = resume) do
    Repo.delete(resume)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking Resume changes.

  ## Examples

      iex> change_resume(Resume)
      %Ecto.Changeset{source: %Resume{}}

  """
  def change_resume(%Resume{} = resume) do
    Resume.changeset(resume, %{})
  end

  @doc """
  Returns the list of personal_info.

  ## Examples

      iex> list_personal_info()
      [%PersonalInfo{}, ...]

  """
  def list_personal_info do
    Repo.all(PersonalInfo)
  end

  @doc """
  Gets a single personal_info.

  Raises `Ecto.NoResultsError` if the Personal info does not exist.

  ## Examples

      iex> get_personal_info!(123)
      %PersonalInfo{}

      iex> get_personal_info!(456)
      ** (Ecto.NoResultsError)

  """
  def get_personal_info!(id), do: Repo.get!(PersonalInfo, id)

  @doc """
  Updates a personal_info.

  ## Examples

      iex> update_personal_info(personal_info, %{field: new_value})
      {:ok, %PersonalInfo{}}

      iex> update_personal_info(personal_info, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_personal_info(%PersonalInfo{} = personal_info, attrs) do
    personal_info
    |> PersonalInfo.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a PersonalInfo.

  ## Examples

      iex> delete_personal_info(personal_info)
      {:ok, %PersonalInfo{}}

      iex> delete_personal_info(personal_info)
      {:error, %Ecto.Changeset{}}

  """
  def delete_personal_info(%PersonalInfo{} = personal_info) do
    Repo.delete(personal_info)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking personal_info changes.

  ## Examples

      iex> change_personal_info(personal_info)
      %Ecto.Changeset{source: %PersonalInfo{}}

  """
  def change_personal_info(%PersonalInfo{} = personal_info) do
    PersonalInfo.changeset(personal_info, %{})
  end

  @doc """
  Returns the list of experiences.

  ## Examples

      iex> list_experiences()
      [%Experience{}, ...]

  """
  def list_experiences do
    Repo.all(Experience)
  end

  @doc """
  Gets a single experience.

  Raises `Ecto.NoResultsError` if the Experience does not exist.

  ## Examples

      iex> get_experience!(123)
      %Experience{}

      iex> get_experience!(456)
      ** (Ecto.NoResultsError)

  """
  def get_experience!(id), do: Repo.get!(Experience, id)

  @doc """
  Updates a experience.

  ## Examples

      iex> update_experience(experience, %{field: new_value})
      {:ok, %Experience{}}

      iex> update_experience(experience, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_experience(%Experience{} = experience, attrs) do
    experience
    |> Experience.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a Experience.

  ## Examples

      iex> delete_experience(experience)
      {:ok, %Experience{}}

      iex> delete_experience(experience)
      {:error, %Ecto.Changeset{}}

  """
  def delete_experience(%Experience{} = experience) do
    Repo.delete(experience)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking experience changes.

  ## Examples

      iex> change_experience(experience)
      %Ecto.Changeset{source: %Experience{}}

  """
  def change_experience(%Experience{} = experience) do
    Experience.changeset(experience, %{})
  end

  ################################# EDUCATION #################################

  @doc """
  Returns the list of education.

  ## Examples

      iex> list_education()
      [%Education{}, ...]

  """
  def list_education do
    Repo.all(Education)
  end

  @doc """
  Gets a single education.

  Raises `Ecto.NoResultsError` if the Education does not exist.

  ## Examples

      iex> get_education!(123)
      %Education{}

      iex> get_education!(456)
      ** (Ecto.NoResultsError)

  """
  def get_education!(id), do: Repo.get!(Education, id)

  @doc """
  Creates a education.

  ## Examples

      iex> create_education(%{field: value})
      {:ok, %Education{}}

      iex> create_education(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_education(attrs \\ %{}) do
    %Education{}
    |> Education.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a education.

  ## Examples

      iex> update_education(education, %{field: new_value})
      {:ok, %Education{}}

      iex> update_education(education, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_education(%Education{} = education, attrs) do
    education
    |> Education.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a Education.

  ## Examples

      iex> delete_education(education)
      {:ok, %Education{}}

      iex> delete_education(education)
      {:error, %Ecto.Changeset{}}

  """
  def delete_education(%Education{} = education) do
    Repo.delete(education)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking education changes.

  ## Examples

      iex> change_education(education)
      %Ecto.Changeset{source: %Education{}}

  """
  def change_education(%Education{} = education) do
    Education.changeset(education, %{})
  end

  alias Data.Resumes.Skill

  @doc """
  Returns the list of skills.

  ## Examples

      iex> list_skills()
      [%Skill{}, ...]

  """
  def list_skills do
    Repo.all(Skill)
  end

  @doc """
  Gets a single skill.

  Raises `Ecto.NoResultsError` if the Skill does not exist.

  ## Examples

      iex> get_skill!(123)
      %Skill{}

      iex> get_skill!(456)
      ** (Ecto.NoResultsError)

  """
  def get_skill!(id), do: Repo.get!(Skill, id)

  @doc """
  Creates a skill.

  ## Examples

      iex> create_skill(%{field: value})
      {:ok, %Skill{}}

      iex> create_skill(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_skill(attrs \\ %{}) do
    %Skill{}
    |> Skill.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a skill.

  ## Examples

      iex> update_skill(skill, %{field: new_value})
      {:ok, %Skill{}}

      iex> update_skill(skill, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_skill(%Skill{} = skill, attrs) do
    skill
    |> Skill.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a Skill.

  ## Examples

      iex> delete_skill(skill)
      {:ok, %Skill{}}

      iex> delete_skill(skill)
      {:error, %Ecto.Changeset{}}

  """
  def delete_skill(%Skill{} = skill) do
    Repo.delete(skill)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking skill changes.

  ## Examples

      iex> change_skill(skill)
      %Ecto.Changeset{source: %Skill{}}

  """
  def change_skill(%Skill{} = skill) do
    Skill.changeset(skill, %{})
  end
end