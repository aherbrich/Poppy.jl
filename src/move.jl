struct Move{type}
    src::UInt8
    dst::UInt8
end

Move(src, dst, type::UInt8) = Move{type}(src, dst)

function push_moves!(moves::Vector{Move}, from_sq, to_bb::UInt64, move_type::UInt8)
    while to_bb != 0
        to_sq = @pop_lsb!(to_bb)
        push!(moves, Move(from_sq, to_sq, move_type))
    end
end

function Base.show(io::IO, move::Move)    
    print(io, string('a' + ((move.src) & 0x07)), string('1' + ((move.src) >> 0x03)))
    print(io, string('a' + ((move.dst) & 0x07)), string('1' + ((move.dst) >> 0x03)))

    if typeof(move) == Move{KNIGHT_PROMOTION} || typeof(move) == Move{KNIGHT_PROMOTION_CAPTURE}
        print(io, 'n')
    elseif typeof(move) == Move{BISHOP_PROMOTION} || typeof(move) == Move{BISHOP_PROMOTION_CAPTURE}
        print(io, 'b')
    elseif typeof(move) == Move{ROOK_PROMOTION} || typeof(move) == Move{ROOK_PROMOTION_CAPTURE}
        print(io, 'r')
    elseif typeof(move) == Move{QUEEN_PROMOTION} || typeof(move) == Move{QUEEN_PROMOTION_CAPTURE}
        print(io, 'q')
    end
end # show
