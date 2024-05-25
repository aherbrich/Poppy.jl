@inline function time_ms()
    return ceil(Int, time() * 1000)
end

@inline function is_draw_by_fifty_move_rule(board::Board, nr_of_checkers::Int)
    # draw by fifty-move rule
    if board.history[board.ply].fifty_move_counter >= 100 && nr_of_checkers == 0
        return true
    end
    return false
end

@inline function is_draw_by_repetition(board::Board)
    current_hash = board.history[board.ply].hash
    repetitions = 0
    for i in 1:board.ply-1
        if board.history[i].hash == current_hash
            repetitions += 1
        end
        if repetitions == 2
            return true
        end
    end
    
    return false
end