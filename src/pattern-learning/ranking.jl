function extract_feature_name(feature::UInt64)
    piece = feature ÷ 64
    square = feature % 64
    piece_name = CHARACTERS[piece]
    square_name = string(Char('a' + square % 8), Char('1' + square ÷ 8))
    return "$square_name-$piece_name"
end


function print_board_feature_map(boards::AbstractArray)
    feature_set = Set{UInt64}()
    for board in boards
        for feature in board
            push!(feature_set, feature)
        end
    end

    print("\033[44m")
    print("Board\\Feature:")
    for feature1 in feature_set
        print("\t$feature1")
    end
    print("\033[0m")

    print("\n\033[44m")
    print("\t")
    for feature1 in feature_set
        print("\t$(extract_feature_name(feature1))")
    end
    print("\033[0m")

    # for every board, print x if feature is in board, else print 0
    for (i,board) in enumerate(boards)
        print("\n$i")
        if i == 1
            print(" (winner)")
        else 
            print("\t")
        end
        for feature1 in feature_set
            if feature1 in board
                print("\tx")
            else
                print("\t ")
            end
        end
        
    end
end


function ranking_update_by_sampling!(urgencies::Dict{UInt64, Gaussian}, weights::Dict{Tuple{UInt64, UInt64}, Gaussian}, boards::AbstractArray; no_samples=1000, beta=1.0)
    # extract a set of all features in all boards
    feature_set = Set{UInt64}()
    for board in boards
        for feature in board
            if !haskey(urgencies, feature)
                urgencies[feature] = GaussianByMeanVariance(0.0, 1.0)
            end
            push!(feature_set, feature)
        end
    end

    print_board_feature_map(boards)

    # ensure that all weights (=combinations of feature1, feature2) are initialized
    for feature1 in feature_set
        for feature2 in feature_set
            if !haskey(weights, (feature1, feature2))
                weights[(feature1, feature2)] = GaussianByMeanVariance(-0.35, 0.5)
            end
        end
    end

    # no_sample many times -> for every feature combination -> sample weight
    weights_samples = Vector{Dict{Tuple{UInt64, UInt64}, Float64}}(undef, no_samples)
    # no_sample many times -> for every feature -> sample urgency
    urgencies_samples = Vector{Dict{UInt64, Float64}}(undef, no_samples)
    # no_sample many times -> for every board -> for every feature -> sample latent urgency
    latent_urgencies_samples = Vector{Vector{Dict{UInt64, Float64}}}(undef, no_samples)
    # no_sample many times -> for every board -> for every feature -> sum up all weights of active rows
    sum_of_rows_samples = Vector{Vector{Dict{UInt64, Float64}}}(undef, no_samples)
    # no_sample many times -> for every board -> for every feature -> mask for active rows
    mask_samples = Vector{Vector{Dict{UInt64, Float64}}}(undef, no_samples)
    # no_sample many times -> for every board -> for every feature -> mask out/in latent urgencies with mask
    masked_urgencies_samples = Vector{Vector{Dict{UInt64, Float64}}}(undef, no_samples)
    # no_sample many times -> for every board -> sum of all latent urgencies
    values_samples = Vector{Vector{Float64}}(undef, no_samples)

    for i in 1:no_samples
        weights_sample = Dict{Tuple{UInt64, UInt64}, Float64}()
        urgencies_sample = Dict{UInt64, Float64}()
        for feature1 in feature_set
            for feature2 in feature_set
                weight = weights[(feature1, feature2)]
                weights_sample[(feature1, feature2)] = rand(Normal(gmean(weight), sqrt(variance(weight))))
            end
            urgency = urgencies[feature1]
            urgencies_sample[feature1] = rand(Normal(gmean(urgency), sqrt(variance(urgency))))
        end
        weights_samples[i] = weights_sample
        urgencies_samples[i] = urgencies_sample

        sum_of_rows_all_boards = Vector{Dict{UInt64, Float64}}(undef, length(boards))
        mask_all_boards = Vector{Dict{UInt64, Float64}}(undef, length(boards))
        latent_urgencies_all_boards = Vector{Dict{UInt64, Float64}}(undef, length(boards))
        masked_urgencies_all_boards = Vector{Dict{UInt64, Float64}}(undef, length(boards))
        values_all_boards = Vector{Float64}(undef, length(boards))

        for (k,board) in enumerate(boards)
            sum_of_rows = Dict{UInt64, Float64}()
            mask = Dict{UInt64, Float64}()
            latent_urgencies = Dict{UInt64, Float64}()
            masked_urgencies = Dict{UInt64, Float64}()
            value = 0.0

            for feature in board
                latent_urgencies[feature] = rand(Normal(urgencies_sample[feature], beta))

                sum_of_row = 0.0
                for feature2 in board
                    sum_of_row += weights_sample[(feature, feature2)]
                end
                sum_of_rows[feature] = sum_of_row
                mask[feature] = (sum_of_row > 0.0) ? 1.0 : 0.0
                masked_urgencies[feature] = latent_urgencies[feature] * mask[feature]
                value += masked_urgencies[feature]
            end

            latent_urgencies_all_boards[k] = latent_urgencies
            sum_of_rows_all_boards[k] = sum_of_rows
            mask_all_boards[k] = mask
            masked_urgencies_all_boards[k] = masked_urgencies
            values_all_boards[k] = value

        end

        latent_urgencies_samples[i] = latent_urgencies_all_boards
        sum_of_rows_samples[i] = sum_of_rows_all_boards
        mask_samples[i] = mask_all_boards
        masked_urgencies_samples[i] = masked_urgencies_all_boards
        values_samples[i] = values_all_boards
    end

    print("\n\n\033[44m")
    print("Mask\\Feature")
    for feature1 in feature_set
        print("\t$(feature1)")
    end
    print("\033[0m")

    print("\n\033[44m")
    print("\t")
    for feature1 in feature_set
        print("\t$(extract_feature_name(feature1))")
    end
    print("\033[0m")

    for (k,board) in enumerate(boards)
        print("\nprio $k\t")
        for feature in feature_set
            if (feature in board)
                avg = 0.0
                for i = 1:no_samples
                    avg += mask_samples[i][k][feature]
                end
                avg /= no_samples
                print("\t$(round(avg, digits=3))")
            else
                print("\t ")
            end
        end

        print("\npost $k\t")
        for feature in feature_set
            if (feature in board)
                prior_avg = 0.0
                post_avg = 0.0
                post_cnt = 0
                for i = 1:no_samples
                    prior_avg += mask_samples[i][k][feature]
                    if count(x -> x >= values_samples[i][1], values_samples[i]) == 1
                        post_avg += mask_samples[i][k][feature]
                        post_cnt += 1
                    end
                end
                prior_avg /= no_samples
                post_avg /= post_cnt
                if abs(post_avg - prior_avg) < 1e-3
                    print("\t$(round(post_avg, digits=3))")
                elseif post_avg > prior_avg
                    print("\t\033[32m$(round(post_avg, digits=3))\033[0m")
                else
                    print("\t\033[31m$(round(post_avg, digits=3))\033[0m")
                end                        
            else
                print("\t ")
            end
        end
    end

    print("\n\n\033[44m")
    print("Urgency\t")
    for feature1 in feature_set
        print("\t$(feature1)")
    end
    print("\033[0m")

    print("\n\033[44m")
    print("\t")
    for feature1 in feature_set
        print("\t$(extract_feature_name(feature1))")
    end
    print("\033[0m")

    print("\nprior\t")
    for feature in feature_set
        avg = 0.0
        avg_squared = 0.0
        for i = 1:no_samples
            avg += urgencies_samples[i][feature]
            avg_squared += urgencies_samples[i][feature]^2
        end
        avg /= no_samples
        avg_squared /= no_samples

        print("\t$(round(avg, digits=3)) ± $(round(sqrt(avg_squared - avg^2), digits=3))")
    end

    print("\nposterior")
    for feature in feature_set
        prior_avg = 0.0
        prior_avg_squared = 0.0
        post_avg = 0.0
        post_avg_squared = 0.0
        post_cnt = 0
        for i = 1:no_samples
            prior_avg += urgencies_samples[i][feature]
            prior_avg_squared += urgencies_samples[i][feature]^2
            if count(x -> x >= values_samples[i][1], values_samples[i]) == 1
                post_avg += urgencies_samples[i][feature]
                post_avg_squared += urgencies_samples[i][feature]^2
                post_cnt += 1
            end
        end
        prior_avg /= no_samples
        prior_avg_squared /= no_samples
        post_avg /= post_cnt
        post_avg_squared /= post_cnt

        if(abs(post_avg - prior_avg) < 1e-2)
            print("\t$(round(post_avg, digits=3)) ± $(round(sqrt(post_avg_squared - post_avg^2), digits=3))")
        elseif post_avg > prior_avg
            print("\t\033[32m$(round(post_avg, digits=3)) ± $(round(sqrt(post_avg_squared - post_avg^2), digits=3))\033[0m")
        else
            print("\t\033[31m$(round(post_avg, digits=3)) ± $(round(sqrt(post_avg_squared - post_avg^2), digits=3))\033[0m")
        end
    end
