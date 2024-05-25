function train_model(path::String; exclude=[], folder="./data/models")
    # find latest model version
    files = filter(x -> occursin(r"model_v\d+\.txt", x), readdir(folder))
    model_version = (isempty(files)) ? 1 : maximum(map(x -> parse(Int, match(r"model_v(\d+)\.txt", x).captures[1]), files)) + 1
    filename_model = abspath(expanduser(joinpath(folder, "model_v$(model_version).txt")))
    model_file = open(filename_model, "w")

    games = open(path, "r")
    urgencies = Dict{UInt64, Gaussian}()

    count = 0
    while !eof(games)
        count += 1
        game = strip(readline(games))

        # skip games which should not be trained on
        if count in exclude
            continue
        end

        # skip empty lines
        if isempty(game)
            continue
        end

        # load board into starting position
        board = Board()
        set_by_fen!(board, "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")

        # extract all moves made in the game
        moves = split(game)
        for best_move in moves
            # calculate legal moves and their hashes
            _, legals = generate_legals(board)
            hashes = map(mv -> move_to_hash(mv, board), legals)
            best_move_hash = move_to_hash(extract_move_by_san(board, best_move), board)
            
            # find index of move in moves
            best_move_idx = findfirst(hash -> hash == best_move_hash, hashes)
            hashes[1], hashes[best_move_idx] = hashes[best_move_idx], hashes[1]
            
            # update urgencies
            ranking_update!(urgencies, hashes)

            # extract move from string and play it
            move = extract_move_by_san(board, best_move)
            do_move!(board, move)
        end
    end

    close(games)

    # write model to file
    for (i, (key, value)) in enumerate(urgencies)
        println(model_file, "$key $(gmean(value)) $(variance(value))")
    end

    close(model_file)

    return filename_model
end