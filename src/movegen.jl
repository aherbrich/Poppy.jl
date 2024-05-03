function generate_pseudo_moves(c::Color{WHITE}, board::Board, filter_functions::Vector{Function})
    moves = Vector{Move}()

    # generate all pseudo legal moves
    generate_pseudo_pawn_moves(c, board, moves)
    generate_pseudo_knight_moves(c, board, moves)
    generate_pseudo_bishop_moves(c, board, moves)
    generate_pseudo_rook_moves(c, board, moves)
    generate_pseudo_queen_moves(c, board, moves)
    generate_pseudo_king_moves(c, board, moves)
    generate_pseudo_castling_moves(c, board, moves)

    # filter by some function
    for filter_function in filter_functions
        moves = filter(filter_function, moves)
    end

    return moves
end

function generate_pseudo_moves(c::Color{BLACK}, board::Board, filter_functions::Vector{Function})
    moves = Vector{Move}()

    # generate all pseudo legal moves
    generate_pseudo_pawn_moves(c, board, moves)
    generate_pseudo_knight_moves(c, board, moves)
    generate_pseudo_bishop_moves(c, board, moves)
    generate_pseudo_rook_moves(c, board, moves)
    generate_pseudo_queen_moves(c, board, moves)
    generate_pseudo_king_moves(c, board, moves)
    generate_pseudo_castling_moves(c, board, moves)

    # filter by some function
    for filter_function in filter_functions
        moves = filter(filter_function, moves)
    end

    return moves
end