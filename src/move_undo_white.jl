function undo_move!(board::Board, c::Color{WHITE}, mv::Move{QUIET})
    # adjust reversible flags
    board.side_to_move = Color(WHITE)
    board.ply -= 1

    # adjust boards
    piece = board.squares[mv.dst+1]
    board.bb_for[piece] ⊻= (bb(mv.src) | bb(mv.dst))
    board.bb_occ ⊻= bb(mv.src) | bb(mv.dst)
    board.bb_white ⊻= bb(mv.src) | bb(mv.dst)

    board.squares[mv.src+1] = piece
    board.squares[mv.dst+1] = EMPTY
end

function undo_move!(board::Board, c::Color{WHITE}, mv::Move{DOUBLE_PAWN_PUSH})
    # adjust reversible flags
    board.side_to_move = Color(WHITE)
    board.ply -= 1

    # adjust boards
    piece = board.squares[mv.dst+1]
    board.bb_for[piece] ⊻= (bb(mv.src) | bb(mv.dst))
    board.bb_occ ⊻= bb(mv.src) | bb(mv.dst)
    board.bb_white ⊻= bb(mv.src) | bb(mv.dst)

    board.squares[mv.src+1] = piece
    board.squares[mv.dst+1] = EMPTY
end

function undo_move!(board::Board, c::Color{WHITE}, mv::Move{KING_CASTLE})
    # adjust reversible flags
    board.side_to_move = Color(WHITE)
    board.ply -= 1

    # adjust boards
    board.bb_for[WHITE_KING] ⊻= 0x0000000000000050          # bb(4) | bb(6)
    board.bb_for[WHITE_ROOK] ⊻= 0x00000000000000a0          # bb(7) | bb(5)
    board.bb_occ ⊻= 0x00000000000000f0                      # bb(4) | bb(5) | bb(6) | bb(7)
    board.bb_white ⊻= 0x00000000000000f0                    # bb(4) | bb(5) | bb(6) | bb(7)

    board.squares[5] = WHITE_KING
    board.squares[8] = WHITE_ROOK
    board.squares[7] = EMPTY
    board.squares[6] = EMPTY
end

function undo_move!(board::Board, c::Color{WHITE}, mv::Move{QUEEN_CASTLE})
    # adjust reversible flags
    board.side_to_move = Color(WHITE)
    board.ply -= 1

    # adjust boards
    board.bb_for[WHITE_KING] ⊻= 0x0000000000000014          # bb(4) | bb(2)
    board.bb_for[WHITE_ROOK] ⊻= 0x0000000000000009          # bb(0) | bb(3)
    board.bb_occ ⊻= 0x000000000000001d                      # bb(0) | bb(2) | bb(3) | bb(4)
    board.bb_white ⊻= 0x000000000000001d                    # bb(0) | bb(2) | bb(3) | bb(4)

    board.squares[1] = WHITE_ROOK
    board.squares[5] = WHITE_KING
    board.squares[3] = EMPTY
    board.squares[4] = EMPTY
end

function undo_move!(board::Board, c::Color{WHITE}, mv::Move{CAPTURE})
    # adjust reversible flags
    board.side_to_move = Color(WHITE)
    board.ply -= 1

    # adjust boards
    piece = board.squares[mv.dst + 1]
    captured_piece = board.history[board.ply].captured_piece

    board.bb_for[piece] ⊻= bb(mv.src) | bb(mv.dst)
    board.bb_for[captured_piece] ⊻= bb(mv.dst)
    board.bb_occ ⊻= bb(mv.src)
    board.bb_white ⊻= bb(mv.src) | bb(mv.dst)
    board.bb_black ⊻= bb(mv.dst)

    board.squares[mv.src + 1] = piece
    board.squares[mv.dst + 1] = captured_piece
end

function undo_move!(board::Board, c::Color{WHITE}, mv::Move{EN_PASSANT})
    # adjust reversible flags
    board.side_to_move = Color(WHITE)
    board.ply -= 1

    # adjust boards
    board.bb_for[WHITE_PAWN] ⊻= bb(mv.src) | bb(mv.dst)
    board.bb_for[BLACK_PAWN] ⊻= bb(mv.dst - 8)
    board.bb_occ ⊻= bb(mv.src) | bb(mv.dst) | bb(mv.dst - 8)
    board.bb_white ⊻= bb(mv.src) | bb(mv.dst)
    board.bb_black ⊻= bb(mv.dst - 8)

    board.squares[mv.src + 1] = WHITE_PAWN
    board.squares[mv.dst + 1] = EMPTY
    board.squares[mv.dst - 8 + 1] = BLACK_PAWN
end

function undo_move!(board::Board, c::Color{WHITE}, mv::Move{KNIGHT_PROMOTION})
    # adjust reversible flags
    board.side_to_move = Color(WHITE)
    board.ply -= 1

    # adjust boards
    board.bb_for[WHITE_PAWN] ⊻= bb(mv.src)
    board.bb_for[WHITE_KNIGHT] ⊻= bb(mv.dst)
    board.bb_occ ⊻= bb(mv.src) | bb(mv.dst)
    board.bb_white ⊻= bb(mv.src) | bb(mv.dst)

    board.squares[mv.src + 1] = WHITE_PAWN
    board.squares[mv.dst + 1] = EMPTY
end

