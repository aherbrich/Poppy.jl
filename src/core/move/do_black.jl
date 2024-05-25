@inline function do_move_quiet_black!(board::Board, mv::Move)
    # adjust boards
    piece = board.squares[mv.src + 1]
    board.bb_for[piece] ⊻= (bb(mv.src) | bb(mv.dst))
    board.bb_occ ⊻= bb(mv.src) | bb(mv.dst)
    board.bb_black ⊻= bb(mv.src) | bb(mv.dst)

    board.squares[mv.src + 1] = EMPTY
    board.squares[mv.dst + 1] = piece

    # adjust reversible flags
    board.side_to_move = WHITE
    board.ply += 1

     # xor in/out changed pieces
     board.history[board.ply].hash ⊻= ZOBRIST_TABLE.pieces[mv.src + 1, piece] ⊻ ZOBRIST_TABLE.pieces[mv.dst + 1, piece]

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
    if mv.src == 60
        board.history[board.ply].castling_rights &= ~CASTLING_B
    elseif mv.src == 56
        board.history[board.ply].castling_rights &= ~CASTLING_BQ
    elseif mv.src == 63
        board.history[board.ply].castling_rights &= ~CASTLING_BK
    end
end

@inline function do_move_double_pawn_push_black!(board::Board, mv::Move)
    # adjust boards
    board.bb_for[BLACK_PAWN] ⊻= bb(mv.src) | bb(mv.dst)
    board.bb_occ ⊻= bb(mv.src) | bb(mv.dst)
    board.bb_black ⊻= bb(mv.src) | bb(mv.dst)

    board.squares[mv.src + 1] = EMPTY
    board.squares[mv.dst + 1] = BLACK_PAWN

    # adjust reversible flags
    board.side_to_move = WHITE
    board.ply += 1

    # xor in/out changed pieces
    board.history[board.ply].hash ⊻= ZOBRIST_TABLE.pieces[mv.src + 1, BLACK_PAWN] ⊻ ZOBRIST_TABLE.pieces[mv.dst + 1, BLACK_PAWN]

    # adjust irreversible flags
    board.history[board.ply].ep_square = mv.dst + 8
    board.history[board.ply].castling_rights = board.history[board.ply - 1].castling_rights
    board.history[board.ply].fifty_move_counter = 0
    board.history[board.ply-1].captured_piece = NO_PIECE

    # xor in new ep square
    board.history[board.ply].hash ⊻= ZOBRIST_TABLE.flags[(mv.dst % 8) + 1]
end

@inline function do_move_king_castle_black!(board::Board, mv::Move)
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
    board.side_to_move = WHITE
    board.ply += 1

    # xor in/out changed pieces
    board.history[board.ply].hash ⊻= ZOBRIST_TABLE.pieces[60 + 1, BLACK_KING] ⊻ ZOBRIST_TABLE.pieces[62 + 1, BLACK_KING]
    board.history[board.ply].hash ⊻= ZOBRIST_TABLE.pieces[63 + 1, BLACK_ROOK] ⊻ ZOBRIST_TABLE.pieces[61 + 1, BLACK_ROOK]

    # adjust irreversible flags
    board.history[board.ply].ep_square = NO_SQUARE
    board.history[board.ply].castling_rights = board.history[board.ply - 1].castling_rights & ~CASTLING_B
    board.history[board.ply].fifty_move_counter = board.history[board.ply - 1].fifty_move_counter + 1
    board.history[board.ply-1].captured_piece = NO_PIECE
end

@inline function do_move_queen_castle_black!(board::Board, mv::Move)
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
    board.side_to_move = WHITE
    board.ply += 1

    # xor in/out changed pieces
    board.history[board.ply].hash ⊻= ZOBRIST_TABLE.pieces[60 + 1, BLACK_KING] ⊻ ZOBRIST_TABLE.pieces[58 + 1, BLACK_KING]
    board.history[board.ply].hash ⊻= ZOBRIST_TABLE.pieces[56 + 1, BLACK_ROOK] ⊻ ZOBRIST_TABLE.pieces[59 + 1, BLACK_ROOK]

    # adjust irreversible flags
    board.history[board.ply].ep_square = NO_SQUARE
    board.history[board.ply].castling_rights = board.history[board.ply - 1].castling_rights & ~CASTLING_B
    board.history[board.ply].fifty_move_counter = board.history[board.ply - 1].fifty_move_counter + 1
    board.history[board.ply-1].captured_piece = NO_PIECE
