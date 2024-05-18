function generate_legals(board::Board)
    if board.side_to_move == WHITE
        return generate_legals_white(board)
    else
        return generate_legals_black(board)
    end
end

function extract_move(board::Board, mv::String)
    legal_moves = generate_legals(board)[2]

    str_src = (mv[1] - 'a') + (mv[2] - '1') * 8
    str_dst = (mv[3] - 'a') + (mv[4] - '1') * 8

    for move in legal_moves
        if move.src == str_src && move.dst == str_dst
            if length(mv) == 4
                return move
            else
                if mv[5] == 'q' && (move.type == QUEEN_PROMOTION || move.type == QUEEN_PROMOTION_CAPTURE)
                    return move
                elseif mv[5] == 'r' && (move.type == ROOK_PROMOTION || move.type == ROOK_PROMOTION_CAPTURE)
                    return move
                elseif mv[5] == 'b' && (move.type == BISHOP_PROMOTION || move.type == BISHOP_PROMOTION_CAPTURE)
                    return move
                elseif mv[5] == 'n' && (move.type == KNIGHT_PROMOTION || move.type == KNIGHT_PROMOTION_CAPTURE)
                    return move
                end
            end
        end
    end
    
    return nothing
end