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
