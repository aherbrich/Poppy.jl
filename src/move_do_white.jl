function do_move!(board::Board, c::Color{WHITE}, mv::Move{QUIET})
    # adjust boards
    piece = board.squares[mv.src + 1]
    board.bb_for[piece] ⊻= (bb(mv.src) | bb(mv.dst))
    board.bb_occ ⊻= bb(mv.src) | bb(mv.dst)
    board.bb_white ⊻= bb(mv.src) | bb(mv.dst)

    board.squares[mv.src + 1] = EMPTY
    board.squares[mv.dst + 1] = piece

    # adjust reversible flags
    board.side_to_move = Color(BLACK)
    board.ply += 1

    # adjust irreversible flags
    board.history[board.ply].ep_square = NO_SQUARE
    board.history[board.ply].castling_rights = board.history[board.ply - 1].castling_rights
    board.history[board.ply].fifty_move_counter = board.history[board.ply - 1].fifty_move_counter + 1
    board.history[board.ply-1].captured_piece = NO_PIECE

    # adjust fifty move counter if pawn moved
    if piece == WHITE_PAWN
        board.history[board.ply].fifty_move_counter = 0
    end

    # adjust castling rights if piece move from initial rook or king square
    if mv.src == 4
        board.history[board.ply].castling_rights &= ~CASTLING_W
    elseif mv.src == 0
        board.history[board.ply].castling_rights &= ~CASTLING_WQ
    elseif mv.src == 7
        board.history[board.ply].castling_rights &= ~CASTLING_WK
    end
end

function do_move!(board::Board, c::Color{WHITE}, mv::Move{DOUBLE_PAWN_PUSH})
    # adjust boards
    board.bb_for[WHITE_PAWN] ⊻= bb(mv.src) | bb(mv.dst)
    board.bb_occ ⊻= bb(mv.src) | bb(mv.dst)
    board.bb_white ⊻= bb(mv.src) | bb(mv.dst)

    board.squares[mv.src + 1] = EMPTY
    board.squares[mv.dst + 1] = WHITE_PAWN

    # adjust reversible flags
    board.side_to_move = Color(BLACK)
    board.ply += 1

    # adjust irreversible flags
    board.history[board.ply].ep_square = mv.dst - 8
    board.history[board.ply].castling_rights = board.history[board.ply - 1].castling_rights
    board.history[board.ply].fifty_move_counter = 0
    board.history[board.ply-1].captured_piece = NO_PIECE
end

function do_move!(board::Board, c::Color{WHITE}, mv::Move{KING_CASTLE})
    # adjust boards
    board.bb_for[WHITE_KING] ⊻= 0x0000000000000050          # bb(4) | bb(6)
    board.bb_for[WHITE_ROOK] ⊻= 0x00000000000000a0          # bb(7) | bb(5)
    board.bb_occ ⊻= 0x00000000000000f0                      # bb(4) | bb(5) | bb(6) | bb(7)
    board.bb_white ⊻= 0x00000000000000f0                    # bb(4) | bb(5) | bb(6) | bb(7)

    board.squares[5] = EMPTY
    board.squares[8] = EMPTY
    board.squares[7] = WHITE_KING
    board.squares[6] = WHITE_ROOK

    # adjust reversible flags
    board.side_to_move = Color(BLACK)
    board.ply += 1

    # adjust irreversible flags
    board.history[board.ply].ep_square = NO_SQUARE
    board.history[board.ply].castling_rights = board.history[board.ply - 1].castling_rights & ~CASTLING_W
    board.history[board.ply].fifty_move_counter = board.history[board.ply - 1].fifty_move_counter + 1
    board.history[board.ply-1].captured_piece = NO_PIECE
end

