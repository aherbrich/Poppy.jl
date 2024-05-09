@inline function attacks_by_pawns(pawns::UInt64, as::Color{BLACK})
    return ((pawns & CLEAR_FILE_H) >> 7) |  ((pawns & CLEAR_FILE_A) >> 9)
end

function calculate_danger_map(board::Board, c::Color{BLACK})
    # attacks by enemy pawns
    danger = attacks_by_pawns(board.bb_for[WHITE_PAWN], Color(WHITE))

    # attacks by enemy king
    danger |= king_pseudo_attack(trailing_zeros(board.bb_for[WHITE_KING]))

    # attacks by enemy knights
    bb1 = board.bb_for[WHITE_KNIGHT]
    while bb1 != 0
        knight_sq = @pop_lsb!(bb1)
        danger |= knight_pseudo_attack(knight_sq)
    end

    # attacks by enemy rooks and queens (orthogonal)
    bb1 = board.bb_for[WHITE_ROOK] | board.bb_for[WHITE_QUEEN]
    while bb1 != 0
        slider_sq = @pop_lsb!(bb1)
        danger |= rook_pseudo_attack(slider_sq, board.bb_occ ⊻ board.bb_for[BLACK_KING])
    end

    # attacks by enemy bishops and queens (diagonal)
    bb1 = board.bb_for[WHITE_BISHOP] | board.bb_for[WHITE_QUEEN]
    while bb1 != 0
        slider_sq = @pop_lsb!(bb1)
        danger |= bishop_pseudo_attack(slider_sq, board.bb_occ ⊻ board.bb_for[BLACK_KING])
    end

    return danger
end

function find_checkers_and_pinned(board::Board, c::Color{BLACK})
    # own king square
    black_king_sq = trailing_zeros(board.bb_for[BLACK_KING])

    # enemy knights attacking the king
    checkers = knight_pseudo_attack(black_king_sq) & board.bb_for[WHITE_KNIGHT]
    
    # enemy pawns attacking the king
    checkers |= attacks_by_pawns(board.bb_for[BLACK_KING], Color(BLACK)) & board.bb_for[WHITE_PAWN]

    # enemy sliders which have an attack on the king (if all of the own pieces are removed)
    candidates = rook_pseudo_attack(black_king_sq, board.bb_white) & (board.bb_for[WHITE_ROOK] | board.bb_for[WHITE_QUEEN]) | 
                 bishop_pseudo_attack(black_king_sq, board.bb_white) & (board.bb_for[WHITE_BISHOP] | board.bb_for[WHITE_QUEEN])

    pinned = UInt64(0)

    while candidates != 0
        slider_sq = @pop_lsb!(candidates)
        bb1 = squares_between(black_king_sq, slider_sq) & board.bb_black
        
        if bb1 == 0                       # i.e. no own piece in between
            checkers |= bb(slider_sq)
        elseif (bb1 & (bb1-1)) == 0       # i.e. only one piece in between
            pinned |= bb1
        end
    end
   
    return checkers, pinned
end

function generate_king_legals(board::Board, c::Color{BLACK}, moves::Vector{Move}, danger::UInt64)
    black_king_sq = trailing_zeros(board.bb_for[BLACK_KING])

    bb1 = king_pseudo_attack(black_king_sq) & ~danger
    push_moves!(moves, black_king_sq, bb1 & ~board.bb_occ, QUIET)
    push_moves!(moves, black_king_sq, bb1 & board.bb_white, CAPTURE)
end

function generate_legal_castle_moves(board::Board, c::Color{BLACK}, moves::Vector{Move}, danger::UInt64)
    oo_mask = 0x6000000000000000
    oo_allowed = board.history[board.ply].castling_rights & CASTLING_BK != 0

    if ((board.bb_occ | danger) & oo_mask) == 0 && oo_allowed
        push!(moves, Move(60, 62, KING_CASTLE))
    end

    ooo_mask = 0x0E00000000000000
    ooo_allowed = board.history[board.ply].castling_rights & CASTLING_BQ != 0
    ignore_b8 = 0xfdffffffffffffff

    if ((board.bb_occ | (danger & ignore_b8)) & ooo_mask) == 0 && ooo_allowed
        push!(moves, Move(60, 58, QUEEN_CASTLE))
    end
end

