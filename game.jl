using Combinatorics
using StatsBase
using Random

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

function encode_state(state::DuelingState)
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

function encode_state(state::WinState)
    return -1
    #Encode a winning state as -1.
end

function encode_state(state::LossState)
     return -2
    #Encode a losing state as -2.
end


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
    card_identifiers = Dict{Int64,Symbol}(1=>:guard,2=>:rush,3=>:dodge,4=>:strike,5=>:punish,9=>:rest)
    card = card_identifiers[digits(coding)[2]]
    feint = Bool(digits(coding)[1])
    return (card,feint)
end

function possible_actions(state::DuelingState)
    """This function returns an encoded list of the possible actions
    that can be taken by the player from a given state."""
    actions = Int64[]
    if (state.status.exhausted) || (state.breath==5)
        return Int64[encode_action((:rest,false))]
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
     return Int64[90]
end

function possible_actions(state::LossState)
     return Int64[90]
end
#Use Rest without feint as a sentinel action for Win/Loss states.

function ΔHP(cards::NamedTuple{(:player,:enemy),Tuple{Symbol,Symbol}})
    """This function computes the change in HP incurred by each player
    when a pair of cards is played. Priority is not taken into account here."""
    if cards.player == cards.enemy
        return (player=0, enemy=0)
        #No damage is dealt in a clash.
    end

    damage_map = Dict{Symbol,Int64}(:rush=>1,:strike=>2,:punish=>3)
    player_Δ = -get(damage_map,cards.enemy,0) *
        #Base damage.
        (cards.player==:dodge ? cards.enemy==:rush : 1) +
        #Dodging reduces base damage from non-Rush attacks to 0.
        (cards.player==:guard ? Int(cards.enemy in keys(damage_map)) : 0)
        #Guarding reduces damage from any attacks by 1.
    enemy_Δ = -get(damage_map,cards.player,0) *
        #Base damage.
        (cards.enemy==:dodge ? cards.player==:rush : 1) +
        #Dodging reduces base damage from non-Rush attacks to 0.
        (cards.enemy==:guard ? Int(cards.player in keys(damage_map)) : 0)
        #Guarding reduces damage from any attacks by 1.

    return (player=player_Δ, enemy=enemy_Δ)

end

priority = Dict{Symbol, Int64}(
    :rest => -1,
    :guard => 0,
    :rush => 1,
    :dodge => 2,
    :strike => 3,
    :punish => 4
)

function breath(
    state::DuelingState,
    picks::NamedTuple{(:player,:enemy),Tuple{Symbol,Symbol}},
    feints::NamedTuple,
    )
    """This function takes complete information about one Breath (i.e. the input state,
    as well as both players' picked cards and the results of any feints) and returns the
    successor state.

    This function is designed to be deterministic and single-valued. To that end, successors
    of a fourth breath are returned as a single placeholder whose `breath` field is set to 5;
    we will use a different function to compute all possible re-deals for the start of a new
    measure.
    """
    plays = (
        player=isnothing(feints.player) ? picks.player : feints.player,
        enemy=isnothing(feints.enemy) ? picks.enemy : feints.enemy
    )
    #Track the actual cards that are played
    #(i.e. if feinting, the drawn card; otherwise, the picked card).

    successor = DuelingState(
        state.breath + 1,
        (; [(card,count-Int(card==picks.player)) for (card,count) in pairs(state.hand)]...),
        #Whichever card was picked is removed from the hand.
        (
            hp = state.status.hp+ΔHP(plays).player,
            #Compute the change in HP and apply it to the HP total.
            exhausted = (plays.player==:punish),
            #If the player played Punish this breath they become exhausted.
            feinted = (!isnothing(feints.player)||state.status.feinted)
            #The player has feinted if they feinted this breath or in a previous breath.
        ),
        (
            hp = state.enemy.hp+ΔHP(plays).enemy,
            hand_size = (state.enemy.hand_size-Int(plays.enemy!=:rest)),
            #The enemy's hand size decreases by 1 unless they rested after a Punish.
            exhausted= (plays.enemy==:punish),
            feinted = (!isnothing(feints.enemy)||state.enemy.feinted)
        ),
        (; [(card,count+sum([picks...,feints...].==card))
            for (card,count) in pairs(state.discard)]...),
        #For each card type in the discard pile, increment the count for every
        #pick and every feint that matched that type this breath.
    )

    if successor.status.hp <= 0
        if successor.enemy.hp <= 0
            return priority[plays.player] < priority[plays.enemy] ? WinState() : LossState()
            #If both players would be reduced to nonpositive HP this breath, the winner
            #is determined by card priority.
        else
            return LossState()
            #If just the player would be reduced to nonpositive HP, it is a loss.
        end
    elseif successor.enemy.hp <= 0
        return WinState()
        #If just the enemy would be reduced to nonpositive HP, it is a win.
    else
        if successor.breath == 5
            successor = DuelingState(
                successor.breath,
                successor.hand,
                (hp=min(3,successor.status.hp+1),exhausted=false,feinted=false),
                (hp=min(3,successor.enemy.hp+1),hand_size=successor.enemy.hand_size,exhausted=false,feinted=false),
                successor.discard
            )
            #When entering a Breath 5 state, both players heal 1 HP (to a max of 3),
            #and status effects (feinted/exhausted) are cleared.
        end

        return successor
        #If both the player and the enemy have positive HP, then the duel continues.
    end
