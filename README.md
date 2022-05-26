# Construct [![Hex.pm](https://img.shields.io/hexpm/v/construct.svg)](https://hex.pm/packages/construct)

---

Library for dealing with data structures

---

* [Installation](#installation)
* [Usage](#usage)
* [Types](#types)
* [Construct definition](#construct-definition)
* [Errors while making structures](#errors-while-making-structures)

---

## Installation

1. Add `construct` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:construct, "~> 2.0"}]
end
```

2. Ensure `construct` is started before your application:

```elixir
def application do
  [applications: [:construct]]
end
```

## Usage

Suppose you have some user input from several sources (DB, HTTP request, WebSocket), and you will need to process that data into something type-validated, like User entity. With this library you can define a type-validated structure for this entity:

```elixir
defmodule User do
  use Construct do
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
  @behaviour Construct.Type

  def cast("yes"), do: {:ok, true}
  def cast("no"), do: {:ok, false}
  def cast(_), do: {:error, :invalid_answer}
end
```

And use it in your structure like this:

```elixir
defmodule Quiz do
  use Construct do
    field :user_id, :integer
    field :answers, {:array, Answer}
  end
end
```

```elixir
iex> Quiz.make(%{user_id: 42, answers: ["yes", "no", "no", "yes"]})
{:ok, %Quiz{answers: [true, false, false, true], user_id: 42}}
```

> What if we need to parse 'optimized' query string from URL, like list of user ids separated by a comma? Do we need to create a custom type for each boxed type?

No! Just use type composition feature:

```elixir
defmodule CommaList do
  @behaviour Construct.Type

  def cast(""), do: {:ok, []}
  def cast(v) when is_binary(v), do: {:ok, String.split(v, ",")}
  def cast(v) when is_list(v), do: {:ok, v}
  def cast(_), do: :error
end

defmodule SearchFilterRequest do
  use Construct do
    field :user_ids, [CommaList, {:array, :integer}], default: []
  end
end
```

(Use `CommaList` type from [construct_types](https://github.com/ExpressApp/construct_types/blob/master/lib/types/comma_list.ex) package).

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
  use Construct do
    field :text
  end
end

defmodule Post do
  use Construct do
    field :title
    field :comments, {:array, Comment}
  end
end

iex> Post.make(%{title: "Some article", comments: [%{"text" => "cool!"}, %{text: "awesome!!!"}]})
{:ok, %Post{comments: [%Comment{text: "cool!"}, %Comment{text: "awesome!!!"}], title: "Some article"}}
```

And include repeated fields in structures:

```elixir
defmodule PK do
  use Construct do
    field :primary_key, :integer
  end
end

defmodule Timestamps do
  use Construct do
    field :created_at, :utc_datetime, default: &DateTime.utc_now/0
    field :updated_at, :utc_datetime, default: nil
  end
end

defmodule User do
  use Construct do
    include PK
    include Timestamps

    field :name
  end
end

iex> User.make(%{name: "John Doe", primary_key: 42})
{:ok,
 %User{created_at: #DateTime<2018-10-14 20:43:06.595119Z>, name: "John Doe",
  primary_key: 42, updated_at: nil}}

iex> User.make(%{name: "John Doe", created_at: "2015-01-23 23:50:07", primary_key: 42})
{:ok,
 %User{created_at: #DateTime<2015-01-23 23:50:07Z>, name: "John Doe",
  primary_key: 42, updated_at: nil}}
```

> What if I don't want to define module to make a nested field?

`field` macro can `do` it for you:

```elixir
defmodule User do
  use Construct do
    field :name do
      field :first
      field :last, :string, default: nil
    end
  end
end

iex> User.make(name: %{first: "John"})
{:ok, %User{name: %User.Name{first: "John", last: nil}}}
```

Construct tries to fit in Elixir as much as it possible:

```elixir
defmodule ComplexDefaults do
  use Construct do
    field :required

    field :nested do
      field :key, :string, default: "nesting 1"

      field :nested do
        field :key, :string, default: "nesting 2"
      end
    end
  end
end

iex> %ComplexDefaults{}
** (ArgumentError) the following keys must also be given when building struct ComplexDefaults: [:required]
    expanding struct: ComplexDefaults.__struct__/1

iex> %ComplexDefaults{required: 1}
%ComplexDefaults{
  nested: %ComplexDefaults.Nested{
    key: "nesting 1",
    nested: %ComplexDefaults.Nested.Nested{key: "nesting 2"}
  },
  required: 1
}
```

> What if I want to use union types?

Use custom types:

```elixir
defmodule User do
  use Construct do
    field :id, :integer
    field :name
    field :age, :integer
  end
end

defmodule Bot do
  use Construct do
    field :id, :integer
    field :name
    field :version
  end
end

defmodule Author do
  @behaviour Construct.Type

  # here's the trick, just choose the type by yourself, based on keys or value in specific field.
  # but be careful, because there can be atoms and strings in keys!
  def cast(%{"age" => _} = v), do: User.make(v)
  def cast(%{"version" => _} = v), do: Bot.make(v)
  def cast(_), do: :error
end

defmodule Post do
  use Construct do
    field :author, Author
  end
end

iex> Post.make(%{"author" => %{}})
{:error, %{author: :invalid}}

iex> Post.make(%{"author" => %{"age" => "420"}})
{:error, %{author: %{id: :missing, name: :missing}}}

iex> Post.make(%{"author" => %{"id" => "42", "name" => "john doe", "age" => "420"}})
{:ok, %Post{author: %User{age: 420, id: 42, name: "john doe"}}}

iex> Post.make(%{"author" => %{"id" => "42", "name" => "john doe", "version" => "1.0.0"}})
{:ok, %Post{author: %Bot{id: 42, name: "john doe", version: "1.0.0"}}}
```

> How can I serialize my structures with Jason?

Use `@derive` attribute and `derive` option for nested fields:

```elixir
defmodule Server do
  @derive {Jason.Encoder, only: [:name, :operating_system]}

  use Construct do
    field :name
    field :password

    field :operating_system, derive: Jason.Encoder do
      field :name, :string
      field :arch, :string, default: "x86"
    end
  end
end

iex> {:ok, server} = Server.make(name: "example", password: "secret", operating_system: %{name: "MacOS"})
{:ok,
 %Server{
   name: "example",
   operating_system: %Server.OperatingSystem{arch: "x86", name: "MacOS"},
   password: "secret"
 }}

iex> Jason.encode!(server)
"{\"name\":\"example\",\"operating_system\":{\"arch\":\"x86\",\"name\":\"MacOS\"}}"
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
  * array
  * map
  * struct
* `{:array, t()}`
* `{:map, t()}`
* `[t()]`

### Complex (custom) types

You can use Ecto custom types like Ecto.UUID or implement by yourself:

```elixir
defmodule CustomType do
  @behaviour Construct.Type

  @spec cast(term) :: {:ok, term} | {:error, term} | :error
  def cast(value) do
    {:ok, value}
  end
end
```

Notice that `cast/1` can return error with reason, this behaviour is supported only by Struct and you can't use types defined using Construct in Ecto schemas.

## Construct definition

```elixir
defmodule User do
  use Construct, struct_opts

  structure do
    include module_name

    field name
    field name, type
    field name, type, field_opts
  end
end
```

Where:

* `use Construct, struct_opts` where:
  * `struct_opts` — options passed to every `make/2` and `make!/2` calls as default options;
* `include module_name` where:
  * `module_name` — is struct module, that validates for existence in compile time;
* `field name, type, field_opts` where:
  * `name` — atom;
  * `type` — primitive or custom type, that validates for existence in compile time;
  * `field_opts`.

## Errors while making structures

When you provide invalid data to your structures you can get tuple with errors as maps:

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
** (Construct.MakeError) %{comments: {:missing, nil}, title: {:missing, nil}}
    iex:10: Post.make!/2

iex> Post.make!(%{comments: %{}, title: :test})
** (Construct.MakeError) %{comments: {:invalid, %{}}, title: {:invalid, :test}}
    iex:10: Post.make!/2

iex> Post.make!(%{comments: [%{}], title: "what the title?"})
** (Construct.MakeError) %{comments: %{text: {:missing, [nil]}}}
    iex:10: Post.make!/2
```

---

### Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
