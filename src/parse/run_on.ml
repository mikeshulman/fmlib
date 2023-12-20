let string
        (needs_more: 'a -> bool)
        (put: string -> 'a -> 'a)
        (put_end: 'a -> 'a)
        (str: string)
        (p: 'a)
    : 'a
    =
    let len = String.length str
    in
    let rec run i p =
        if not (needs_more p) then
            p
        else if i = len then
            put_end p
        else
            let charlen = Uchar.utf_decode_length (String.get_utf_8_uchar str i) in
            run (i + charlen) (put (String.sub str i charlen) p)
    in
    run 0 p

let channel
        (needs_more: 'a -> bool)
        (put: string -> 'a -> 'a)
        (put_end: 'a -> 'a)
        (ic: in_channel)
        (p: 'a)
    : 'a
    =
    let rec input_uchar str =
        let str = str ^ String.make 1 (input_char ic) in
        let dec = String.get_utf_8_uchar str 0 in
        if Uchar.utf_decode_is_valid dec then
            str
        else if String.length str < 4 then
            input_uchar str
        else
            raise (Invalid_argument "UTF-8 decoding error")
    in
    let rec run p =
        if not (needs_more p) then
            p
        else
            try
                run (put (input_uchar "") p)
            with End_of_file ->
                put_end p
    in
    run p
