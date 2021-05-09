if Code.ensure_loaded?(Absinthe) do
  defmodule Cqrs.Absinthe do
    @moduledoc """
    Macros to derive queries and mutations from [Queries](`Cqrs.Query`) and [Commands](`Cqrs.Command`), respectfully.

    ## Example

        defmodule ExampleApi.Types.UserTypes do
          @moduledoc false
          use Cqrs.Absinthe

          use Absinthe.Schema.Notation

          alias Example.Queries.{ListUsers, GetUser}
          alias Example.Users.Protocol.{CreateUser, SuspendUser, ReinstateUser}

          import ExampleApi.Resolvers.UserResolver

          enum :user_status do
            value :active
            value :suspended
          end

          object :user do
            field :id, :id
            field :name, :string
            field :email, :string
            field :status, :user_status
          end

          object :user_queries do
            derive_query GetUser, :user,
              as: :user,
              except: [:name]

            derive_query ListUsers, :user,
              as: :users,
              arg_types: [status: :user_status]
          end

          derive_mutation_input CreateUser

          object :user_mutations do
            derive_mutation CreateUser, :user, input_object?: true, then: &fetch_user/1
            derive_mutation SuspendUser, :user, then: &fetch_user/1
            derive_mutation ReinstateUser, :user, then: &fetch_user/1
          end
        end

    """
    alias Cqrs.Guards
    alias Cqrs.Absinthe.{Mutation, Query}

    defmacro __using__(_) do
      quote do
        import Cqrs.Absinthe,
          only: [
            derive_mutation_input: 1,
            derive_mutation_input: 2,
            derive_mutation: 2,
            derive_mutation: 3,
            derive_query: 2,
            derive_query: 3
          ]
      end
    end

    @doc """
    Defines an `Absinthe` `query` from a [Query](`Cqrs.Query`).

    ## Options

    * `:as` - The name to use for the query. Defaults to the query_module name snake_cased.
    * `:only` - Use only the filters listed
    * `:except` - Create filters for all except those listed
    """
    defmacro derive_query(query_module, return_type, opts \\ []) do
      opts = Keyword.merge(opts, source: query_module, macro: :derive_query)

      field =
        quote location: :keep do
          Guards.ensure_is_query!(unquote(query_module))

          Query.create_query(
            unquote(query_module),
            unquote(return_type),
            unquote(opts)
          )
        end

      Module.eval_quoted(__CALLER__, field)
    end

    @doc """
    Defines an `Absinthe` `input_object` for a [Command](`Cqrs.Command`).

    ## Options

    * `:as` - The name to use for the query. Defaults to the command_module name snake_cased with `_input` appended.
    """
    defmacro derive_mutation_input(command_module, opts \\ []) do
      opts =
        opts
        |> Keyword.merge(source: command_module, macro: :derive_mutation_input)
        |> Keyword.drop([:only, :except])

      input =
        quote location: :keep do
          Guards.ensure_is_command!(unquote(command_module))
          Mutation.create_input_object(unquote(command_module), unquote(opts))
        end

      Module.eval_quoted(__CALLER__, input)
    end

    @doc """
    Defines an `Absinthe` `mutation` for a [Command](`Cqrs.Command`).

    ## Options

    * `:as` - The name to use for the mutation. Defaults to the query_module name snake_cased.
    * `:then` - A `function/1` that accepts the result of the command execution. The function should return the standard `Absinthe` `{:ok, response}` or `{:error, error}` tuple.
    * `:input_object?` - `true | false`. Defaults to `false`

      * If `true`, one arg with the name of `:input` will be generated.

      * If `true`, an `input_object` for the [Command](`Cqrs.Command`) is expected to exist. See `derive_mutation_input/2`.

    """
    defmacro derive_mutation(command_module, return_type, opts \\ []) do
      opts =
        opts
        |> Keyword.merge(source: command_module, macro: :derive_mutation)
        |> Keyword.drop([:only, :except])

      mutation =
        quote location: :keep do
          Guards.ensure_is_command!(unquote(command_module))

          Mutation.create_mutatation(
            unquote(command_module),
            unquote(return_type),
            unquote(opts)
          )
        end

      Module.eval_quoted(__CALLER__, mutation)
    end
  end
end
