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
