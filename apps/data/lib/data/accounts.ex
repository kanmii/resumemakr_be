defmodule Data.Accounts do
  import Ecto.Query, warn: false
  import Comeonin.Bcrypt, only: [{:dummy_checkpw, 0}, {:checkpw, 2}]

  alias Data.Repo
  alias Data.Accounts.Registration
  alias Data.Accounts.Credential
  alias Data.Accounts.User

  # ACCOUNTS

  def register(%{} = params) do
    Ecto.Multi.new()
    |> Registration.create(params)
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user, credential: credential}} ->
        user =
          Map.put(user, :credential, %{
            credential
            | token: nil,
              password: nil
          })

        {:ok, user}

      {:error, failed_operations, changeset, _successes} ->
        {:error, failed_operations, changeset}
    end
  end

  def authenticate(%{email: email, password: password} = _params) do
    Credential
    |> join(:inner, [c], assoc(c, :user))
    |> where([c, u], u.email == ^email)
    |> preload([c, u], user: u)
    |> Repo.one()
    |> case do
      nil ->
        dummy_checkpw()
        {:error, "Invalid email/password"}

      %Credential{} = cred ->
        if checkpw(password, cred.token) do
          {:ok, cred}
        else
          {:error, "Invalid email/password"}
        end
    end
  end

  #################################### CREDENTIAL ##############################

  @doc """
  Returns the list of credentials.

  ## Examples

      iex> list_credential()
      [%Credential{}, ...]

  """
  def list_credential do
    Repo.all(Credential)
  end

  @doc """
  Gets a single credential.

  Raises `Ecto.NoResultsError` if the Credential does not exist.

  ## Examples

      iex> get_credential(123)
      %Credential{}

      iex> get_credential(456)
      ** nil

  """
  def get_credential(id), do: Repo.get(Credential, id)

  @doc """
  Updates a credential.

  ## Examples

      iex> update_credential(credential, %{field: new_value})
      {:ok, %Credential{}}

      iex> update_credential(credential, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_credential(%Credential{} = credential, attrs) do
    credential
    |> Credential.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a Credential.

  ## Examples

      iex> delete_credential(credential)
      {:ok, %Credential{}}

      iex> delete_credential(credential)
      {:error, %Ecto.Changeset{}}

  """
  def delete_credential(%Credential{} = credential) do
    Repo.delete(credential)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking credential changes.

  ## Examples

      iex> change_credential(credential, %{})
      %Ecto.Changeset{source: %Credential{}}

  """
  def change_credential(%Credential{} = credential, attrs \\ %{}) do
    Credential.changeset(credential, attrs)
  end

  ################################## USERS ##################################

  @doc """
  Returns the list of users.

  ## Examples

      iex> list_user()
      [%User{}, ...]

  """
  def list_user do
    Repo.all(User)
  end

  @doc """
  Gets a single user.

  Raises `Ecto.NoResultsError` if the User does not exist.

  ## Examples

      iex> get(123)
      %User{}

      iex> get(456)
      ** nil

  """
  def get_user(id), do: Repo.get(User, id)

  @doc """
  Updates a user.

  ## Examples

      iex> update_user(user, %{field: new_value})
      {:ok, %User{}}

      iex> update_user(user, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_user(%User{} = user, attrs) do
    user
    |> User.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a User.

  ## Examples

      iex> delete_user(user)
      {:ok, %User{}}

      iex> delete_user(user)
      {:error, %Ecto.Changeset{}}

  """
  def delete_user(%User{} = user) do
    Repo.delete(user)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user changes.

  ## Examples

      iex> change_user(user)
      %Ecto.Changeset{source: %User{}}

  """
  def change_user(%User{} = user, attrs \\ %{}) do
    User.changeset(user, attrs)
  end

  def get_user_by(attrs), do: Repo.get_by(User, attrs)
end