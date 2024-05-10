struct Move
    src::UInt8
    dst::UInt8
    type::UInt8
end


function push_moves!(moves, from_sq, to_bb::UInt64, move_type::UInt8)
    while to_bb != 0
        to_sq = @pop_lsb!(to_bb)
        push!(moves, Move(from_sq, to_sq, move_type))
    end
end

function Base.show(io::IO, move::Move)    
    print(io, string('a' + ((move.src) & 0x07)), string('1' + ((move.src) >> 0x03)))
    print(io, string('a' + ((move.dst) & 0x07)), string('1' + ((move.dst) >> 0x03)))

    if move.type == KNIGHT_PROMOTION || move.type == KNIGHT_PROMOTION_CAPTURE
        print(io, 'n')
    elseif move.type == BISHOP_PROMOTION || move.type == BISHOP_PROMOTION_CAPTURE
        print(io, 'b')
    elseif move.type == ROOK_PROMOTION || move.type == ROOK_PROMOTION_CAPTURE
        print(io, 'r')
    elseif move.type == QUEEN_PROMOTION || move.type == QUEEN_PROMOTION_CAPTURE
        print(io, 'q')
    end
end # show
