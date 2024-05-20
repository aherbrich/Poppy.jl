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
    
    export WHITE, BLACK, EMPTY, NO_PIECE, NO_SQUARE 
    export PAWN, KNIGHT, BISHOP, ROOK, QUEEN, KING
    export WHITE_PAWN, WHITE_KNIGHT, WHITE_BISHOP, WHITE_ROOK, WHITE_QUEEN, WHITE_KING
    export BLACK_PAWN, BLACK_KNIGHT, BLACK_BISHOP, BLACK_ROOK, BLACK_QUEEN, BLACK_KING
    export QUIET, DOUBLE_PAWN_PUSH, KING_CASTLE, QUEEN_CASTLE, CAPTURE, EN_PASSANT
    export KNIGHT_PROMOTION, BISHOP_PROMOTION, ROOK_PROMOTION, QUEEN_PROMOTION
    export KNIGHT_PROMOTION_CAPTURE, BISHOP_PROMOTION_CAPTURE, ROOK_PROMOTION_CAPTURE, QUEEN_PROMOTION_CAPTURE

    export Board, set_by_fen!, extract_fen, do_move!, undo_move!, generate_legals, extract_move
    export perft!, perft_divide!, perft_alla_stockfish!
end
