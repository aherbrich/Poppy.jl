function do_move!(board::Board, c::Color{BLACK}, mv::Move{QUIET})
    # adjust boards
    piece = board.squares[mv.src + 1]
    board.bb_for[piece] ⊻= (bb(mv.src) | bb(mv.dst))
    board.bb_occ ⊻= bb(mv.src) | bb(mv.dst)
    board.bb_black ⊻= bb(mv.src) | bb(mv.dst)

    board.squares[mv.src + 1] = EMPTY
    board.squares[mv.dst + 1] = piece

    # adjust reversible flags
    board.side_to_move = Color(WHITE)
    board.ply += 1

    # adjust irreversible flags
    board.history[board.ply].ep_square = NO_SQUARE
    board.history[board.ply].castling_rights = board.history[board.ply - 1].castling_rights
    board.history[board.ply].fifty_move_counter = board.history[board.ply - 1].fifty_move_counter + 1
    board.history[board.ply-1].captured_piece = NO_PIECE

    # adjust fifty move counter if pawn moved
    if piece == BLACK_PAWN
        board.history[board.ply].fifty_move_counter = 0
    end

    # adjust castling rights if piece move from initial rook or king square
    if mv.dst == 60
        board.history[board.ply].castling_rights &= ~CASTLING_B
    elseif mv.dst == 56
        board.history[board.ply].castling_rights &= ~CASTLING_BQ
    elseif mv.dst == 63
        board.history[board.ply].castling_rights &= ~CASTLING_BK
    end
end

function do_move!(board::Board, c::Color{BLACK}, mv::Move{DOUBLE_PAWN_PUSH})
    # adjust boards
    board.bb_for[BLACK_PAWN] ⊻= bb(mv.src) | bb(mv.dst)
    board.bb_occ ⊻= bb(mv.src) | bb(mv.dst)
    board.bb_black ⊻= bb(mv.src) | bb(mv.dst)

    board.squares[mv.src + 1] = EMPTY
    board.squares[mv.dst + 1] = BLACK_PAWN

    # adjust reversible flags
    board.side_to_move = Color(WHITE)
    board.ply += 1

    # adjust irreversible flags
    board.history[board.ply].ep_square = mv.dst + 8
    board.history[board.ply].castling_rights = board.history[board.ply - 1].castling_rights
    board.history[board.ply].fifty_move_counter = 0
    board.history[board.ply-1].captured_piece = NO_PIECE
end

function do_move!(board::Board, c::Color{BLACK}, mv::Move{KING_CASTLE})
    # adjust boards
    board.bb_for[BLACK_KING] ⊻= 0x5000000000000000          # bb(60) | bb(62)
    board.bb_for[BLACK_ROOK] ⊻= 0xa000000000000000          # bb(63) | bb(61)
    board.bb_occ ⊻= 0xf000000000000000                      # bb(60) | bb(61) | bb(62) | bb(63)
    board.bb_black ⊻= 0xf000000000000000                    # bb(60) | bb(61) | bb(62) | bb(63)

    board.squares[61] = EMPTY
    board.squares[64] = EMPTY
    board.squares[63] = BLACK_KING
    board.squares[62] = BLACK_ROOK

    # adjust reversible flags
    board.side_to_move = Color(WHITE)
    board.ply += 1

    # adjust irreversible flags
    board.history[board.ply].ep_square = NO_SQUARE
    board.history[board.ply].castling_rights = board.history[board.ply - 1].castling_rights & ~CASTLING_B
    board.history[board.ply].fifty_move_counter = board.history[board.ply - 1].fifty_move_counter + 1
    board.history[board.ply-1].captured_piece = NO_PIECE
end

function do_move!(board::Board, c::Color{BLACK}, mv::Move{QUEEN_CASTLE})
    # adjust boards
    board.bb_for[BLACK_KING] ⊻= 0x1400000000000000          # bb(60) | bb(58)
    board.bb_for[BLACK_ROOK] ⊻= 0x0900000000000000          # bb(56) | bb(59)
    board.bb_occ ⊻= 0x1d00000000000000                      # bb(56) | bb(58) | bb(59) | bb(60)
    board.bb_black ⊻= 0x1d00000000000000                    # bb(56) | bb(58) | bb(59) | bb(60)

    board.squares[57] = EMPTY
    board.squares[61] = EMPTY
    board.squares[59] = BLACK_KING
    board.squares[60] = BLACK_ROOK

    # adjust reversible flags
    board.side_to_move = Color(WHITE)
    board.ply += 1

    # adjust irreversible flags
    board.history[board.ply].ep_square = NO_SQUARE
    board.history[board.ply].castling_rights = board.history[board.ply - 1].castling_rights & ~CASTLING_B
    board.history[board.ply].fifty_move_counter = board.history[board.ply - 1].fifty_move_counter + 1
    board.history[board.ply-1].captured_piece = NO_PIECE
