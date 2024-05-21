using Random
Random.seed!(123)

struct ZobristMoveTable
    from::Vector{UInt64}
    to::Vector{UInt64}
    piece::Vector{UInt64}
    move_type::Vector{UInt64}
    in_check::UInt64
end

function ZobristMoveTable()
    from = [rand(UInt64) for _ in 1:64]
    to = [rand(UInt64) for _ in 1:64]
    piece = [rand(UInt64) for _ in 1:15]
    move_type = [rand(UInt64) for _ in 1:17]
    in_check = rand(UInt64)

    return ZobristMoveTable(from, to, piece, move_type, in_check)
end

const ZOBRIST_MOVE_TABLE = ZobristMoveTable()


function move_to_hash(move, board)
    nr_checkers, _ = generate_legals(board)

    src = Int64(move.src)
    dst = Int64(move.dst)
    type = Int64(move.type)

    hash = UInt64(0)
    hash = hash ⊻ ZOBRIST_MOVE_TABLE.piece[board.squares[src + 1]]
    hash = hash ⊻ ZOBRIST_MOVE_TABLE.move_type[type + 1]
    hash = hash ⊻ ZOBRIST_MOVE_TABLE.from[src + 1]
    hash = hash ⊻ ZOBRIST_MOVE_TABLE.to[dst + 1]
    hash = hash ⊻ (nr_checkers > 0 ? ZOBRIST_MOVE_TABLE.in_check : 0)

    return hash
end