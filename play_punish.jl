using Random
using StatsBase
using JSON

q_filepaths = Dict(
    "naive" => "q_naive.json"
)

function strkeys2int(d::Dict{String,Any})
    """This is a function that recursively converts the keys of a `Dict{String,Any}`
    and its nested `Dict{String,Any}` values into `Int64` data."""
    return Dict(parse(Int64,key)=>strkeys2int(value) for (key,value) in d)
    #Parse all keys as integers and then call this function on the value.
    #If the value is a `Dict{String,Any}`, then its keys will be converted too;
    #if not, the value will be left alone.
end

function strkeys2int(value::Any)
    return value
end


LOGO = """
   ▄███████▄ ███    █▄  ███▄▄▄▄    ▄█     ▄████████    ▄█    █▄
  ███    ███ ███    ███ ███▀▀▀██▄ ███    ███    ███   ███    ███
  ███    ███ ███    ███ ███   ███ ███▌   ███    █▀    ███    ███
  ███    ███ ███    ███ ███   ███ ███▌   ███         ▄███▄▄▄▄███▄▄
▀█████████▀  ███    ███ ███   ███ ███▌ ▀███████████ ▀▀███▀▀▀▀███▀
  ███        ███    ███ ███   ███ ███           ███   ███    ███
  ███        ███    ███ ███   ███ ███     ▄█    ███   ███    ███
 ▄████▀      ████████▀   ▀█   █▀  █▀    ▄████████▀    ███    █▀
"""
#https://patorjk.com/software/taag/#p=display&h=0&f=Delta%20Corps%20Priest%201&t=PUNISH

function prompt_selection(prompt::String,checkvalid::Function)
    response = nothing
    while true
        println(prompt)
        response = readline()
        if checkvalid(response)
            break
        else
            print("Invalid selection. ")
        end
    end
    return response
end


function get_players()
    println(LOGO)
    mode = prompt_selection("""
    Select game mode:

    [0] Player vs CPU
    [1] CPU vs CPU
    [2] Player vs Player (WIP)
    """,(x -> x in ["0","1","2"]))

    p1_username = nothing
    p1_cpu = nothing
    p2_username = nothing
    p2_cpu = nothing
    p1_temp = nothing
    p2_temp = nothing
    p1_q_function = nothing
    p2_q_function = nothing

    if mode == "1"
        p1_cpu_selection = prompt_selection(
            """
            Select CPU agent (P1):

            [0] Naïve
            """, (x -> x in ["0"])
        )
        p1_cpu = Dict("0"=>"naive")[p1_cpu_selection]

        p1_temp = parse(Float64,prompt_selection(
            """
            Set CPU temperature parameter (P1):
            """, (t -> !isnothing(tryparse(Float64,t))&&(parse(Float64,t)>=0))
        ))

        p1_q_function = strkeys2int(JSON.parsefile(q_filepaths[p1_cpu],use_mmap=false))

    else
        println("""
        Enter username (P1):
        """)
        p1_username = readline()
    end

    if mode == "2"
        println("""
        Enter username (P2):
        """)
        p2_username = readline()
    else
        p2_cpu_selection = prompt_selection(
            """
            Select CPU agent (P2):

            [0] Naïve
            """, (x -> x in ["0"])
        )
        p2_cpu = Dict("0"=>"naive")[p2_cpu_selection]

        p2_temp = parse(Float64,prompt_selection(
            """
            Set CPU temperature parameter (P2):
            """, (t -> !isnothing(tryparse(Float64,t))&&(parse(Float64,t)>=0))
        ))

        p2_q_function = strkeys2int(JSON.parsefile(q_filepaths[p2_cpu],use_mmap=false))
    end

    players = (
        p1 = (
            name=(mode=="1") ? p1_cpu : p1_username,
            type=(mode=="1") ? :cpu : :human,
            temperature=p1_temp,
            q_function=p1_q_function
        ),
        p2 = (
            name=(mode=="2") ? p2_username : p2_cpu,
            type=(mode=="2") ? :human : :cpu,
            temperature=p2_temp,
            q_function=p2_q_function
        )
    )

    return players
end

