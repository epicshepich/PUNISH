#This script normalizes JSON-formatted game log files (specified in the
#command line) and writes them to punish_data.db.
#In this directory, input the following into the command line:
#julia json2db.jl filepath
using JSON
using SQLite
using SQLStrings
using DataFrames

CONFIG = Dict(
    :bot_names => ["PARLESS"],
    :verbose => true
)
#Settings for this script.

STATE_SPACE = Set(JSON.parsefile("../envs/statespace.json",use_mmap=false))
#Load the state space in order to ensure all states are valid before writing
#games to database.

db = SQLite.DB("punish_data.db")
#Initialize connection to database.

CONFIG[:verbose] && println("Connection to database established. Reading records...")

game_ids = (DBInterface.execute(db,"SELECT game_id FROM games;") |> DataFrame)[:,"game_id"]
#Get game ids already in-use to prevent adding redundant records.

player_table = DBInterface.execute(db,"""SELECT * FROM players""") |> DataFrame
#Retrieve player table to ensure player ids are assigned consistently.
players = Dict(
    row["username"] => (
        player_id=row["player_id"],
        is_bot=row["is_bot"]
    )
    for row in eachrow(player_table)
)
#Map usernames to (id, is_bot) tuples.
max_player_id = length(players)==0 ? 0 : maximum(player.player_id for player in values(players))
#Find the largest existing ID in the database; new assignments will pick up from this value.


bot_parameters_table = DBInterface.execute(db,"""SELECT * FROM bot_parameters""") |> DataFrame
#Retrieve table of bot parameters to ensure parameter set ids are assigned consistently.
bot_parameters = Dict(
    (temperature = row["temperature"]) => row["paramset_id"]
    for row in eachrow(bot_parameters_table)
)
#Map the named parameter tuple to the parameter set id.
max_paramset_id = length(bot_parameters)==0 ? 0 : maximum(values(bot_parameters))
#Find the largest existing ID in the database; new assignments will pick up from this value.


CONFIG[:verbose] && println("Read complete.")

function new_player!(username)
    """This function assigns an ID to a new username and writes it to the
    `players` table of the database.
    """
    new_id = max_player_id+1
    global max_player_id += 1
    #Set the ID of the player to the next integer after the largest existing ID.
    is_bot = (username ∈ CONFIG[:bot_names]) ? 1 : 0
    #For the time being, we will identify bots by protected usernames.
    players[username] = (player_id=new_id, is_bot=is_bot)
    DBInterface.execute(db,sql`INSERT INTO players VALUES ($(new_id),'$(username)',$(is_bot));`)
    #Save the player to the username dict and insert record into database.
end

function new_paramset!(paramset)
    """This function assigns an ID to a new set of parameters and writes it to
    the `bot_parameters` table of the database."""
    new_id = max_paramset_id+1
    global max_paramset_id += 1
    #Set the ID of the paramset to the next integer after the largest existing ID.
    bot_parameters[paramset] = new_id
    DBInterface.execute(db,sql`INSERT INTO bot_parameters(paramset_id,temperature)
    VALUES ($(new_id),$(paramset.temperature));`)
    #Save the record to the dict and write to the database.
end

function new_game!(game_id, winner, loser)
    """This function writes a new game to the `games` table of the database;
    any new usernames or combinations of parameters are detected and handled
    in this function.
    """
    if winner ∉ keys(players)
        new_player!(winner)
    end
    if loser ∉ keys(players)
        new_player!(loser)
    end
    #Add unfamiliar usernames to the database.
    winner_id = players[winner].player_id
    loser_id = players[loser].player_id
    winner_params = (players[winner].is_bot==1) ? (temperature=0) : nothing
    loser_params = (players[loser].is_bot==1) ? (temperature=0) : nothing
    #For the time being, all bots use a temperature parameter of 0
    #(i.e. strict greedy choice).
    if isnothing(winner_params)
        winner_paramset_id = "NULL"
        #Human players should have a "NULL" entry for bot parameters.
    else
        if winner_params ∉ keys(bot_parameters)
            new_paramset!(winner_params)
            #If the combination of parameter values is new,
            #then write them to the db.
        end
        winner_paramset_id = bot_parameters[winner_params]
        #Get the id of the parameter set.
    end

    if isnothing(loser_params)
        loser_paramset_id = "NULL"
        #Human players should have a "NULL" entry for bot parameters.
    else
        if loser_params ∉ keys(bot_parameters)
            new_paramset!(loser_params)
            #If the combination of parameter values is new,
            #then write them to the db.
        end
        loser_paramset_id = bot_parameters[loser_params]
        #Get the id of the parameter set.
    end

    DBInterface.execute(
        db,
        sql`INSERT INTO
        games(game_id,winner_id,loser_id,winner_paramset_id,loser_paramset_id) VALUES
        ($(game_id),$(winner_id),$(loser_id),$(winner_paramset_id),$(loser_paramset_id))
        ;`)

end

bugged_game_ids = []
#Track which games encountered bugs.
new_games = Dict()

for filepath in ARGS
    CONFIG[:verbose] && println("Parsing data from $(filepath)...")
    data = JSON.parsefile(filepath,use_mmap=false)

    for breath in data
        game_id = breath["GameID"]

        if (game_id ∈ game_ids)||(game_id ∈ bugged_game_ids)
            continue
            #Skip games whose ids are already present in the database, as well
            #as games that have been identified to have experienced bugs.
        end

        state = parse(Int64,breath["State"])
        #Encoded states are represented as string in the JSON logs.

        if state ∉ STATE_SPACE
            push!(bugged_game_ids,game_id)
            if game_id ∈ keys(new_games)
                delete!(new_games,game_id)
            end
            continue
            #Sometimes, a glitch will result in impossible states. Games with
            #impossible states should be thrown out.
        end

        action = breath["Choice"]*10+breath["Feint"]
        #Actions are encoded as two-digit integers in which the first indicates
        #the card selected and the second indicates whether or not a feint was
        #used.


        winner = (breath["Result"]==-1) ? breath["UserName"] : breath["EnemyName"]
        loser = (breath["Result"]==-2) ? breath["UserName"] : breath["EnemyName"]
        #-1 means the player won; -2 means the enemy won.

        if game_id ∉ keys(new_games)
            new_games[game_id] = (
                winner = winner, loser = loser,
                breaths = [(state=state,action=action,is_winner=breath["Result"]+2)]
            )
        else
            push!(
                new_games[game_id].breaths,
                (state=state,action=action,is_winner=breath["Result"]+2)
            )
        end

    end

end


CONFIG[:verbose] && println("Finished parsing $(length(new_games)) games.")
CONFIG[:verbose] && println("Encountered $(length(bugged_game_ids)) games with invalid states:")
CONFIG[:verbose] && println(bugged_game_ids)
CONFIG[:verbose] && println("Writing games to database...")

for (game_id,game) in new_games
    new_game!(game_id,game.winner,game.loser)

    for breath in game.breaths
        DBInterface.execute(
            db,
            sql`INSERT INTO breaths(game_id,is_winner,state,action) VALUES
            ($(game_id),$(breath.is_winner),$(breath.state),$(breath.action))
            ;`)
    end

end


CONFIG[:verbose] && println("Finished.")