function generate_legal_captures_on_checker_sq(board::Board, c::Color{BLACK}, moves::Vector{Move}, checker_sq::Int, not_pinned::UInt64)
    checker = bb(checker_sq)

    attacks = knight_pseudo_attack(checker_sq) & board.bb_for[BLACK_KNIGHT]
    attacks |= attacks_by_pawns(checker, Color(WHITE)) & board.bb_for[BLACK_PAWN]
    attacks |= rook_pseudo_attack(checker_sq, board.bb_occ) & (board.bb_for[BLACK_ROOK] | board.bb_for[BLACK_QUEEN])
    attacks |= bishop_pseudo_attack(checker_sq, board.bb_occ) & (board.bb_for[BLACK_BISHOP] | board.bb_for[BLACK_QUEEN])

    attacks &= not_pinned

    while attacks != 0
        from_sq = @pop_lsb!(attacks)
        push!(moves, Move(from_sq, checker_sq, CAPTURE))
    end
end

function generate_legal_ep_captures_on_checker_sq(board::Board, c::Color{BLACK}, moves::Vector{Move}, checker_sq::Int, not_pinned::UInt64)
    ep_sq = board.history[board.ply].ep_square

    if ep_sq != 0 && ep_sq == checker_sq - 8
        bb1 = attacks_by_pawns(bb(ep_sq), Color(WHITE)) & board.bb_for[BLACK_PAWN] & not_pinned

        while bb1 != 0
            from_sq = @pop_lsb!(bb1)
            push!(moves, Move(from_sq, ep_sq, EN_PASSANT))
        end
    end
end

function generate_legal_non_pinned_moves(board::Board, c::Color{BLACK}, moves::Vector{Move}, quiet_mask::UInt64, capture_mask::UInt64, not_pinned::UInt64)
    ###################
    # KNIGHTS
    knights = board.bb_for[BLACK_KNIGHT] & not_pinned
    while knights != 0
        from_sq = @pop_lsb!(knights)
        attacks = knight_pseudo_attack(from_sq)
        push_moves!(moves, from_sq, attacks & quiet_mask, QUIET)
        push_moves!(moves, from_sq, attacks & capture_mask, CAPTURE)
    end

    ###################
    # DIAGONALS
    diagonals = (board.bb_for[BLACK_BISHOP] | board.bb_for[BLACK_QUEEN]) & not_pinned
    while diagonals != 0
        from_sq = @pop_lsb!(diagonals)
        attacks = bishop_pseudo_attack(from_sq, board.bb_occ)
        push_moves!(moves, from_sq, attacks & quiet_mask, QUIET)
        push_moves!(moves, from_sq, attacks & capture_mask, CAPTURE)
    end

    ###################
    # ORTHOGONALS
    orthogonals = (board.bb_for[BLACK_ROOK] | board.bb_for[BLACK_QUEEN]) & not_pinned
    while orthogonals != 0
        from_sq = @pop_lsb!(orthogonals)
        attacks = rook_pseudo_attack(from_sq, board.bb_occ)
        push_moves!(moves, from_sq, attacks & quiet_mask, QUIET)
        push_moves!(moves, from_sq, attacks & capture_mask, CAPTURE)
    end

    pawns = board.bb_for[BLACK_PAWN] & not_pinned & ~RANK_2

    ###################
    # PAWN PUSHES
    single_pushes = (pawns >> 8) & ~board.bb_occ
    double_pushes = ((single_pushes & RANK_6) >> 8) & ~board.bb_occ

    single_pushes &= quiet_mask
    double_pushes &= quiet_mask

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

    ###################
    # PAWN CAPTURES
    left_captures = (pawns & CLEAR_FILE_H) >> 7 & capture_mask
    right_captures = (pawns & CLEAR_FILE_A) >> 9 & capture_mask

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

    ###################
    # PAWN PROMOTIONS
    pawns = board.bb_for[BLACK_PAWN] & RANK_2 & not_pinned

    if pawns != 0
        single_pushes = (pawns >> 8) & quiet_mask
        while single_pushes != 0
            to_sq = @pop_lsb!(single_pushes)
            from_sq = to_sq + 8
            push!(moves, Move(from_sq, to_sq, KNIGHT_PROMOTION))
            push!(moves, Move(from_sq, to_sq, BISHOP_PROMOTION))
            push!(moves, Move(from_sq, to_sq, ROOK_PROMOTION))
            push!(moves, Move(from_sq, to_sq, QUEEN_PROMOTION))
        end

        left_captures = (pawns & CLEAR_FILE_H) >> 7 & capture_mask
        right_captures = (pawns & CLEAR_FILE_A) >> 9 & capture_mask

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
end