end

function do_move!(board::Board, c::Color{BLACK}, mv::Move{CAPTURE})
    # adjust boards
    piece = board.squares[mv.src + 1]
    captured_piece = board.squares[mv.dst + 1]

    board.bb_for[piece] ⊻= bb(mv.src) | bb(mv.dst)
    board.bb_for[captured_piece] ⊻= bb(mv.dst)
    board.bb_occ ⊻= bb(mv.src)
    board.bb_black ⊻= bb(mv.src) | bb(mv.dst)
    board.bb_white ⊻= bb(mv.dst)

    board.squares[mv.src + 1] = EMPTY
    board.squares[mv.dst + 1] = piece
    
    # adjust reversible flags
    board.side_to_move = Color(WHITE)
    board.ply += 1

    # adjust irreversible flags
    board.history[board.ply].ep_square = NO_SQUARE
    board.history[board.ply].castling_rights = board.history[board.ply - 1].castling_rights
    board.history[board.ply].fifty_move_counter = 0
    board.history[board.ply-1].captured_piece = captured_piece

    # adjust castling rights if piece move from initial rook or king square
    if mv.dst == 60
        board.history[board.ply].castling_rights &= ~CASTLING_B
    elseif mv.dst == 56
        board.history[board.ply].castling_rights &= ~CASTLING_BQ
    elseif mv.dst == 63
        board.history[board.ply].castling_rights &= ~CASTLING_BK
    end

    # adjust castling rights if rook captured
    if mv.dst == 0
        board.history[board.ply].castling_rights &= ~CASTLING_WQ
    elseif mv.dst == 7
        board.history[board.ply].castling_rights &= ~CASTLING_WK
    end
end

function do_move!(board::Board, c::Color{BLACK}, mv::Move{EN_PASSANT})
    # adjust boards
    board.bb_for[BLACK_PAWN] ⊻= bb(mv.src) | bb(mv.dst)
    board.bb_for[WHITE_PAWN] ⊻= bb(mv.dst + 8)
    board.bb_occ ⊻= bb(mv.src) | bb(mv.dst) | bb(mv.dst + 8)
    board.bb_black ⊻= bb(mv.src) | bb(mv.dst)
    board.bb_white ⊻= bb(mv.dst + 8)

    board.squares[mv.src + 1] = EMPTY
    board.squares[mv.dst + 1] = BLACK_PAWN
    board.squares[mv.dst + 8 + 1] = EMPTY

    # adjust reversible flags
    board.side_to_move = Color(WHITE)
    board.ply += 1

    # adjust irreversible flags
    board.history[board.ply].ep_square = NO_SQUARE
    board.history[board.ply].castling_rights = board.history[board.ply - 1].castling_rights
    board.history[board.ply].fifty_move_counter = 0
    board.history[board.ply-1].captured_piece = WHITE_PAWN
end

function do_move!(board::Board, c::Color{BLACK}, mv::Move{KNIGHT_PROMOTION})
    # adjust boards
    board.bb_for[BLACK_PAWN] ⊻= bb(mv.src)
    board.bb_for[BLACK_KNIGHT] ⊻= bb(mv.dst)
    board.bb_occ ⊻= bb(mv.src) | bb(mv.dst)
    board.bb_black ⊻= bb(mv.src) | bb(mv.dst)

    board.squares[mv.src + 1] = EMPTY
    board.squares[mv.dst + 1] = BLACK_KNIGHT

    # adjust reversible flags
    board.side_to_move = Color(WHITE)
    board.ply += 1

    # adjust irreversible flags
    board.history[board.ply].ep_square = NO_SQUARE
    board.history[board.ply].castling_rights = board.history[board.ply - 1].castling_rights
    board.history[board.ply].fifty_move_counter = 0
    board.history[board.ply-1].captured_piece = NO_PIECE
