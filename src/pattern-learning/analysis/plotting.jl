using Plots
using StatsPlots
using Distributions
using LaTeXStrings
using Measures

function nr_of_features(model_id::Int, trained_on::Int)
    @info "Extracting number of features for model $model_id trained on $trained_on"

    #################################
    # CONFIGURATION
    folder = "./data/models"

    urgency_model_base_name = "$(folder)/urgency_model_"
    urgency_model_version_names = [
        ("v1", "MT"),
        ("v2", "PT"),
        ("v3", "Hybrid")
    ]

    boardval_model_base_name = "$(folder)/boardval_model_"
    boardval_model_version_names = [
        ("v1", "PP"),
        ("v2", "MS"),
        ("v3", "Hybrid")
    ]


    #################################
    # EXTRACT FEATURE COUNTS
    model_feature_counts = Dict{String, Int}()

    for (version, version_name) in urgency_model_version_names
        model_file = urgency_model_base_name * version * "_trained_on_" * string(trained_on) * "_id_" * string(model_id) * ".bin"

        if !isfile(abspath(expanduser(model_file)))
            @warn "Model file $model_file does not exist - skipping"
            continue
        end

        model = load_model(model_file)
        model_feature_counts["Urgency Model ($version_name)"] = length(model)
    end

    for (version, version_name) in boardval_model_version_names
        model_file = boardval_model_base_name * version * "_trained_on_" * string(trained_on) * "_id_" * string(model_id) * ".bin"

        if !isfile(model_file)
            @warn "Model file $model_file does not exist - skipping"
            continue
        end

        model = load_model(model_file)
        model_feature_counts["Boardval Model ($version_name)"] = length(model)
    end

    for (model_name, feature_count) in model_feature_counts
        println("$model_name:\t$feature_count")
    end
end

function plot_overall_accuracy(model_id::Int, trained_on::Int)
    @info "Plotting overall accuracy for model $model_id trained on $trained_on"

    #################################
    # CONFIGURATION
    folder = "./data/predictions"

    random_model_file = "$(folder)/random_model_id_$(model_id).bin"

    urgency_model_base_name = "$(folder)/urgency_model_"
    urgency_model_version_names = [
        ("v1", "MT"),
        ("v2", "PT"),
        ("v3", "Hybrid")
    ]

    boardval_model_base_name = "$(folder)/boardval_model_"
    boardval_model_version_names = [
        ("v1", "PP"),
        ("v2", "MS"),
        ("v3", "Hybrid")
    ]

    #################################
    # EXTRACT RANDOM MODEL
    random_model = load_predictions(random_model_file)
    random_acc = accuracy(random_model)

    println("Random Choice: $random_acc")

    #################################
    # PLOT URGENCY MODEL 

    plt = plot(dpi=500, fontfamily="serif-roman", title="Overall Accuracy of Urgency Models", xlabel="Model Version", ylabel="Accuracy", tickfontsize=14, guidefontsize=14, legendfontsize=14, titlefontsize=18, top_margin=8mm, bottom_margin=8mm)
    ylims!(0, 0.3)
    # use bold font
    
    for (version, version_name) in urgency_model_version_names
        prediction_file = urgency_model_base_name * version * "_trained_on_" * string(trained_on) * "_id_" * string(model_id) * ".bin"

        if !isfile(prediction_file)
            @warn "Prediction file $prediction_file does not exist - skipping"
            continue
        end

        model = load_predictions(prediction_file)

        acc = accuracy(model)
        println("Urgency Model ($version_name): $acc")
        bar!(["$version_name"], [acc], label=false)
    end
    bar!(["Random\nChoice"], [random_acc], label=false)

    savefig(plt, "./plots/urgency_model_overall_accuracy.png")

    #################################
    # PLOT BOARDVAL MODEL

    plt2 = plot(dpi=500, fontfamily="serif-roman", title="Overall Accuracy of BoardVal Models", xlabel="Model Version", ylabel="Accuracy", tickfontsize=14, guidefontsize=14, legendfontsize=14, titlefontsize=18, top_margin=8mm, bottom_margin=8mm)
    ylims!(0, 0.3)

    for (version, version_name) in boardval_model_version_names
        prediction_file = boardval_model_base_name * version * "_trained_on_" * string(trained_on) * "_id_" * string(model_id) * ".bin"

        if !isfile(prediction_file)
            @warn "Prediction file $prediction_file does not exist - skipping"
            continue
        end

        model = load_predictions(prediction_file)

        acc = accuracy(model)
        println("BoardVal Model ($version_name): $acc")
        bar!(["$version_name"], [acc], label=false)
    end
    bar!(["Random\nChoice"], [random_acc], label=false)

    savefig(plt2, "./plots/boardval_model_overall_accuracy.png")

    #################################
    # DISPLAY PLOTS

    run(`open ./plots/urgency_model_overall_accuracy.png`)
    run(`open ./plots/boardval_model_overall_accuracy.png`)
