struct ZobristTable
    pieces::Matrix{UInt64}
    flags::Vector{UInt64}
end

function ZobristTable()
    pieces = rand(UInt64, 64, 14)
    flags = rand(UInt64, 26)
    return ZobristTable(pieces, flags)
end

const ZOBRIST_TABLE = ZobristTable()