end

@inline function do_move_capture_black!(board::Board, mv::Move)
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
    board.side_to_move = WHITE
    board.ply += 1

    # xor in/out changed pieces
    board.history[board.ply].hash ⊻= ZOBRIST_TABLE.pieces[mv.src + 1, piece] ⊻ ZOBRIST_TABLE.pieces[mv.dst + 1, piece] ⊻ ZOBRIST_TABLE.pieces[mv.dst + 1, captured_piece]

    # adjust irreversible flags
    board.history[board.ply].ep_square = NO_SQUARE
    board.history[board.ply].castling_rights = board.history[board.ply - 1].castling_rights
    board.history[board.ply].fifty_move_counter = 0
    board.history[board.ply-1].captured_piece = captured_piece

    # adjust castling rights if piece move from initial rook or king square
    if mv.src == 60
        board.history[board.ply].castling_rights &= ~CASTLING_B
    elseif mv.src == 56
        board.history[board.ply].castling_rights &= ~CASTLING_BQ
    elseif mv.src == 63
        board.history[board.ply].castling_rights &= ~CASTLING_BK
    end

    # adjust castling rights if rook captured
    if mv.dst == 0
        board.history[board.ply].castling_rights &= ~CASTLING_WQ
    elseif mv.dst == 7
        board.history[board.ply].castling_rights &= ~CASTLING_WK
    end
end

@inline function do_move_en_passant_black!(board::Board, mv::Move)
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
    board.side_to_move = WHITE
    board.ply += 1

    # xor in/out changed pieces
    board.history[board.ply].hash ⊻= ZOBRIST_TABLE.pieces[mv.src + 1, BLACK_PAWN] ⊻ ZOBRIST_TABLE.pieces[mv.dst + 1, BLACK_PAWN] ⊻ ZOBRIST_TABLE.pieces[mv.dst + 8 + 1, WHITE_PAWN]

    # adjust irreversible flags
    board.history[board.ply].ep_square = NO_SQUARE
    board.history[board.ply].castling_rights = board.history[board.ply - 1].castling_rights
    board.history[board.ply].fifty_move_counter = 0
    board.history[board.ply-1].captured_piece = WHITE_PAWN
end

@inline function do_move_knight_promotion_black!(board::Board, mv::Move)
    # adjust boards
    board.bb_for[BLACK_PAWN] ⊻= bb(mv.src)
    board.bb_for[BLACK_KNIGHT] ⊻= bb(mv.dst)
    board.bb_occ ⊻= bb(mv.src) | bb(mv.dst)
    board.bb_black ⊻= bb(mv.src) | bb(mv.dst)

    board.squares[mv.src + 1] = EMPTY
    board.squares[mv.dst + 1] = BLACK_KNIGHT

    # adjust reversible flags
    board.side_to_move = WHITE
    board.ply += 1

    # xor in/out changed pieces
    board.history[board.ply].hash ⊻= ZOBRIST_TABLE.pieces[mv.src + 1, BLACK_PAWN] ⊻ ZOBRIST_TABLE.pieces[mv.dst + 1, BLACK_KNIGHT]

    # adjust irreversible flags
    board.history[board.ply].ep_square = NO_SQUARE
    board.history[board.ply].castling_rights = board.history[board.ply - 1].castling_rights
    board.history[board.ply].fifty_move_counter = 0
    board.history[board.ply-1].captured_piece = NO_PIECE
end