function undo_move!(board::Board, c::Color{WHITE}, mv::Move{BISHOP_PROMOTION})
    # adjust reversible flags
    board.side_to_move = Color(WHITE)
    board.ply -= 1

    # adjust boards
    board.bb_for[WHITE_PAWN] ⊻= bb(mv.src)
    board.bb_for[WHITE_BISHOP] ⊻= bb(mv.dst)
    board.bb_occ ⊻= bb(mv.src) | bb(mv.dst)
    board.bb_white ⊻= bb(mv.src) | bb(mv.dst)

    board.squares[mv.src + 1] = WHITE_PAWN
    board.squares[mv.dst + 1] = EMPTY
end

function undo_move!(board::Board, c::Color{WHITE}, mv::Move{ROOK_PROMOTION})
    # adjust reversible flags
    board.side_to_move = Color(WHITE)
    board.ply -= 1

    # adjust boards
    board.bb_for[WHITE_PAWN] ⊻= bb(mv.src)
    board.bb_for[WHITE_ROOK] ⊻= bb(mv.dst)
    board.bb_occ ⊻= bb(mv.src) | bb(mv.dst)
    board.bb_white ⊻= bb(mv.src) | bb(mv.dst)

    board.squares[mv.src + 1] = WHITE_PAWN
    board.squares[mv.dst + 1] = EMPTY
end

function undo_move!(board::Board, c::Color{WHITE}, mv::Move{QUEEN_PROMOTION})
    # adjust reversible flags
    board.side_to_move = Color(WHITE)
    board.ply -= 1

    # adjust boards
    board.bb_for[WHITE_PAWN] ⊻= bb(mv.src)
    board.bb_for[WHITE_QUEEN] ⊻= bb(mv.dst)
    board.bb_occ ⊻= bb(mv.src) | bb(mv.dst)
    board.bb_white ⊻= bb(mv.src) | bb(mv.dst)

    board.squares[mv.src + 1] = WHITE_PAWN
    board.squares[mv.dst + 1] = EMPTY
end

function undo_move!(board::Board, c::Color{WHITE}, mv::Move{KNIGHT_PROMOTION_CAPTURE})
    # adjust reversible flags
    board.side_to_move = Color(WHITE)
    board.ply -= 1

    # adjust boards
    captured_piece = board.history[board.ply].captured_piece

    board.bb_for[WHITE_PAWN] ⊻= bb(mv.src)
    board.bb_for[WHITE_KNIGHT] ⊻= bb(mv.dst)
    board.bb_for[captured_piece] ⊻= bb(mv.dst)
    board.bb_occ ⊻= bb(mv.src)
    board.bb_white ⊻= bb(mv.src) | bb(mv.dst)
    board.bb_black ⊻= bb(mv.dst)

    board.squares[mv.src + 1] = WHITE_PAWN
    board.squares[mv.dst + 1] = captured_piece
end

function undo_move!(board::Board, c::Color{WHITE}, mv::Move{BISHOP_PROMOTION_CAPTURE})
    # adjust reversible flags
    board.side_to_move = Color(WHITE)
    board.ply -= 1

    # adjust boards
    captured_piece = board.history[board.ply].captured_piece

    board.bb_for[WHITE_PAWN] ⊻= bb(mv.src)
    board.bb_for[WHITE_BISHOP] ⊻= bb(mv.dst)
    board.bb_for[captured_piece] ⊻= bb(mv.dst)
    board.bb_occ ⊻= bb(mv.src)
    board.bb_white ⊻= bb(mv.src) | bb(mv.dst)
    board.bb_black ⊻= bb(mv.dst)

    board.squares[mv.src + 1] = WHITE_PAWN
    board.squares[mv.dst + 1] = captured_piece
end

function undo_move!(board::Board, c::Color{WHITE}, mv::Move{ROOK_PROMOTION_CAPTURE})
    # adjust reversible flags
    board.side_to_move = Color(WHITE)
    board.ply -= 1

    # adjust boards
    captured_piece = board.history[board.ply].captured_piece

    board.bb_for[WHITE_PAWN] ⊻= bb(mv.src)
    board.bb_for[WHITE_ROOK] ⊻= bb(mv.dst)
    board.bb_for[captured_piece] ⊻= bb(mv.dst)
    board.bb_occ ⊻= bb(mv.src)
    board.bb_white ⊻= bb(mv.src) | bb(mv.dst)
    board.bb_black ⊻= bb(mv.dst)

    board.squares[mv.src + 1] = WHITE_PAWN
    board.squares[mv.dst + 1] = captured_piece
end

function undo_move!(board::Board, c::Color{WHITE}, mv::Move{QUEEN_PROMOTION_CAPTURE})
    # adjust reversible flags
    board.side_to_move = Color(WHITE)
    board.ply -= 1

    # adjust boards
    captured_piece = board.history[board.ply].captured_piece

    board.bb_for[WHITE_PAWN] ⊻= bb(mv.src)
    board.bb_for[WHITE_QUEEN] ⊻= bb(mv.dst)
    board.bb_for[captured_piece] ⊻= bb(mv.dst)
    board.bb_occ ⊻= bb(mv.src)
    board.bb_white ⊻= bb(mv.src) | bb(mv.dst)
    board.bb_black ⊻= bb(mv.dst)

    board.squares[mv.src + 1] = WHITE_PAWN
    board.squares[mv.dst + 1] = captured_piece
end