end

function redeal(state::DuelingState)
    """This function takes an end-of-measure ("Breath 5") state and returns a
    dict mapping each possible beginning-of-new-measure state to its
    probability of occuring based on a random redealing of cards."""
    successors = Int64[]
    for draws in combinations(
        vcat([repeat([card],count) for (card, count) in pairs(state.discard)]...),
        5-sum(state.hand)
    )
        #Randomly draw a number of cards equal to the difference between 5 and your
        #ending hand size from the cards visible in the discard pile.

        hand = (; [(card,count+sum(draws.==card)) for (card,count) in pairs(state.hand)]...)
        #Add the drawn cards to the cards remaining in your hand at the end of the Breath.

        for discards in combinations(
            vcat([repeat([card],count-sum(draws.==card)) for (card, count) in pairs(state.discard)]...),
            3
        )
            #Randomly choose 3 cards to go face-up into the discard pile from the cards
            #that remain after you've made your draws.
            discard = (; [(card,sum(discards.==card)) for (card,count) in pairs(state.discard)]...)
            #These three cards replace the old discard pile. The rest of the cards fill the
            #enemy's hand and the face-down deck.

            successor = DuelingState(
                1, #The first breath of a new measure.
                hand,
                (hp=state.status.hp,exhausted=false,feinted=false),
                #Between measures, each player heals 1HP up to a maximum of 3,
                #and status effects are removed.
                (hp=state.enemy.hp,hand_size=5,exhausted=false,feinted=false),
                discard
            )

            push!(successors,encode_state(successor))
        end
    end
    return proportionmap(successors)
end


function redeal(state::Int)
    return redeal(decode_state(state))
end

function enemy_states(state::DuelingState)
    """This function takes a DuelingState based on the player's incomplete
    information and returns a dict mapping each possible state of the enemy's
    incomplete information to a probability based on card counts."""

    enemy_states = Int64[]

    for enemy_hand in combinations(
        vcat([repeat([card],3-state.hand[card]-state.discard[card]) for card in keys(state.discard)]...),
        state.enemy.hand_size
    )
    #The enemy's hand could be any member of the set of all possible combinations of n cards chosen
    #from whichever cards the player cannot see, where n is the enemy's hand size.
        enemy_state = DuelingState(
            state.breath,
            (; [(card,sum(enemy_hand.==card)) for card in [:guard,:rush,:dodge,:strike,:punish]]...),
            (hp=state.enemy.hp, exhausted=state.enemy.exhausted, feinted=state.enemy.feinted),
            (
                hp=state.status.hp,
                hand_size=sum(state.hand),
                exhausted=state.status.exhausted,
                feinted=state.status.feinted
            ),
            state.discard
        )
        #Breath number, discard, and statuses are all common information.
        push!(enemy_states,encode_state(enemy_state))
    end
    return proportionmap(enemy_states)
    #Return normalized value counts of the possible enemy states.
end