@inline function do_move_bishop_promotion_black!(board::Board, mv::Move)
    # adjust boards
    board.bb_for[BLACK_PAWN] ⊻= bb(mv.src)
    board.bb_for[BLACK_BISHOP] ⊻= bb(mv.dst)
    board.bb_occ ⊻= bb(mv.src) | bb(mv.dst)
    board.bb_black ⊻= bb(mv.src) | bb(mv.dst)

    board.squares[mv.src + 1] = EMPTY
    board.squares[mv.dst + 1] = BLACK_BISHOP

    # adjust reversible flags
    board.side_to_move = WHITE
    board.ply += 1

    # xor in/out changed pieces
    board.history[board.ply].hash ⊻= ZOBRIST_TABLE.pieces[mv.src + 1, BLACK_PAWN] ⊻ ZOBRIST_TABLE.pieces[mv.dst + 1, BLACK_BISHOP]

    # adjust irreversible flags
    board.history[board.ply].ep_square = NO_SQUARE
    board.history[board.ply].castling_rights = board.history[board.ply - 1].castling_rights
    board.history[board.ply].fifty_move_counter = 0
    board.history[board.ply-1].captured_piece = NO_PIECE
end

@inline function do_move_rook_promotion_black!(board::Board, mv::Move)
    # adjust boards
    board.bb_for[BLACK_PAWN] ⊻= bb(mv.src)
    board.bb_for[BLACK_ROOK] ⊻= bb(mv.dst)
    board.bb_occ ⊻= bb(mv.src) | bb(mv.dst)
    board.bb_black ⊻= bb(mv.src) | bb(mv.dst)

    board.squares[mv.src + 1] = EMPTY
    board.squares[mv.dst + 1] = BLACK_ROOK

    # adjust reversible flags
    board.side_to_move = WHITE
    board.ply += 1

    # xor in/out changed pieces
    board.history[board.ply].hash ⊻= ZOBRIST_TABLE.pieces[mv.src + 1, BLACK_PAWN] ⊻ ZOBRIST_TABLE.pieces[mv.dst + 1, BLACK_ROOK]

    # adjust irreversible flags
    board.history[board.ply].ep_square = NO_SQUARE
    board.history[board.ply].castling_rights = board.history[board.ply - 1].castling_rights
    board.history[board.ply].fifty_move_counter = 0
    board.history[board.ply-1].captured_piece = NO_PIECE
end

@inline function do_move_queen_promotion_black!(board::Board, mv::Move)
    # adjust boards
    board.bb_for[BLACK_PAWN] ⊻= bb(mv.src)
    board.bb_for[BLACK_QUEEN] ⊻= bb(mv.dst)
    board.bb_occ ⊻= bb(mv.src) | bb(mv.dst)
    board.bb_black ⊻= bb(mv.src) | bb(mv.dst)

    board.squares[mv.src + 1] = EMPTY
    board.squares[mv.dst + 1] = BLACK_QUEEN

    # adjust reversible flags
    board.side_to_move = WHITE
    board.ply += 1

    # xor in/out changed pieces
    board.history[board.ply].hash ⊻= ZOBRIST_TABLE.pieces[mv.src + 1, BLACK_PAWN] ⊻ ZOBRIST_TABLE.pieces[mv.dst + 1, BLACK_QUEEN]

    # adjust irreversible flags
    board.history[board.ply].ep_square = NO_SQUARE
    board.history[board.ply].castling_rights = board.history[board.ply - 1].castling_rights
    board.history[board.ply].fifty_move_counter = 0
    board.history[board.ply-1].captured_piece = NO_PIECE
end

@inline function do_move_knight_promotion_capture_black!(board::Board, mv::Move)
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
    board.side_to_move = WHITE
    board.ply += 1

    # xor in/out changed pieces
    board.history[board.ply].hash ⊻= ZOBRIST_TABLE.pieces[mv.src + 1, BLACK_PAWN] ⊻ ZOBRIST_TABLE.pieces[mv.dst + 1, BLACK_KNIGHT] ⊻ ZOBRIST_TABLE.pieces[mv.dst + 1, captured_piece]

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

