defmodule CosasRaras do
  @callback hola_mundo(name :: String.t()) :: String.t()
  @callback chao_mundo(name :: String.t()) :: String.t()

  defmacro __using__(_opts) do
    quote do
      @behaviour CosasRaras

      @impl CosasRaras
      def hola_mundo(name) do
        "Hola, #{name}!"
      end

      defoverridable hola_mundo: 1

    end
  end
end