function do_move!(board::Board, c::Color{WHITE}, mv::Move{QUEEN_CASTLE})
    # adjust boards
    board.bb_for[WHITE_KING] ⊻= 0x0000000000000014          # bb(4) | bb(2)
    board.bb_for[WHITE_ROOK] ⊻= 0x0000000000000009          # bb(0) | bb(3)
    board.bb_occ ⊻= 0x000000000000001d                      # bb(0) | bb(2) | bb(3) | bb(4)
    board.bb_white ⊻= 0x000000000000001d                    # bb(0) | bb(2) | bb(3) | bb(4)

    board.squares[1] = EMPTY
    board.squares[5] = EMPTY
    board.squares[3] = WHITE_KING
    board.squares[4] = WHITE_ROOK

    # adjust reversible flags
    board.side_to_move = Color(BLACK)
    board.ply += 1

    # adjust irreversible flags
    board.history[board.ply].ep_square = NO_SQUARE
    board.history[board.ply].castling_rights = board.history[board.ply - 1].castling_rights & ~CASTLING_W
    board.history[board.ply].fifty_move_counter = board.history[board.ply - 1].fifty_move_counter + 1
    board.history[board.ply-1].captured_piece = NO_PIECE
end

function do_move!(board::Board, c::Color{WHITE}, mv::Move{CAPTURE})
    # adjust boards
    piece = board.squares[mv.src + 1]
    captured_piece = board.squares[mv.dst + 1]

    board.bb_for[piece] ⊻= bb(mv.src) | bb(mv.dst)
    board.bb_for[captured_piece] ⊻= bb(mv.dst)
    board.bb_occ ⊻= bb(mv.src)
    board.bb_white ⊻= bb(mv.src) | bb(mv.dst)
    board.bb_black ⊻= bb(mv.dst)

    board.squares[mv.src + 1] = EMPTY
    board.squares[mv.dst + 1] = piece
    
    # adjust reversible flags
    board.side_to_move = Color(BLACK)
    board.ply += 1

    # adjust irreversible flags
    board.history[board.ply].ep_square = NO_SQUARE
    board.history[board.ply].castling_rights = board.history[board.ply - 1].castling_rights
    board.history[board.ply].fifty_move_counter = 0
    board.history[board.ply-1].captured_piece = captured_piece

    # adjust castling rights if piece move from initial rook or king square
    if mv.src == 4
        board.history[board.ply].castling_rights &= ~CASTLING_W
    elseif mv.src == 0
        board.history[board.ply].castling_rights &= ~CASTLING_WQ
    elseif mv.src == 7
        board.history[board.ply].castling_rights &= ~CASTLING_WK
    end

    # adjust castling rights if rook captured
    if mv.dst == 56
        board.history[board.ply].castling_rights &= ~CASTLING_BQ
    elseif mv.dst == 63
        board.history[board.ply].castling_rights &= ~CASTLING_BK
    end
end

function do_move!(board::Board, c::Color{WHITE}, mv::Move{EN_PASSANT})
    # adjust boards
    board.bb_for[WHITE_PAWN] ⊻= bb(mv.src) | bb(mv.dst)
    board.bb_for[BLACK_PAWN] ⊻= bb(mv.dst - 8)
    board.bb_occ ⊻= bb(mv.src) | bb(mv.dst) | bb(mv.dst - 8)
    board.bb_white ⊻= bb(mv.src) | bb(mv.dst)
    board.bb_black ⊻= bb(mv.dst - 8)

    board.squares[mv.src + 1] = EMPTY
    board.squares[mv.dst + 1] = WHITE_PAWN
    board.squares[mv.dst - 8 + 1] = EMPTY

    # adjust reversible flags
    board.side_to_move = Color(BLACK)
    board.ply += 1

    # adjust irreversible flags
    board.history[board.ply].ep_square = NO_SQUARE
    board.history[board.ply].castling_rights = board.history[board.ply - 1].castling_rights
    board.history[board.ply].fifty_move_counter = 0
    board.history[board.ply-1].captured_piece = BLACK_PAWN
end

function do_move!(board::Board, c::Color{WHITE}, mv::Move{KNIGHT_PROMOTION})
    # adjust boards
    board.bb_for[WHITE_PAWN] ⊻= bb(mv.src)
    board.bb_for[WHITE_KNIGHT] ⊻= bb(mv.dst)
    board.bb_occ ⊻= bb(mv.src) | bb(mv.dst)
    board.bb_white ⊻= bb(mv.src) | bb(mv.dst)

    board.squares[mv.src + 1] = EMPTY
    board.squares[mv.dst + 1] = WHITE_KNIGHT

    # adjust reversible flags
    board.side_to_move = Color(BLACK)
    board.ply += 1

    # adjust irreversible flags
    board.history[board.ply].ep_square = NO_SQUARE
    board.history[board.ply].castling_rights = board.history[board.ply - 1].castling_rights
    board.history[board.ply].fifty_move_counter = 0
    board.history[board.ply-1].captured_piece = NO_PIECE