end

function plot_top_k_accuracy(model_id::Int, trained_on::Int)
    @info "Plotting top-k accuracy for model $model_id trained on $trained_on"

    #################################
    # CONFIGURATION
    folder = "./data/predictions"

    random_model_file = "$(folder)/random_model_id_$(model_id).bin"

    urgency_model_base_name = "$(folder)/urgency_model_"
    urgency_model_version_names = [
        ("v1", "MT"),
        ("v2", "PT"),
        ("v3", "Hybrid")
    ]

    boardval_model_base_name = "$(folder)/boardval_model_"
    boardval_model_version_names = [
        ("v1", "PP"),
        ("v2", "MS"),
        ("v3", "Hybrid")
    ]


    # indices of models to be mixed
    mixed_versions = ([3], [3]) # in this case v3 vs v3

    #################################
    # EXTRACT RANDOM MODEL
    random_model = load_predictions(random_model_file)
    random_accuracies = Vector{Float64}()
    for i in 1:50
        push!(random_accuracies, top_k_accuracy(random_model, i))
    end

    #################################
    # PLOT URGENCY MODEL 

    plt = plot(dpi=500, fontfamily="serif-roman", title="Top-k Accuracy of Urgency Models", legend=:bottomright, xlabel="k", ylabel="Accuracy", tickfontsize=14, guidefontsize=14, legendfontsize=14, titlefontsize=18, top_margin=8mm, bottom_margin=8mm)
    ylims!(0, 1.0)

    for (version, version_name) in urgency_model_version_names
        prediction_file = urgency_model_base_name * version * "_trained_on_" * string(trained_on) * "_id_" * string(model_id) * ".bin"

        if !isfile(prediction_file)
            @warn "Prediction file $prediction_file does not exist - skipping"
            continue
        end

        model = load_predictions(prediction_file)

        accuracies = Vector{Float64}()
        for i in 1:50
            push!(accuracies, top_k_accuracy(model, i))
        end

        plot!(1:50, accuracies, label=version_name, lw=3)
    end

    plot!(1:50, random_accuracies, label="Random Choice", lw=3)

    savefig(plt, "./plots/urgency_model_top_k_accuracy.png")

    #################################
    # PLOT BOARDVAL MODEL

    plt2 = plot(dpi=500, fontfamily="serif-roman", title="Top-k Accuracy of BoardVal Models", legend=:bottomright, xlabel="k", ylabel="Accuracy", tickfontsize=14, guidefontsize=14, legendfontsize=14, titlefontsize=18, top_margin=8mm, bottom_margin=8mm)
    ylims!(0, 1.0)

    for (version, version_name) in boardval_model_version_names
        prediction_file = boardval_model_base_name * version * "_trained_on_" * string(trained_on) * "_id_" * string(model_id) * ".bin"

        if !isfile(prediction_file)
            @warn "Prediction file $prediction_file does not exist - skipping"
            continue
        end

        model = load_predictions(prediction_file)

        accuracies = Vector{Float64}()
        for i in 1:50
            push!(accuracies, top_k_accuracy(model, i))
        end

        plot!(1:50, accuracies, label=version_name, lw=3)
    end

    plot!(1:50, random_accuracies, label="Random Choice", lw=3)
    savefig(plt2, "./plots/boardval_model_top_k_accuracy.png")

    #################################
    # PLOT MIXED

    plt3 = plot(dpi=500, fontfamily="serif-roman", title="Top-k Accuracy\n(Urgency vs. BoardVal Model)", legend=:bottomright, xlabel="k", ylabel="Accuracy", tickfontsize=14, guidefontsize=14, legendfontsize=14, titlefontsize=17, top_margin=8mm, bottom_margin=8mm)
    ylims!(0, 1.0)

    for (version, version_name) in urgency_model_version_names[mixed_versions[1]]
        prediction_file = urgency_model_base_name * version * "_trained_on_" * string(trained_on) * "_id_" * string(model_id) * ".bin"

        if !isfile(prediction_file)
            @warn "Prediction file $prediction_file does not exist - skipping"
            continue
        end

        model = load_predictions(prediction_file)

        accuracies = Vector{Float64}()
        for i in 1:50
            push!(accuracies, top_k_accuracy(model, i))
        end

        plot!(1:50, accuracies, label="Urgency Model ($version_name)", lw=3, color=:red)
        println("Urgency Model ($version_name): ", Dict(zip(1:50, accuracies)))
    end

    for (version, version_name) in boardval_model_version_names[mixed_versions[2]]
        prediction_file = boardval_model_base_name * version * "_trained_on_" * string(trained_on) * "_id_" * string(model_id) * ".bin"

        if !isfile(prediction_file)
            @warn "Prediction file $prediction_file does not exist - skipping"
            continue
        end

        model = load_predictions(prediction_file)

        accuracies = Vector{Float64}()
        for i in 1:50
            push!(accuracies, top_k_accuracy(model, i))
        end

        plot!(1:50, accuracies, label="BoardVal Model ($version_name)", lw=3, color=:black)
        println("BoardVal Model ($version_name): ", Dict(zip(1:50, accuracies)))
    end

    plot!(1:50, random_accuracies, label="Random Choice", lw=3, color=4)
    savefig(plt3, "./plots/mixed_model_top_k_accuracy.png")


    #################################
    # DISPLAY PLOTS

    run(`open ./plots/urgency_model_top_k_accuracy.png`)
    run(`open ./plots/boardval_model_top_k_accuracy.png`)
    run(`open ./plots/mixed_model_top_k_accuracy.png`)
