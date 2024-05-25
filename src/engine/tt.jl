const LOWERBOUND = 0x00
const EXACT = 0x01
const UPPERBOUND = 0x02


struct TranspositionEntry
    key::UInt64
    score::Int64
    best_move::Move
    depth::UInt8
    flag::UInt8
end

mutable struct TranspositionBucket
    always_replace::TranspositionEntry
    replace_if_better::TranspositionEntry
end

struct TranspositionTable
    table::Vector{TranspositionBucket}
    no_bits::UInt64
end

function fibonacci_hash(key::UInt64, no_bits::UInt64)
    return (key * UInt64(11400714819323198485)) >> (64 - no_bits)
end

function TranspositionTable(size_in_mb::Int)
    nr_of_entries = size_in_mb * 1024 * 1024 ÷ sizeof(TranspositionBucket)

    # round to the nearest power of 2 (equal of smaller)
    no_bits = 63 - leading_zeros(nr_of_entries)
    nr_of_entries = 2^no_bits

    return TranspositionTable(
        [TranspositionBucket(TranspositionEntry(0, 0, Move(UInt8(0), UInt8(0), UInt8(0)), 0, 0), 
                             TranspositionEntry(0, 0, Move(UInt8(0), UInt8(0), UInt8(0)), 0, 0)) for _ in 1:nr_of_entries],
        UInt64(no_bits)
    )
end

const TT = TranspositionTable(64)

function store_tt_entry(tt::TranspositionTable, board::Board, score::Int, move::Move, depth::UInt8, flags::UInt8)
    key = board.history[board.ply].hash
    index = fibonacci_hash(key, tt.no_bits) + 1

    # update the 'always replace' entry
    tt.table[index].always_replace = TranspositionEntry(key, score, move, depth, flags)

    # update the 'replace if better' entry (i.e. if the depth is greater)
    if tt.table[index].replace_if_better.depth < depth
        tt.table[index].replace_if_better = TranspositionEntry(key, score, move, depth, flags)
    end
end

function retrieve_tt_entry(tt::TranspositionTable, board::Board)
    key = board.history[board.ply].hash
    index = fibonacci_hash(key, tt.no_bits) + 1

    # check if the key matches
    if tt.table[index].always_replace.key == key
        return tt.table[index].always_replace
    end

    if tt.table[index].replace_if_better.key == key
        return tt.table[index].replace_if_better
    end



    return nothing
end

function tt_best_score(tt::TranspositionTable, board::Board)
    entry = retrieve_tt_entry(tt, board)
    if isnothing(entry)
        return nothing
    end

    return entry.score
end

function tt_best_move(tt::TranspositionTable, board::Board)
    entry = retrieve_tt_entry(tt, board)
    if isnothing(entry)
        return nothing
    end

    return entry.best_move
end

function get_pv(tt::TranspositionTable, board::Board, depth::Int)
    board_copy = copy(board)
    pv = ""

    for i in 1:depth
        best_move = tt_best_move(tt, board_copy)
        if isnothing(best_move)
            break
        end
        pv *= string(best_move) * " "
        do_move!(board_copy, best_move)
    end

    return pv
end