function load_model(filename::T) where T<:AbstractString
    urgencies = Dict{UInt64, Gaussian}()

    model = open(filename, "r")
    while !eof(model)
        line = strip(readline(model))
        if isempty(line)
            continue
        end

        key, mean, variance = split(line)
        urgencies[parse(UInt64, key)] = GaussianByMeanVariance(parse(Float64, mean), parse(Float64, variance))
    end

    close(model)

    return urgencies
end

function test_model(path::String)
    nr_games = count_lines_in_files(path)

    # split games into training and test set (a 80/20)
    test_indices = rand(1:nr_games, ceil(Int, nr_games * 0.2))
    train_indices = setdiff(1:nr_games, test_indices)

    # train
    model_filename = train_model(path, exclude=test_indices)
    println("model: $model_filename")
    model = load_model(model_filename)

    # test
    games = open(path, "r")
    count = 0
    correct = 0
    total = 0
    while !eof(games)
        count += 1
        game = strip(readline(games))

        # skip games which should not be tested on
        if count in train_indices
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
            # calculate legal moves 
            _, legals = generate_legals(board)
            # sort legals by urgency
            sort!(legals, by = mv -> (haskey(model, move_to_hash(mv, board)) ? gmean(model[move_to_hash(mv, board)]) : 0), rev = true)
            # calculate hashes
            hashes = map(mv -> move_to_hash(mv, board), legals)
            best_move_hash = move_to_hash(extract_move_by_san(board, best_move), board)

            # find index of move in moves
            best_move_idx = findfirst(hash -> hash == best_move_hash, hashes)
            if best_move_idx == 1 correct += 1 end
            total += 1

            # extract move from string and play it
            move = extract_move_by_san(board, best_move)
            do_move!(board, move)
        end
        print("result: $correct / $total = $(correct / total)\r")
    end
    
    close(games)

    # append accuracy to model file
    model_file = open(model_filename, "a")
    println(model_file, "\n{accuracy: $(correct / total)}")
    close(model_file)

    println("result: $correct / $total = $(correct / total)")
    return correct / total
end