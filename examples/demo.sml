(* demo.sml - deterministic walkthrough of the pure session model, the
   in-memory backend, and the signed-cookie backend. No wall clock, no
   filesystem/network I/O; the Memory backend id is minted from a seeded
   PRNG so output is identical on every run. *)

structure S = Session

val () = print "sml-session demo\n"

val sess = S.put (S.put (S.put S.empty "user" "alice") "role" "admin") "theme" "dark"
val () = print ("get user = " ^ valOf (S.get sess "user") ^ "\n")
val () = print ("get role = " ^ valOf (S.get sess "role") ^ "\n")
val () = print ("toList   = ["
                ^ String.concatWith ", "
                    (List.map (fn (k, v) => k ^ "=" ^ v) (S.toList sess))
                ^ "]\n")

val json = S.toJson sess
val () = print ("toJson   = " ^ json ^ "\n")
val sessBack = valOf (S.fromJson json)
val () = print ("fromJson roundtrip matches original = "
                ^ Bool.toString (S.toList sessBack = S.toList sess) ^ "\n")

val (sid, store1, _) = S.Memory.create S.Memory.empty (Random.fromInt 42) sess
val () = print ("\nMemory.create id = " ^ sid ^ "\n")
val loaded = valOf (S.Memory.load store1 sid)
val () = print ("Memory.load toList = ["
                ^ String.concatWith ", "
                    (List.map (fn (k, v) => k ^ "=" ^ v) (S.toList loaded))
                ^ "]\n")
val store2 = S.Memory.destroy store1 sid
val () = print ("after Memory.destroy, load = "
                ^ (case S.Memory.load store2 sid of NONE => "NONE" | SOME _ => "SOME")
                ^ "\n")

val key = "fixed-secret-key"
val cookie = S.SignedCookie.encode key sess
val () = print ("\nSignedCookie.encode = " ^ cookie ^ "\n")
val decoded = valOf (S.SignedCookie.decode key cookie)
val () = print ("SignedCookie.decode roundtrip matches = "
                ^ Bool.toString (S.toList decoded = S.toList sess) ^ "\n")

fun flipFirst c = if c = #"A" then #"B" else #"A"
val tampered =
  case String.explode cookie of
    []      => cookie
  | c :: cs => String.implode (flipFirst c :: cs)
val () = print ("SignedCookie.decode(tampered cookie)  = "
                ^ (case S.SignedCookie.decode key tampered of NONE => "NONE" | SOME _ => "SOME")
                ^ "\n")
