function validate_game(game::Dict)
    """This function validates a game by checking that each state,action pair is a valid transition."""
    previous = (
        winner_state=game["winner"]["states"][1], 
        loser_state=game["loser"]["states"][1], 
        winner_action=game["winner"]["actions"][1], 
        loser_action=game["loser"]["actions"][1]
    )

    if (previous.winner_state ∉ STARTING_STATES) || (previous.loser_state ∉ STARTING_STATES)
        return false
    end

    for (winner_state, loser_state, winner_action, loser_action) in zip(
        game["winner"]["states"], game["loser"]["states"], game["winner"]["actions"], game["loser"]["actions"]
    )[2:end]

        winner_transitions = transitionmap(previous.winner_state)
        if (previous.winner_action ∉ keys(winner_transitions)) || (winner_state ∉ winner_transitions[previous.winner_action])
            return false
        end

        loser_transitions = transitionmap(previous.loser_state)
        if (previous.loser_action ∉ keys(loser_transitions)) || (loser_state ∉ losrr_transitions[previous.loser_action])
            return false
        end

        #Ensure each state is a possible result of the previous state,action pair.
        

        previous = (
            winner_state=winner_state,
            loser_state=loser_state,
            winner_action=winner_action,
            loser_action=loser_action
        )

    end

    return true

end


function post_game(game::Dict)
        if !validate_game(game)
            return (400, "Invalid state-action transitions.")
        end

        try
            conn = DBInterface.connect(MySQL.Connection, PUNISH_HOST, PUNISH_USER, PUNISH_PASSWORD, port=PUNISH_PORT)
            insert_game_statement = DBInterface.prepare(conn, """
            INSERT INTO 
                games.games(winner_id, loser_id, play_timestamp, post_timestamp)
            VALUES 
                (SELECT id FROM games.players WHERE username=?),
                (SELECT id FROM games.players WHERE username=?),
                ?,?)
            """)

            insert_game_results = DBInterface.execute(
                insert_game_statement, 
                [game["winner"]["username"], game["loser"]["username"], game["play_timestamp"], round(Int64,time())]
            )

            game_id = DBInterface.lastrowid(insert_game_results)

            insert_bot_params_statement = DBInterface.prepare(conn, """
            INSERT INTO 
                games.bot_params(game_id, is_winner, parameter, val)
            VALUES 
                (:game_id, :is_winner, :parameter, :val)
            """)

            DBInterface.executemany(
                conn, insert_bot_params_statement,
                (
                    repeat(game_id, length(game["winner"]["bot_parameters"])),
                    repeat(true, length(game["winner"]["bot_parameters"])),
                    keys(game["winner"]["bot_parameters"]),
                    values(game["winner"]["bot_parameters"])
                )
            )

            DBInterface.executemany(
                conn, insert_bot_params_statement,
                (
                    repeat(game_id, length(game["loser"]["bot_parameters"])),
                    repeat(false, length(game["loser"]["bot_parameters"])),
                    keys(game["loser"]["bot_parameters"]),
                    values(game["loser"]["bot_parameters"])
                )
            )

            insert_breaths_statement = DBInterface.prepare(conn, """
            INSERT INTO 
                games.breaths(game_id, is_winner, information, choice)
            VALUES 
                (:game_id, :is_winner, :information, :choice)
            """)
            
            DBInterface.executemany(
                conn, insert_breaths_statement,
                (
                    repeat(game_id, length(game["winner"]["states"])),
                    repeat(true, length(game["winner"]["states"])),
                    game["winner"]["states"],
                    game["winner"]["actions"]
                )
            )

            DBInterface.executemany(
                conn, insert_breaths_statement,
                (
                    repeat(game_id, length(game["loser"]["states"])),
                    repeat(false, length(game["loser"]["states"])),
                    game["loser"]["states"],
                    game["loser"]["actions"]
                )
            )

            DBInterface.close!(conn)    
        catch err
            return return(500,"Error: $err")
        end
        return(200, "Success")
end