struct GameState
    measure::Int64
    breath::Int64
    p1::NamedTuple{(:hand, :hp, :exhausted, :feinted), Tuple{NamedTuple, Int64, Bool, Bool}}
    p2::NamedTuple{(:hand, :hp, :exhausted, :feinted), Tuple{NamedTuple, Int64, Bool, Bool}}
    discard::NamedTuple{(:guard, :rush, :dodge, :strike, :punish), NTuple{5, Int64}}
    deck::NamedTuple{(:guard, :rush, :dodge, :strike, :punish), NTuple{5, Int64}}
end

struct EndGameState
    winner::Symbol
end

struct PlayerState
    breath::Int64
    hand::NamedTuple{(:guard, :rush, :dodge, :strike, :punish), NTuple{5, Int64}}
    status::NamedTuple{(:hp, :exhausted, :feinted), Tuple{Int64, Bool, Bool}}
    enemy::NamedTuple{(:hp, :hand_size, :exhausted, :feinted), Tuple{Int64, Int64, Bool, Bool}}
    discard::NamedTuple{(:guard, :rush, :dodge, :strike, :punish), NTuple{5, Int64}}
end


function encode_state(state::PlayerState)
    """This function encodes a `DuelingState` structure as an integer in which each digit
    corresponds to an attribute of the game state."""
    digit_list = vcat(
        [state.breath],
        [card for card in state.hand],
        [Int(stat) for stat in state.status],
        [Int(stat) for stat in state.enemy],
        [card for card in state.discard]
    )
    #Sequentially add each attribute of the game state to a list of digits.
    return sum([digit*10^(i-1) for (i, digit) in enumerate(reverse(digit_list))])
    #Convert the list of digits into an integer by multiplying each digit by the
    #next power of 10 and adding them all together. Reverse the array so that
    #the first digit in the array gets multiplied by the largest power of 10
    #and becomes the leftmost digit in the resulting integer.
end

function encode_action(action::Tuple{Symbol,Bool})
    """This function takes an action represented as a (card, is_feint) tuple and
    encodes it as an integer in which the first digit represents the card used and
    the second represents whether or not the action is a feint.
    """
    card_identifiers = (guard=1,rush=2,dodge=3,strike=4,punish=5,rest=9)
    #Encode cards as their priority +1; encode a "rest"/the nothing card as a 9.
    return card_identifiers[action[1]]*10+Int(action[2])
end

function decode_action(coding::Int)
    """This function decodes an action encoded as an integer back into a (card,is_feint) tuple."""
    card_identifiers = Dict(1=>:guard,2=>:rush,3=>:dodge,4=>:strike,5=>:punish,9=>:rest)
    card = card_identifiers[digits(coding)[2]]
    feint = Bool(digits(coding)[1])
    return (card,feint)
end

function possible_actions(state::PlayerState)
    """This function returns an encoded list of the possible actions
    that can be taken by the player from a given state."""
    actions = []
    if (state.status.exhausted) || (state.breath==5)
        return [encode_action((:rest,false))]
        #When the player is exhausted, the only action they can take
        #is rest (which by definition does not involve a feint).
        #Use Rest without reint as a sentinel action for intermediary
        #"Breath 5" states.
    end

    for (card,count) in pairs(state.hand)
        if count == 0
            continue
        else
            push!(actions,encode_action((card,false)))
            #The player can play any card that they hold at least 1 of.
            if !state.status.feinted
                push!(actions,encode_action((card,true)))
                #If they have not already feinted this breath, they also
                #have the option of discarding that card to perform a feint.
            end
        end
    end
    return actions
end

CARDS = [:guard,:rush,:dodge,:strike,:punish]

function get_playerstate(gamestate::GameState,player::Symbol)
    opponent = (player==:p1) ? :p2 : :p1
    return PlayerState(
        gamestate.breath,
        getfield(gamestate,player).hand,
        (
            hp=getfield(gamestate,player).hp,
            exhausted=getfield(gamestate,player).exhausted,
            feinted=getfield(gamestate,player).feinted
        ),
        (
            hp=getfield(gamestate,opponent).hp,
            hand_size=sum(getfield(gamestate,opponent).hand),
            exhausted=getfield(gamestate,opponent).exhausted,
            feinted=getfield(gamestate,opponent).feinted
        ),
        gamestate.discard
    )
end


