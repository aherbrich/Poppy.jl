function perft!(board::Board, depth::Int)
    if depth == 0 return 1 end
    old_color = board.side_to_move
    moves = generate_pseudo_moves(old_color, board)
    nodes = 0
    for move in moves
        do_move!(board, old_color, move)
        if in_check(board, old_color, move) == false
            nodes += perft!(board, depth-1)
        end
        undo_move!(board, old_color, move)
    end
    return nodes
end

function perft_divide!(board::Board, depth::Int)
    old_color = board.side_to_move
    moves = generate_pseudo_moves(old_color, board)
    global_nodes = 0
    for move in moves
        do_move!(board, old_color, move)
        if in_check(board, old_color, move) == false
            nodes = perft!(board, depth-1)
            println(move, ": ", nodes)
            global_nodes += nodes
        end
        undo_move!(board, old_color, move)
    end
    return global_nodes
end