end

function plot_accuracy_over_time(model_id::Int)
    @info "Plotting accuracy over time for model $model_id"
    #################################
    # CONFIGURATION
    folder = "./data/predictions"

    urgency_model_base_name = "$(folder)/urgency_model_"
    urgency_model_version_names = [
        ("v1", "MT"),
        ("v2", "PT"),
        ("v3", "Hybrid")
    ]

    boardval_model_base_name = "$(folder)/boardval_model_"
    boardval_model_version_names = [
        ("v1", "PP"),
        ("v2", "MS"),
        ("v3", "Hybrid")
    ]

    ##############################################
    # PLOT ACCURACY OVER TIME FOR URGENCY MODELS

    plt = plot(dpi=500, fontfamily="serif-roman", title="Accuracy Over Time of Urgency Models", xlabel="Number of Games Trained On", ylabel="Accuracy", legend=:bottomright, tickfontsize=14, guidefontsize=14, legendfontsize=14, titlefontsize=17, top_margin=8mm, bottom_margin=8mm)
    ylims!(0, 0.3)

    for (version, version_name) in urgency_model_version_names
        model_files = filter(x -> occursin(basename(urgency_model_base_name * version), x) && occursin("id_$(model_id).bin", x), readdir(folder))
        
        accuracies = Dict{Int, Float64}()
        for model_file in model_files
            nr_of_games = parse(Int, split(split(model_file, "trained_on_")[2], "_")[1])
            
            model = load_predictions(joinpath(folder, model_file))
            accuracies[nr_of_games] = accuracy(model)
        end

        sorted_accuracies = sort(collect(accuracies), by=x->x[1])
        plot!([x[1] for x in sorted_accuracies], [x[2] for x in sorted_accuracies], label=version_name, xticks=collect(2 .^ (0:3:ceil(Int, log2(sorted_accuracies[end][1])))), xaxis=:log2, lw=3)
    end

    savefig(plt, "./plots/urgency_model_accuracy_over_time.png")

    ##############################################
    # PLOT ACCURACY OVER TIME FOR BOARDVAL MODELS

    plt2 = plot(dpi=500, fontfamily="serif-roman", title="Accuracy Over Time of BoardVal Models", xlabel="Number of Games Trained On", ylabel="Accuracy", legend=:bottomright, tickfontsize=14, guidefontsize=14, legendfontsize=14, titlefontsize=17, top_margin=8mm, bottom_margin=8mm)
    ylims!(0, 0.3)

    for (version, version_name) in boardval_model_version_names
        model_files = filter(x -> occursin(basename(boardval_model_base_name * version), x) && occursin("id_$(model_id).bin", x), readdir(folder))
        
        accuracies = Dict{Int, Float64}()
        for model_file in model_files
            nr_of_games = parse(Int, split(split(model_file, "trained_on_")[2], "_")[1])
            
            model = load_predictions(joinpath(folder, model_file))
            accuracies[nr_of_games] = accuracy(model)
        end

        sorted_accuracies = sort(collect(accuracies), by=x->x[1])
        plot!([x[1] for x in sorted_accuracies], [x[2] for x in sorted_accuracies], label=version_name, xticks=collect(2 .^ (0:3:ceil(Int, log2(sorted_accuracies[end][1])))), xaxis=:log2, lw=3)
    end

    savefig(plt2, "./plots/boardval_model_accuracy_over_time.png")

    ##############################################
    # DISPLAY PLOTS

    run(`open ./plots/urgency_model_accuracy_over_time.png`)
    run(`open ./plots/boardval_model_accuracy_over_time.png`)

