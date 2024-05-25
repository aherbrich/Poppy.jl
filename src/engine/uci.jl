using ThreadPools

function parse_position(board::Board, position::T) where T<:AbstractString
    words = split(position)
    words = words[2:end]

    # set position
    if words[1] == "startpos"
        set_by_fen!(board, "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")
        if length(words) == 1 return end # no moves to play
        words = words[2:end] # remove "startpos" from words, for further move processing
    elseif words[1] == "fen"
        if length(words) < 7
            throw(ArgumentError("Invalid FEN string - not all fields present"))
        end

        words = words[2:end] # remove "fen" from words, for further fen string processing

        fen = join(words[1:6], " ")
        set_by_fen!(board, fen)

        if length(words) == 6 return end # no moves to play
        words = words[7:end] # remove fen string from words, for further move processing
    end

    # play moves
    if words[1] != "moves"
        throw(ArgumentError("Invalid position command - 'moves' keyword missing"))
    end

    words = words[2:end] # remove "moves" from words, for further move processing

    for word in words
        move = extract_move_by_uci(board, word)
        do_move!(board, move)
    end

    return
end

function parse_go(board::Board, command::T) where T<:AbstractString
    limits = SearchLimits()
    
    # split the command into words and throw away the first one (since it's "go")
    words = split(command)
    words = words[2:end]

    # moves to go
    movestogo = UInt64(40)
    winc = UInt64(0)
    binc = UInt64(0)
    wtime = typemax(UInt64)
    btime = typemax(UInt64)
    movetime = typemax(UInt64)

    idx = 1
    while idx <= length(words)
        word = words[idx]
        if word == "infinite"
            # 'infinite' doesnt really have an effect here, because 
            # 'movetime', 'w/btime', 'nodes' and 'depth' override it
            # (don't ask me why, but thats how stockfish does it)
        elseif word == "movetime"
            idx += 1
            movetime = parse(UInt64, words[idx])
        elseif word == "depth"
            idx += 1
            limits.max_depth = parse(Int, words[idx])
        elseif word == "nodes"
            idx += 1
            limits.nodes = parse(UInt64, words[idx])
        elseif word == "movestogo"
            idx += 1
            movestogo = parse(UInt64, words[idx])
        elseif word == "wtime"
            idx += 1
            wtime = parse(UInt64, words[idx])
        elseif word == "btime"
            idx += 1
            btime = parse(UInt64, words[idx])
        elseif word == "winc"
            idx += 1
            winc = parse(UInt64, words[idx])
        elseif word == "binc"
            idx += 1
            binc = parse(UInt64, words[idx])
        elseif word == "mate"
            idx += 1
            # TODO
        elseif word == "ponder"
            # TODO
        end
        idx += 1
    end

    # determine time limit
    if board.side_to_move == WHITE
        # calculate time limit for white
        time_limit_by_wtime = (typemax(UInt64) - (wtime / movestogo) < time_ms()) ? typemax(UInt64) : time_ms() + (wtime / movestogo)
        time_limit_by_movetime = (typemax(UInt64) - movetime < time_ms()) ? typemax(UInt64) : time_ms() + movetime
        
        limits.time_limit = min(time_limit_by_wtime, time_limit_by_movetime)

        # add increment
        limits.time_limit = (typemax(UInt64) - winc < limits.time_limit) ? typemax(UInt64) : limits.time_limit + winc
    else
        # calculate time limit for black
        time_limit_by_btime = (typemax(UInt64) - (btime / movestogo) < time_ms()) ? typemax(UInt64) : time_ms() + (btime / movestogo)
        time_limit_by_movetime = (typemax(UInt64) - movetime < time_ms()) ? typemax(UInt64) : time_ms() + movetime
        
        limits.time_limit = min(time_limit_by_btime, time_limit_by_movetime)

        # add increment
        limits.time_limit = (typemax(UInt64) - binc < limits.time_limit) ? typemax(UInt64) : limits.time_limit + binc
    end

    # subtract a tolerance of 5ms (and make sure the engine has at least 5ms to think)
    limits.time_limit = max(limits.start_time + 5, limits.time_limit - 5)

    return limits
end

function respond_to_uci_cmd()
    println("id name Poppy")
    println("id author Alexander Herbrich")
    # TODO: add options
    println("uciok")
end

function respond_to_isready_cmd()
    println("readyok")
end

function uci_loop()
    # check if atleast 2 threads are available
    if Threads.nthreads() < 2
        println("Error: at least 2 threads are required. Start julia with '-t 2' option.")
        return
    end

    # precompile search function to reduce latency
    precompile(search, (Board, SearchLimits))

    # create a board and load the starting position
    board = Board()
    set_by_fen!(board, "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")

    # load standard search limits ("no" time limit, "no" node limit, max depth 1024)
    search_limits = SearchLimits()
    
    # variable to store search thread handle (initially set to a dummy task that finishes immediately)
    search_thread = schedule(Task(() -> nothing))

    ########################################
    # UCI loop

    println("Poppy v1.0 by Alexander Herbrich")
    while true
        command = strip(readline())

        if isempty(command)
            continue
        elseif command == "uci"
            respond_to_uci_cmd()
        elseif command == "isready"
            respond_to_isready_cmd()
        elseif command == "ucinewgame"
            clear!(board)
        elseif startswith(command, "position")
            parse_position(board, command)
        elseif startswith(command, "go") && istaskdone(search_thread)
            search_limits = parse_go(board, command)
            search_thread = @tspawnat 2 search(board, search_limits)
        elseif command == "stop" && !istaskdone(search_thread)
            search_limits.stop = true
        elseif command == "quit"
            break
        elseif startswith(command, "setoption")
            # TODO
        else
            continue
        end
    end
end