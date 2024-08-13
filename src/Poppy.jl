module Poppy
module PoppyCore
include("core/constants.jl")
include("core/helpers.jl")
include("core/zobrist.jl")
include("core/board.jl")
include("core/move/lookup.jl")
include("core/move/move.jl")
include("core/move/do_white.jl")
include("core/move/do_black.jl")
include("core/move/do.jl")
include("core/move/undo_white.jl")
include("core/move/undo_black.jl")
include("core/move/undo.jl")
include("core/move/gen_white.jl")
include("core/move/gen_black.jl")
include("core/move/gen.jl")
include("core/perft.jl")

export CHARACTERS
export WHITE, BLACK, EMPTY, NO_PIECE, NO_SQUARE 
export PAWN, KNIGHT, BISHOP, ROOK, QUEEN, KING
export WHITE_PAWN, WHITE_KNIGHT, WHITE_BISHOP, WHITE_ROOK, WHITE_QUEEN, WHITE_KING
export BLACK_PAWN, BLACK_KNIGHT, BLACK_BISHOP, BLACK_ROOK, BLACK_QUEEN, BLACK_KING
export QUIET, DOUBLE_PAWN_PUSH, KING_CASTLE, QUEEN_CASTLE, CAPTURE, EN_PASSANT, PROMOTION
export KNIGHT_PROMOTION, BISHOP_PROMOTION, ROOK_PROMOTION, QUEEN_PROMOTION
export KNIGHT_PROMOTION_CAPTURE, BISHOP_PROMOTION_CAPTURE, ROOK_PROMOTION_CAPTURE, QUEEN_PROMOTION_CAPTURE
export ZOBRIST_TABLE

export Board, clear!, set_by_fen!, extract_fen, do_move!, undo_move!, generate_legals, extract_move_by_uci, extract_move_by_san
export Move
export perft!, perft_divide!, perft_alla_stockfish!
end

module Engine
using ..PoppyCore
include("engine/helpers.jl")
include("engine/eval.jl")
include("engine/ordering.jl")
include("engine/tt.jl")
include("engine/searchdata.jl")
include("engine/search.jl")
include("engine/uci.jl")

export uci_loop
end

module Parser
using ..PoppyCore
include("parsing/files.jl")
include("parsing/filter_elo.jl")
include("parsing/clean.jl")

export filter_elo, clean_pgn, count_lines_in_files
end

module PatternLearning
using ..PoppyCore
using ..Parser
include("pattern-learning/binary.jl")
include("pattern-learning/gaussian.jl")
include("pattern-learning/factors.jl")
include("pattern-learning/board_features.jl")
include("pattern-learning/model.jl")
include("pattern-learning/ranking.jl")
include("pattern-learning/correctness.jl")
include("pattern-learning/analysis/prediction.jl")
include("pattern-learning/analysis/metadata.jl")
include("pattern-learning/train.jl")
include("pattern-learning/test.jl")

export test_correctness_simple, test_correctness_complex
export train_model, test_model
end

export PoppyCore, Engine, Parser, PatternLearning

end
