using Plots

mutable struct TrainingMetadata
    count::Int
    nr_of_games::Int
    const predictions::Vector{Prediction}
    global_start_time::Float64
end

function TrainingMetadata(training_file::AbstractString)
    nr_of_games = count_lines_in_files(training_file)
    return TrainingMetadata(0, nr_of_games, Vector{Prediction}(), time())
end

function Base.show(io::IO, metadata::TrainingMetadata)
    elapsed_time = time() - metadata.global_start_time
    time_per_game = elapsed_time / metadata.count
    games_left = metadata.nr_of_games - metadata.count
    time_left = ceil(Int, games_left * time_per_game)

    if length(metadata.predictions) == 0
        print(io, "\r\033[1mPrognosed time left: $(time_left ÷ 3600)h $((time_left ÷ 60) % 60)m $(time_left % 60)s\033[0m\t\033[1;30m(game $(metadata.count)/$(metadata.nr_of_games))\033[0m")
    else
        println(io, "\r\033[1mPrognosed time left: $(time_left ÷ 3600)h $((time_left ÷ 60) % 60)m $(time_left % 60)s\033[0m\t\033[1;30m(game $(metadata.count)/$(metadata.nr_of_games))\033[0m")
        print(io, "\r\033[1;30mAccuracy: $(round(accuracy(metadata.predictions), digits=4))\033[0m\033[F")
    end
end

function plot_metadata(metadata::TrainingMetadata)
    # plot accuracy per ply
    correct_model_per_ply = zeros(Int, 100)
    correct_random_per_ply = zeros(Int, 100)
    total_per_ply = zeros(Int, 100)

    

    for prediction in metadata.predictions
        correct_model_per_ply[min(prediction.ply_number, 100)] += (prediction.predicted_rank == 1)
        correct_random_per_ply[min(prediction.ply_number, 100)] += (rand(1:prediction.nr_of_possible_moves) == 1)
        total_per_ply[min(prediction.ply_number, 100)] += 1
    end

    accuracy_model_per_ply = correct_model_per_ply ./ total_per_ply
    accuracy_random_per_ply = correct_random_per_ply ./ total_per_ply

    plt = plot(1:100, accuracy_model_per_ply, label="Model", xlabel="Ply", ylabel="Accuracy", title="Accuracy per ply")
    plot!(1:100, accuracy_random_per_ply, label="Random")

    display(plt)
end

mutable struct TestMetadata
    count::Int
    nr_of_games::Int
    const predictions::Vector{Prediction}
    global_start_time::Float64
    # for each board, remember at which which move was played how often at which ply
    hashtable::Dict{UInt64, Dict{UInt64, Vector{Int}}}
end

function TestMetadata(test_file::AbstractString)
    nr_of_games = count_lines_in_files(test_file)

    return TestMetadata(0, nr_of_games, Vector{Prediction}(), time(), Dict{UInt64, Dict{UInt64, Vector{Int}}}())
end

function Base.show(io::IO, metadata::TestMetadata)
    if length(metadata.predictions) == 0
        print(io, "\r\033[1mTested on: $(metadata.count)/$(metadata.nr_of_games)\033[0m")
    else
        println(io, "\r\033[1mTested on: $(metadata.count)/$(metadata.nr_of_games)\033[0m")
        print(io, "\r\033[1;30mAccuracy: $(round(accuracy(metadata.predictions), digits=4))\033[0m\033[F")
    end
end

function plot_metadata(metadata::TestMetadata; plot_max_accuracy=false)
    # plot accuracy per ply
    correct_model_per_ply = zeros(Int, 100)
    correct_random_per_ply = zeros(Int, 100)
    total_per_ply = zeros(Int, 100)

    for prediction in metadata.predictions
        correct_model_per_ply[min(prediction.ply_number, 100)] += (prediction.predicted_rank == 1)
        correct_random_per_ply[min(prediction.ply_number, 100)] += (rand(1:prediction.nr_of_possible_moves) == 1)
        total_per_ply[min(prediction.ply_number, 100)] += 1
    end

    accuracy_model_per_ply = correct_model_per_ply ./ total_per_ply
    accuracy_random_per_ply = correct_random_per_ply ./ total_per_ply

    plt = plot(1:100, accuracy_model_per_ply, label="Model", xlabel="Ply", ylabel="Accuracy", title="Accuracy per ply", legend=:topright)
    plot!(1:100, accuracy_random_per_ply, label="Random")

    if plot_max_accuracy
        correct_max_model_per_ply = zeros(Float64, 100)
        seen_at_each_ply = zeros(Int, 100)

        # calculate the maximum possible accuracy for the model
        # for this we saved for each board, which move was played how often at which ply
        for (board_hash, move_dict) in metadata.hashtable
            # for a board, we have to find the move that was played most often
            # over all plies (since we need to make a consistent decision on each ply)
            # => else we overestimate the accuracy (since we would always choose the most played move for each ply)
            # and not the most played move over all plies
            best_move = reduce((x, y) -> sum(move_dict[x]) > sum(move_dict[y]) ? x : y, keys(move_dict))
            
            # now we have to calculate the accuracy per ply if we always played the most played move (over all plies)
            for (move_hash, counts) in move_dict
                for (i, count) in enumerate(counts)
                    if move_hash == best_move
                        correct_max_model_per_ply[min(i, 100)] += count
                    end
                    seen_at_each_ply[min(i, 100)] += count
                end
            end
        end


        accuracy_max_model_per_ply = correct_max_model_per_ply ./ seen_at_each_ply

        plot!(1:100, accuracy_max_model_per_ply, label="Max Model")
    end

    display(plt)
end