function generate_legal_pinned_moves(board::Board, c::Color{BLACK}, moves::Vector{Move}, quiet_mask::UInt64, capture_mask::UInt64, pinned::UInt64)
    our_king_sq = trailing_zeros(board.bb_for[BLACK_KING])

    ###################
    # BISHOPS
    bb1 = board.bb_for[BLACK_BISHOP] & pinned
    while bb1 != 0
        from_sq = @pop_lsb!(bb1)
        attacks = bishop_pseudo_attack(from_sq, board.bb_occ) & line_spanned(our_king_sq, from_sq)

        push_moves!(moves, from_sq, attacks & quiet_mask, QUIET)
        push_moves!(moves, from_sq, attacks & capture_mask, CAPTURE)
    end

    ###################
    # ROOKS
    bb1 = board.bb_for[BLACK_ROOK] & pinned
    while bb1 != 0
        from_sq = @pop_lsb!(bb1)
        attacks = rook_pseudo_attack(from_sq, board.bb_occ) & line_spanned(our_king_sq, from_sq)

        push_moves!(moves, from_sq, attacks & quiet_mask, QUIET)
        push_moves!(moves, from_sq, attacks & capture_mask, CAPTURE)
    end

    ###################
    # QUEENS
    bb1 = board.bb_for[BLACK_QUEEN] & pinned
    while bb1 != 0
        from_sq = @pop_lsb!(bb1)
        attacks = (rook_pseudo_attack(from_sq, board.bb_occ) | bishop_pseudo_attack(from_sq, board.bb_occ)) & line_spanned(our_king_sq, from_sq)

        push_moves!(moves, from_sq, attacks & quiet_mask, QUIET)
        push_moves!(moves, from_sq, attacks & capture_mask, CAPTURE)
    end

    ###################
    # PROMOTING PAWNS
    bb1 = board.bb_for[BLACK_PAWN] & pinned & RANK_2
    while bb1 != 0
        from_sq = @pop_lsb!(bb1)
        attacks = attacks_by_pawns(bb(from_sq), Color(BLACK)) & capture_mask & line_spanned(our_king_sq, from_sq)

        while attacks != 0
            to_sq = @pop_lsb!(attacks)
            push!(moves, Move(from_sq, to_sq, KNIGHT_PROMOTION_CAPTURE))
            push!(moves, Move(from_sq, to_sq, BISHOP_PROMOTION_CAPTURE))
            push!(moves, Move(from_sq, to_sq, ROOK_PROMOTION_CAPTURE))
            push!(moves, Move(from_sq, to_sq, QUEEN_PROMOTION_CAPTURE))
        end
    end

    ###################
    # PAWNS
    bb1 = board.bb_for[BLACK_PAWN] & pinned & ~RANK_2

    while bb1 != 0
        from_sq = @pop_lsb!(bb1)

        # captures
        attacks = attacks_by_pawns(bb(from_sq), Color(BLACK)) & capture_mask & line_spanned(our_king_sq, from_sq)
        while attacks != 0
            to_sq = @pop_lsb!(attacks)
            push!(moves, Move(from_sq, to_sq, CAPTURE))
        end

        # quiet moves
        single_push = (bb(from_sq) >> 8) & ~board.bb_occ & line_spanned(our_king_sq, from_sq)
        double_push = ((single_push & RANK_6) >> 8) & ~board.bb_occ & line_spanned(our_king_sq, from_sq)

        while single_push != 0
            to_sq = @pop_lsb!(single_push)
            push!(moves, Move(from_sq, to_sq, QUIET))
        end

        while double_push != 0
            to_sq = @pop_lsb!(double_push)
            push!(moves, Move(from_sq, to_sq, DOUBLE_PAWN_PUSH))
        end
    end

    ###################
    # KNIGHTS
    # pinned knights can't move
end

