function print_as_bb(bb)
    println("")
    mask = 0xff00000000000000
    shift = 56
    for _ in 1:8
        println(join(c * " " for c in reverse(string(((bb & mask) >> shift), base=2, pad=8))))
        mask >>= 8
        shift -= 8
    end  
end


@inline function is_white(piece::UInt8)
    return (piece & 0b1000) == 0
end

macro pop_lsb!(bb)
    esc(quote
        idx = trailing_zeros($bb)
        $bb &= $bb - 1
        idx
    end)
end

@inline function rank(sq)
    return sq ÷ 8
end

@inline function file(sq)
    return sq % 8
end

@inline function diagonal(sq)
    return rank(sq) + 7 - file(sq)
end

@inline function anti_diagonal(sq)
    return rank(sq) + file(sq)
end

@inline function Base.sort(sq1, sq2)
    return sq1 < sq2 ? (sq1, sq2) : (sq2, sq1)
end