end


function plot_per_ply(model_id::Int, trained_on::Int)
    @info "Plotting accuracy per ply for model $model_id trained on $trained_on"

    #################################
    # CONFIGURATION
    folder = "./data/predictions"

    random_model_file = "$(folder)/random_model_id_$(model_id).bin"

    urgency_model_base_name = "$(folder)/urgency_model_"
    urgency_model_version_names = [
        ("v1", "MT"),
        ("v2", "PT"),
        ("v3", "Hybrid")
    ]

    boardval_model_base_name = "$(folder)/boardval_model_"
    boardval_model_version_names = [
        ("v1", "PP"),
        ("v2", "MS"),
        ("v3", "Hybrid")
    ]

    # indices of models to be mixed
    mixed_versions = ([3], [3]) # in this case v3 vs v3

    #################################
    # EXTRACT RANDOM MODEL

    random_model = load_predictions(random_model_file)
    random_accuracies = Dict{Int, Float64}()

    for ply in 1:100
        predictions = filter(pred -> pred.ply_number == ply, random_model)
        random_accuracies[ply] = accuracy(predictions)
    end

    #################################
    # PLOT URGENCY MODEL

    plt = plot(dpi=500, fontfamily="serif-roman", title="Accuracy per Ply of Urgency Models", xlabel="Ply", ylabel="Accuracy", legend=:topright, tickfontsize=14, guidefontsize=14, legendfontsize=14, titlefontsize=17, top_margin=8mm, bottom_margin=8mm)
    ylims!(0, 0.6)

    accuracies = Dict{String, Dict{Int, Float64}}() # for every model, for every ply

    for (version, version_name) in urgency_model_version_names
        prediction_file = urgency_model_base_name * version * "_trained_on_" * string(trained_on) * "_id_" * string(model_id) * ".bin"

        if !isfile(prediction_file)
            @warn "Prediction file $prediction_file does not exist - skipping"
            continue
        end

        model = load_predictions(prediction_file)

        accuracies[version_name] = Dict{Int, Float64}()
        for ply in 1:100
            predictions = filter(pred -> pred.ply_number == ply, model)
            accuracies[version_name][ply] = accuracy(predictions)
        end
    end
    accuracies["Random Choice"] = random_accuracies

    plys = collect(1:100)
    model_names = vcat([version_name for (_, version_name) in urgency_model_version_names], ["Random Choice"])

    for model_name in model_names
        plot!(plys, [accuracies[model_name][ply] for ply in plys], label=model_name, lw=3)
    end

    savefig(plt, "./plots/urgency_model_per_ply.png")

    #################################
    # PLOT BOARDVAL MODEL

    plt2 = plot(dpi=500, fontfamily="serif-roman", title="Accuracy per Ply of BoardVal Models", xlabel="Ply", ylabel="Accuracy", legend=:topright, tickfontsize=14, guidefontsize=14, legendfontsize=14, titlefontsize=17, top_margin=8mm, bottom_margin=8mm)
    ylims!(0, 0.6)

    accuracies = Dict{String, Dict{Int, Float64}}() # for every model, for every ply

    for (version, version_name) in boardval_model_version_names
        prediction_file = boardval_model_base_name * version * "_trained_on_" * string(trained_on) * "_id_" * string(model_id) * ".bin"

        if !isfile(prediction_file)
            @warn "Prediction file $prediction_file does not exist - skipping"
            continue
        end

        model = load_predictions(prediction_file)

        accuracies[version_name] = Dict{Int, Float64}()
        for ply in 1:100
            predictions = filter(pred -> pred.ply_number == ply, model)
            accuracies[version_name][ply] = accuracy(predictions)
        end
    end

    accuracies["Random Choice"] = random_accuracies

    plys = collect(1:100)
    model_names = vcat([version_name for (_, version_name) in boardval_model_version_names], ["Random Choice"])

    for model_name in model_names
        plot!(plys, [accuracies[model_name][ply] for ply in plys], label=model_name, lw=3)
    end

    savefig(plt2, "./plots/boardval_model_per_ply.png")

    #################################
    # PLOT MIXED

    plt3 = plot(dpi=500, fontfamily="serif-roman", title="Accuracy per Ply\n(Urgency vs. BoardVal Model)", xlabel="Ply", ylabel="Accuracy", legend=:topright, tickfontsize=14, guidefontsize=14, legendfontsize=14, titlefontsize=17, top_margin=8mm, bottom_margin=8mm)
    ylims!(0, 0.6)

    accuracies = Dict{String, Dict{Int, Float64}}() # for every model, for every ply

    for (version, version_name) in urgency_model_version_names[mixed_versions[1]]
        prediction_file = urgency_model_base_name * version * "_trained_on_" * string(trained_on) * "_id_" * string(model_id) * ".bin"

        if !isfile(prediction_file)
            @warn "Prediction file $prediction_file does not exist - skipping"
            continue
        end

        model = load_predictions(prediction_file)

        accuracies["Urgency Model ($version_name)"] = Dict{Int, Float64}()
        for ply in 1:100
            predictions = filter(pred -> pred.ply_number == ply, model)
            accuracies["Urgency Model ($version_name)"][ply] = accuracy(predictions)
        end
    end

    for (version, version_name) in boardval_model_version_names[mixed_versions[2]]
        prediction_file = boardval_model_base_name * version * "_trained_on_" * string(trained_on) * "_id_" * string(model_id) * ".bin"

        if !isfile(prediction_file)
            @warn "Prediction file $prediction_file does not exist - skipping"
            continue
        end

        model = load_predictions(prediction_file)

        accuracies["BoardVal Model ($version_name)"] = Dict{Int, Float64}()
        for ply in 1:100
            predictions = filter(pred -> pred.ply_number == ply, model)
            accuracies["BoardVal Model ($version_name)"][ply] = accuracy(predictions)
        end
    end

    accuracies["Random Choice"] = random_accuracies

    plys = collect(1:100)
    model_names = vcat(["Urgency Model ($version_name)" for (_, version_name) in urgency_model_version_names[mixed_versions[1]]], ["BoardVal Model ($version_name)" for (_, version_name) in boardval_model_version_names[mixed_versions[2]]], ["Random Choice"])

    colors = [:red, :black, 4]
    for (i, model_name) in enumerate(model_names)
        plot!(plys, [accuracies[model_name][ply] for ply in plys], label=model_name, lw=3, color=colors[i])
    end

    savefig(plt3, "./plots/mixed_model_per_ply.png")

    #################################
    # DISPLAY PLOTS

    run(`open ./plots/urgency_model_per_ply.png`)
    run(`open ./plots/boardval_model_per_ply.png`)
    run(`open ./plots/mixed_model_per_ply.png`)
