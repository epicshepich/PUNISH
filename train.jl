#Time log: 1 hour 50 minutes
using StatsBase
using JSON
using BenchmarkTools
using DataFrames
using CUDA
using Distributed
using SharedArrays
include("game.jl")

addprocs(4)


STATE_SPACE = Int64[JSON.parsefile("statespace.json",use_mmap=false)...]

trans = Vector{Dict{Int64,Dict{Int64,Float64}}}(undef,length(STATE_SPACE))

"""NAIVE_TRANSITIONS = Dict(
        state => Dict(
            action => transitionmap(state,action)
            for action in possible_actions(state)
        )
        for state in smallstatespace
    )"""

@btime for i in 1:1000
    trans[i] = Dict(
        action => transitionmap(STATE_SPACE[i],action)
        for action in possible_actions(STATE_SPACE[i])
    )

end
println(first(trans,100))

"""smallstatespace = CuArray(first(STATE_SPACE,1000))
successors = CuArray(Vector{Vector{Int64}}(undef,length(smallstatespace)))
probs = CuArray(Vector{Vector{Float64}}(undef,length(smallstatespace)))
#State, action, list of successors
const n = length(STATE_SPACE)
const THREADS_PER_BLOCK = 256


function get_transitions(successors, probs, statespace)
    x = (blockIdx().x - 1) * blockDim().x + threadIdx().x
    transitions = transitionmap(statespace[x],first(possible_actions(statespace[x])))

    @inbounds successors[x] = collect(keys(transitions))
    @inbounds probs[x] =  collect(values(transitions))
    return
end

@cuda threads=THREADS_PER_BLOCK blocks=n÷THREADS_PER_BLOCK get_transitions(successors, probs, smallstatespace)

println(transitions)

@btime NAIVE_TRANSITIONS = Dict(
        state => Dict(
            action => transitionmap(state,action)
            for action in possible_actions(state)
        )
        for state in smallstatespace
    )
"""
