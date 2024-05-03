module Poppy
    include("constants.jl")
    include("helpers.jl")
    include("lookup.jl")
    include("board.jl")
    include("move.jl")
    include("movegen_white.jl")
    include("movegen_black.jl")
    include("movegen.jl")

    println("Poppy loaded")

    board = Board()
    set_by_fen!(board, "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")

    moves = generate_pseudo_moves(board.side_to_move, board, Vector{Function}())
    println("number of moves: ", length(moves))
end
