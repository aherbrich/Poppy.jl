function undo_move!(board::Board, move::Move)
    if board.side_to_move == WHITE
        undo_move_black!(board, move)
    else
        undo_move_white!(board, move)
    end
end