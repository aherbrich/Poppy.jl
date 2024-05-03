function sq_is_attacked(board::Board, c::Color{WHITE}, sq)
    pawn_captures = (bb(sq) & CLEAR_FILE_A) << 7 | (bb(sq) & CLEAR_FILE_H) << 9
    if (pawn_captures & board.bb_for[BLACK_PAWN]) != 0
        return true
    end

    if knight_pseudo_attack(sq) & board.bb_for[BLACK_KNIGHT] != 0
        return true
    end

    if king_pseudo_attack(sq) & board.bb_for[BLACK_KING] != 0
        return true
    end

    if rook_pseudo_attack(sq, board.bb_occ) & (board.bb_for[BLACK_ROOK] | board.bb_for[BLACK_QUEEN]) != 0
        return true
    end

    if bishop_pseudo_attack(sq, board.bb_occ) & (board.bb_for[BLACK_BISHOP] | board.bb_for[BLACK_QUEEN]) != 0
        return true
    end

    return false
end

function sq_is_attacked(board::Board, c::Color{BLACK}, sq)
    pawn_captures = (bb(sq) & CLEAR_FILE_A) >> 9 | (bb(sq) & CLEAR_FILE_H) >> 7
    if (pawn_captures & board.bb_for[WHITE_PAWN]) != 0
        return true
    end

    if knight_pseudo_attack(sq) & board.bb_for[WHITE_KNIGHT] != 0
        return true
    end

    if king_pseudo_attack(sq) & board.bb_for[WHITE_KING] != 0
        return true
    end

    if rook_pseudo_attack(sq, board.bb_occ) & (board.bb_for[WHITE_ROOK] | board.bb_for[WHITE_QUEEN]) != 0
        return true
    end

    if bishop_pseudo_attack(sq, board.bb_occ) & (board.bb_for[WHITE_BISHOP] | board.bb_for[WHITE_QUEEN]) != 0
        return true
    end

    return false
end

@inline function in_check(board::Board, c::Color{WHITE}, move::Move)
    return sq_is_attacked(board, c, trailing_zeros(board.bb_for[WHITE_KING]))
end

@inline function in_check(board::Board, c::Color{BLACK}, move::Move)
    return sq_is_attacked(board, c, trailing_zeros(board.bb_for[BLACK_KING]))
end

function generate_pseudo_moves(c::Color{WHITE}, board::Board)
    moves = Vector{Move}()

    # generate all pseudo legal moves
    generate_pseudo_pawn_moves(c, board, moves)
    generate_pseudo_knight_moves(c, board, moves)
    generate_pseudo_bishop_moves(c, board, moves)
    generate_pseudo_rook_moves(c, board, moves)
    generate_pseudo_queen_moves(c, board, moves)
    generate_pseudo_king_moves(c, board, moves)
    generate_pseudo_castling_moves(c, board, moves)

    return moves
end

function generate_pseudo_moves(c::Color{BLACK}, board::Board)
    moves = Vector{Move}()

    # generate all pseudo legal moves
    generate_pseudo_pawn_moves(c, board, moves)
    generate_pseudo_knight_moves(c, board, moves)
    generate_pseudo_bishop_moves(c, board, moves)
    generate_pseudo_rook_moves(c, board, moves)
    generate_pseudo_queen_moves(c, board, moves)
    generate_pseudo_king_moves(c, board, moves)
    generate_pseudo_castling_moves(c, board, moves)

    return moves
end