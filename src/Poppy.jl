module Poppy
    include("constants.jl")
    include("helpers.jl")
    include("lookup.jl")
    include("board.jl")
    include("move.jl")
    include("move_gen_white.jl")
    include("move_gen_black.jl")
    include("move_gen.jl")
    include("move_do_white.jl")
    include("move_do_black.jl")
    include("move_undo_white.jl")
    include("move_undo_black.jl")
    include("perft.jl")


    export Board, set_by_fen!, perft!, perft_divide!
end
