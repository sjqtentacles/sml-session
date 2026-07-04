(* test.sml -- sml-session tests. *)

structure SessionTests =
struct
  open Harness

  fun run () =
    let
      (* ---- pure session map ---- *)
      val () = section "session map"
      val s0 = Session.empty
      val s1 = Session.put s0 "user" "alice"
      val s2 = Session.put s1 "role" "admin"
      val () = checkBool "get present" (true, Session.get s2 "user" = SOME "alice")
      val () = checkBool "get absent" (true, Session.get s2 "missing" = NONE)
      val () = checkInt "two keys" (2, List.length (Session.toList s2))
      val s3 = Session.put s2 "user" "bob"
      val () = checkString "overwrite" ("bob", valOf (Session.get s3 "user"))
      val () = checkInt "overwrite keeps count" (2, List.length (Session.toList s3))
      val () = checkStringList "order stable after overwrite"
        (["user", "role"], List.map #1 (Session.toList s3))
      val s4 = Session.remove s3 "role"
      val () = checkBool "removed" (true, Session.get s4 "role" = NONE)
      val () = checkInt "one key" (1, List.length (Session.toList s4))
      val () = checkInt "fromList dedup"
        (2, List.length (Session.toList
              (Session.fromList [("a","1"),("b","2"),("a","3")])))

      (* ---- JSON round-trip ---- *)
      val () = section "json"
      val () = checkString "toJson"
        ("{\"user\":\"bob\",\"role\":\"admin\"}",
         Session.toJson (Session.fromList [("user","bob"),("role","admin")]))
      val rt = valOf (Session.fromJson (Session.toJson s3))
      val () = checkString "fromJson round-trips user" ("bob", valOf (Session.get rt "user"))
      val () = checkString "fromJson round-trips role" ("admin", valOf (Session.get rt "role"))
      val () = checkBool "fromJson bad input -> NONE"
        (true, not (isSome (Session.fromJson "not json")))
      val () = checkBool "fromJson non-object -> NONE"
        (true, not (isSome (Session.fromJson "[1,2,3]")))
      (* A large integer field (e.g. a millisecond timestamp) exceeds a
         fixed-width Int on both MLton (32-bit default) and Poly/ML (63-bit):
         it must round-trip losslessly without raising Overflow, since JInt now
         carries an arbitrary-precision IntInf.int. *)
      val bigJson = valOf (Session.fromJson "{\"ts\":1700000000000}")
      val () = checkString "fromJson large int field"
        ("1700000000000", valOf (Session.get bigJson "ts"))

      (* ---- in-memory backend ---- *)
      val () = section "memory backend"
      val rng = Random.fromInt 7
      val (sid, store1, _) = Session.Memory.create Session.Memory.empty rng
                               (Session.fromList [("k","v")])
      val () = checkInt "id length" (32, String.size sid)
      val () = checkBool "load created"
        (true, Option.map (fn s => Session.get s "k") (Session.Memory.load store1 sid)
               = SOME (SOME "v"))
      val store2 = Session.Memory.save store1 sid (Session.fromList [("k","v2")])
      val () = checkString "save overwrites"
        ("v2", valOf (Session.get (valOf (Session.Memory.load store2 sid)) "k"))
      val () = checkBool "load unknown -> NONE"
        (true, not (isSome (Session.Memory.load store2 "nope")))
      val store3 = Session.Memory.destroy store2 sid
      val () = checkBool "destroyed" (true, not (isSome (Session.Memory.load store3 sid)))
      (* distinct ids from advanced generator *)
      val (sidA, _, rngB) = Session.Memory.create Session.Memory.empty (Random.fromInt 1)
                              Session.empty
      val (sidB, _, _) = Session.Memory.create Session.Memory.empty rngB Session.empty
      val () = checkBool "fresh ids differ" (true, sidA <> sidB)

      (* ---- signed-cookie backend ---- *)
      val () = section "signed-cookie backend"
      val key = "session-secret"
      val sess = Session.fromList [("user","alice"),("role","admin")]
      val enc = Session.SignedCookie.encode key sess
      val dec = valOf (Session.SignedCookie.decode key enc)
      val () = checkString "decode user" ("alice", valOf (Session.get dec "user"))
      val () = checkString "decode role" ("admin", valOf (Session.get dec "role"))
      val () = checkBool "wrong key -> NONE"
        (true, not (isSome (Session.SignedCookie.decode "other" enc)))
      (* tamper: change the payload prefix *)
      val tampered = "X" ^ String.extract (enc, 1, NONE)
      val () = checkBool "tampered -> NONE"
        (true, not (isSome (Session.SignedCookie.decode key tampered)))
    in
      ()
    end
end
