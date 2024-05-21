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

function square_to_index(square::T) where T<:AbstractString
    file = square[1] 
    rank = square[2]
    return (file - 'a') + 8 * (rank - '1')
end

function extract_move_by_san(board::Board, move_str::T) where T<:AbstractString
    _, legals = generate_legals(board)

    #############################################
    # CASTLING
    if move_str == "O-O"
        moves = filter(move -> move.type == KING_CASTLE, legals)
        if length(moves) != 1 error("Invalid move: $move_str") end
        return moves[1]
    end

    if move_str == "O-O-O"
        moves = filter(move -> move.type == QUEEN_CASTLE, legals)
        if length(moves) != 1 error("Invalid move: $move_str") end
        return moves[1]
    end

    #############################################
    # PROMOTION
    if occursin("=" , move_str)
        # filter all promotion moves
        moves = filter(move -> (move.type & PROMOTION) != 0, legals)

        # filter by destination square
        dst_sq = square_to_index(move_str[end-3:end-2])
        moves = filter(move -> move.dst == dst_sq, moves)

        # filter by promotion piece
        promotion_piece = move_str[end] == 'N' ? KNIGHT_PROMOTION & 0x03 :
                          move_str[end] == 'B' ? BISHOP_PROMOTION & 0x03 :
                          move_str[end] == 'R' ? ROOK_PROMOTION & 0x03 :
                          move_str[end] == 'Q' ? QUEEN_PROMOTION & 0x03 : error("Invalid move: $move_str")
        moves = filter(move -> (move.type & 0x03) == promotion_piece, moves)

        if length(moves) == 1 return moves[1] end
        
        # filter by source file
        src_file = move_str[1] - 'a'
        moves = filter(move -> (move.src % 8) == src_file, moves)

        if length(moves) != 1 error("Invalid move: $move_str") end
        return moves[1]
    end
    
    #############################################
    # REGULAR MOVE

    # filter by destination square
    dst_sq = square_to_index(move_str[end-1:end])
    moves = filter(move -> move.dst == dst_sq, legals)

    if length(moves) == 1 return moves[1] end

    # filter by piece type
    piece_type = move_str[1] == 'N' ? KNIGHT :
                 move_str[1] == 'B' ? BISHOP :
                 move_str[1] == 'R' ? ROOK :
                 move_str[1] == 'Q' ? QUEEN :
                 move_str[1] == 'K' ? KING :
                 islowercase(move_str[1]) ? PAWN : error("Invalid move: $move_str")

    moves = filter(move -> (board.squares[move.src + 1] & 0x07) == piece_type, moves)

    if length(moves) == 1 return moves[1] end

    # if we are here, then there are two (or three) pieces of the same type
    # that can move to the same square -> they will differ in 
    # file or rank (or both)
    
    # filter by rank (ambiguous only by rank)
    if isuppercase(move_str[1]) && isnumeric(move_str[2])
        src_rank = move_str[2] - '1'
        moves = filter(move -> (move.src >> 3) == src_rank, moves)
        if length(moves) == 1 return moves[1] end
    end

    # filter by file (ambiguous only by file)
    src_file = islowercase(move_str[1]) ? move_str[1] - 'a' : move_str[2] - 'a'
    moves = filter(move -> (move.src % 8) == src_file, moves)

    if length(moves) == 1 return moves[1] end

    # filter by rank (ambiguous by both file and rank)
    src_rank = move_str[3] - '1'
    moves = filter(move -> (move.src >> 3) == src_rank, moves)

    if length(moves) != 1 error("Invalid move: $move_str") end

    return moves[1]
end
