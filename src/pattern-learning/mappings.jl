function move_to_hash(mv, board; hash_func::Symbol)
    if hash_func == :simple
        return ((UInt(mv.src) << 10) | (UInt(mv.dst) << 4) | UInt(mv.type))
    elseif hash_func == :complex
        return ((UInt(count_ones(board.bb_occ)) << 16) | (UInt(mv.src) << 10) | (UInt(mv.dst) << 4) | UInt(mv.type))
    else
        error("Unknown hash function")
    end
end