end


function plot_per_move_type(model_id::Int, trained_on::Int)
    @info "Plotting accuracy per move type for model $model_id trained on $trained_on"

    #################################
    # CONFIGURATION
    folder = "./data/predictions"

    random_model_file = "$(folder)/random_model_id_$(model_id).bin"

    urgency_model_base_name = "$(folder)/urgency_model_"
    urgency_model_version_names = [
        ("v1", "MT"),
        ("v2", "PT"),
        ("v3", "Hybrid")
    ]

    boardval_model_base_name = "$(folder)/boardval_model_"
    boardval_model_version_names = [
        ("v1", "PP"),
        ("v2", "MS"),
        ("v3", "Hybrid")
    ]

    # indices of models to be mixed
    mixed_versions = ([3], [3]) # in this case v3 vs v3

    move_types = [
        (QUIET, "Quiet"),
        (DOUBLE_PAWN_PUSH, "Double\nPush"),
        (KING_CASTLE, "King\nCastle"),
        (QUEEN_CASTLE, "Queen\nCastle"),
        (CAPTURE, "Capture"),
        (EN_PASSANT, "En\nPassant"),
        (PROMOTION, "Promotion")
    ]


    #################################
    # EXTRACT RANDOM MODEL
    random_model = load_predictions(random_model_file)
    random_accuracies = Dict{String, Float64}()
    move_counts = Dict{String, Int}() # for every move type

    for (move_type, label) in move_types
        if move_type == PROMOTION
            predictions = filter(mv -> mv.move_type & PROMOTION != 0, random_model)
        else
            predictions = filter(mv -> mv.move_type == move_type, random_model)
        end

        random_accuracies[label] = accuracy(predictions)
        move_counts[label] = length(predictions)
    end

    for (_, label) in move_types
        println("$label: $(move_counts[label]) -> $(round((move_counts[label] / sum(values(move_counts))) * 100, digits=2))")
    end

    #################################
    # PLOT URGENCY MODEL

    plt = plot(dpi=500, fontfamily="serif-roman", title="Accuracy per Move Type of Urgency Models", xlabel="Move Type", ylabel="Accuracy", legend=:topright, tickfontsize=14, guidefontsize=14, legendfontsize=11, titlefontsize=17, top_margin=8mm, bottom_margin=8mm, xrotation=45)
    ylims!(0, 1.0)

    accuracies = Dict{String, Dict{String, Float64}}() # for every model, for every move type

    for (version, version_name) in urgency_model_version_names
        prediction_file = urgency_model_base_name * version * "_trained_on_" * string(trained_on) * "_id_" * string(model_id) * ".bin"

        if !isfile(prediction_file)
            @warn "Prediction file $prediction_file does not exist - skipping"
            continue
        end

        model = load_predictions(prediction_file)

        accuracies[version_name] = Dict{String, Float64}()
        for (move_type, label) in move_types
            if move_type == PROMOTION
                predictions = filter(mv -> mv.move_type & PROMOTION != 0, model)
            else
                predictions = filter(mv -> mv.move_type == move_type, model)
            end

            accuracies[version_name][label] = accuracy(predictions)
        end
    end
    accuracies["Random"] = random_accuracies

    type_names = [label for (_, label) in move_types]
    model_names = vcat([version_name for (_, version_name) in urgency_model_version_names], ["Random"])

    x_labels = repeat(type_names, outer=length(model_names))
    group_labels = repeat(model_names, inner=length(type_names))
    accuracy_matrix = zeros(length(type_names), length(model_names))

    for (i, model_name) in enumerate(model_names)
        for (j, type_name) in enumerate(type_names)
            accuracy_matrix[j, i] = accuracies[model_name][type_name]
        end
    end

    println("Urgency Model")
    for (i, (_, label)) in enumerate(move_types)
        println("$label: ", Dict(zip(model_names, accuracy_matrix[i, :])))
    end

    groupedbar!(x_labels, accuracy_matrix, group=group_labels, bar_position = :dodge, bar_width = 0.5, color=[3 1 2 4])

    savefig(plt, "./plots/urgency_model_per_move_type.png")

    #################################
    # PLOT BOARDVAL MODEL

    plt2 = plot(dpi=500, fontfamily="serif-roman", title="Accuracy per Move Type of BoardVal Models", xlabel="Move Type", ylabel="Accuracy", legend=:topleft, tickfontsize=14, guidefontsize=14, legendfontsize=11, titlefontsize=17, top_margin=8mm, bottom_margin=8mm, xrotation=45)
    ylims!(0, 1.0)

    accuracies = Dict{String, Dict{String, Float64}}() # for every model, for every move type

    for (version, version_name) in boardval_model_version_names
        prediction_file = boardval_model_base_name * version * "_trained_on_" * string(trained_on) * "_id_" * string(model_id) * ".bin"

        if !isfile(prediction_file)
            @warn "Prediction file $prediction_file does not exist - skipping"
            continue
        end

        model = load_predictions(prediction_file)

        accuracies[version_name] = Dict{String, Float64}()
        for (move_type, label) in move_types
            if move_type == PROMOTION
                predictions = filter(mv -> mv.move_type & PROMOTION != 0, model)
            else
                predictions = filter(mv -> mv.move_type == move_type, model)
            end

            accuracies[version_name][label] = accuracy(predictions)
        end
    end

    accuracies["Random"] = random_accuracies

    type_names = [label for (_, label) in move_types]
    model_names = vcat([version_name for (_, version_name) in boardval_model_version_names], ["Random"])

    x_labels = repeat(type_names, outer=length(model_names))
    group_labels = repeat(model_names, inner=length(type_names))

    accuracy_matrix = zeros(length(type_names), length(model_names))

    for (i, model_name) in enumerate(model_names)
        for (j, type_name) in enumerate(type_names)
            accuracy_matrix[j, i] = accuracies[model_name][type_name]
        end
    end

    println("BoardVal Model")
    for (i, (_, label)) in enumerate(move_types)
        println("$label: ", Dict(zip(model_names, accuracy_matrix[i, :])))
    end

    groupedbar!(x_labels, accuracy_matrix, group=group_labels, bar_position = :dodge, bar_width = 0.5, color=[3 2 1 4])

    savefig(plt2, "./plots/boardval_model_per_move_type.png")

    #################################
    # PLOT MIXED

    plt3 = plot(dpi=500, fontfamily="serif-roman", title="Accuracy per Move Type\n(Urgency vs. BoardVal Model)", xlabel="Move Type", ylabel="Accuracy", legend=:topleft, tickfontsize=14, guidefontsize=14, legendfontsize=10, titlefontsize=17, top_margin=8mm, bottom_margin=8mm, xrotation=45)
    ylims!(0, 1.0)

    accuracies = Dict{String, Dict{String, Float64}}() # for every model, for every move type

    for (version, version_name) in urgency_model_version_names[mixed_versions[1]]
        prediction_file = urgency_model_base_name * version * "_trained_on_" * string(trained_on) * "_id_" * string(model_id) * ".bin"

        if !isfile(prediction_file)
            @warn "Prediction file $prediction_file does not exist - skipping"
            continue
        end

        model = load_predictions(prediction_file)

        accuracies["Urgency Model ($version_name)"] = Dict{String, Float64}()
        for (move_type, label) in move_types
            if move_type == PROMOTION
                predictions = filter(mv -> mv.move_type & PROMOTION != 0, model)
            else
                predictions = filter(mv -> mv.move_type == move_type, model)
            end

            accuracies["Urgency Model ($version_name)"][label] = accuracy(predictions)
        end
    end

    for (version, version_name) in boardval_model_version_names[mixed_versions[2]]
        prediction_file = boardval_model_base_name * version * "_trained_on_" * string(trained_on) * "_id_" * string(model_id) * ".bin"

        if !isfile(prediction_file)
            @warn "Prediction file $prediction_file does not exist - skipping"
            continue
        end

        model = load_predictions(prediction_file)

        accuracies["BoardVal Model ($version_name)"] = Dict{String, Float64}()
        for (move_type, label) in move_types
            if move_type == PROMOTION
                predictions = filter(mv -> mv.move_type & PROMOTION != 0, model)
            else
                predictions = filter(mv -> mv.move_type == move_type, model)
            end

            accuracies["BoardVal Model ($version_name)"][label] = accuracy(predictions)
        end
    end

    accuracies["Random Choice"] = random_accuracies

    type_names = [label for (_, label) in move_types]
    model_names = vcat(["Urgency Model ($version_name)" for (_, version_name) in urgency_model_version_names[mixed_versions[1]]], ["BoardVal Model ($version_name)" for (_, version_name) in boardval_model_version_names[mixed_versions[2]]], ["Random Choice"])

    x_labels = repeat(type_names, outer=length(model_names))
    group_labels = repeat(model_names, inner=length(type_names))

    accuracy_matrix = zeros(length(type_names), length(model_names))

    for (i, model_name) in enumerate(model_names)
        for (j, type_name) in enumerate(type_names)
            accuracy_matrix[j, i] = accuracies[model_name][type_name]
        end
    end

    println("Mixed Model")
    for (i, (_, label)) in enumerate(move_types)
        println("$label: ", Dict(zip(model_names, accuracy_matrix[i, :])))
    end

    groupedbar!(x_labels, accuracy_matrix, group=group_labels, bar_position = :dodge, bar_width = 0.5, color=[:black 4 :red])

    savefig(plt3, "./plots/mixed_model_per_move_type.png")

    #################################
    # DISPLAY PLOTS

    run(`open ./plots/urgency_model_per_move_type.png`)
    run(`open ./plots/boardval_model_per_move_type.png`)
    run(`open ./plots/mixed_model_per_move_type.png`)
