function undo_move!(board::Board, c::Color{BLACK}, mv::Move{QUIET})
    # adjust reversible flags
    board.side_to_move = Color(BLACK)
    board.ply -= 1

    # adjust boards
    piece = board.squares[mv.dst+1]
    board.bb_for[piece] ⊻= (bb(mv.src) | bb(mv.dst))
    board.bb_occ ⊻= bb(mv.src) | bb(mv.dst)
    board.bb_black ⊻= bb(mv.src) | bb(mv.dst)

    board.squares[mv.src+1] = piece
    board.squares[mv.dst+1] = EMPTY
end

function undo_move!(board::Board, c::Color{BLACK}, mv::Move{DOUBLE_PAWN_PUSH})
    # adjust reversible flags
    board.side_to_move = Color(BLACK)
    board.ply -= 1

    # adjust boards
    piece = board.squares[mv.dst+1]
    board.bb_for[piece] ⊻= (bb(mv.src) | bb(mv.dst))
    board.bb_occ ⊻= bb(mv.src) | bb(mv.dst)
    board.bb_black ⊻= bb(mv.src) | bb(mv.dst)

    board.squares[mv.src+1] = piece
    board.squares[mv.dst+1] = EMPTY
end

function undo_move!(board::Board, c::Color{BLACK}, mv::Move{KING_CASTLE})
    # adjust reversible flags
    board.side_to_move = Color(BLACK)
    board.ply -= 1

    # adjust boards
    board.bb_for[BLACK_KING] ⊻= 0x5000000000000000          # bb(60) | bb(62)
    board.bb_for[BLACK_ROOK] ⊻= 0xa000000000000000          # bb(63) | bb(61)
    board.bb_occ ⊻= 0xf000000000000000                      # bb(60) | bb(61) | bb(62) | bb(63)
    board.bb_black ⊻= 0xf000000000000000                    # bb(60) | bb(61) | bb(62) | bb(63)

    board.squares[61] = BLACK_KING
    board.squares[64] = BLACK_ROOK
    board.squares[63] = EMPTY
    board.squares[62] = EMPTY
end

function undo_move!(board::Board, c::Color{BLACK}, mv::Move{QUEEN_CASTLE})
    # adjust reversible flags
    board.side_to_move = Color(BLACK)
    board.ply -= 1

    # adjust boards
    board.bb_for[BLACK_KING] ⊻= 0x1400000000000000          # bb(60) | bb(58)
    board.bb_for[BLACK_ROOK] ⊻= 0x0900000000000000          # bb(56) | bb(59)
    board.bb_occ ⊻= 0x1d00000000000000                      # bb(56) | bb(58) | bb(59) | bb(60)
    board.bb_black ⊻= 0x1d00000000000000                    # bb(56) | bb(58) | bb(59) | bb(60)

    board.squares[57] = BLACK_ROOK
    board.squares[61] = BLACK_KING
    board.squares[59] = EMPTY
    board.squares[60] = EMPTY

end

function undo_move!(board::Board, c::Color{BLACK}, mv::Move{CAPTURE})
    # adjust reversible flags
    board.side_to_move = Color(BLACK)
    board.ply -= 1

    # adjust boards
    piece = board.squares[mv.dst + 1]
    captured_piece = board.history[board.ply].captured_piece

    board.bb_for[piece] ⊻= bb(mv.src) | bb(mv.dst)
    board.bb_for[captured_piece] ⊻= bb(mv.dst)
    board.bb_occ ⊻= bb(mv.src)
    board.bb_black ⊻= bb(mv.src) | bb(mv.dst)
    board.bb_white ⊻= bb(mv.dst)

    board.squares[mv.src + 1] = piece
    board.squares[mv.dst + 1] = captured_piece
end

function undo_move!(board::Board, c::Color{BLACK}, mv::Move{EN_PASSANT})
    # adjust reversible flags
    board.side_to_move = Color(BLACK)
    board.ply -= 1

    # adjust boards
    board.bb_for[BLACK_PAWN] ⊻= bb(mv.src) | bb(mv.dst)
    board.bb_for[WHITE_PAWN] ⊻= bb(mv.dst + 8)
    board.bb_occ ⊻= bb(mv.src) | bb(mv.dst) | bb(mv.dst + 8)
    board.bb_black ⊻= bb(mv.src) | bb(mv.dst)
    board.bb_white ⊻= bb(mv.dst + 8)

    board.squares[mv.src + 1] = BLACK_PAWN
    board.squares[mv.dst + 1] = EMPTY
    board.squares[mv.dst + 8 + 1] = WHITE_PAWN
end

function undo_move!(board::Board, c::Color{BLACK}, mv::Move{KNIGHT_PROMOTION})
    # adjust reversible flags
    board.side_to_move = Color(BLACK)
    board.ply -= 1

    # adjust boards
    board.bb_for[BLACK_PAWN] ⊻= bb(mv.src)
    board.bb_for[BLACK_KNIGHT] ⊻= bb(mv.dst)
    board.bb_occ ⊻= bb(mv.src) | bb(mv.dst)
    board.bb_black ⊻= bb(mv.src) | bb(mv.dst)

    board.squares[mv.src + 1] = BLACK_PAWN
    board.squares[mv.dst + 1] = EMPTY
end

