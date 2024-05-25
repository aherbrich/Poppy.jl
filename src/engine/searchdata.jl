const MAX_DEPTH = 1023

mutable struct SearchStats
    nodes::Array{UInt64}            # number of nodes searched at each depth
    total_nodes::UInt64             # total number of nodes searched
    
    qnodes::Array{UInt64}           # number of quiescence nodes searched at each depth
    total_qnodes::UInt64            # total number of quiescence nodes searched

    cutoffs::Array{UInt64}          # number of beta cutoffs at each depth (excluding qsearch)
    qcutoffs::Array{UInt64}         # number of beta cutoffs at each depth (only qsearch)

    tt_hits::Array{UInt64}          # number of transposition table hits at each depth
    tt_probes::Array{UInt64}        # number of transposition table probes at each depth
    tt_collisions::Array{UInt64}    # number of transposition table collisions at each depth

    # TODO: add more search statistics here
end

function SearchStats()
    return SearchStats(zeros(UInt64, MAX_DEPTH), 0,  zeros(UInt64, MAX_DEPTH), 0, 
                       zeros(UInt64, MAX_DEPTH), zeros(UInt64, MAX_DEPTH), 
                       zeros(UInt64, MAX_DEPTH), zeros(UInt64, MAX_DEPTH), zeros(UInt64, MAX_DEPTH))
end

mutable struct SearchLimits
    max_depth::Int                  # maximum depth to search
    nodes_limit::UInt64             # maximum number of nodes to search
    time_limit::UInt64              # end time of the search
    stop::Bool                      # whether to stop the search

    start_time::UInt64              # start time of the search

    # TODO: add more search limits (especially the ones for uci compatibility)
end

function SearchLimits(;max_depth::Int=MAX_DEPTH, nodes_limit::UInt64=typemax(UInt64), time_limit::UInt64=typemax(UInt64))
    return SearchLimits(max_depth, nodes_limit, time_limit, false, time_ms())
end