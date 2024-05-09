module Poppy
    include("constants.jl")
    include("helpers.jl")
    include("lookup.jl")
    include("board.jl")
    include("move.jl")
    include("move_do_white.jl")
    include("move_do_black.jl")
    include("move_undo_white.jl")
    include("move_undo_black.jl")
    include("movegen_white_legal.jl")
    include("movegen_black_legal.jl")
    include("perft.jl")

    export Board, set_by_fen!, perft!, perft_divide!
end