end

function ranking_update!(feature_values::ValueTable, boards::AbstractArray; loop_eps=1e-2, beta=1.0)
    board_values = Vector{Gaussian}()
    sum_factors = Vector{SumFactor}()

    # INITIALIZE FEATURE NODES, BOARD NODES AND SUM FACTORS
    for board in boards
        summands = Vector{Gaussian}()
        nr_of_features = length(board)
        for feature in board
            if isnothing(feature_values[feature])
                feature_values[feature] = GaussianByMeanVariance(0.0, 1.0 / nr_of_features)
            end

            push!(summands, feature_values[feature])
        end
        
        board_value = GaussianUniform()
        push!(board_values, board_value)
        push!(sum_factors, SumFactor(summands, board_value))
    end

    # INITIALIZE LATENT NODES AND FACTORS

    latent_values = Vector{Gaussian}()
    gaussian_mean_factors = Vector{GaussianMeanFactor}()

    for i in eachindex(board_values)
        latent_value = GaussianUniform()
        push!(latent_values, latent_value)
        push!(gaussian_mean_factors, GaussianMeanFactor(latent_value, board_values[i], beta^2))
    end

    # INITIALIZE DIFF NODES, DIFFERENCE FACTORS AND GREATER THAN FACTORS

    difference_values = Vector{Gaussian}()
    difference_factors = Vector{DifferenceFactor}()
    greather_than_factors = Vector{GreaterThanFactor}()

    for i in 2:length(latent_values)
        diff = GaussianUniform()
        push!(difference_values, diff)
        push!(difference_factors, DifferenceFactor(latent_values[1], latent_values[i], diff))
        push!(greather_than_factors, GreaterThanFactor(diff))
    end

    #############################################
    # SUM PRODUCT ALGORITHM

    # FORWARD-PASS: BOARD NODES
    for (i, factor) in enumerate(sum_factors)
        update_msg_to_sum!(factor)
    end


    # FORWARD-PASS: LATENT NODES
    for (i, factor) in enumerate(gaussian_mean_factors)
        update_msg_to_x!(factor)
    end

    # RUN UNTIL LOOP CONVERGES
    ϵ = 10 * loop_eps
    while ϵ > loop_eps
        ϵ = 0.0
        for (i, factor) in enumerate(difference_factors)
            ϵ = max(ϵ, update_msg_to_z!(factor))
            ϵ = max(ϵ, update_msg_to_x!(greather_than_factors[i]))
            ϵ = max(ϵ, update_msg_to_x!(factor))
        end
    end

    # BACKPASS: LATENT NODES
    for (i, factor) in enumerate(difference_factors)
        update_msg_to_y!(factor)
    end

    # BACKPASS: BOARD NODES
    for (i, factor) in enumerate(gaussian_mean_factors)
        update_msg_to_y!(factor)
    end

    # UPDATE FEATURE NODES
    for (i, factor) in enumerate(sum_factors)
        update_msg_to_summands!(factor)
    end
end
