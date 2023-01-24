using JSON

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

NAIVE_TRANSITIONS = strkeys2int(
        JSON.parsefile("archived/envs/naive_transitions.json",use_mmap=false)
    )

println(maximum([length(successors) for successors in values(NAIVE_TRANSITIONS)]))