end

function do_move!(board::Board, c::Color{BLACK}, mv::Move{BISHOP_PROMOTION})
    # adjust boards
    board.bb_for[BLACK_PAWN] ⊻= bb(mv.src)
    board.bb_for[BLACK_BISHOP] ⊻= bb(mv.dst)
    board.bb_occ ⊻= bb(mv.src) | bb(mv.dst)
    board.bb_black ⊻= bb(mv.src) | bb(mv.dst)

    board.squares[mv.src + 1] = EMPTY
    board.squares[mv.dst + 1] = BLACK_BISHOP

    # adjust reversible flags
    board.side_to_move = Color(WHITE)
    board.ply += 1

    # adjust irreversible flags
    board.history[board.ply].ep_square = NO_SQUARE
    board.history[board.ply].castling_rights = board.history[board.ply - 1].castling_rights
    board.history[board.ply].fifty_move_counter = 0
    board.history[board.ply-1].captured_piece = NO_PIECE
end

function do_move!(board::Board, c::Color{BLACK}, mv::Move{ROOK_PROMOTION})
    # adjust boards
    board.bb_for[BLACK_PAWN] ⊻= bb(mv.src)
    board.bb_for[BLACK_ROOK] ⊻= bb(mv.dst)
    board.bb_occ ⊻= bb(mv.src) | bb(mv.dst)
    board.bb_black ⊻= bb(mv.src) | bb(mv.dst)

    board.squares[mv.src + 1] = EMPTY
    board.squares[mv.dst + 1] = BLACK_ROOK

    # adjust reversible flags
    board.side_to_move = Color(WHITE)
    board.ply += 1

    # adjust irreversible flags
    board.history[board.ply].ep_square = NO_SQUARE
    board.history[board.ply].castling_rights = board.history[board.ply - 1].castling_rights
    board.history[board.ply].fifty_move_counter = 0
    board.history[board.ply-1].captured_piece = NO_PIECE
end

function do_move!(board::Board, c::Color{BLACK}, mv::Move{QUEEN_PROMOTION})
    # adjust boards
    board.bb_for[BLACK_PAWN] ⊻= bb(mv.src)
    board.bb_for[BLACK_QUEEN] ⊻= bb(mv.dst)
    board.bb_occ ⊻= bb(mv.src) | bb(mv.dst)
    board.bb_black ⊻= bb(mv.src) | bb(mv.dst)

    board.squares[mv.src + 1] = EMPTY
    board.squares[mv.dst + 1] = BLACK_QUEEN

    # adjust reversible flags
    board.side_to_move = Color(WHITE)
    board.ply += 1

    # adjust irreversible flags
    board.history[board.ply].ep_square = NO_SQUARE
    board.history[board.ply].castling_rights = board.history[board.ply - 1].castling_rights
    board.history[board.ply].fifty_move_counter = 0
    board.history[board.ply-1].captured_piece = NO_PIECE
end

function do_move!(board::Board, c::Color{BLACK}, mv::Move{KNIGHT_PROMOTION_CAPTURE})
    # adjust boards
    captured_piece = board.squares[mv.dst + 1]

    board.bb_for[BLACK_PAWN] ⊻= bb(mv.src)
    board.bb_for[BLACK_KNIGHT] ⊻= bb(mv.dst)
    board.bb_for[captured_piece] ⊻= bb(mv.dst)
    board.bb_occ ⊻= bb(mv.src)
    board.bb_black ⊻= bb(mv.src) | bb(mv.dst)
    board.bb_white ⊻= bb(mv.dst)

    board.squares[mv.src + 1] = EMPTY
    board.squares[mv.dst + 1] = BLACK_KNIGHT

    # adjust reversible flags
    board.side_to_move = Color(WHITE)
    board.ply += 1

    # adjust irreversible flags
    board.history[board.ply].ep_square = NO_SQUARE
    board.history[board.ply].castling_rights = board.history[board.ply - 1].castling_rights
    board.history[board.ply].fifty_move_counter = 0
    board.history[board.ply-1].captured_piece = captured_piece

    # adjust castling rights if rook captured
    if mv.dst == 0
        board.history[board.ply].castling_rights &= ~CASTLING_WQ
    elseif mv.dst == 7
        board.history[board.ply].castling_rights &= ~CASTLING_WK
    end