end


# function plot_vs_number_of_possible_moves()
#     model = load_predictions("./data/predictions/model_a.bin")


#     # Initialize an empty array to store the count of predictions for each move type
#     move_counts = Vector{Int}()
#     accuracies = Vector{Float64}()

#     for nr_of_possible_moves in 1:maximum([length(pred.predicted_values) for pred in model])
#         # Filter predictions based on move type
#         predictions = filter(mv -> length(mv.predicted_values) == nr_of_possible_moves, model)
        
#         # Append the count of predictions to the move_counts array
#         if length(predictions) == 0
#             push!(move_counts, 0)
#             push!(accuracies, 0)
#             continue
#         else 
#             push!(move_counts, length(predictions))
#             push!(accuracies, accuracy(predictions))
#         end
#     end

#     max_count = maximum(move_counts)  # Find the max count to normalize the widths
#     bar_widths = [count / max_count for count in move_counts]  # Normalize counts

#     # Generate the bar plot with vertical ylabel
#     plt = bar(1:maximum([length(pred.predicted_values) for pred in model]), accuracies, bar_width=bar_widths, legend=false, 
#               title="Accuracy vs. Number of Possible Moves", ylabel="Accuracy", xlabel="Number of Possible Moves", yaxis=[0, 1])
    
#     # Set ylabel to be vertical (rotation=90 degrees)
#     ylabel!("Count", rotation=90)

