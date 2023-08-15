open Fmlib_browser



type state = {
    elapsed: float;
    start:   float;
    duration: float;
}


type msg =
    | Animate  of float
    | Duration of float
    | Restart

let duration_value (str: string): msg =
    (* Convert floating point string value to the [Duration] message with
       the floating point value. *)
    try
        Duration (float_of_string str)
    with Failure _ ->
        assert false    (* Illegal call, must be a floating point value. *)



let init: state =
    {elapsed = 0.0; start = 0.0; duration = 2.0}



let view (state: state): msg Html.t =
    let open Html in
    let open Attribute in
    let open Printf in
    let elapsed_string  = sprintf "%.3f" state.elapsed
    and elapsed_string2 = sprintf "%.1f" state.elapsed
    and duration_string = sprintf "%.1f" state.duration
    in
    let elapsed =
        label [] [
            text "Elapsed time: "
          ; node
                "progress"
                [ attribute "value" elapsed_string
                ; attribute "max"   duration_string
                ]
                []
          ; text elapsed_string2
          ; text "s"
        ]
    and duration =
        label
            []
            [ text "Duration: "
            ; input [ attribute "type" "range"
                    ; attribute "min" "0.5"
                    ; attribute "max" "30"
                    ; attribute "step" "0.5"
                    ; attribute "value" duration_string
                    ; on_input duration_value
                    ] []
            ; text duration_string
            ; text "s"
            ]
    in
    div [] [ h2 [] [text "Timer"]
           ; p [] [text
                   {|A timer runs for a duration. A click on the restart button
                     restarts the timer. A change of the duration has an
                     immediate effect.
             |}]
           ; p [] [elapsed]
           ; p [] [duration]
           ; p [] [button [on_click Restart] [text "Restart"]]
           ]



let subs (state: state): msg Subscription.t =
    if state.duration <= state.elapsed then
        Subscription.none
    else
        Subscription.on_animation (fun ms -> Animate (Time.to_float ms))




let update (state: state): msg -> state =
    function
    | Duration duration ->
        {state with duration}

    | Animate ms ->
        if state.start = 0.0 then
            {state with start = ms}
        else
            {state with
             elapsed =
                 min state.duration ((ms -. state.start) /. 1000.0)
            }
    | Restart ->
        {state with start = 0.0; elapsed = 0.0}


let _ =
    sandbox_plus
        init
        view
        subs
        update