function generate_legal_ep_capture_moves(board::Board, c::Color{BLACK}, moves::Vector{Move}, danger::UInt64, not_pinned::UInt64)
    ep_sq = board.history[board.ply].ep_square

    if ep_sq != 0
        bb1 = attacks_by_pawns(bb(ep_sq), Color(WHITE)) & board.bb_for[BLACK_PAWN]

        unpinned = bb1 & not_pinned
        our_king_sq = trailing_zeros(board.bb_for[BLACK_KING])

        while unpinned != 0
            from_sq = @pop_lsb!(unpinned)
            
            occ = board.bb_occ ⊻ bb(from_sq) ⊻ bb(ep_sq + 8)
            if (rook_pseudo_attack(our_king_sq, occ) & RANK_4) & (board.bb_for[WHITE_ROOK] | board.bb_for[WHITE_QUEEN]) == 0 
                push!(moves, Move(from_sq, ep_sq, EN_PASSANT))
            end
        end

        pinned = bb1 & ~not_pinned & line_spanned(our_king_sq, ep_sq)
        while pinned != 0
            from_sq = @pop_lsb!(pinned)
            push!(moves, Move(from_sq, ep_sq, EN_PASSANT))
        end
    end
end

function generate_legals(board::Board, c::Color{BLACK})
    moves = Vector{Move}()
    
    # relevant danger, checkers and pinned bitboards
    danger = calculate_danger_map(board, c)
    checkers, pinned = find_checkers_and_pinned(board, c)
    not_pinned = ~pinned

    #############################################################
    #                                                           #
    # ACTUAL MOVE GENERATION                                    #
    #                                                           #
    # We have to generate                                       #
    #   - king moves                                            #
    #   - moves of pinned pieces (excluding ep captures)        #
    #   - moves of non-pinned pieces (excluding ep captures)    #
    #   - ep captures                                           #
    #   - castling moves                                        #
    #                                                           #
    # We can handle the the generation differently (and more    #
    # efficiently) depending on the number of checkers          #
    #                                                           #
    # 1. double check                                           #
    #   - king moves only                                       # 
    #                                                           #
    # 2. single check                                           #
    #   2.1 checking piece is a pawn or knight                  #
    #       - king moves                                        #
    #       - capturing moves (by non-pinned pieces)            #
    #       - ep capture (by non-pinned pawns)                  #
    #   2.2 checking piece is a slider                          #
    #       - king moves                                        #
    #       - capturing moves (by non-pinned pieces)            #
    #       - blocking moves (by non-pinned pieces)             #
    #                                                           #
    # 3. no check                                               #    
    #   - king moves                                            #
    #   - moves of pinned pieces                                #
    #   - moves of non-pinned pieces                            #
    #   - ep captures (by non-pinned pawns)                     #
    #   - castling moves                                        #
    #                                                           #
    #############################################################
    nr_checkers = count_ones(checkers)

    if nr_checkers == 2
        generate_king_legals(board, c, moves, danger)
        return moves
    elseif nr_checkers == 1
        generate_king_legals(board, c, moves, danger)

        checker_sq = trailing_zeros(checkers)
        checking_piece = board.squares[checker_sq + 1]

        if checking_piece == WHITE_KNIGHT
            generate_legal_captures_on_checker_sq(board, c, moves, checker_sq, not_pinned)
        elseif checking_piece == WHITE_PAWN
            generate_legal_captures_on_checker_sq(board, c, moves, checker_sq, not_pinned)
            generate_legal_ep_captures_on_checker_sq(board, c, moves, checker_sq, not_pinned)
        else
            quiet_mask = squares_between(trailing_zeros(board.bb_for[BLACK_KING]), checker_sq)
            capture_mask = checkers
            generate_legal_non_pinned_moves(board, c, moves, quiet_mask, capture_mask, not_pinned)
        end
    else
        quiet_mask = ~board.bb_occ
        capture_mask = board.bb_white

        generate_king_legals(board, c, moves, danger)
        generate_legal_pinned_moves(board, c, moves, quiet_mask, capture_mask, pinned)
        generate_legal_non_pinned_moves(board, c, moves, quiet_mask, capture_mask, not_pinned)
        generate_legal_ep_capture_moves(board, c, moves, danger, not_pinned)
        generate_legal_castle_moves(board, c, moves, danger)
    end

    return moves
end