#     return plt
# end


function visualize_piece_sq(model_id::Int, trained_on::Int, feature_set_name::String)
    model_b_piece = load_model("./data/models/boardval_model_$(feature_set_name)_trained_on_$(trained_on)_id_$(model_id).bin")
    
    pieces = [
        (WHITE_PAWN, "White Pawn"),
        (WHITE_KNIGHT, "White Knight"),
        (WHITE_BISHOP, "White Bishop"),
        (WHITE_ROOK, "White Rook"),
        (WHITE_QUEEN, "White Queen"),
        (WHITE_KING, "White King"),
        (BLACK_PAWN, "Black Pawn"),
        (BLACK_KNIGHT, "Black Knight"),
        (BLACK_BISHOP, "Black Bishop"),
        (BLACK_ROOK, "Black Rook"),
        (BLACK_QUEEN, "Black Queen"),
        (BLACK_KING, "Black King")
    ]

    for (piece, label) in pieces
        plt = plot(dpi=500, fontfamily="serif-roman", title="Visualization of Feature Set (PP)\n" * L"\mu" * "-Value of $(label) x Square", xlabel="File", ylabel="Rank", tickfontsize=14, guidefontsize=14, legendfontsize=14, titlefontsize=17, right_margin=15mm, left_margin=15mm, top_margin=8mm)
    
        mus = Matrix{Float64}(undef, 8, 8)
        for row in 0:7
            for col in 0:7
                sq = row * 8 + col
                feature_id = ((UInt(piece) << 6) | UInt(sq))
                mu = (haskey(model_b_piece, feature_id) ? mean(model_b_piece[feature_id]) : 0)
                mus[row + 1, col + 1] = mu
            end
        end

        clim = (-maximum(abs.(mus)), maximum(abs.(mus)))
        heatmap!(mus, aspect_ratio=1, c=:vik, clim=clim)
        xticks!([1, 2, 3, 4, 5, 6, 7, 8], ["a", "b", "c", "d", "e", "f", "g", "h"])
        yticks!([1, 2, 3, 4, 5, 6, 7, 8], ["1", "2", "3", "4", "5", "6", "7", "8"])

        savefig(plt, "./plots/boardval_model_visualization_piece_sq_$(join(lowercase.(split(label)), "_")).png")

        run(`open ./plots/boardval_model_visualization_piece_sq_$(join(lowercase.(split(label)), "_")).png`)
    end
