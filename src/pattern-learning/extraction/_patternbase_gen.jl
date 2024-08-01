function extend_patternbase_from_game(game_str::T, pattern_file::IOStream) where T<:AbstractString
    # set board into initial state
    board = Board()
    set_by_fen!(board, "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")

    move_strings = split(game_str)
    # play through game, move by move
    for move_str in move_strings
        move = extract_move_by_san(board, move_str)
        do_move!(board, move)

        # the board itself is a pattern of piece-square pairs
        pattern = Vector{Int}()
        for square in 1:64
            piece = board.squares[square]
            push!(pattern, (square - 1) + 64 * piece)
        end

        # write pattern to file
        println(pattern_file, join(pattern, " "))
    end
end

function generate_patternbase(path::T) where T<:AbstractString
    games = open(path, "r")
    pattern_file = open(abspath(expanduser("./data/training/processed/tokenbase.txt")), "w")
    while !eof(games)
        game_str = strip(readline(games))

        # play game and write encountered patterns to file
        extend_patternbase_from_game(game_str, pattern_file)
    end

    close(games)
    close(pattern_file)
end