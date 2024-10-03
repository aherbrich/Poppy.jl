function move_to_hash(mv::Move, board::Board; hash_func::Symbol)
    if hash_func == :v1
        return ((UInt(mv.src) << 10) | (UInt(mv.dst) << 4) | UInt(mv.type))
    elseif hash_func == :v2
        piece_type = board.squares[mv.src + 1]
        return ((UInt(mv.src) << 10) | (UInt(mv.dst) << 4) | UInt(piece_type))
    elseif hash_func == :v3
        piece_type = board.squares[mv.src + 1]
        return ((UInt(mv.src) << 14) | (UInt(mv.dst) << 8) | (UInt(mv.type) << 4) | UInt(piece_type))
    else    
        error("Unknown hash function")
    end
end