# sml-session

[![CI](https://github.com/sjqtentacles/sml-session/actions/workflows/ci.yml/badge.svg)](https://github.com/sjqtentacles/sml-session/actions/workflows/ci.yml)

Pure session handling for Standard ML: one immutable `string -> string` session
model with two interchangeable backends — a server-side in-memory store and a
stateless HMAC-signed cookie. I/O-free, deterministic, and built test-first.
Dual-compiler: **MLton + Poly/ML**.

## Features

- **Session model** — an ordered, insertion-stable string map with pure
  `get` / `put` / `remove` / `toList` / `fromList`.
- **JSON serialization** — `toJson` / `fromJson` via
  [sml-json](https://github.com/sjqtentacles/sml-json) (flat object of strings).
  Integer fields carry an arbitrary-precision `IntInf.int`, so a large value
  (e.g. a millisecond timestamp like `1700000000000`) round-trips losslessly and
  identically on MLton (32-bit default `int`) and Poly/ML (63-bit `int`) — both
  fixed-width, so a naive `int` would overflow past their `Int` range.
- **`Memory` backend** — an immutable store keyed by session id; `create` mints
  a hex id from an [sml-random](https://github.com/sjqtentacles/sml-random)
  generator and threads it forward, so id streams are reproducible from a seed.
- **`SignedCookie` backend** — stateless: the session is JSON-encoded into an
  HMAC-SHA256 signed value via [sml-crypto](https://github.com/sjqtentacles/sml-crypto);
  `decode` verifies the signature and rejects tampered or wrong-key payloads.

## API

```sml
type session
val empty    : session
val get      : session -> string -> string option
val put      : session -> string -> string -> session
val remove   : session -> string -> session
val toList   : session -> (string * string) list
val fromList : (string * string) list -> session
val toJson   : session -> string
val fromJson : string -> session option

structure Memory : sig
  type store
  val empty   : store
  val create  : store -> Random.t -> session -> string * store * Random.t
  val load    : store -> string -> session option
  val save    : store -> string -> session -> store
  val destroy : store -> string -> store
end

structure SignedCookie : sig
  val encode : string -> session -> string          (* key -> session -> cookie value *)
  val decode : string -> string -> session option   (* key -> cookie value -> session *)
end
```

## Example

```sml
(* Stateless, signed-cookie session *)
val key  = "session-secret"
val sess = Session.fromList [("user","alice"), ("role","admin")]
val cookieValue = Session.SignedCookie.encode key sess
val SOME back   = Session.SignedCookie.decode key cookieValue
val SOME "alice" = Session.get back "user"

(* Server-side store with reproducible ids *)
val (sid, store, _) = Session.Memory.create Session.Memory.empty (Random.fromInt 7) sess
val SOME loaded     = Session.Memory.load store sid
```

## Build & test

```sh
make test        # MLton
make test-poly   # Poly/ML
make all-tests   # both
```

**25 deterministic checks**, identical under MLton and Poly/ML.

## Installation

```
package github.com/sjqtentacles/sml-session
require {
  github.com/sjqtentacles/sml-cookie
  github.com/sjqtentacles/sml-random
  github.com/sjqtentacles/sml-json
}
```

Dependencies are also vendored under `lib/github.com/sjqtentacles/` and
committed, so `make` needs no network.

## Layout

```
lib/github.com/sjqtentacles/sml-session/
  session.sig  session.sml    model + Memory + SignedCookie backends
  sources.mlb  sml-session.mlb
test/                         Harness suite (25 checks)
```

## License

MIT
