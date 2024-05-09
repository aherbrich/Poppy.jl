function perft!(board::Board, depth::Int)
    if depth == 0 return 1 end

    old_color = board.side_to_move
    moves = generate_legals(board, board.side_to_move)
    nodes = 0
    
    for move in moves
        do_move!(board, old_color, move)
        nodes += perft!(board, depth-1)
        undo_move!(board, old_color, move)
    end

    return nodes
end

function perft_alla_stockfish!(board::Board, depth::Int)
    old_color = board.side_to_move
    moves = generate_legals(board, board.side_to_move)
    nodes = 0
    for move in moves
        if depth == 1
            nodes += 1
            continue
        end

        do_move!(board, old_color, move)
        if depth == 2
            nodes += length(generate_legals(board, board.side_to_move))
        else
            nodes += perft!(board, depth-1)
        end
        undo_move!(board, old_color, move)
    end
    return nodes
end

function perft_divide!(board::Board, depth::Int)
    old_color = board.side_to_move
    moves = generate_legals(board, board.side_to_move)
    for move in moves
        do_move!(board, old_color, move)
        nodes = perft!(board, depth-1)
        println(move, ": ", nodes)
        global_nodes += nodes
        undo_move!(board, old_color, move)
    end
    return global_nodes
end