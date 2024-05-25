function evaluate(board::Board)
    white_material = 0
    black_material = 0

    for square in board.squares
        if square == WHITE_PAWN
            white_material += 100
        elseif square == WHITE_KNIGHT
            white_material += 300
        elseif square == WHITE_BISHOP
            white_material += 300
        elseif square == WHITE_ROOK
            white_material += 500
        elseif square == WHITE_QUEEN
            white_material += 900
        elseif square == BLACK_PAWN
            black_material += 100
        elseif square == BLACK_KNIGHT
            black_material += 300
        elseif square == BLACK_BISHOP
            black_material += 300
        elseif square == BLACK_ROOK
            black_material += 500
        elseif square == BLACK_QUEEN
            black_material += 900
        end
    end

    if board.side_to_move == WHITE
        return white_material - black_material
    else
        return black_material - white_material
    end
end