@inline function do_move_bishop_promotion_capture_black!(board::Board, mv::Move)
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
    board.side_to_move = WHITE
    board.ply += 1

    # xor in/out changed pieces
    board.history[board.ply].hash ⊻= ZOBRIST_TABLE.pieces[mv.src + 1, BLACK_PAWN] ⊻ ZOBRIST_TABLE.pieces[mv.dst + 1, BLACK_BISHOP] ⊻ ZOBRIST_TABLE.pieces[mv.dst + 1, captured_piece]

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

@inline function do_move_rook_promotion_capture_black!(board::Board, mv::Move)
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
    board.side_to_move = WHITE
    board.ply += 1

    # xor in/out changed pieces
    board.history[board.ply].hash ⊻= ZOBRIST_TABLE.pieces[mv.src + 1, BLACK_PAWN] ⊻ ZOBRIST_TABLE.pieces[mv.dst + 1, BLACK_ROOK] ⊻ ZOBRIST_TABLE.pieces[mv.dst + 1, captured_piece]

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

@inline function do_move_queen_promotion_capture_black!(board::Board, mv::Move)
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
    board.side_to_move = WHITE
    board.ply += 1

    # xor in/out changed pieces
    board.history[board.ply].hash ⊻= ZOBRIST_TABLE.pieces[mv.src + 1, BLACK_PAWN] ⊻ ZOBRIST_TABLE.pieces[mv.dst + 1, BLACK_QUEEN] ⊻ ZOBRIST_TABLE.pieces[mv.dst + 1, captured_piece]

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

@inline function do_move_black!(board::Board, move::Move)
    # carry over hash (since we only have to changed some bits)
    board.history[board.ply+1].hash = board.history[board.ply].hash

    # xor out old ep square
    if board.history[board.ply].ep_square != NO_SQUARE
        board.history[board.ply+1].hash ⊻= ZOBRIST_TABLE.flags[(board.history[board.ply].ep_square % 8) + 1]
    end

    # xor out old castling rights
    board.history[board.ply+1].hash ⊻= ZOBRIST_TABLE.flags[9 + board.history[board.ply].castling_rights]

    if move.type == QUIET
        do_move_quiet_black!(board, move)
    elseif move.type == DOUBLE_PAWN_PUSH
        do_move_double_pawn_push_black!(board, move)
    elseif move.type == KING_CASTLE
        do_move_king_castle_black!(board, move)
    elseif move.type == QUEEN_CASTLE
        do_move_queen_castle_black!(board, move)
    elseif move.type == CAPTURE
        do_move_capture_black!(board, move)
    elseif move.type == EN_PASSANT
        do_move_en_passant_black!(board, move)
    elseif move.type == KNIGHT_PROMOTION
        do_move_knight_promotion_black!(board, move)
    elseif move.type == BISHOP_PROMOTION
        do_move_bishop_promotion_black!(board, move)
    elseif move.type == ROOK_PROMOTION
        do_move_rook_promotion_black!(board, move)
    elseif move.type == QUEEN_PROMOTION
        do_move_queen_promotion_black!(board, move)
    elseif move.type == KNIGHT_PROMOTION_CAPTURE
        do_move_knight_promotion_capture_black!(board, move)
    elseif move.type == BISHOP_PROMOTION_CAPTURE
        do_move_bishop_promotion_capture_black!(board, move)
    elseif move.type == ROOK_PROMOTION_CAPTURE
        do_move_rook_promotion_capture_black!(board, move)
    elseif move.type == QUEEN_PROMOTION_CAPTURE
        do_move_queen_promotion_capture_black!(board, move)
    end

    # xor out old and xor in new side to move
    board.history[board.ply].hash ⊻= ZOBRIST_TABLE.flags[25] ⊻ ZOBRIST_TABLE.flags[26]

    # xor in new castling rights
    board.history[board.ply].hash ⊻= ZOBRIST_TABLE.flags[9 + board.history[board.ply].castling_rights]
end