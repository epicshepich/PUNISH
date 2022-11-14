STATE_SPACE = Set(JSON.parsefile("../envs/statespace.json",use_mmap=false))
#Load the state space in order to ensure all states are valid before writing
#games to database.

abstract type PunishState end

struct DuelingState <: PunishState
    breath::Int64
    hand::NamedTuple{(:guard, :rush, :dodge, :strike, :punish), NTuple{5, Int64}}
    status::NamedTuple{(:hp, :exhausted, :feinted), Tuple{Int64, Bool, Bool}}
    enemy::NamedTuple{(:hp, :hand_size, :exhausted, :feinted), Tuple{Int64, Int64, Bool, Bool}}
    discard::NamedTuple{(:guard, :rush, :dodge, :strike, :punish), NTuple{5, Int64}}
end

struct WinState <: PunishState end
struct LossState <: PunishState end

function decode_state(coding::Int64)
    """This function decodes a game state that has been
    encoded as an integer and returns a `DuelingState` structure."""
    if coding < 0
        return [WinState(),LossState()][abs(coding)]
    end
    digit_list = reverse(digits(coding))
    #Convert the encoding into an array of digits, and reverse it so
    #that the leftmost digit is the first entry in the array.
    state = DuelingState(
        digit_list[1],
        (
            guard=digit_list[2],
            rush=digit_list[3],
            dodge=digit_list[4],
            strike=digit_list[5],
            punish=digit_list[6]
        ),
        (
            hp=digit_list[7],
            exhausted=Bool(digit_list[8]),
            feinted=Bool(digit_list[9])
        ),
        (
            hp=digit_list[10],
            hand_size=digit_list[11],
            exhausted=Bool(digit_list[12]),
            feinted=Bool(digit_list[13])
        ),
        (
            guard=digit_list[14],
            rush=digit_list[15],
            dodge=digit_list[16],
            strike=digit_list[17],
            punish=digit_list[18]
        )
    )
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

function possible_actions(state::DuelingState)
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

function possible_actions(state::Int)
     return possible_actions(decode_state(state))
end

function possible_actions(state::WinState)
     return [90]
end

function possible_actions(state::LossState)
     return [90]
end
#Use Rest without feint as a sentinel action for Win/Loss states.
