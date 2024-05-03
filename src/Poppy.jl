module Poppy
    include("constants.jl")
    include("helpers.jl")
    include("lookup.jl")
    include("board.jl")
    include("move.jl")
    include("movegen_white.jl")
    include("movegen_black.jl")
    include("movegen.jl")
    include("move_do_white.jl")
    include("move_do_black.jl")
    include("move_undo_white.jl")
    include("move_undo_black.jl")

    println("Poppy loaded")

    board = Board()
    set_by_fen!(board, "r4rk1/1pp1qppp/p1np1n2/2b1p1B1/2B1P1b1/P1NP1N2/1PP1QPPP/R4RK1 w - - 0 10 ")

    function perft!(board::Board, depth::Int)
        if depth == 0 return 1 end
        old_color = board.side_to_move
        moves = generate_pseudo_moves(old_color, board)
        nodes = 0
        for move in moves
            do_move!(board, old_color, move)
            if in_check(board, old_color, move) == false
                nodes += perft!(board, depth-1)
            end
            undo_move!(board, old_color, move)
        end
        return nodes
    end

    println(@time perft!(board, 4))
end
