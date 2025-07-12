defmodule CosasWeonas do
  use CosasRaras

  @impl CosasRaras
  def hola_mundo(name) do
    "Hola, #{name}! Weonas"
  end

  @impl CosasRaras
  def chao_mundo(name) do
    "Chao, #{name}! Weonas"
  end
end