end

function do_move!(board::Board, c::Color{WHITE}, mv::Move{BISHOP_PROMOTION})
    # adjust boards
    board.bb_for[WHITE_PAWN] ⊻= bb(mv.src)
    board.bb_for[WHITE_BISHOP] ⊻= bb(mv.dst)
    board.bb_occ ⊻= bb(mv.src) | bb(mv.dst)
    board.bb_white ⊻= bb(mv.src) | bb(mv.dst)

    board.squares[mv.src + 1] = EMPTY
    board.squares[mv.dst + 1] = WHITE_BISHOP

    # adjust reversible flags
    board.side_to_move = Color(BLACK)
    board.ply += 1

    # adjust irreversible flags
    board.history[board.ply].ep_square = NO_SQUARE
    board.history[board.ply].castling_rights = board.history[board.ply - 1].castling_rights
    board.history[board.ply].fifty_move_counter = 0
    board.history[board.ply-1].captured_piece = NO_PIECE
end

function do_move!(board::Board, c::Color{WHITE}, mv::Move{ROOK_PROMOTION})
    # adjust boards
    board.bb_for[WHITE_PAWN] ⊻= bb(mv.src)
    board.bb_for[WHITE_ROOK] ⊻= bb(mv.dst)
    board.bb_occ ⊻= bb(mv.src) | bb(mv.dst)
    board.bb_white ⊻= bb(mv.src) | bb(mv.dst)

    board.squares[mv.src + 1] = EMPTY
    board.squares[mv.dst + 1] = WHITE_ROOK

    # adjust reversible flags
    board.side_to_move = Color(BLACK)
    board.ply += 1

    # adjust irreversible flags
    board.history[board.ply].ep_square = NO_SQUARE
    board.history[board.ply].castling_rights = board.history[board.ply - 1].castling_rights
    board.history[board.ply].fifty_move_counter = 0
    board.history[board.ply-1].captured_piece = NO_PIECE
end

function do_move!(board::Board, c::Color{WHITE}, mv::Move{QUEEN_PROMOTION})
    # adjust boards
    board.bb_for[WHITE_PAWN] ⊻= bb(mv.src)
    board.bb_for[WHITE_QUEEN] ⊻= bb(mv.dst)
    board.bb_occ ⊻= bb(mv.src) | bb(mv.dst)
    board.bb_white ⊻= bb(mv.src) | bb(mv.dst)

    board.squares[mv.src + 1] = EMPTY
    board.squares[mv.dst + 1] = WHITE_QUEEN

    # adjust reversible flags
    board.side_to_move = Color(BLACK)
    board.ply += 1

    # adjust irreversible flags
    board.history[board.ply].ep_square = NO_SQUARE
    board.history[board.ply].castling_rights = board.history[board.ply - 1].castling_rights
    board.history[board.ply].fifty_move_counter = 0
    board.history[board.ply-1].captured_piece = NO_PIECE
end

function do_move!(board::Board, c::Color{WHITE}, mv::Move{KNIGHT_PROMOTION_CAPTURE})
    # adjust boards
    captured_piece = board.squares[mv.dst + 1]

    board.bb_for[WHITE_PAWN] ⊻= bb(mv.src)
    board.bb_for[WHITE_KNIGHT] ⊻= bb(mv.dst)
    board.bb_for[captured_piece] ⊻= bb(mv.dst)
    board.bb_occ ⊻= bb(mv.src)
    board.bb_white ⊻= bb(mv.src) | bb(mv.dst)
    board.bb_black ⊻= bb(mv.dst)

    board.squares[mv.src + 1] = EMPTY
    board.squares[mv.dst + 1] = WHITE_KNIGHT

    # adjust reversible flags
    board.side_to_move = Color(BLACK)
    board.ply += 1

    # adjust irreversible flags
    board.history[board.ply].ep_square = NO_SQUARE
    board.history[board.ply].castling_rights = board.history[board.ply - 1].castling_rights
    board.history[board.ply].fifty_move_counter = 0
    board.history[board.ply-1].captured_piece = captured_piece

    # adjust castling rights if rook captured
    if mv.dst == 56
        board.history[board.ply].castling_rights &= ~CASTLING_BQ
    elseif mv.dst == 63
        board.history[board.ply].castling_rights &= ~CASTLING_BK
    end