function transitionmap(state::DuelingState,action::Tuple{Symbol,Bool}; empirical_strategies=Dict())
    """This function takes a `DuelingState` and an action tuple and
    returns a dict mapping all possible successor states to the probability of
    that successor resulting from taking the given action from the given state, i.e.
    a dict of (successor, transition probability) pairs.

    The `empirical_strategies` keyword argument allows you to pass in a dictionary of
    (state, action probability map) pairs corresponding to the enemy's empirically observed
    mixed strategies (probability distribution over possible actions). For any states
    not in the dictionary, a uniform distribution over all possible actions will be assumed.
    """
    transitions = Dict{Int64,Float64}()
    for (enemy_state,p_enemy_state) in enemy_states(state)
        #Loop over all possible enemy hands.
        enemy_actions = get(
            empirical_strategies,
            enemy_state,
            Dict{Int64,Float64}(enemy_action=>1/length(possible_actions(enemy_state))
                for enemy_action in possible_actions(enemy_state) )
        )
        #Look up the enemy's state in the empirical strategies dict. If the entry is missing,
        #assume a uniform mixed strategy (equal probability of all possible actions).

        decoded_enemy_state = decode_state(enemy_state)

        for (enemy_action,p_enemy_action) in enemy_actions
            #Loop over all possible enemy actions.

            deck = vcat([repeat([card],3-(
                        state.hand[card]+
                        decoded_enemy_state.hand[card]+
                        state.discard[card]
                        ))
                    for card in keys(state.discard)]...)
            #With a fixed enemy hand, we have certainty about which cards are in the deck.

            feints = [(player=pf,enemy=ef) for (pf,ef) in zip(
                (action[2] ? deck : repeat([nothing],length(deck))),
                (decode_action(enemy_action)[2] ? reverse(deck) : repeat([nothing],length(deck))),
            )]
            #Generate the set of possible outcomes of the feints taken.
            if length(feints) == 0
                feints = [(player=nothing,enemy=nothing)]
            end

            for (feint, p_feint) in proportionmap(feints)
                #Loop over the distinct feint outcomces.
                picks = (player=action[1],enemy=decode_action(enemy_action)[1])
                if state.breath != 5
                    successors = Dict(
                        encode_state(breath(state,picks,feint))=>1
                    )
                    #Simulate a Breath using the fixed player and enemy actions and feint outcomes.
                else
                    successors = redeal(state)
                    #If the result is a Breath 5 state, then generate the possible redeals
                    #and their probabilities. Otherwise, there is a single successor that
                    #occurs with probability 1.
                end
                for (successor,p_redealt) in successors
                    p = p_enemy_state * p_enemy_action * p_feint * p_redealt
                    #Multiply all the conditional probabilities to get the overall
                    #probability of the successor resulting from the player taking
                    #the given action from the given state.
                    if successor in keys(transitions)
                        transitions[successor] += p
                    else
                        transitions[successor] = p
                    end
                    #If this successor has already been mapped out, add the
                    #probability from this path to it.
                end
            end
        end
    end
    return transitions
end


function transitionmap(state::WinState,action::Tuple{Symbol,Bool};kwargs...)
    return Dict{Int64,Float64}(-1=>1.0)
end
function transitionmap(state::LossState,action::Tuple{Symbol,Bool};kwargs...)
    return Dict{Int64,Float64}(-2=>1.0)
end
#Win/Loss are "absorbing states"; when the game is over, it's over forever.

function transitionmap(state::Int,action::Int; kwargs...)
     return transitionmap(decode_state(state),decode_action(action);kwargs...)
end

function transitionmap(state::Int;kwargs...)
    """This dispatch creates the transition map for every possible action
    that can be taken at the given state."""
    return Dict(
        action => transitionmap(state,action;kwargs...)
        for action in possible_actions(state)
    )
end

function state_int2vector(state)
    return reverse(digits(state).*1.0)
    #Reverse the digits so the first component is breath number; multiply by
    #1.0 so vectors are float-valued.
end

function state_vector2int(state_vector)
    return sum([convert(Int64, component*10^(i-1) ) for (i,component) in enumerate(reverse(state_vector))])
    #Multiply each digit by the power of 10 corresponding to its place in the number; convert back to integers
    #to avoid roundoff error.
end

ACTION_COMPONENTS = [10,11,20,21,30,31,40,41,50,51,90]
function strategy_dict2vector(strategy_dict::Dict{Int64,Float64})
    return [get(strategy_dict,action,0) for action in ACTION_COMPONENTS]
    #Unavailable actions get a probability of 0.
end


function strategy_vector2dict(strategy_vector)
    """This function converts a raw strategy vector back into a dict
    by simply mapping each action to the value of the corresponding component."""
    return Dict(action=>component for (action,component) in zip(ACTION_COMPONENTS,strategy_vector))
end

function strategy_vector2dict(strategy_vector,state::Int64)
    """This dispatch uses the corresponding state to filter out unavailable actions
    and normalize the probabilities."""
    raw_strategy = strategy_vector2dict(strategy_vector)
    #Get the raw dictionary from the vector.
    actions = possible_actions(state)
    normalizer = sum(raw_strategy[action] for action in actions)
    #Sum together the raw probabilities of each possible action to get the denominator.
    return Dict(action => raw_strategy[action]/normalizer for action in actions)
    #Map each possible action to its normalized probability.
end