function start_game()
    stack = shuffle(
        vcat([repeat([card],3) for card in [:guard,:rush,:dodge,:strike,:punish]]...)
    )
    #Shuffle the stack of 15 cards.
    p1_hand = (; [(card,get(countmap(stack[1:5]),card,0)) for card in CARDS]...)
    #Deal 5 to P1.
    p2_hand = (; [(card,get(countmap(stack[6:10]),card,0)) for card in CARDS]...)
    #Deal the next 5 to P2.
    discard = (; [(card,get(countmap(stack[11:13]),card,0)) for card in CARDS]...)
    #Turn the next 3 face-up into the discard pile.
    deck = (; [(card,get(countmap(stack[14:15]),card,0)) for card in CARDS]...)
    #The last 2 stay in the deck for feints.
    starting_state = GameState(
        1,
        1,
        (hand=p1_hand, hp=3, exhausted=false, feinted=false),
        (hand=p2_hand, hp=3, exhausted=false, feinted=false),
        discard,
        deck
    )
    return starting_state
end


function ΔHP(plays::NamedTuple{(:p1,:p2),Tuple{Symbol,Symbol}})
    """This function computes the change in HP incurred by each player
    when a pair of cards is played. Priority is not taken into account here."""
    if plays.p1 == plays.p2
        return (p1=0, p2=0)
        #No damage is dealt in a clash.
    end

    damage_map = Dict(:rush=>1,:strike=>2,:punish=>3)
    p1_Δ = -get(damage_map,plays.p2,0) *
        #Base damage.
        (plays.p1==:dodge ? plays.p2==:rush : 1) +
        #Dodging reduces base damage from non-Rush attacks to 0.
        (plays.p1==:guard ? Int(plays.p2 in keys(damage_map)) : 0)
        #Guarding reduces damage from any attacks by 1.
    p2_Δ = -get(damage_map,plays.p1,0) *
        #Base damage.
        (plays.p2==:dodge ? plays.p1==:rush : 1) +
        #Dodging reduces base damage from non-Rush attacks to 0.
        (plays.p2==:guard ? Int(plays.p1 in keys(damage_map)) : 0)
        #Guarding reduces damage from any attacks by 1.

    return (p1=p1_Δ, p2=p2_Δ)

end

PRIORITY = Dict(
    :rest => -1,
    :guard => 0,
    :rush => 1,
    :dodge => 2,
    :strike => 3,
    :punish => 4
)

function breath(
    state::GameState,
    picks::NamedTuple{(:p1,:p2),Tuple{Symbol,Symbol}},
    feinting::NamedTuple{(:p1,:p2),Tuple{Bool,Bool}},
    )
    """This function takes complete information about one Breath (i.e. the input state,
    as well as both players' picked cards and the results of any feints) and returns the
    successor state.

    This function is designed to be deterministic and single-valued. To that end, successors
    of a fourth breath are returned as a single placeholder whose `breath` field is set to 5;
    we will use a different function to compute all possible re-deals for the start of a new
    measure.
    """
    feints = (
        p1 = feinting.p1 ? vcat([repeat([card],count) for (card,count) in pairs(state.deck)]...)[1] : nothing,
        p2 = feinting.p2 ? reverse(vcat([repeat([card],count) for (card,count) in pairs(state.deck)]...))[1] : nothing
    )

    plays = (
        p1=isnothing(feints.p1) ? picks.p1 : feints.p1,
        p2=isnothing(feints.p2) ? picks.p2 : feints.p2
    )

    #Track the actual cards that are played
    #(i.e. if feinting, the drawn card; otherwise, the picked card).

    successor = GameState(
        state.measure,
        state.breath + 1,
        (
            hand = (; [(card,count-Int(card==picks.p1)) for (card,count) in pairs(state.p1.hand)]...),
            hp = state.p1.hp + ΔHP(plays).p1,
            exhausted = (plays.p1==:punish),
            feinted = (!isnothing(feints.p1)||state.p1.feinted)
        ),
        (
            hand = (; [(card,count-Int(card==picks.p2)) for (card,count) in pairs(state.p2.hand)]...),
            hp = state.p2.hp + ΔHP(plays).p2,
            exhausted = (plays.p2==:punish),
            feinted = (!isnothing(feints.p2)||state.p2.feinted)
        ),
        (; [(card,count+sum([picks...,feints...].==card))
            for (card,count) in pairs(state.discard)]...),
        #For each card type in the discard pile, increment the count for every
        #pick and every feint that matched that type this breath.
        (; [(card,count-sum([feints...].==card))
            for (card,count) in pairs(state.deck)]...)
    )

    if successor.p1.hp <= 0
        if successor.p2.hp <= 0
            return PRIORITY[plays.p1] < PRIORITY[plays.p2] ? EndGameState(:p1) : EndGameState(:p2)
            #If both players would be reduced to nonpositive HP this breath, the winner
            #is determined by card priority.
        else
            return EndGameState(:p2)
        end
    elseif successor.p2.hp <= 0
        return EndGameState(:p1)
    else
        if successor.breath == 5
            return redeal(successor)
        else
            return successor
        end
    end
