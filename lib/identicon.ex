defmodule Identicon do
  @moduledoc """
  Converts a string into an identicon.
  """
  def main(input) do
    input
    |> hash_input
    |> pick_color
    |> build_grid
    |> filter_odd_squares
    |> build_pixel_map
    |> draw_image
    |> save_image(input)
  end

  @doc """
  Converts a string into it's md5 hash and returned as an %Identicon.Image{} struct.
  Hex attribute is an array of 16 int values.

  ## Examples

      iex> Identicon.hash_input("banana")
      %Identicon.Image{hex: [114, 179, 2, 191, 41, 122, 34, 138, 117, 115, 1, 35, 239, 239, 124, 65]}

  """
  def hash_input(input) do
    hex = :crypto.hash(:md5, input)
          |> :binary.bin_to_list
    %Identicon.Image{hex: hex}
  end

  @doc """
  Takes an `%Identicon.Image{}` and set it's `color` attribute using 3 first values of it's hex attribute.
  Returns an `%Identicon.Image{}`

  ## Examples
      iex> Identicon.pick_color(%Identicon.Image{hex: [114, 179, 2, 191, 41, 122, 34, 138, 117, 115, 1, 35, 239, 239, 124, 65]})
      %Identicon.Image{color: {114, 179, 2}, hex: [114, 179, 2, 191, 41, 122, 34, 138, 117, 115, 1, 35, 239, 239, 124, 65]}

  """
  def pick_color(%Identicon.Image{hex: [r, g, b | _tail]} = image) do
    # using extracted r g b values with pattern matching (image arg is passed anyway)
    # creating a new image struct with a color attribute
    %Identicon.Image{image | color: {r, g, b}}
  end

  @doc """
  Takes an `Identicon.Image{}` and set it's `grid` attribute to an array of tuples.
  Each tuple `{x, y}` composed with a code `x` and an index `y`.
  Returns an `Identicon.Image{}`.

  ## Examples

      iex> Identicon.build_grid(%Identicon.Image{color: {114, 179, 2}, hex: [114, 179, 2, 191, 41, 122, 34, 138, 117, 115, 1, 35, 239, 239, 124, 65]})
      %Identicon.Image{color: {114, 179, 2}, grid: [{114, 0}, {179, 1}, {2, 2}, {179, 3}, {114, 4}, {191, 5}, {41, 6}, {122, 7}, {41, 8}, {191, 9}, {34, 10}, {138, 11}, {117, 12}, {138, 13}, {34, 14}, {115, 15}, {1, 16}, {35, 17}, {1, 18}, {115, 19}, {239, 20}, {239, 21}, {124, 22}, {239, 23}, {239, 24}], hex: [114, 179, 2, 191, 41, 122, 34, 138, 117, 115, 1, 35, 239, 239, 124, 65]}
  """
  def build_grid(%Identicon.Image{hex: hex_list} = image) do
    # split hex_list into an array of subarrays of size 3
    # then mirror each subarray using mirror_row function
    grid =
      hex_list
      |> Enum.chunk(3)
      |> Enum.map(&mirror_row/1)
      |> List.flatten
      |> Enum.with_index

    %Identicon.Image{image | grid: grid}
  end

  @doc """
  Take an array `x`  and returns a 'mirrored' array `y` with `size(y) = 5`.
  `size(x)` must be 3.

  ## Examples

      iex> Identicon.mirror_row([1, 2, 3])
      [1, 2, 3, 2, 1]
  """
  def mirror_row([first, second | _tail] = row) do
    # append 'second' and 'first' in the 'row' list
    row ++ [second, first]
  end

  @doc """
  Takes an `Identicon.Image{}` and filter it's `grid` attribute to remove all element which
  code value is an odd number. Returns an `Identicon.Image{}`.

  ## Examples

      iex> Identicon.filter_odd_squares(%Identicon.Image{color: {114, 179, 2}, grid: [{114, 0}, {179, 1}, {2, 2}, {179, 3}, {114, 4}, {191, 5}, {41, 6}, {122, 7}, {41, 8}, {191, 9}, {34, 10}, {138, 11}, {117, 12}, {138, 13}, {34, 14}, {115, 15}, {1, 16}, {35, 17}, {1, 18}, {115, 19}, {239, 20}, {239, 21}, {124, 22}, {239, 23}, {239, 24}], hex: [114, 179, 2, 191, 41, 122, 34, 138, 117, 115, 1, 35, 239, 239, 124, 65]})
      %Identicon.Image{color: {114, 179, 2}, grid: [{114, 0}, {2, 2}, {114, 4}, {122, 7}, {34, 10}, {138, 11}, {138, 13}, {34, 14}, {124, 22}], hex: [114, 179, 2, 191, 41, 122, 34, 138, 117, 115, 1, 35, 239, 239, 124, 65]}
  """
  def filter_odd_squares(%Identicon.Image{grid: grid} = image) do
    # syntaxic sugar: function parenthesis can be removed
    grid = Enum.filter grid, fn({code, _index}) ->
      # code % 2 (modulo)
      rem(code, 2) == 0
    end
    %Identicon.Image{image | grid: grid}
  end

  @doc """
  Takes an `%Identicon.Image{}` and set `pixel_map` attribute to an array of nested tuples,
  each containing 2 sets of 2-D coordinates `{{x1,y1}, {x2,y2}}`.
  """
  def build_pixel_map(%Identicon.Image{grid: grid} = image) do
    pixel_map = Enum.map grid, fn({_code, index}) ->
      # remainder of index / 5 euclidian division
      horizontal = rem(index, 5) * 50
      # quotient of index / 5
      vertical = div(index, 5) * 50

      top_left      = {horizontal, vertical}
      bottom_right  = {horizontal + 50, vertical + 50}

      {top_left, bottom_right}
    end
    %Identicon.Image{image | pixel_map: pixel_map}
  end

  @doc """
  Drawing a 250x250px image using egd erlang library
  """
  def draw_image(%Identicon.Image{color: color, pixel_map: pixel_map}) do
    # if we don't need reference to original arg we don't have to add the '= image'
    image = :egd.create(250, 250)
    fill = :egd.color(color)

    # exceptionnal case of modifying by object reference, mainly specific to egd library
    Enum.each pixel_map, fn({start, stop}) ->
      :egd.filledRectangle(image, start, stop, fill)
    end

    :egd.render(image)
  end

  @doc """
  Save a rendered image on hard drive nammed by the original text input
  """
  def save_image(image, filename) do
    File.write("#{filename}.png")
  end
end