end

function visualize_move(model_id::Int, trained_on::Int, feature_set_name::String)
    model_a_piece = load_model("./data/models/urgency_model_$(feature_set_name)_trained_on_$(trained_on)_id_$(model_id).bin")

    pieces = [
        (WHITE_PAWN, "White Pawn"),
        (WHITE_KNIGHT, "White Knight"),
        (WHITE_BISHOP, "White Bishop"),
        (WHITE_ROOK, "White Rook"),
        (WHITE_QUEEN, "White Queen"),
        (WHITE_KING, "White King"),
        (BLACK_PAWN, "Black Pawn"),
        (BLACK_KNIGHT, "Black Knight"),
        (BLACK_BISHOP, "Black Bishop"),
        (BLACK_ROOK, "Black Rook"),
        (BLACK_QUEEN, "Black Queen"),
        (BLACK_KING, "Black King")
    ]

    for (piece, label) in pieces
        plt = plot(dpi=500, fontfamily="serif-roman", title="Visualization of Moves (PT)\n" * L"\mu" * "-Value of src x dst x $(label)", xlabel="Destination Square", ylabel="Source Square", tickfontsize=12, guidefontsize=14, legendfontsize=14, titlefontsize=17, right_margin=15mm, left_margin=15mm, top_margin=8mm)
   
        xs = collect(0:63)
        ys = collect(0:63)
        zs = Matrix{Float64}(undef, 64, 64)

        for x in xs
            for y in ys
                move_id = ((UInt(x) << 10) | (UInt(y) << 4) | UInt(piece))
                mu = (haskey(model_a_piece, move_id) ? mean(model_a_piece[move_id]) : 0)
                zs[x+1, y+1] = mu
            end
        end


        clim = (-maximum(abs.(zs)), maximum(abs.(zs)))

        heatmap!(zs, aspect_ratio=1, c=:bwr, clim=clim, xlabel="Destination Square", ylabel="Source Square")
        xticks!(collect(1:7:64))
        yticks!(collect(1:7:64))

        savefig(plt, "./plots/urgency_model_visualization_move_$(join(lowercase.(split(label)), "_")).png")

        run(`open ./plots/urgency_model_visualization_move_$(join(lowercase.(split(label)), "_")).png`)
    end
end

function plot_all(model_id::Int, trained_on::Int)
    # plot_overall_accuracy(model_id, trained_on)
    # plot_top_k_accuracy(model_id, trained_on)
    # plot_accuracy_over_time(model_id)
    # plot_per_move_type(model_id, trained_on)
    # plot_per_ply(model_id, trained_on)
    visualize_piece_sq(model_id, trained_on, "v1")
    visualize_move(model_id, trained_on, "v2")
end