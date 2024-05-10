function generate_legals(board::Board)
    if board.side_to_move == WHITE
        return generate_legals_white(board)
    else
        return generate_legals_black(board)
    end
end