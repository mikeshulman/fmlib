val string:
    ('a -> bool) -> (string -> 'a -> 'a) -> ('a -> 'a) -> string -> 'a -> 'a

val channel:
    ('a -> bool) -> (string -> 'a -> 'a) -> ('a -> 'a) -> in_channel -> 'a -> 'a
