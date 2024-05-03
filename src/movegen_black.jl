function generate_pseudo_pawn_pushes(c::Color{BLACK}, board::Board, moves::Vector{Move})
    # determine all pawns which are not about to promote
    pawns = board.bb_for[BLACK_PAWN] & ~RANK_2

    single_pushes = (pawns >> 8) & ~board.bb_occ
    double_pushes = ((single_pushes & RANK_6) >> 8) & ~board.bb_occ

    while single_pushes != 0
        to_sq = @pop_lsb!(single_pushes)
        from_sq = to_sq + 8
        push!(moves, Move(from_sq, to_sq, QUIET))
    end

    while double_pushes != 0
        to_sq = @pop_lsb!(double_pushes)
        from_sq = to_sq + 16
        push!(moves, Move(from_sq, to_sq, DOUBLE_PAWN_PUSH))
    end
end

function generate_pseudo_pawn_captures(c::Color{BLACK}, board::Board, moves::Vector{Move})
    # determine all pawns which are not about to promote
    pawns = board.bb_for[BLACK_PAWN] & ~RANK_2

    left_captures = (pawns & CLEAR_FILE_H) >> 7 & board.bb_white
    right_captures = (pawns & CLEAR_FILE_A) >> 9 & board.bb_white

    while left_captures != 0
        to_sq = @pop_lsb!(left_captures)
        from_sq = to_sq + 7 
        push!(moves, Move(from_sq, to_sq, CAPTURE))
    end

    while right_captures != 0
        to_sq = @pop_lsb!(right_captures)
        from_sq = to_sq + 9
        push!(moves, Move(from_sq, to_sq, CAPTURE))
    end
end

function generate_pseudo_pawn_ep(c::Color{BLACK}, board::Board, moves::Vector{Move})
    ep_sq = board.history[board.ply].ep_square

    if ep_sq == NO_SQUARE
        return
    end

    pawns = board.bb_for[BLACK_PAWN] & RANK_4

    left_ep = (pawns & CLEAR_FILE_H) >> 7
    right_ep = (pawns & CLEAR_FILE_A) >> 9


    
    while left_ep != 0
        idx = @pop_lsb!(left_ep)
        if idx == ep_sq
            from_sq = idx + 7
            push!(moves, Move(from_sq, ep_sq, EN_PASSANT))
        end
    end

    
    while right_ep != 0
        idx = @pop_lsb!(right_ep)
        if idx == ep_sq
            from_sq = idx + 9
            push!(moves, Move(from_sq, ep_sq, EN_PASSANT))
        end
    end
end

function generate_pseudo_pawn_promotions(c::Color{BLACK}, board::Board, moves::Vector{Move})
    pawns = board.bb_for[BLACK_PAWN] & RANK_2

    if pawns == 0
        return
    end

    single_pushes = (pawns >> 8) & ~board.bb_occ
    left_captures = (pawns & CLEAR_FILE_H) >> 7 & board.bb_white
    right_captures = (pawns & CLEAR_FILE_A) >> 9 & board.bb_white

    while single_pushes != 0
        to_sq = @pop_lsb!(single_pushes)
        from_sq = to_sq + 8
        push!(moves, Move(from_sq, to_sq, KNIGHT_PROMOTION))
        push!(moves, Move(from_sq, to_sq, BISHOP_PROMOTION))
        push!(moves, Move(from_sq, to_sq, ROOK_PROMOTION))
        push!(moves, Move(from_sq, to_sq, QUEEN_PROMOTION))
    end

    while left_captures != 0
        to_sq = @pop_lsb!(left_captures)
        from_sq = to_sq + 7
        push!(moves, Move(from_sq, to_sq, KNIGHT_PROMOTION_CAPTURE))
        push!(moves, Move(from_sq, to_sq, BISHOP_PROMOTION_CAPTURE))
        push!(moves, Move(from_sq, to_sq, ROOK_PROMOTION_CAPTURE))
        push!(moves, Move(from_sq, to_sq, QUEEN_PROMOTION_CAPTURE))
    end

    while right_captures != 0
        to_sq = @pop_lsb!(right_captures)
        from_sq = to_sq + 9
        push!(moves, Move(from_sq, to_sq, KNIGHT_PROMOTION_CAPTURE))
        push!(moves, Move(from_sq, to_sq, BISHOP_PROMOTION_CAPTURE))
        push!(moves, Move(from_sq, to_sq, ROOK_PROMOTION_CAPTURE))
        push!(moves, Move(from_sq, to_sq, QUEEN_PROMOTION_CAPTURE))
    end
