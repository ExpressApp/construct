# Struct [![Build Status](https://img.shields.io/travis/ExpressApp/struct.svg)](https://travis-ci.org/ExpressApp/struct) [![Hex.pm](https://img.shields.io/hexpm/v/struct.svg)](https://hex.pm/packages/struct)

---

Library for dealing with data structures

---

## Installation

1. Add `struct` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:struct, "~> 1.0.0"}]
end
```

2. Ensure `struct` is started before your application:

```elixir
def application do
  [applications: [:struct]]
end
```

## Usage

Suppose you have some user input from several sources (DB, HTTP request, WebSocket), and you will need to process that data into something type-validated, like User entity. With this library you can define a type-validated struct for this entity:

```elixir
defmodule User do
  use Struct

  structure do
    field :name
    field :age, :integer
  end
end
```

And use it to cast your data into something identical, to prevent type coercion in different places of your code. Like this:

```elixir
iex> User.make(%{"name" => "John Doe", "age" => "37"})
{:ok, %User{age: 37, name: "John Doe"}}
```

Pretty neat, yeah? But what if you need more complex type? We have a solution!

```elixir
defmodule Answer do
  @behaviour Struct.Type

  def cast("yes"), do: {:ok, true}
  def cast("no"), do: {:ok, false}
  def cast(_), do: {:error, :invalid_answer}
end
```

And use it in your struct like this:

```elixir
defmodule Quiz do
  use Struct

  structure do
    field :user_id, :integer
    field :answers, {:array, Answer}
  end
end
```

```elixir
iex> Quiz.make(%{user_id: 42, answers: ["yes", "no", "no", "yes"]})
{:ok, %Quiz{answers: [true, false, false, true], user_id: 42}}
```

What if we need to parse 'optimized' query string from URL, like list of user ids separated by a comma? Do we need to create a custom type for each boxed type? No! Just use type composition feature:

```elixir
defmodule CommaList do
  @behaviour Struct.Type

  def cast(""), do: {:ok, []}
  def cast(v) when is_binary(v), do: {:ok, String.split(v, ",")}
  def cast(v) when is_list(v), do: {:ok, v}
  def cast(_), do: :error
end

defmodule SearchFilterRequest do
  use Struct

  structure do
    field :user_ids, [CommaList, {:array, :integer}], default: []
  end
end
```

```elixir
iex> SearchFilterRequest.make(%{"user_ids" => "1,2,42"})
{:ok, %SearchFilterRequest{user_ids: [1, 2, 42]}}
```

Also we have `default` option in our `user_ids` field:

```elixir
iex> SearchFilterRequest.make(%{})
{:ok, %SearchFilterRequest{user_ids: []}}
```

> What if I have a lot of identical code?

You can use already defined structures as types:

```elixir
defmodule Comment do
  use Struct

  structure do
    field :text
  end
end

defmodule Post do
  use Struct

  structure do
    field :title
    field :comments, {:array, Comment}
  end
end

iex> Post.make(%{title: "Some article", comments: [%{"text" => "cool!"}, %{text: "awesome!!!"}]})
{:ok, %Post{comments: [%Comment{text: "cool!"}, %Comment{text: "awesome!!!"}], title: "Some article"}}
```

And include repeated fields in structs:

```elixir
defmodule PK do
  use Struct

  structure do
    field :primary_key, :integer
  end
end

defmodule Timestamps do
  use Struct

  structure do
    field :inserted_at, :utc_datetime
    field :updated_at, :utc_datetime, default: nil
  end
end

defmodule User do
  use Struct

  structure do
    include PK
    include Timestamps

    field :name
  end
end

iex> User.make(%{name: "John Doe", inserted_at: "2015-01-23 23:50:07", primary_key: 42})
{:ok,
 %User{inserted_at: #DateTime<2015-01-23 23:50:07Z>, name: "John Doe",
  primary_key: 42, updated_at: nil}}
```

## Types

### Primitive types

* `t()`:
  * integer
  * float
  * boolean
  * string
  * binary
  * decimal
  * utc_datetime
  * naive_datetime
  * date
  * time
  * any
* `{:array, t()}`
* `{:map, t()}`
* `[t()]`

### Complex (custom) types

You can use Ecto custom types like Ecto.UUID or implement by yourself:

```elixir
defmodule CustomType do
  @behaviour Struct.Type

  @spec cast(term) :: {:ok, term} | {:error, term} | :error
  def cast(value) do
    {:ok, value}
  end
end
```

Notice that `cast/1` can return error with reason, this behaviour is supported only by Struct and you can't use types defined using Struct in Ecto schemas.

## Struct definition

```elixir
defmodule User do
  use Struct, struct_opts

  structure do
    include module_name

    field name
    field name, type
    field name, type, field_opts
  end
end
```

Where:

* `use Struct, struct_opts` where:
  * `struct_opts` — options passed to every `make/2` and `make!/2` calls as default options;
* `include module_name` where:
  * `module_name` — is struct module, that validates for existence in compile time;
* `field name, type, field_opts` where:
  * `name` — atom;
  * `type` — primitive or custom type, that validates for existence in compile time;
  * `field_opts`.

## Errors while making structs

When you provide invalid data to your structs you can get tuple with errors:

```elixir
iex> Post.make
{:error, %{comments: :missing, title: :missing}}

iex> Post.make(%{comments: %{}, title: :test})
{:error, %{comments: :invalid, title: :invalid}}

iex> Post.make(%{comments: [%{}], title: "what the title?"})
{:error, %{comments: %{text: :missing}}}
```

Or receive an exception with invalid data:

```elixir
iex> Post.make!
** (Struct.MakeError) %{comments: {:missing, nil}, title: {:missing, nil}}
    iex:10: Post.make!/2

iex> Post.make!(%{comments: %{}, title: :test})
** (Struct.MakeError) %{comments: {:invalid, %{}}, title: {:invalid, :test}}
    iex:10: Post.make!/2

iex> Post.make!(%{comments: [%{}], title: "what the title?"})
** (Struct.MakeError) %{comments: %{text: {:missing, [nil]}}}
    iex:10: Post.make!/2
```

---

### Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