function undo_move!(board::Board, c::Color{BLACK}, mv::Move{BISHOP_PROMOTION})
    # adjust reversible flags
    board.side_to_move = Color(BLACK)
    board.ply -= 1

    # adjust boards
    board.bb_for[BLACK_PAWN] ⊻= bb(mv.src)
    board.bb_for[BLACK_BISHOP] ⊻= bb(mv.dst)
    board.bb_occ ⊻= bb(mv.src) | bb(mv.dst)
    board.bb_black ⊻= bb(mv.src) | bb(mv.dst)

    board.squares[mv.src + 1] = BLACK_PAWN
    board.squares[mv.dst + 1] = EMPTY
end

function undo_move!(board::Board, c::Color{BLACK}, mv::Move{ROOK_PROMOTION})
    # adjust reversible flags
    board.side_to_move = Color(BLACK)
    board.ply -= 1

    # adjust boards
    board.bb_for[BLACK_PAWN] ⊻= bb(mv.src)
    board.bb_for[BLACK_ROOK] ⊻= bb(mv.dst)
    board.bb_occ ⊻= bb(mv.src) | bb(mv.dst)
    board.bb_black ⊻= bb(mv.src) | bb(mv.dst)

    board.squares[mv.src + 1] = BLACK_PAWN
    board.squares[mv.dst + 1] = EMPTY
end

function undo_move!(board::Board, c::Color{BLACK}, mv::Move{QUEEN_PROMOTION})
    # adjust reversible flags
    board.side_to_move = Color(BLACK)
    board.ply -= 1

    # adjust boards
    board.bb_for[BLACK_PAWN] ⊻= bb(mv.src)
    board.bb_for[BLACK_QUEEN] ⊻= bb(mv.dst)
    board.bb_occ ⊻= bb(mv.src) | bb(mv.dst)
    board.bb_black ⊻= bb(mv.src) | bb(mv.dst)

    board.squares[mv.src + 1] = BLACK_PAWN
    board.squares[mv.dst + 1] = EMPTY
end

function undo_move!(board::Board, c::Color{BLACK}, mv::Move{KNIGHT_PROMOTION_CAPTURE})
    # adjust reversible flags
    board.side_to_move = Color(BLACK)
    board.ply -= 1

    # adjust boards
    captured_piece = board.history[board.ply].captured_piece

    board.bb_for[BLACK_PAWN] ⊻= bb(mv.src)
    board.bb_for[BLACK_KNIGHT] ⊻= bb(mv.dst)
    board.bb_for[captured_piece] ⊻= bb(mv.dst)
    board.bb_occ ⊻= bb(mv.src)
    board.bb_black ⊻= bb(mv.src) | bb(mv.dst)
    board.bb_white ⊻= bb(mv.dst)

    board.squares[mv.src + 1] = BLACK_PAWN
    board.squares[mv.dst + 1] = captured_piece
end

function undo_move!(board::Board, c::Color{BLACK}, mv::Move{BISHOP_PROMOTION_CAPTURE})
    # adjust reversible flags
    board.side_to_move = Color(BLACK)
    board.ply -= 1

    # adjust boards
    captured_piece = board.history[board.ply].captured_piece

    board.bb_for[BLACK_PAWN] ⊻= bb(mv.src)
    board.bb_for[BLACK_BISHOP] ⊻= bb(mv.dst)
    board.bb_for[captured_piece] ⊻= bb(mv.dst)
    board.bb_occ ⊻= bb(mv.src)
    board.bb_black ⊻= bb(mv.src) | bb(mv.dst)
    board.bb_white ⊻= bb(mv.dst)

    board.squares[mv.src + 1] = BLACK_PAWN
    board.squares[mv.dst + 1] = captured_piece
end

function undo_move!(board::Board, c::Color{BLACK}, mv::Move{ROOK_PROMOTION_CAPTURE})
    # adjust reversible flags
    board.side_to_move = Color(BLACK)
    board.ply -= 1

    # adjust boards
    captured_piece = board.history[board.ply].captured_piece

    board.bb_for[BLACK_PAWN] ⊻= bb(mv.src)
    board.bb_for[BLACK_ROOK] ⊻= bb(mv.dst)
    board.bb_for[captured_piece] ⊻= bb(mv.dst)
    board.bb_occ ⊻= bb(mv.src)
    board.bb_black ⊻= bb(mv.src) | bb(mv.dst)
    board.bb_white ⊻= bb(mv.dst)

    board.squares[mv.src + 1] = BLACK_PAWN
    board.squares[mv.dst + 1] = captured_piece
end

function undo_move!(board::Board, c::Color{BLACK}, mv::Move{QUEEN_PROMOTION_CAPTURE})
    # adjust reversible flags
    board.side_to_move = Color(BLACK)
    board.ply -= 1

    # adjust boards
    captured_piece = board.history[board.ply].captured_piece

    board.bb_for[BLACK_PAWN] ⊻= bb(mv.src)
    board.bb_for[BLACK_QUEEN] ⊻= bb(mv.dst)
    board.bb_for[captured_piece] ⊻= bb(mv.dst)
    board.bb_occ ⊻= bb(mv.src)
    board.bb_black ⊻= bb(mv.src) | bb(mv.dst)
    board.bb_white ⊻= bb(mv.dst)

    board.squares[mv.src + 1] = BLACK_PAWN
    board.squares[mv.dst + 1] = captured_piece
end