end

function do_move!(board::Board, c::Color{WHITE}, mv::Move{BISHOP_PROMOTION_CAPTURE})
    # adjust boards
    captured_piece = board.squares[mv.dst + 1]

    board.bb_for[WHITE_PAWN] ⊻= bb(mv.src)
    board.bb_for[WHITE_BISHOP] ⊻= bb(mv.dst)
    board.bb_for[captured_piece] ⊻= bb(mv.dst)
    board.bb_occ ⊻= bb(mv.src)
    board.bb_white ⊻= bb(mv.src) | bb(mv.dst)
    board.bb_black ⊻= bb(mv.dst)

    board.squares[mv.src + 1] = EMPTY
    board.squares[mv.dst + 1] = WHITE_BISHOP

    # adjust reversible flags
    board.side_to_move = Color(BLACK)
    board.ply += 1

    # adjust irreversible flags
    board.history[board.ply].ep_square = NO_SQUARE
    board.history[board.ply].castling_rights = board.history[board.ply - 1].castling_rights
    board.history[board.ply].fifty_move_counter = 0
    board.history[board.ply-1].captured_piece = captured_piece

    # adjust castling rights if rook captured
    if mv.dst == 56
        board.history[board.ply].castling_rights &= ~CASTLING_BQ
    elseif mv.dst == 63
        board.history[board.ply].castling_rights &= ~CASTLING_BK
    end
end

function do_move!(board::Board, c::Color{WHITE}, mv::Move{ROOK_PROMOTION_CAPTURE})
    # adjust boards
    captured_piece = board.squares[mv.dst + 1]

    board.bb_for[WHITE_PAWN] ⊻= bb(mv.src)
    board.bb_for[WHITE_ROOK] ⊻= bb(mv.dst)
    board.bb_for[captured_piece] ⊻= bb(mv.dst)
    board.bb_occ ⊻= bb(mv.src)
    board.bb_white ⊻= bb(mv.src) | bb(mv.dst)
    board.bb_black ⊻= bb(mv.dst)

    board.squares[mv.src + 1] = EMPTY
    board.squares[mv.dst + 1] = WHITE_ROOK

    # adjust reversible flags
    board.side_to_move = Color(BLACK)
    board.ply += 1

    # adjust irreversible flags
    board.history[board.ply].ep_square = NO_SQUARE
    board.history[board.ply].castling_rights = board.history[board.ply - 1].castling_rights
    board.history[board.ply].fifty_move_counter = 0
    board.history[board.ply-1].captured_piece = captured_piece

    # adjust castling rights if rook captured
    if mv.dst == 56
        board.history[board.ply].castling_rights &= ~CASTLING_BQ
    elseif mv.dst == 63
        board.history[board.ply].castling_rights &= ~CASTLING_BK
    end
end

function do_move!(board::Board, c::Color{WHITE}, mv::Move{QUEEN_PROMOTION_CAPTURE})
    # adjust boards
    captured_piece = board.squares[mv.dst + 1]

    board.bb_for[WHITE_PAWN] ⊻= bb(mv.src)
    board.bb_for[WHITE_QUEEN] ⊻= bb(mv.dst)
    board.bb_for[captured_piece] ⊻= bb(mv.dst)
    board.bb_occ ⊻= bb(mv.src)
    board.bb_white ⊻= bb(mv.src) | bb(mv.dst)
    board.bb_black ⊻= bb(mv.dst)

    board.squares[mv.src + 1] = EMPTY
    board.squares[mv.dst + 1] = WHITE_QUEEN

    # adjust reversible flags
    board.side_to_move = Color(BLACK)
    board.ply += 1

    # adjust irreversible flags
    board.history[board.ply].ep_square = NO_SQUARE
    board.history[board.ply].castling_rights = board.history[board.ply - 1].castling_rights
    board.history[board.ply].fifty_move_counter = 0
    board.history[board.ply-1].captured_piece = captured_piece

    # adjust castling rights if rook captured
    if mv.dst == 56
        board.history[board.ply].castling_rights &= ~CASTLING_BQ
    elseif mv.dst == 63
        board.history[board.ply].castling_rights &= ~CASTLING_BK
    end
end