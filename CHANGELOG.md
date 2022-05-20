## Changelog

## v3.0.0

* Enhancements
  * Add `structure_compile_hook/2` macro to inject code into structures
    See `Construct.Hooks.Map` and `Construct.Hooks.OmitDefault` for examples
  * Compiler optimization and refactor

* Hard-deprecations
  * Remove `make_map` option
  * Remove `empty_values` option

## v2.1.10

* Enhancements
  * Add `enforce_keys` option to not enforce keys when building struct

## v2.1.9

* Enhancements
  * Add `only` option to `include`

## v2.1.8

* Enhancements
  * Add experimental TypeC behaviour
  * Add `error_values` option

* Bug fixes
  * Fix warnings for Elixir 1.10

## v2.1.7

* Enhancements
  * Add typespec generation

## v2.1.6

* Bug fixes
  * Ensure module is compiled when checking for Construct def in `include` macro

## v2.1.5

* Bug fixes
  * Ensure module is compiled when checking for Construct def

## v2.1.4 (retired)

* Bug fixes
  * Ensure module is trying to be compiled when checking that if this module is Construct definition

## v2.1.3

* Enhancements
  * Add `:pid` and `:reference` types

## v2.1.2

* Bug fixes
  * Fix case when non-enumerable values passed in array struct

## v2.1.1

* Bug fixes
  * Fix default values retriever for construct modules as types

## v2.1.0

* Enhancements
  * Derive inheritance
  * Add `Construct.types_of/1`
  * Support to build Construct definitions from raw types
  * Support nested types in `Construct.Cast.make/3`

## v2.0.0

* Enhancements
  * Functions as default values
  * Structs created from `Kernel.struct/1,2` and `make/1,2` are now equal
  * Structs with required fields return error when creating from `Kernel.struct/1,2`
  * `__construct__(:types)` returns types with defined options `%{name => {type, opts}}`
  * Improve decimals and datetimes handling
  * Performance of `Construct.Cast` is increased by almost 1.5x times

* Bug fixes
  * Fix define structure via using

* Hard-deprecations
  * Remove `__structure__/1` and `__structure__/2`, use `__construct__(:types)` instead

## v1.2.0

* Enhancements
  * Add `struct` type

## v1.1.1

* Enhancements
  * Definition in using macro
  * Add able to override fields

## v1.1.0

* Enhancements
  * Make structs from params as a keyword list
  * Simplify type declaration in standalone cast
  * Accept types declaration as a key value structure

## v1.0.1

* Enhancements
  * Self and cross dependent types
