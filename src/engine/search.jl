function alpha_beta!(board::Board, ply::Int, alpha::Int, beta::Int, limits::SearchLimits, stats::SearchStats)
    stats.nodes[ply] += 1
    stats.total_nodes += 1

    # make sure to abort the search at some global maximum depth
    if ply >= MAX_DEPTH
        return evaluate(board)
    end

    # if max nodes reached, evaluate the position
    if stats.total_nodes >= limits.nodes_limit
        return evaluate(board)
    end

    # println("now $(time_ms()) limit $(limits.time_limit) diff $(time_ms() - limits.start_time)")

    # check if time limit reached
    if time_ms() >= limits.time_limit
        return evaluate(board)
    end

    # check if stop signal received
    if limits.stop
        return 0
    end

    nr_of_checkers, unordered_moves = generate_legals(board)

    # check if draw by repetition or fifty-move rule
    if is_draw_by_fifty_move_rule(board, nr_of_checkers) || is_draw_by_repetition(board)
        return 0
    end

    # if max depth reached, evaluate the position
    if ply >= limits.max_depth
        return evaluate(board)
    end


    # TODO: do all the transposition table magic


    # if no moves, game is over in this branch -> evaluate the position
    if isempty(unordered_moves)
        if nr_of_checkers > 0
            return typemin(Int) + ply
        else
            return 0
        end
    end

    moves = order(board, unordered_moves)

    best_score = typemin(Int)
    best_move = nothing
    tt_flag = UPPERBOUND
    for move in moves
        do_move!(board, move)
        score = -alpha_beta!(board, ply + 1, -beta, -alpha, limits, stats)
        undo_move!(board, move)

        if score >= best_score
            best_score = score
            best_move = move

            # adjust alpha 
            if score > alpha
                alpha = score
                tt_flag = EXACT
            end
            
            # beta cutoff
            if score >= beta
                stats.cutoffs[ply] += 1
                # TODO fix
                if !isempty(moves)
                    tt_flag = LOWERBOUND
                end  
                break
            end 
        end
    end

    if !limits.stop
        store_tt_entry(TT, board, best_score, best_move, UInt8(limits.max_depth - ply), tt_flag)
    end

    return best_score
end 


function search(board::Board, limits::SearchLimits)
    println("searching on thread $(Threads.threadid())")
    # reset hashes from previous searches 
    # of course we keep the hashes of already played positions untouched
    for i in board.ply+1:MAX_DEPTH
        board.history[i].hash = UInt64(0)
    end

    stats = SearchStats()

    # iterative deepening
    max_depth = limits.max_depth
    for depth in 1:max_depth
        limits.max_depth = depth + 1
        eval = alpha_beta!(board, 1, typemin(Int), typemax(Int), limits, stats)
        println("info depth $depth score cp $eval nodes $(stats.total_nodes) time $(time_ms() - limits.start_time) pv $(get_pv(TT, board, depth))")

        if limits.stop || time_ms() >= limits.time_limit || stats.total_nodes >= limits.nodes_limit || depth == max_depth 
            best_move = tt_best_move(TT, board)
            println("bestmove $best_move")
            break
        end
    end
end