end

function generate_pseudo_pawn_moves(c::Color{BLACK}, board::Board, moves::Vector{Move})
    generate_pseudo_pawn_pushes(c, board, moves)
    generate_pseudo_pawn_captures(c, board, moves)
    generate_pseudo_pawn_ep(c, board, moves)
    generate_pseudo_pawn_promotions(c, board, moves)
end

function generate_pseudo_knight_moves(c::Color{BLACK}, board::Board, moves::Vector{Move})
    knights = board.bb_for[BLACK_KNIGHT]
    while knights != 0
        from_sq = @pop_lsb!(knights)

        attacks = knight_pseudo_attack(from_sq)
        
        quiet_bb = attacks & ~board.bb_occ
        capture_bb = attacks & board.bb_white

        push_moves!(moves, from_sq, quiet_bb, QUIET)
        push_moves!(moves, from_sq, capture_bb, CAPTURE)
    end
end

function generate_pseudo_king_moves(c::Color{BLACK}, board::Board, moves::Vector{Move})
    kings = board.bb_for[BLACK_KING]
    while kings != 0
        from_sq = @pop_lsb!(kings)

        attacks = king_pseudo_attack(from_sq)
        
        quiet_bb = attacks & ~board.bb_occ
        capture_bb = attacks & board.bb_white

        push_moves!(moves, from_sq, quiet_bb, QUIET)
        push_moves!(moves, from_sq, capture_bb, CAPTURE)
    end
end

function generate_pseudo_bishop_moves(c::Color{BLACK}, board::Board, moves::Vector{Move})
    bishops = board.bb_for[BLACK_BISHOP]
    while bishops != 0
        from_sq = @pop_lsb!(bishops)

        attacks = bishop_pseudo_attack(from_sq, board.bb_occ)
        
        quiet_bb = attacks & ~board.bb_occ
        capture_bb = attacks & board.bb_white

        push_moves!(moves, from_sq, quiet_bb, QUIET)
        push_moves!(moves, from_sq, capture_bb, CAPTURE)
    end
end

function generate_pseudo_rook_moves(c::Color{BLACK}, board::Board, moves::Vector{Move})
    rooks = board.bb_for[BLACK_ROOK]
    while rooks != 0
        from_sq = @pop_lsb!(rooks)

        attacks = rook_pseudo_attack(from_sq, board.bb_occ)
        
        quiet_bb = attacks & ~board.bb_occ
        capture_bb = attacks & board.bb_white

        push_moves!(moves, from_sq, quiet_bb, QUIET)
        push_moves!(moves, from_sq, capture_bb, CAPTURE)
    end
end

function generate_pseudo_queen_moves(c::Color{BLACK}, board::Board, moves::Vector{Move})
    queens = board.bb_for[BLACK_QUEEN]
    while queens != 0
        from_sq = @pop_lsb!(queens)

        attacks = rook_pseudo_attack(from_sq, board.bb_occ) | bishop_pseudo_attack(from_sq, board.bb_occ)
        
        quiet_bb = attacks & ~board.bb_occ
        capture_bb = attacks & board.bb_white

        push_moves!(moves, from_sq, quiet_bb, QUIET)
        push_moves!(moves, from_sq, capture_bb, CAPTURE)
    end
end

function generate_pseudo_castling_moves(c::Color{BLACK}, board::Board, moves::Vector{Move})
    king_mask, queen_mask = (0x6000000000000000, 0x0e00000000000000)
    
    king_castle_allowed = board.history[board.ply].castling_rights & CASTLING_BK != 0
    queen_castle_allowed = board.history[board.ply].castling_rights & CASTLING_BQ != 0

    if (board.bb_occ & king_mask) == 0 && king_castle_allowed
        for sq in 60:61
            if sq_is_attacked(board, c, sq)
                return
            end
        end
        push!(moves, Move(60, 62, KING_CASTLE))
    end

    if (board.bb_occ & queen_mask) == 0 && queen_castle_allowed
        for sq in 59:60
            if sq_is_attacked(board, c, sq)
                return
            end
        end
        push!(moves, Move(60, 58, QUEEN_CASTLE))
    end
end
