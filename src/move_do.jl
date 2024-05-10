function do_move!(board::Board, move::Move)
    if board.side_to_move == WHITE
        do_move_white!(board, move)
    else
        do_move_black!(board, move)
    end
end