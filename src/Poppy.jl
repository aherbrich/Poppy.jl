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
    include("perft.jl")


    println("Poppy loaded")

    board = Board()
    set_by_fen!(board, "r4rk1/1pp1qppp/p1np1n2/2b1p1B1/2B1P1b1/P1NP1N2/1PP1QPPP/R4RK1 w - - 0 10")

    println(perft_divide!(board, 5))

end