end

function do_move!(board::Board, c::Color{BLACK}, mv::Move{BISHOP_PROMOTION_CAPTURE})
    # adjust boards
    captured_piece = board.squares[mv.dst + 1]

    board.bb_for[BLACK_PAWN] ⊻= bb(mv.src)
    board.bb_for[BLACK_BISHOP] ⊻= bb(mv.dst)
    board.bb_for[captured_piece] ⊻= bb(mv.dst)
    board.bb_occ ⊻= bb(mv.src)
    board.bb_black ⊻= bb(mv.src) | bb(mv.dst)
    board.bb_white ⊻= bb(mv.dst)

    board.squares[mv.src + 1] = EMPTY
    board.squares[mv.dst + 1] = BLACK_BISHOP

    # adjust reversible flags
    board.side_to_move = Color(WHITE)
    board.ply += 1

    # adjust irreversible flags
    board.history[board.ply].ep_square = NO_SQUARE
    board.history[board.ply].castling_rights = board.history[board.ply - 1].castling_rights
    board.history[board.ply].fifty_move_counter = 0
    board.history[board.ply-1].captured_piece = captured_piece

    # adjust castling rights if rook captured
    if mv.dst == 0
        board.history[board.ply].castling_rights &= ~CASTLING_WQ
    elseif mv.dst == 7
        board.history[board.ply].castling_rights &= ~CASTLING_WK
    end
end

function do_move!(board::Board, c::Color{BLACK}, mv::Move{ROOK_PROMOTION_CAPTURE})
    # adjust boards
    captured_piece = board.squares[mv.dst + 1]

    board.bb_for[BLACK_PAWN] ⊻= bb(mv.src)
    board.bb_for[BLACK_ROOK] ⊻= bb(mv.dst)
    board.bb_for[captured_piece] ⊻= bb(mv.dst)
    board.bb_occ ⊻= bb(mv.src)
    board.bb_black ⊻= bb(mv.src) | bb(mv.dst)
    board.bb_white ⊻= bb(mv.dst)

    board.squares[mv.src + 1] = EMPTY
    board.squares[mv.dst + 1] = BLACK_ROOK

    # adjust reversible flags
    board.side_to_move = Color(WHITE)
    board.ply += 1

    # adjust irreversible flags
    board.history[board.ply].ep_square = NO_SQUARE
    board.history[board.ply].castling_rights = board.history[board.ply - 1].castling_rights
    board.history[board.ply].fifty_move_counter = 0
    board.history[board.ply-1].captured_piece = captured_piece

    # adjust castling rights if rook captured
    if mv.dst == 0
        board.history[board.ply].castling_rights &= ~CASTLING_WQ
    elseif mv.dst == 7
        board.history[board.ply].castling_rights &= ~CASTLING_WK
    end
end

function do_move!(board::Board, c::Color{BLACK}, mv::Move{QUEEN_PROMOTION_CAPTURE})
    # adjust boards
    captured_piece = board.squares[mv.dst + 1]

    board.bb_for[BLACK_PAWN] ⊻= bb(mv.src)
    board.bb_for[BLACK_QUEEN] ⊻= bb(mv.dst)
    board.bb_for[captured_piece] ⊻= bb(mv.dst)
    board.bb_occ ⊻= bb(mv.src)
    board.bb_black ⊻= bb(mv.src) | bb(mv.dst)
    board.bb_white ⊻= bb(mv.dst)

    board.squares[mv.src + 1] = EMPTY
    board.squares[mv.dst + 1] = BLACK_QUEEN

    # adjust reversible flags
    board.side_to_move = Color(WHITE)
    board.ply += 1

    # adjust irreversible flags
    board.history[board.ply].ep_square = NO_SQUARE
    board.history[board.ply].castling_rights = board.history[board.ply - 1].castling_rights
    board.history[board.ply].fifty_move_counter = 0
    board.history[board.ply-1].captured_piece = captured_piece

    # adjust castling rights if rook captured
    if mv.dst == 0
        board.history[board.ply].castling_rights &= ~CASTLING_WQ
    elseif mv.dst == 7
        board.history[board.ply].castling_rights &= ~CASTLING_WK
    end
end