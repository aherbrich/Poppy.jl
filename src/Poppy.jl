module Poppy
    include("constants.jl")
    include("helpers.jl")
    include("board.jl")
    include("move/lookup.jl")
    include("move/move.jl")
    include("move/do_white.jl")
    include("move/do_black.jl")
    include("move/do.jl")
    include("move/undo_white.jl")
    include("move/undo_black.jl")
    include("move/undo.jl")
    include("move/gen_white.jl")
    include("move/gen_black.jl")
    include("move/gen.jl")
    include("perft.jl")
    
    export Board, set_by_fen!, perft!, perft_divide!, perft_alla_stockfish!, extract_fen
end
