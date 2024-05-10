function perft!(board::Board, depth::Int)
    if depth == 0 return 1 end

    moves = generate_legals(board)
    nodes = 0
    
    for move in moves
        do_move!(board, move)
        nodes += perft!(board, depth-1)
        undo_move!(board, move)
    end

    return nodes
end

function perft_alla_stockfish!(board::Board, depth::Int)
    moves = generate_legals(board)
    nodes = 0
    for move in moves
        if depth == 1
            nodes += 1
            continue
        end

        do_move!(board, move)
        if depth == 2
            nodes += length(generate_legals(board))
        else
            nodes += perft_alla_stockfish!(board, depth-1)
        end
        undo_move!(board, move)
    end
    return nodes
end

function perft_divide!(board::Board, depth::Int)
    moves = generate_legals(board)
    for move in moves
        do_move!(board, move)
        nodes = perft!(board, depth-1)
        println(move, ": ", nodes)
        global_nodes += nodes
        undo_move!(board, move)
    end
    return global_nodes
end