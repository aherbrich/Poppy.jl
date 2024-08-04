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
        print(io, "\r\033[1;30mAccuray: $(accuracy(metadata.predictions))\033[0m\033[F")
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
end

function TestMetadata(test_file::AbstractString)
    nr_of_games = count_lines_in_files(test_file)
    return TestMetadata(0, nr_of_games, Vector{Prediction}(), time())
end

function Base.show(io::IO, metadata::TestMetadata)
    if length(metadata.predictions) == 0
        print(io, "\r\033[1mTested on: $(metadata.count)/$(metadata.nr_of_games)\033[0m")
    else
        println(io, "\r\033[1mTested on: $(metadata.count)/$(metadata.nr_of_games)\033[0m")
        print(io, "\r\033[1;30mAccuray: $(accuracy(metadata.predictions))\033[0m\033[F")
    end
end

function plot_metadata(metadata::TestMetadata)
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