end


function redeal(state::GameState)
    stack = shuffle(
        vcat([repeat([card],state.discard[card]+state.deck[card]) for card in [:guard,:rush,:dodge,:strike,:punish]]...)
    )
    #Shuffle the discard and deck together.
    p1_draws = stack[1:5-sum(state.p1.hand)]
    p2_draws = stack[5-sum(state.p1.hand)+1:5-sum(state.p1.hand)+5-sum(state.p2.hand)]
    discard_pile = stack[5-sum(state.p1.hand)+5-sum(state.p2.hand)+1:5-sum(state.p1.hand)+5-sum(state.p2.hand)+3]
    deck_pile = stack[5-sum(state.p1.hand)+5-sum(state.p2.hand)+3:end]

    p1_hand = (; [(card,count+get(countmap(p1_draws),card,0)) for (card,count) in pairs(state.p1.hand)]...)
    #Deal 5 to P1.
    p2_hand = (; [(card,count+get(countmap(p2_draws),card,0)) for (card,count) in pairs(state.p2.hand)]...)
    #Deal the next 5 to P2.
    discard = (; [(card,get(countmap(discard_pile),card,0)) for card in CARDS]...)
    #Turn the next 3 face-up into the discard pile.
    deck = (; [(card,get(countmap(deck_pile),card,0)) for card in CARDS]...)
    #The last 2 stay in the deck for feints.
    redealt_state = GameState(
        state.measure+1,
        1,
        (hand=p1_hand, hp=min(3,state.p1.hp+1), exhausted=false, feinted=false),
        (hand=p2_hand, hp=min(3,state.p2.hp+1), exhausted=false, feinted=false),
        discard,
        deck
    )
    return redealt_state
end

function ε_greedy_choice(action_values::Dict, temp::Float64)
    """This function implements an ε-greedy policy, which uses a Boltzmann distribution
    based on state-action values to make a stochastic choice of the action from
    a given state."""
    actions = [action for action in keys(action_values)]
    #List all the actions from the state.
    raw_weights = [exp(value/temp) for (action,value) in action_values]
    #Compute the un-normalized Boltzmann factor for each action from the given state.
    weights = raw_weights ./ sum(raw_weights)
    #Normalize the Boltzmann factors by dividing by their sum.
    return sample(actions, Weights(weights))
    #Use weighted sampling to choose which action to take.
end


function breath_prompt(state::PlayerState,player::NamedTuple)
    if player.type == :human
        println("YOUR STATUS:")
        println(state.status)
        println("\nENEMY STATUS:")
        println(state.enemy)
        println("\nHAND:")
        println(state.hand)
        println("\nDISCARD PILE:")
        println(state.discard)

        actions = possible_actions(state)

        action_response = prompt_selection("""
        Select action (card, feint):
        """*join([
            "[$(a)] $(decode_action(a))\n" for a in actions
        ]),(x -> tryparse(Int64,x) in actions))

        return decode_action(parse(Int64,action_response))

    else
        return decode_action(ε_greedy_choice(player.q_function[encode_state(state)],player.temperature))
    end
end


function play(players)
    gamestate = start_game()
    while !(gamestate isa EndGameState)
        println("""MEASURE $(gamestate.measure) BREATH $(gamestate.breath)""")
        p1_action = breath_prompt(get_playerstate(gamestate,:p1),players.p1)
        p2_action = breath_prompt(get_playerstate(gamestate,:p2),players.p2)
        gamestate = breath(
            gamestate,
            (p1=p1_action[1],p2=p2_action[1]),
            (p1=p1_action[2],p2=p2_action[2])
        )
        println("$(players.p1.name) plays $(p1_action)")
        println("$(players.p2.name) plays $(p2_action)")
    end
    println("Game over. $(players[gamestate.winner].name) wins!")
    again = prompt_selection("Play again? [y/n]",(x->x in ["y","Y","n","N"]))

    if again in ["y","Y"]
        play(players)
    end


end




play(get_players())
