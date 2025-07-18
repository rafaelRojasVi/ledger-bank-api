defmodule LedgerBankApi.CrudHelpers do
  defmacro __using__(opts) do
    schema = Keyword.fetch!(opts, :schema)
    quote do
      alias LedgerBankApi.Repo
      def list, do: Repo.all(unquote(schema))
      def get!(id), do: Repo.get!(unquote(schema), id)
      def create(attrs \\ %{}), do: %unquote(schema){} |> unquote(schema).changeset(attrs) |> Repo.insert()
      def update(struct, attrs), do: struct |> unquote(schema).changeset(attrs) |> Repo.update()
      def delete(struct), do: Repo.delete(struct)
    end
  end
end
